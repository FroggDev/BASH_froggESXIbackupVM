#!/bin/sh
#            _ __ _
#        ((-)).--.((-))
#        /     ''     \
#       (   \______/   )
#        \    (  )    /
#        / /~~~~~~~~\ \
#   /~~\/ /          \ \/~~\
#  (   ( (            ) )   )
#   \ \ \ \          / / / /
#   _\ \/  \.______./  \/ /_
#   ___/ /\__________/\ \___
#  *****************************
SCN="ESXI VM BackUp"   			# script name
SCD="BackUp all Vm in ESXI and send it to ftp server"
					# script description
SCT="Esxi 5.5"				# script OS Test
SRQ="Required version : Esxi 5.1+"	# script Required
SCC="sh ${0##*/}"			# script call
SCV="1.001"				# script version
SCO="2015/02/23"			# script date creation
SCU="2015/11/08"			# script last modification
SCA="Marsiglietti Remy (Frogg)"		# script author
SCM="admin@frogg.fr"			# script author Mail
SCS="cv.frogg.fr"			# script author Website
SCF="www.frogg.fr"			# script made for
SCP=$PWD				# script path
SCY="2015"				# script copyright year
echo "*******************************"
echo "# ${SCN}"
echo "# ${SCD}"
echo "# ${SRQ}"
echo "# Tested on   : ${SCT}"
echo "# v${SCV} ${SCU}, Powered By ${SCA} - ${SCM} - ${SCS} - Copyright ${SCY}"
echo "# For         : ${SCF}"
echo "# script call : ${SCC}"
echo "Optional Parameters"
echo " ${SCC} {VMNAME} for single VM save"
echo "*******************************"

#==[ SUB PART ] Variables==#
#[ Const infos ]#
TIM=`date '+%Y%m%d'`		#current date format YYYYMMDD
FTM=`date '+%Y/%m/%d %H:%M:%S'`	#current date format YYYY/MM/DD HH:MM:SS
doTAR=1				#Copy Compressed VM files to $TAR (0 to disable)
doBAR=1				#Copy Compressed VM to $BAK (0 to disable)
doBAK=0				#Copy VM folders to $BAK (0 to disable)
doFTP=0				#Copy Compressed VM files to FTP (0 to disable)
doMAI=1				#Send log by mail once done (0 to disable)
#[ Esxi infos ]#
SRC=/vmfs/volumes/datastore1	#VM folder
TAR=/vmfs/volumes/datastore1/backup	#BACKUP TAR folder
BAK=/vmfs/volumes/backup	#BACKUP COPY folder
MAXTAR=4			#MAX nb of backup in $TAR
MAXBAK=4			#MAX nb of backup in $BAK
MAXBAR=4			#MAX nb of backup in $BAR
#[ FTP infos ]#
FTP=xxx				#This is the FTP servers host or IP address.
PRT=21				#This is the FTP servers port
USR=xxx        			#This is the FTP user that has access to the server.
PSS=xxx				#This is the password for the FTP user.
#[ EMAIL infos ]#
SMTP="xxx"			#smtp client used to send the mail
SNAME="www.frogg.fr"		#server name from smtp ELO
EFROM="esxi@frogg.fr"        	#email from
ETO="admin@frogg.fr"        	#email to
ELOG="xxx"     			#email smtp log base64 encoded
EPAS="xxx"      	 	#email smtp pass base64 encoded

#[ Script infos ]#
SCR=/vmfs/volumes/datastore1/script/	#script path
CLI=./ncftp/bin/ncftpput		#Path to ncftpput command 
LOG=/vmfs/volumes/datastore1/backup.log	#script logs

#[ SUB PART ] Functions#
#Backup old log
prepareLogFile()
{
touch ${1}
touch ${1}.history
cat ${1} >> ${1}.history
echo "" > ${1}
}
#Create time + event in log file
logEventTime()
{
echo $1
echo -e "[ "`date '+%H:%M:%S'`" ] $1"  >> $LOG
}
#Delete old backup if needed
delOldBk()
{
#count nb backup folder
nbBAK=$(ls $1/*/ -d | wc -l)
logEventTime "there is [ $nbBAK / $2 ] $4 backup found in $1..."
if [ $3 = 1 ];then 	
	#if too much backups then remove oldest
	if [ $nbBAK -gt $2 ];then
		oldBAK=$(ls -dt $1/*/ | tail -1)
		rm -r $1/$oldBAK >> $LOG 2>&1
		logEventTime "...oldest backup  deleted: $oldBAK"
	fi
fi
}
#remove backup folder if it is empty
delEmptyBk()
{
if [ $2 = 1 ];then 	
	[ ! "$(ls -A $1)" ] &&  echo "rm -R $1"  >> $LOG 2>&1
fi
}
#Test if server port is UP
testConn()
{
logEventTime "...Checking if server '${1}' is available, please wait..."
if nc -w5 -z ${1} ${2} &> /dev/null;then
	logEventTime "Server [${1}:${2}] port is opened !"	
else
	logEventTime "Can't access to Server port [${1}:${2}], End of the script"
	sendLogByMail
	exit
fi
}
#Send log by mail
sendLogByMail()
{
if [ ${doMAI} = 1 ];then
# Disable firewall
esxcli network firewall set --enabled false
# Create Mail
echo "HELO ${SNAME}" > mail.txt
echo "AUTH LOGIN" >> mail.txt
echo "${ELOG}" >> mail.txt
echo "${EPAS}" >> mail.txt
echo "MAIL FROM:${EFROM}" >> mail.txt
echo "RCPT TO:${ETO}" >> mail.txt
echo "DATA" >> mail.txt
echo "From: ${EFROM}" >> mail.txt
echo "To: ${ETO}" >> mail.txt
echo "Subject: Esxi Backup result" >> mail.txt
echo "" >> mail.txt
cat $LOG >>  mail.txt
echo "" >> mail.txt
echo "." >> mail.txt
echo "QUIT" >> mail.txt
# Send the mail
/usr/bin/nc ${SMTP} 25 < mail.txt
# Enable Firewall
esxcli network firewall set --enabled true
fi
}

