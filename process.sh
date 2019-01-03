#!/bin/bash

### Store keywords into array
keywords=($(awk '{print $1}' keywords.txt)) 

### Declare arrays
declare -a pidArray
declare -a processArray

### Delete temp files in case it wasnt deleted and clear temp files 
rm -f temp.txt pid.csv
touch temp.txt pid.csv

function GetProcess () {
	server=$(hostname)	
	date=$(date +%m-%d-%Y"="%H:%M:%S)

	for (( i=0; i<${#keywords[@]}; i++ ))
	do	
		if [ -z "${keywords[$i]}" ]; then	#If keyword is null/empty move on 
			continue
		fi

	 	ps -e | grep ${keywords[$i]} | grep -v grep | awk '{print $1}' |while read PID #GET ALL PID PROCESSES THAT MATCH KEYWORD 
		do
			if /usr/xpg4/bin/grep -q "$PID" pid.csv;then #If pid has been scanned move on
				continue
			else 
				processName=$(ps -p "$PID" -o comm=) 
				user=$(ps -p $PID -o user= | tr -d '[:space:]')
				path=$(ls -l /proc/"$PID"/path/a.out | cut -d ">" -f 2 | awk '{$1=$1;print}')
				counter=1
				version='NONE'
				commandLine=$(ps -p "$PID" -o args= | tr -d '[:space:]')
				FirstDiscovered="$date"
				LastDiscovered="$date"

				### Error handling, move on if processName, user, path, or commandline are empty
				if [ -z "$processName" ] || [ -z "$user" ] || [ -z "$path" ] || [ -z "$commandLine" ]; then
					echo "$server,$processName,$user,$path,$commandLine,$date" >> error.txt
					continue
				fi
					
				if ls -l "$path" | /usr/xpg4/bin/egrep -q "x"; then #If path is an executable
					version=$("$path" -version 2>&1 | head -1 | cut -d '"' -f 2)
			
					#### Error handling, in case we have any issues with the version, set version to none	
					if echo "$version" | /usr/xpg4/bin/egrep -q "(No|Error|Such|File|Directory|ksh)";then
						version='NONE'
					fi
				fi
		
				line=$(echo "$server,$processName,$user,$path,$version,$counter,$commandLine,$FirstDiscovered,$LastDiscovered")
				if /usr/xpg4/bin/grep -q "$commandLine" temp.txt; then  #If command line was found in storage then increase counter,if no add to storage
					echo "$(/usr/xpg4/bin/awk -v command="$commandLine" 'BEGIN{FS=OFS=";"}{if($NF==command) $6+=1}1' temp.txt)" > temp.txt
				else
					printf "%s\n" "$server;$processName;$user;$path;$version;$counter;$FirstDiscovered;$LastDiscovered;$commandLine" >> temp.txt
				fi 
				
				printf '%s\n' "$PID" >> pid.csv
			fi
		done
	done 

	processArray=($(awk '{print $1}' temp.txt))
}

function CreateFile () {
	echo "Server;ProcessName;User;Path;Version;Counter;FirstDiscovered;LastDiscovered;CommandLine" > java_process.txt
	printf '%s\n' "${processArray[@]}" >> java_process.txt 
}

function ModifyFile () {
	for (( j=0; j<${#processArray[@]}; j++ ))
	do
		checkCommand=($(printf "%s\n" "${processArray[$j]}" | awk 'BEGIN{FS=";"} {print $NF}'))
		if /usr/xpg4/bin/grep -q "$checkCommand" file.csv; then #If command was found in storage , increment counter and change last discovered date
			runningCounter=$(/usr/xpg4/bin/awk -v command="$checkCommand" 'BEGIN{FS=OFS=";"}{if($NF==command) {print $6}}' temp.txt)
			echo "$(/usr/xpg4/bin/awk -v command="$checkCommand" -v rCounter="$runningCounter" -v discovered="$date" 'BEGIN{FS=OFS=";"}NR>1{if($NF==command)$6+=rCounter ; $8=discovered}1' java_process.txt)" > java_process.txt 
		else
			printf "%s\n" "${processArray[$j]}" >> java_process.txt 
		fi
	done
}

GetProcess
if [ ! -f java_process.txt ]; then
	echo 'Creating file' 
	CreateFile
elif [ -f java_process.txt ]; then
	echo 'File exists!'
	ModifyFile
fi
rm temp.txt pid.csv # remove temp files
