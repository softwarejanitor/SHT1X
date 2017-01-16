HT1x Library
 *
 * Copyright 2009 Jonathan Oxer <jon@oxer.com.au> / <www.practicalarduino.com>
 * Based on previous work by:
 *    Maurice Ribble: <www.glacialwanderer.com/hobbyrobotics/?p=5>
 *    Wayne ?: <ragingreality.blogspot.com/2008/01/ardunio-and-sht15.html>
 *
 * Updated for Arduino 1.6.5 Library Manger by Joel Bartlett 
 * SparkFun Electronics 
 * September 16, 2015
 *
 * Ported from Arduino to Esquilo 20161215 Leeland Heins
 *
 * Manages communication with SHT1x series (SHT10, SHT11, SHT15)
 * temperature / humidity sensors from Sensirion (www.sensirion.com).
 */

const MSBFIRST = 0;
const LSBFIRST = 1;

class SHT1x
{
    _dataPin = 0;
    _clockPin = 0;

    constructor (dataPin, clockPin)
    {
        _dataPin = GPIO(dataPin);
        _clockPin = GPIO(clockPin);
        _dataPin.input();
        _clockPin.output();
    }
}


/* ================  Public methods ================ */
//Reads the current temperature in degrees Celsius

function SHT1x::readTemperatureC()
{
    local _val;          // Raw value returned from sensor
    local _temperature;  // Temperature derived from raw value

    // Conversion coefficients from SHT15 datasheet
    const D1 = -40.0;  // for 14 Bit @ 5V
    const D2 = 0.01;   // for 14 Bit DEGC

    // Fetch raw value
    _val = readTemperatureRaw();

    // Convert raw value to degrees Celsius
    _temperature = (_val * D2) + D1;

    return (_temperature);
}


////////////////////////////////////////////////////////////////////////
//Reads the current temperature in degrees Fahrenheit
function SHT1x::readTemperatureF()
{
    local _val;          // Raw value returned from sensor
    local _temperature;  // Temperature derived from raw value

    // Conversion coefficients from SHT15 datasheet
    local D1 = -40.0;  // for 14 Bit @ 5V
    local D2 = 0.018;  // for 14 Bit DEGF

    // Fetch raw value
    _val = readTemperatureRaw();

    // Convert raw value to degrees Fahrenheit
    _temperature = (_val * D2) + D1;

    return (_temperature);
}


////////////////////////////////////////////////////////////////////////
//Reads current temperature-corrected relative humidity
function SHT1x::readHumidity()
{
    local _val;                // Raw humidity value returned from sensor
    local _linearHumidity;     // Humidity with linear correction applied
    local _correctedHumidity;  // Temperature-corrected humidity
    local _temperature;        // Raw temperature value
  
    // Conversion coefficients from SHT15 datasheet
    //local C1 = -4.0;        // for V3 sensors
    //local C2 = 0.0405;      // for V3 sensors, 12-bit precision
    //local C3 = -0.0000028;  // for V3 sensors, 12-bit precision
    local C1 = -2.0468;     // for V4 sensors
    local C2 = 0.0367;      // for V4 sensors, 12-bit precision
    local C3 = -1.5955E-6;  // for V4 sensors, 12-bit precision
    local T1 = 0.01;        // for 14 Bit @ 5V
    local T2 = 0.00008;     // for 14 Bit @ 5V

    // Command to send to the SHT1x to request humidity
    local _gHumidCmd = 0x05;  // 0b00000101

    // Fetch the value from the sensor
    sendCommandSHT(_gHumidCmd);
    waitForResultSHT();
    _val = getData16SHT();
    skipCrcSHT();

    // Apply linear conversion to raw value
    _linearHumidity = C1 + C2 * _val + C3 * _val * _val;

    // Get current temperature for humidity correction
    _temperature = readTemperatureC();

    // Correct humidity value for current temperature
    _correctedHumidity = (_temperature - 25.0 ) * (T1 + T2 * _val) + _linearHumidity;

    return (_correctedHumidity);
}


