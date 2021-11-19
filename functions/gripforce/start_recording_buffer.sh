#!/bin/bash
# arg1: title of terminal window
# arg2: host port number (default=1972)
# arg3: output folder (default: /data/saving_buffer/raw/)

title='FT saving: not specified'
if [ $# -gt 0 ]; then title='FT saving: '$1; fi
echo -e "\033]2;$title\007"

hostport=1972
if [ $# -gt 1 ]; then hostport=$2; fi
echo host port: $hostport

if [ $# -gt 2 ]; then 
	savfld=$3
else
	savfld='/data/saving_buffer/raw'
	# echo error, specify data saving folder
	# exit -1
fi
mkdir -p $savfld

cd `dirname ${BASH_SOURCE[0]}`
source ./set_environment.sh

if [ `uname -s` == 'Linux' ]; then
	OS='glnxa64'
else # Mac
	OS='maci64'
fi
	
newfld=buffer_`date +%Y%m%d_%H%M%S`
#mkdir newfld	
filename=$savfld/$newfld

ft_rec_exe=fieldtrip/realtime/bin/$OS/recording	

echo saving data to: $filename		
echo fieldtrip saving buffer started ...
$ft_rec_exe $filename $hostport

	

