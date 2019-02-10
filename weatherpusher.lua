return {
	on = {
		devices = {
			8, -- Temp / humid / baro	Temp + Humidity + Baro	THB1 - BTHR918, BTHGN129	16.3 C, 85 %, 1012 hPa	
			9, -- Wind	Wind	TFA	252.00;WSW;0;0;16.3;16.3	
			-- 10, -- 	UV	UV	UVN128,UV138	0.0 UVI (not used)
			11, -- Rain	Rain	WWW	0;7.0	
			-- 12, -- Visibility (not used)
			13 -- Solar Radiation
		}
	},
	logging = {
		--level = domoticz.LOG_INFO,
		marker = "weather_push"
	},
	data = {
		lasttemperature = { },
		lastspeed = { },
		lastdirection = { },
		lastrainRate = { },
		lastradiation = { },
		-- Influx database URI, including database name
		influxURI = { initial = 'http://localhost:8086/write?db=DATABASE&precision=s' }
	},
	execute = function(dz, dev)
		if (dev.idx == 8) then
			if (dev.temperature ~= lasttemperature) then
				lasttemperature = dev.temperature
				-- Push to influxDB
				dz.openURL({
					url = dz.data.influxURI,
					method = 'POST',
					postData = 'temperature,type=weather,device=wunderground value=' .. tostring(dev.temperature)
				})
			end
		elseif (dev.idx == 9) then
			if (dev.speed ~= lastspeed or dev.direction ~= lastdirection) then
				lastspeed = dev.speed
				lastdirection = dev.direction
				--lasttemperature = dev.temperature -- superfluous with aboveidx 8 maybe
				-- Push to influxDB
				dz.openURL({
					url = dz.data.influxURI,
					method = 'POST',
					postData = 'wind,type=weather,device=wunderground value=' .. tostring(dev.speed) ..
					'\nwinddirection,type=weather,device=wunderground value=' .. tostring(dev.direction)
				})
			end
		elseif (dev.idx == 11) then
			if (dev.rainRate ~= lastrainRate) then
				lastrainRate = dev.rainRate
				dz.openURL({
					url = dz.data.influxURI,
					method = 'POST',
					postData = 'rain,type=weather,device=wunderground value=' .. tostring(dev.rainRate)
				})
			end
		elseif (dev.idx == 13) then
			if (dev.radiation ~= lastradiation) then
				lastradiation = dev.radiation
				dz.openURL({
					url = dz.data.influxURI,
					method = 'POST',
					postData = 'power,type=irradiance,device=PWS:IUTRECHT432 value=' .. tostring(dev.radiation)
				})
			end
		end
	end
}