/* ================  Private methods ================ */
function SHT1x::readTemperatureRaw()
{
    local _val;

    // Command to send to the SHT1x to request Temperature
    local _gTempCmd = 0x03;  // 0b00000011

    sendCommandSHT(_gTempCmd);
    waitForResultSHT();
    _val = getData16SHT();
    skipCrcSHT();

    return (_val);
}


////////////////////////////////////////////////////////////////////////
// commands for reading/sending data to a SHTx sensor 
function SHT1x::shiftIn(_numBits)
{
    local ret = 0;
    local i;
    local dp;

    _dataPin.input();
    
    for (i = 0; i < _numBits; ++i) {
        _clockPin.high();
        delay(10);  // I don't know why I need this, but without it I don't get my 8 lsb of temp
        dp =_dataPin.ishigh() ? 1 : 0;
        ret = (ret * 2) + dp;
        _clockPin.low();
    }

    return(ret);
}


////////////////////////////////////////////////////////////////////////
function shiftOut(bitOrder, val)
{
    local i;
    local vb;

    _dataPin.output();

    for (i = 0; i < 8; i++)  {
        if (bitOrder == LSBFIRST) {
            vb = !!(val & (1 << i));
        } else {
            vb = !!(val & (1 << (7 - i)));
        }
        
        if (vb) {
            _dataPin.high();
        } else {
            _dataPin.low();
        }
                
        _clockPin.high();
        _clockPin.low();            
    }
}

////////////////////////////////////////////////////////////////////////
// send a command to the SHTx sensor 
function SHT1x::sendCommandSHT(_command)
{
    local ack;

    // Transmission Start
    _dataPin.output();
    _clockPin.output();
    _dataPin.high();
    _clockPin.high();
    _dataPin.low();
    _clockPin.low();
    _clockPin.high();
    _dataPin.high();
    _clockPin.low();

    // The command (3 msb are address and must be 000, and last 5 bits are command)
    shiftOut(MSBFIRST, _command);

    // Verify we get the correct ack
    _clockPin.high();
    _dataPin.input();
    ack = _dataPin.ishigh();
    //if (ack != LOW) {
    //   //print("Ack Error 0\n");
    //}
    _clockPin.low();
    ack = _dataPin.ishigh();
    //if (ack != HIGH) {
    //    //print("Ack Error 1\n");
    //}
}


////////////////////////////////////////////////////////////////////////
// wait for the SHTx answer 
function SHT1x::waitForResultSHT()
{
    local i;
    local ack;

    _dataPin.input();

    for (i = 0; i < 100; ++i) {
        delay(10);
        ack = _dataPin.ishigh();

        if (ack == LOW) {
            break;
        }
    }

    //if (ack == HIGH) {
    //    //print("Ack Error 2\n");   // Can't do serial stuff here, need another way of reporting errors
    //}
}


////////////////////////////////////////////////////////////////////////
// get data from the SHTx sensor 
function SHT1x::getData16SHT()
{
    local val; 
 
    // get the MSB (most significant bits) 
    _dataPin.input(); 
    _clockPin.output(); 
    val = shiftIn(8); 
    val *= 256;  // this is equivalent to val << 8; 
  
    // send the required ACK 
    _dataPin.output(); 
    _dataPin.high(); 
    _dataPin.low(); 
    _clockPin.high(); 
    _clockPin.low(); 
  
    // get the LSB (less significant bits) 
    _dataPin.input(); 
    val = val | shiftIn(8); 
  
    return val; 
}


////////////////////////////////////////////////////////////////////////
function SHT1x::skipCrcSHT()
{
    // Skip acknowledge to end trans (no CRC)
    _dataPin.output();
    _clockPin.output();

    _dataPin.high();
    _clockPin.high();
    _clockPin.low();
}

