#!/bin/bash
TEMPFILE="/tmp/userlist.txt"
HOSTNAME=`uname -n`
OUTPUTFILE="${HOSTNAME}.csv"
OSVER=RHEL" "`cat /etc/redhat-release | awk '{ print $1  $2 $7}'`
awk -F: '($4 == 0) || ($3 == 0) {printf "%s:%s:%s:%s\n",$1,$3,$4,$5}' /etc/passwd > ${TEMPFILE}
printf "OS-VERSION,HOSTNAME,USER NAME,UID,GID,REMARKS\n" > ${OUTPUTFILE}
while read LINE
do
        USER=`echo $LINE | awk -F: '{print $1}'`
        USERID=`echo $LINE | awk -F: '{print $2}'`
        GID=`echo $LINE | awk -F: '{print $3}'`
        REM=`echo $LINE | awk -F: '{print $4}'`
        printf "$OSVER,$HOSTNAME,$USER,$USERID,$GID,$REM\n" >> ${OUTPUTFILE}
done <"$TEMPFILE"
rm -rf $TEMPFILE
