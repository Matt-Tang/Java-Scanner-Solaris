#!/bin/bash

### Declare keywords and create temp file
keywords=($(awk '{print $1}'  keywords.txt))
rm -f temp.txt 
touch temp.txt 

function GetApplication() {
	server=$(hostname)
	date=$(date +%m/%d/%y"="%H:%M:%S)
	FirstDiscovered="$date"
	LastDiscovered="$date"
	
	#### Use different search commands depending on what is avaliable
	if type locate > /dev/null; then
		locateOutput=$(locate -ei 'java' 'jre' 'jdk' 'jvm')
	elif type find > /dev/null; then
		locateOutput=$(find / -name "java" -o -name "jre" -o -name "jdk" -o -name "jvm")	
	else
		locateOutput=''
	fi


	printf "%s\n" "$locateOutput" >> temp.txt
	pathArray=($(awk '{print $1}'  temp.txt)) #store file contents into array
	> temp.txt #clear the contents of the temp file

	for (( i=0; i<${#pathArray[@]}; i++ ))
	do
		path=${pathArray[$i]}
		echo "$i:"

		if [ -f "$path" ]; then
			IFS='/' read -r -a lineArray <<< "$path" #Break path into array by directory

			if [[ ${lineArray[*]: -1} == *"java"* ]] && [[ ${lineArray[*]: -1} != *"."* ]]; then #If it a java file and does not contain a period add to storage
				Add $server $path $FirstDiscovered $LastDiscovered
			else
				continue
			fi
	
		else
			### Trim path and remove last '/'
			Trim $path
			path=${path%?}

			if [[ -n "$path" ]] && !(/usr/xpg4/bin/grep -q "$path" temp.txt); then #If path is not empty and its not found in storage, add to storage
				Add $server $path $FirstDiscovered $LastDiscovered
			fi
		fi
	done

	applicationArray=($(awk '{print $1}'  temp.txt)) #Store file contents into array
}

function Add () {
	IFS='/' read -r -a fileLine <<< "$path" #Break path into array by directory

	#Critera: File and its an executable and its last directory is 4 letters and its "java" only
	if [ -f "$path" ] && (ls -l "$path" | /usr/xpg4/bin/egrep -q "x") && [[ ${#fileLine[${#fileLine[@]}-1]} -eq 4 ]] && (echo ${fileLine[*]: -1} | /usr/xpg4/bin/egrep -q '\<java\>'); then
		type='JAVA'
		version=$("$path" -version 2>&1 | head -1 | cut -d '"' -f 2)
		if echo "$version" | /usr/xpg4/bin/egrep -q "(No|Error|Such|File|Directory|ksh|ERROR)" || [ -z "$path" ]; then #Error handling in case version gives an error
			version='NONE'
			type='EXE'
		fi
	elif [ -f "$path" ] && (ls -l "$path" | /usr/xpg4/bin/egrep -q "x"); then
		type='EXE'
		version='NONE'
	else
		version='NONE'
		type='FOLDER'
	fi

	LastAccessDate=$(perl -MPOSIX -e 'print POSIX::strftime "%m/%d/%y=%H:%M:%S\n", localtime((stat $ARGV[0])[9])' "$path")
	line=$(echo "$server,$path,$type,$version,$LastAccessDate,$FirstDiscovered,$LastDiscovered")
	printf "%s\n" "$line" >> temp.txt

} 

function Trim() {
	IFS='/' read -r -a line <<< "$path"

	cutNow=0

	for (( j=(${#line[@]}-1); j>=1; j--))
	do
		for item in "${keywords[@]}";
		do
			if [[ ${line[$j]} == *"$item"* ]] && [[ ! ${line[$j]} == *"."* ]]; then
				cutNow=1
				break
			fi
		done

		if [ "$cutNow" -eq 1 ]; then
			break
		fi
	done

	if [ "$j" -ge 1 ]; then
		j=$((j+1))
		path=$(printf "%s/" "${line[@]:0:$j}")
	else
		path=''
	fi

}

function CreateFile() {
	echo "Server,Path,Type,Version,LastAccessDate,FirstDiscovered,LastDiscovered" > java_application.csv
	printf '%s\n' "${applicationArray[@]}" >> java_application.csv 
}

function ModifyFile() {
	for (( j=0; j<${#applicationArray[@]}; j++ ))
	do
		checkPath=($(printf "%s\n" "${applicationArray[$j]}" | awk -F, '{print $2}'))

		if /usr/xpg4/bin/grep -q "$checkPath" java_application.csv; then #If path is found in report then change the last discovered date 
			echo "$(/usr/xpg4/bin/awk -v path="$checkPath" -v currentTime="$date" 'BEGIN{FS=OFS=","}NR>1{if($2==path) $7=currentTime}1' java_application.csv)" > java_application.csv
		else #If path not found add to reprot
			printf "%s\n" "${applicationArray[$j]}" >> java_application.csv
		fi

	done
}

GetApplication
if [ ! -f java_application.csv ]; then
	echo 'Creating file'
	CreateFile
elif [ -f java_application.csv ]; then
	echo 'Modifying file'
	ModifyFile
else
	echo 'No installed applications'
fi

rm -f temp.txt 
