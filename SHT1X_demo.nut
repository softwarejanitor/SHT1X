require("GPIO");

dofile("sd:/SHT1X.nut");

local sht = SHT1x(8, 9);

local tempC = sht.readTemperatureC();

print("tempC=" + tempC + "\n");

local tempF = sht.readTemperatureF();

print("tempF=" + tempF + "\n");

local hum = sht.readHumidity();

print("humidity=" + hum + "\n");

