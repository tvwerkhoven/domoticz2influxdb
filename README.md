# domoticz2influxdb - push data from domoticz to influxdb

This project consists of two branches

- Convert (offline) domoticz database to influxdb line format - `domoticz2influxdb.py`
- Live pushing of domoticz data to influxdb using dzVents - `domoticzpusher*.lua`

## Convert database to influx line format

`domoticz2influxdb.py` takes a domoticz database and converts this data to the
influxdb line format, which can subsequently be loaded as bulk data into 
influxdb through e.g. `curl` using 

    curl -i -XPOST "http://localhost:8086/write?db=mydb" --data-binary @data.txt

See https://docs.influxdata.com/influxdb/v1.7/tools/api#examples-6

## Live pushing of domoticz to influxdb

For live updating data read by domoticz into influxdb there is a set of 
dzVents / lua scripts that push data depending on the domoticz meter type.

- `evohomepusher.lua` - push evohome data
- `smartmeterpusher.lua` - push smartmeter (multimeter) data
- `weatherpusher.lua` - push weather data
