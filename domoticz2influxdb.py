#!/usr/bin/env python
#
# Convert domoticz database to influxdb
#

### Settings
# influxdb query strings
METER_FORMAT="meter,device={dev_name},src=domoticz2influxdb value={value} counter={counter} {epoch_date:d}\n"
MULTIMETER_FORMAT="multimeter,device={dev_name},src=domoticz2influxdb counter1={counter1} counter2={counter2} counter3={counter3} counter4={counter4} {epoch_date:d}\n"
TEMPERATURE_FORMAT="temperature,type=heating,device={dev_name},subtype=actual,src=domoticz2influxdb temp={temp} setpoint={setpoint} {epoch_date:d}\n"

### Libraries
import sqlite3
import datetime as dt
import argparse

### Code starts here
def get_devices(dbpath):
	"""
	Return list of devices from DeviceStatus table. Additionally, check in 
	which data tables these devices occur (Temperature, Meter, MultiMeter)
	"""
	conn = sqlite3.connect(dbpath)
	c = conn.cursor()

	fields = "ID,Name,Type"
	query = "SELECT {} FROM DeviceStatus".format(fields)

	rows = c.execute(query)
	devices = {}
	for dev_id, dev_name, dev_type in rows:
		# E.g. (34, 'Amperage')
		devices[dev_id] = {'dev_name': dev_name, 'type': dev_type, 'table': 'unknown'}

	# Find out in which data tables the device data are stored
	check_tables = ["Temperature", "Meter", "MultiMeter"]
	for table in check_tables:
		query = "SELECT DISTINCT DeviceRowID FROM {}".format(table)
		rows = c.execute(query)
		for dev_id in rows:
			devices[dev_id[0]]['table'] = table

	return devices

def get_data(dbpath, dev_id, meterquery, multimeterquery, tempquery, outfile="./influx_data.csv"):
	# For any device, get device type, then query data using specialized
	# query functions
	devs = get_devices(dbpath)
	dev_name = devs[dev_id]['dev_name']

	if (devs[dev_id]['table'] == "Meter"):
		get_meter(dbpath, dev_id, dev_name, meterquery, outfile)
	elif (devs[dev_id]['table'] == "MultiMeter"):
		get_multimeter(dbpath, dev_id, dev_name, multimeterquery, outfile)
	elif (devs[dev_id]['table'] == "Temperature"):
		get_temperature(dbpath, dev_id, dev_name, tempquery, outfile)
	else:
		print ("Meter type not supported")

def get_meter(dbpath, dev_id, dev_name, query, outfile="./influx_data.csv"):
	"""
	Get meter data 
	"""
	conn = sqlite3.connect(dbpath)
	c = conn.cursor()

	t = (dev_id,)

	rows = c.execute("SELECT Value,Counter,Date FROM Meter_Calendar WHERE DeviceRowID = ?", t)
	with open(outfile, 'a') as writeFile:
		for value, counter, date in rows:
			# Example: "18.74, Living Room, 2018-11-14'"
			# Set date to midday local time by adding 12 hours
			date_epoch = int(dt.datetime.strptime(date, "%Y-%m-%d").timestamp()+ 12*3600) 
			# Contruct influxdb query
			row = query.format(dev_name=dev_name.replace(" ",""), value=value, counter=counter, epoch_date=date_epoch)
			writeFile.write(row)


def get_multimeter(dbpath, dev_id, dev_name, query, outfile="./influx_data.csv"):
	"""
	Get multimeter data 

	Source: DeviceRowID, Value1-6, Counter1-4, Date
	"""
	conn = sqlite3.connect(dbpath)
	c = conn.cursor()

	t = (dev_id,)

	rows = c.execute("SELECT Counter1,Counter2,Counter3,Counter4,Date FROM MultiMeter_Calendar WHERE DeviceRowID = ?", t)
	with open(outfile, 'a') as writeFile:
		for c1, c2, c3, c4, date in rows:
			# Set date to midday local time by adding 12 hours
			date_epoch = int(dt.datetime.strptime(date, "%Y-%m-%d").timestamp()+ 12*3600) 
			# Contruct influxdb query
			row = query.format(dev_name=dev_name.replace(" ",""), counter1=c1, counter2=c2, counter3=c3, counter4=c4, countersum=c1-c2+c3-c4, epoch_date=date_epoch)
			writeFile.write(row)

def get_temperature(dbpath, dev_id, dev_name, query, outfile="./influx_data.csv"):
	"""
	Get temperature sensor data
	Source: DeviceRowID, Temp_Min, Temp_Max, Temp_Avg, ... SetPoint_Min, SetPoint_Max, SetPoint_Avg, Date
	Target: temperature,<nametag>=<name>,type='heating',subtype='<actual|setpoint>' value=Temp_Avg <timestamp>
	"""
	conn = sqlite3.connect(dbpath)
	c = conn.cursor()

	t = (dev_id,)

	rows = c.execute("SELECT Temp_Avg,SetPoint_Avg,Date FROM Temperature_Calendar WHERE DeviceRowID = ?", t)
	with open(outfile, 'a') as writeFile:
		for temp, setpoint, date in rows:
			# Example: "18.74, Living Room, 2018-11-14'"
			# Set date to midday local time by adding 12 hours
			date_epoch = int(dt.datetime.strptime(date, "%Y-%m-%d").timestamp()+ 12*3600) 
			# Contruct influxdb query
			row = query.format(dev_name=dev_name.replace(" ",""), temp=temp, setpoint=setpoint, epoch_date=date_epoch)
			writeFile.write(row)


def main():
	parser = argparse.ArgumentParser(description='Convert domoticz database to influxdb.')

	parser.add_argument('--inspect', action='store_true',
		help='inspect database file and print available devices')

	parser.add_argument('--devids', metavar='id', type=int, nargs='*',
		help='device ids of sensors to process')
	
	parser.add_argument('--meterquery', metavar='query',
		default=METER_FORMAT, help='influxdb line query template to \
		format meter data. Available variables: dev_name, value, usage, \
		epoch_date')
	parser.add_argument('--multimeterquery', metavar='query',
		default=MULTIMETER_FORMAT, help='influxdb line query template to \
		format multimeter data. Available variables: dev_name, counter1, \
		counter2, counter3, counter4, epoch_date, countersum \
		(=counter1-counter2+counter3-counter4)')
	parser.add_argument('--tempquery', metavar='query',
		default=TEMPERATURE_FORMAT, help='influxdb line query template to \
		format temperature data. Available variables: dev_name, temp, \
		setpoint, epoch_date')

	parser.add_argument('--influxfile', type=str, metavar='path', 
		default='./influx_data.csv', help='file to store influxdb queries to')
	
	parser.add_argument('domoticzdb', type=str, metavar='path',
		help='domoticz database file to import')

	# Pre-process command-line arguments
	args = parser.parse_args()

	devices = get_devices(args.domoticzdb)
	if (args.inspect):
		for dev_id, dev_props in devices.items():
			print(dev_id, dev_props)
		return

	if (args.devids != None):
		for tid in args.devids:
			get_data(args.domoticzdb, tid, meterquery=args.meterquery, multimeterquery=args.multimeterquery, tempquery=args.tempquery, outfile=args.influxfile)


if __name__ == "__main__":
	main()
	exit()