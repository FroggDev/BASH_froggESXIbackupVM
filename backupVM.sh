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
SCN="ESXI VM BackUp"               # script name
SCD="BackUp all Vm in ESXI and send it to ftp server"
                                   # script description
SCT="Esxi 5.1 to 6.7"              # script OS Test
SRQ="Required version : Esxi 5.1+" # script Required
SCC="sh ${0##*/}"                  # script call
SCV="1.001"                        # script version
SCO="2015/02/23"                   # script date creation
SCU="2020/07/08"                   # script last modification
SCA="Marsiglietti Remy (Frogg)"    # script author
SCM="admin@frogg.fr"               # script author Mail
SCS="cv.frogg.fr"                  # script author Website
SCF="www.frogg.fr"                 # script made for
SCP=$PWD                           # script path
SCY="2020"                         # script copyright year
############
#   TODO   #
############
# TODO : tar exclude ( impossible on Esxi 5.5 )
# TODO : test if client FTP exist and is executable
# TODO : test if can send mail
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
TIM=`date '+%Y%m%d'`             #current date format YYYYMMDD
FTM=`date '+%Y/%m/%d %H:%M:%S'`  #current date format YYYY/MM/DD HH:MM:SS
doTAR=1                          #Copy Compressed VM files to $TAR (0 to disable)
doBAR=0                          #Copy Compressed VM to $BAK (0 to disable)
doBAK=0                          #Copy VM folders to $BAK (0 to disable)
doFTP=1                          #Copy Compressed VM files to FTP (0 to disable)
doMAI=1                          #Send log by mail once done (0 to disable)
#[ Esxi infos ]#
SRC=/vmfs/volumes/datastore1     #VM folder
TAR=/vmfs/volumes/datastore1/backup   #BACKUP TAR folder
BAK=/vmfs/volumes/backup         #BACKUP COPY folder
MAXTAR=5                         #MAX nb of backup in $TAR
MAXBAK=5                         #MAX nb of backup in $BAK
MAXBAR=5                         #MAX nb of backup in $BAR
#[ FTP infos ]#
FTP=ftp.smtp.domain.ltd          #This is the FTP servers host or IP address.
PRT=21                           #This is the FTP servers port
USR=userFTP                      #This is the FTP user that has access to the server.
PSS=passFTP                      #This is the password for the FTP user.
#[ EMAIL infos ]#
SMTP="smtp.domain.ltd"           #smtp client used to send the mail
SMTPPORT=25                      #smtp port
SNAME="domain.ltd"               #server name from smtp ELO
EFROM="emailfrom@domain.ltd"     #email from
ETO="emailto1@domain.ltd emailto2@domain.ltd" #email to (for multiple recipient must be separated by space)
ELOG="base64loginsmtp"           #email smtp log base64 encoded
EPAS="base64passsmtp"            #email smtp pass base64 encoded

#[ Script infos ]#
SCR=/vmfs/volumes/datastore1/script/         #script path
CLI=./ncftp/bin/ncftpput                     #Path to ncftpput command 
LOGP=/vmfs/volumes/datastore1/log/
LOG=${LOGP}/backup.log                       #script logs

#[ SUB PART ] Functions#
#Backup old log
prepareLogFile()
{
mkdir -p ${2}
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
# check if functionnality is enabled
if [ $3 = 1 ];then 	
  #count nb backup folder
  nbBAK=$(ls $1/*/ -d | wc -l)
  logEventTime "there is [ $nbBAK / $2 ] $4 backup found in $1..."

	#if too much backups then remove oldest
	if [ $nbBAK -gt $2 ];then
		oldBAK=$(ls -dt $1/*/ | tail -1)
		rm -r $oldBAK >> $LOG 2>&1
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
for email in ${ETO}; do echo "RCPT TO:${email}" >> mail.txt;done
echo "DATA" >> mail.txt
echo "From: ${EFROM}" >> mail.txt
for email in ${ETO}; do echo "To: ${email}" >> mail.txt;done
echo "Subject: [SUCCESS] Esxi backup result" >> mail.txt
echo "" >> mail.txt
cat $LOG >>  mail.txt
echo "" >> mail.txt
echo "." >> mail.txt
echo "QUIT" >> mail.txt
# Send the mail
cat "mail.txt" |while read L; do sleep "2"; echo "$L"; done | "nc" -C -v ${SMTP} ${SMTPPORT}
# Enable Firewall
esxcli network firewall set --enabled true
fi
}

#==[ PART 0 ] Prepare Script==#
prepareLogFile ${LOG} ${LOGP}
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

# Check config
[[ $doBAK = 1 ]] && logEventTime "Copy VM to $BAK enabled"
[[ $doTAR = 1 ]] && logEventTime "VM compression in $TAR enabled"
[[ $doBAR = 1 ]] && logEventTime "VM compression in $BAK enabled"
[[ $doFTP = 1 ]] && logEventTime "FTP copy to $FTP enabled"
[[ $doMAI = 1 ]] && logEventTime "Send mail to $ETO enabled"

#Create backup folders depending of user request
[ $doBAK = 1 ] && mkdir -p $BAK/$TIM
[ $doBAR = 1 ] && mkdir -p $BAK/$TIM
[ $doTAR = 1 ] && mkdir -p $TAR/$TIM

#==[ PART 1 ] Check number of existing Backup==#
#check number of old backup removed oldest if needed
logEventTime ""
logEventTime "[ I ] Checking number of backup"
logEventTime "==============================="
logEventTime ""
delEmptyBk $BAK/$TIM $doBAK
delEmptyBk $TAR/$TIM $doTAR
delOldBk $TAR $MAXTAR $doTAR "TAR"
delOldBk $BAK $MAXBAR $doBAR "TAR COPY"
delOldBk $BAK $MAXBAK $doBAK "VM COPY"

#==[ PART 2 ] Backup File==#
logEventTime ""
logEventTime "[ II ] Doing VM Backup"
logEventTime "======================"
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

#==[ PART 3 ] Send to BackUp FTP==#
if [ $doFTP = 1 ];then

  [[ $doTAR = 1 ]] && READFROM=$TAR
  [[ $doBAR = 1 ]] && READFROM=$BAK

	logEventTime ""
	logEventTime "[ III ] Sending by FTP"
	logEventTime "====================="
	logEventTime ""
	testConn $FTP $PRT
	logEventTime "Disable FTP client firewall ..."
	esxcli network firewall set --enabled false >> $LOG 2>&1
	for BK in $(ls $READFROM/$TIM/);do
		logEventTime "send [$BK] via ftp ..."
		cd $SCR
		$CLI -u $USR -p $PSS -v -z -t 3 -F -P $PRT $FTP / $READFROM/$TIM/$BK >> $LOG 2>&1
	done
	logEventTime "Enabling FTP client firewall ..."
	esxcli network firewall set --enabled true >> $LOG 2>&1
fi

#==[ PART 4 ] END==#
logEventTime ""
logEventTime "Script Done !"

#==[ PART 5 ] EMAIL==#
sendLogByMail
