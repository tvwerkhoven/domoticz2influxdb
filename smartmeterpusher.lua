return {
	on = {
		devices = {
			1 -- Kaifa
		}
	},
	logging = {
		--level = domoticz.LOG_INFO,
		marker = "kaifa_push"
	},
	data = {
	    -- Power and energy values are always >0, such that -1 is a good initial 
	    -- value to check for changes. Could be nil as well I guess.
		lastusage1 = { initial = -1 },
		lastreturn1 = { initial = -1 },
		lastusage2 = { initial = -1 },
		lastreturn2 = { initial = -1 },
		lastusage = { initial = -1 },
		lastreturn = { initial = -1 },
		-- Influx database URI, including database name
		influxURI = { initial = 'http://localhost:8086/write?db=smarthome&precision=s' }
	},
	execute = function(dz, dev)
		if (dev.changed) then
			-- Although smart meters only update ONE of U1, R1, U2, or R2 each 
			-- time, we need to check all independently because if we sample 
			-- slowly (e.g. once per day), all values are different.
			upd_str = 'Device ' .. dev.name .. ' changed ' .. dev.lastUpdate.raw

			-- These parameters measure energy. Unit is Watt-hour (by default)
			if (dev.usage1 > dz.data.lastusage1 or 
				dev.return1 > dz.data.lastreturn1 or
				dev.usage2 > dz.data.lastusage2 or
				dev.return2 > dz.data.lastreturn2) then
				dz.data.lastusage1 = dev.usage1
				dz.data.lastreturn1 = dev.return1
				dz.data.lastusage2 = dev.usage2
				dz.data.lastreturn2 = dev.return2
				upd_str = upd_str .. ' U1: ' .. tostring(dev.usage1)
				upd_str = upd_str .. ' R1: ' .. tostring(dev.return1)
				upd_str = upd_str .. ' U2: ' .. tostring(dev.usage2)
				upd_str = upd_str .. ' R2: ' .. tostring(dev.return2)
				
				-- Push to influxDB here, as combined usage in Joule (SI unit).
				-- Because we sample data quickly, we don't need to store the 4 values:
				--  rate 1/2 can be reconstructed from the timestamp of the data
				--  return/usage can be reconstructed from positive or negative change
				kaifa_energy = (dev.usage1 - dev.return1 + dev.usage2 - dev.return2)*3600
				-- Format string as integer
				-- format v1
				dz.openURL({
					url = dz.data.influxURI,
					method = 'POST',
					postData = 'energy,type=elec,device=kaifa value=' .. string.format("%d", kaifa_energy)
				})

				-- Format string as integer
				-- format v2
				dz.openURL({
					url = dz.data.influxURI,
					method = 'POST',
					postData = 'energyv2 kaifa=' .. string.format("%d", kaifa_energy)
				})
			end

			-- These two parameters measure power, which are by definition positive
			if (dev.usage ~= dz.data.lastusage or dev.usageDelivered ~= dz.data.lastreturn) then
				dz.data.lastusage = dev.usage
				dz.data.lastreturn = dev.usageDelivered
				upd_str = upd_str .. ' U: ' .. tostring(dev.usage)
				upd_str = upd_str .. ' R: ' .. tostring(dev.usageDelivered)
				
				-- Push to influxDB here, as combined instantaneous power usage (or return).
				-- We can reconstruct usage and generation from positive or negative values
				-- format v1
				kaifa_power = dz.data.lastusage - dz.data.lastreturn
				dz.openURL({
					url = dz.data.influxURI,
					method = 'POST',
					postData = 'power,type=elec,device=kaifa value=' .. string.format("%d", kaifa_power)
				})

				-- format v2
				dz.openURL({
					url = dz.data.influxURI,
					method = 'POST',
					postData = 'powerv2 kaifa=' .. string.format("%d", kaifa_power)
				})

			end

			dz.log(upd_str, dz.LOG_INFO) -- Only while debugging
		end
	end
}

