return {
	on = {
		devices = {
			2, -- 2 Living room -- 3  Bedroom -- 4  Bathroom -- 5 Guest room -- 6 Office, --35 Kitching
			3,
			4,
			5,
			6,
			35
		}
	},
	logging = {
		--level = domoticz.LOG_INFO,
		marker = "evohome_push"
	},
	data = {
		-- Store temp and setpoints in table
		lasttemperature = { initial = {} },
		lastsetpoint2 = { initial = {} },
		-- Influx database URI, including database name
		influxURI = { initial = 'http://localhost:8086/write?db=DATABASE&precision=s' }
	},
	execute = function(dz, dev)
		-- if temp or setpoint changed, push to influxdb
		if (dev.temperature ~= dz.data.lasttemperature[dev.name] or 
			dev.setPoint ~= dz.data.lastsetpoint2[dev.name]) then
			dz.data.lasttemperature[dev.name] = dev.temperature
			dz.data.lastsetpoint2[dev.name] = dev.setPoint
			dz.log('Device ' .. dev.name .. ' was changed. Temp: ' .. tostring(dev.temperature) .. ' setpoint: ' .. tostring(dev.setPoint), dz.LOG_INFO)
			
			-- Push new temperature to influxdb, both actual and setpoint. Strip 
			-- device names from spaces for tags in influxdb.
			dz.openURL({
				url = dz.data.influxURI,
				method = 'POST',
				postData = "temperature,type=heating,device="..dev.name:gsub("%s+", "")..",subtype=actual value=" .. tonumber(dev.temperature) .. 
				"\ntemperature,type=heating,device="..dev.name:gsub("%s+", "")..",subtype=setpoint value=" .. tonumber(dev.setPoint)
			})
		else
			dz.log('Device ' .. dev.name .. ' was not changed.')
		end
	end
}