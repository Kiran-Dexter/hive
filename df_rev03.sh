#!/bin/sh
#Threshold value can be set here
HOST=`hostname`
today=`date '+%d/%m/%Y-%H:%M:%S'`
mkdir -p /tmp/scripts/
output=/tmp/scripts/temp.txt
THRESHOLD=30
IP_ADR=`hostname -I`


echo "Disk utilization report | Running out of Space | $HOST | ${IP_ADR} ">$output
echo "Hostname / IP Address | Partition | Usage % | Free Space |">>$output

df -H | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $5 " " $6 " " $4}' | while read output;
do
  usep=$(echo $output | awk '{ print $1}' | cut -d'%' -f1  )
  partition=$(echo $output | awk '{ print $2 }' )
  available=$(echo $output | awk '{ print $3 }' )
  if [ $usep -ge $THRESHOLD ]; then
echo ${today} ${HOST}   ${IP_ADR} $partition  $usep  $available >> /tmp/scripts/temp.txt
  fi
done
MAIL_FLAG=`cat /tmp/scripts/temp.txt | wc -l`
if [ $MAIL_FLAG -gt 2 ]
then
mailx  -s "Sever  Running out of Space " vilbiraju@gmail.com < $output
fi
