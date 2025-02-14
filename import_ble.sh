#!/bin/bash

# Version Info
echo 'Mi Body Composition Scale 2 Garmin Connect v3.1 (import_ble.sh)'
echo ''

# Create a data backup file
path=`cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd`
if [ ! -f $path/backup.csv ] ; then
	echo '* Create a data backup file, checking for new data'
	echo 'Weight;Impedance;Unix_time;Readable_time' > $path/backup.csv
else echo '* Data backup file exists, checking for new data'
fi

# Checking device, create file with import data
if [ -z `hcitool dev | awk 'NR>1 {print $2}'` ] ; then
	echo '* No BLE device detected'
else read_all=`python3 -B $path/scanner_ble.py | awk 'END{print}'`
	 read_unixtime=`echo $read_all | awk -F ";" '{print $3}'`
	 nosec=`echo $read_all | awk -F ";" '{print $1";"$2";"substr($3,1,8)}'`
	if [ -z $read_unixtime ] ; then
		echo '* No BLE data from scale or incomplete'
	elif grep -q $nosec $path/backup.csv ; then
		echo '* There is no new data to upload to Garmin Connect'
	elif [ -f $path/$read_unixtime.tlog ] ; then
		echo '* Import file already exists, calculating data to upload'
	else echo $read_all > $path/$read_unixtime.tlog
		echo '* Importing and calculating data to upload'
	fi
fi

# Calculate data and export to Garmin Connect, logging, handling errors, backup file
if compgen -G $path/*.tlog > /dev/null ; then
	python3 -B $path/export_garmin.py > $path/temp.log 2>&1
	move=`awk -F ": " '/Processed file:/{print $2}' $path/temp.log`
	if grep -q 'Error\|panic\|denied\|There\|Exec' $path/temp.log ; then
		echo '* Upload to Garmin Connect has failed, check temp.log for error details'
	else cat $path/$move >> $path/backup.csv
		rm $path/$move
		echo '* Data upload to Garmin Connect is complete'
	fi
fi