#==[ PART 0 ] Prepare Script==#
prepareLogFile ${LOG}
logEventTime "*******************************************"
logEventTime "[ $FTM ] Starting BackUp script"
logEventTime "*******************************************"
logEventTime ""
if [ $doTAR = 0 -a $doBAK = 0 ];then
	logEventTime "ERROR: Tar and Copy backup are disabled...script require at least one of both action"
	logEventTime "Please check script configuration, script is ending"
	sendLogByMail
	exit
fi
if [ $doFTP = 1 -a $doTAR = 0 ];then
	logEventTime "WARNING: Tar backup is disabled...script require it enabled to FTP compressed files"
	logEventTime "script is forcing Tar creation to be correct"
	logEventTime "Please check script configuration for doTAR value, script continue"
	doTAR=1
fi
if [ $doBAR = 1 -a $doTAR = 0 ];then
	logEventTime "WARNING: Tar backup is disabled...script require it enabled to backup compressed files"
	logEventTime "script is forcing Tar creation to be correct"
	logEventTime "Please check script configuration for doTAR value, script continue"
	doTAR=1
fi

#Create backup folders depending of user request
[ $doBAK = 1 ] && mkdir -p $BAK/$TIM
[ $doBAR = 1 ] && mkdir -p $BAK/$TIM
[ $doTAR = 1 ] && mkdir -p $TAR/$TIM

#==[ PART 1 ] Backup File==#
logEventTime ""
logEventTime "[ I ] Doing VM Backup"
logEventTime "====================="
logEventTime ""
#check all folder in data-store
for VM in $(ls $SRC);do
	#Test if it is a folder
	if [ -d "$SRC/$VM" ]; then
		#Test if it is as VM
		if [ -e $SRC/$VM/$VM.vmx ]; then
			#only VM send to script
			if [ -z $1 ]||[ $1 = $VM ];then
				logEventTime "Backuping [$VM]"
				logEventTime "...Snapshoting..."
				vim-cmd vmsvc/snapshot.removeall $SRC/$VM/$VM.vmx >> $LOG 2>&1
				vim-cmd vmsvc/snapshot.create $SRC/$VM/$VM.vmx "$TIM Backup" "Auto-backup taken the $FTM" 0 >> $LOG 2>&1 #include memory = 0
				if [ $doTAR = 1 ];then
					cd $SRC/$VM/
					logEventTime "...Compressing..."	
					tar czvf $TAR/$TIM/$VM.tar.gz ./ >> $LOG 2>&1 # TAR EXCLUDE NOT WORKING ON ESXI 5.5 --exclude '*.vswap*' --exclude '*.vmsn*' --exclude '*.lck*' etc ...
					[ $doBAR = 1 ]&&cp $TAR/$TIM/$VM.tar.gz $BAK/$TIM/
				fi
				if [ $doBAK = 1 ];then
					cd $SRC/
					mkdir -p $BAK/$TIM/$VM/
					logEventTime "...Copying..."
					for VMFile in $SRC/$VM/*;do
						if [ ! -z ${VMFile##*"~"*} ]&&[ ! -z ${VMFile##*".vswap"*} ]&&[ ! -z ${VMFile##*".vswp"*} ]&&[ ! -z ${VMFile##*".vmsn"*} ]&&[ ! -z ${VMFile##*".lck"*} ]&&[ ! -z ${VMFile##*".log"*} ];then
							cp $VMFile $BAK/$TIM/$VM/ >> $LOG 2>&1
						fi
					done
				fi
				logEventTime "...Removing Snapshot..."
				vim-cmd vmsvc/snapshot.removeall $SRC/$VM/$VM.vmx >> $LOG 2>&1
				logEventTime "...Done : [$VM] as been Backuped"
			fi
		fi
	fi
done

#==[ PART 2 ] Check number of existing Backup==#
#check number of old backup removed oldest if needed
logEventTime ""
logEventTime "[ II ] Checking number of backup"
logEventTime "================================"
logEventTime ""
delEmptyBk $BAK/$TIM $doBAK
delEmptyBk $TAR/$TIM $doTAR
delOldBk $TAR $MAXTAR $doTAR "TAR"
delOldBk $BAK $MAXBAR $doBAR "TAR COPY"
delOldBk $BAK $MAXBAK $doBAK "VM COPY"

#==[ PART 3 ] Send to BackUp FTP==#
if [ $doFTP = 1 ];then
	logEventTime ""
	logEventTime "[ III ] Sending by FTP"
	logEventTime "====================="
	logEventTime ""
	testConn $FTP $PRT
	logEventTime "Disable FTP client firewall ..."
	esxcli network firewall set --enabled false >> $LOG 2>&1
	for BK in $(ls $BAK/$TIM/);do
		logEventTime "send [$BK] via ftp ..."
		cd $SCR
		$CLI -u $USR -p $PSS -v -z -t 3 -F -P $PRT $FTP / $BAK/$TIM/$BK >> $LOG 2>&1
	done
	logEventTime "Enabling FTP client firewall ..."
	esxcli network firewall set --enabled true >> $LOG 2>&1
fi

#==[ PART 4 ] END==#
logEventTime ""
logEventTime "Script Done !"

#==[ PART 5 ] EMAIL==#
sendLogByMail
