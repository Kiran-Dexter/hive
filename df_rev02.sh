#!/bin/sh
#Threshold value can be set here
HOST=`hostname`
today=`date '+%d/%m/%Y-%H:%M:%S'`
mkdir -p /tmp/scripts/
html_output=/tmp/scripts/${HOST}.html
THRESHOLD=80
IP_ADR=`hostname -I`

echo "<html>
<head>
<style>
table, td, th {
  border: 1px solid black;
 text-align: left;
 height: 20px;
 vertical-align: center;
 padding: 3px;
font-family: 'Montserrat', sans-serif;
border-collapse: collapse;
}
h3 {text-align: center;}
</style>
</head>

<body>
<table align="center" border="0">
<tr><td>
<table align="center" border="0">
<table align="center" width="100%">
<br>

<h3 >Disk utilization report | Running out of Space | $HOST | ${IP_ADR}  </h3>
<tr><th>Date </th><th>Hostname / IP Address </th><th> Partition </th><th> Usage % </th><th> Free Space </th></tr> ">$html_output

df -H | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $5 " " $6 " " $4}' | while read output;
do
  usep=$(echo $output | awk '{ print $1}' | cut -d'%' -f1  )
  partition=$(echo $output | awk '{ print $2 }' )
  available=$(echo $output | awk '{ print $3 }' )
  if [ $usep -ge $THRESHOLD ]; then
echo "<tr><td>${today}</td><td> ${HOST} /  ${IP_ADR} </td><td> $partition </td><td> $usep%</td> <td> $available</td></tr>">>$html_output 
  #  mail -s "Alert: Almost out of disk space $usep%" you@somewhere.com
  fi
done
echo "</table></table></td></tr></table>">>$html_output
#mailx -a 'Content-Type: text/html' -s "Sever  Running out of Space " kiran2345@gmail.com <$html_output
