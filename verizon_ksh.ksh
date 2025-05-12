#!/bin/ksh
#--------------------------------------------------------------------------------
# @(#) Verizon Wireless / SEDW
# @(#) LG_AR_SCRN_XREF.ksh Version 1.2
# @(#) Created by Devanshi Patel on 2014-08-14
# @(#) Modified by Devanshi Patel on: 08/23/14 18:49:51
#--------------------------------------------------------------------------------
#########################################################################################
# Script Name   :         LG AR SCRN XREF.ksh
# Description   :         This script extracts the disposition data
#                         from INC_EDO_SCRN_DICT_ file and loads it EDW table LG_AR_SCRN_TYPE.
#=========================================================================================
#Modification History 
# Name         Date Modified    Comments
#========================================================================================= 
# Devanshi P        2014-08-14      Original Version
# Sudhakar Upputuri 2018-03-01      New Zweig Changes Array replacement
##########################################################################################

################################
#Save log file function
################################
function save_log_file 
{
		#set -x
		if [ -d $LOG_SAVE_DIR ]
		then
				echo "Creating directory for the new month."
		echo "LOG_SAVE_DIR :$LOG_SAVE_DIR"
				mkdir $LOG_SAVE_DIR
		fi

		mv $lf $LOG_SAVE_DIR
		return $?
}

################################
#Archivefile function
################################
function archivefiles
{
		#set-x
		cd $INDIR
		FILESIN=`ls -1 ${FILE NAME}`
		for file in ${FILESIN[@]}
			do 
				echo "$(date): Archiving $(file)..."
				mv ${file} ${BKUPDIR}
				echo "compressing ${file}"
				gzip ${BKJPDIR}/${file}
			done

		return $?
}

################################
# CHECK FILES
################################

function check file
{
		#set -x
		cd ${INDIR}
		PROCFILE=`ls -1 INC_EDO_SCRN_DICT_SDC_${PARM_DT}.DAT INC_EDO_SCRN_DICT_ODC_${PARM_DT}.DAT INC_EDO_SCRN_DICT_TDC_${PARM_DT}.DAT`
		if ! test -f ${PROCFILE}; then
				dw_log ${0} "The TXT file does not exist in the $INDIR directory."
				echo "The TXT file for the LG_AR_SCRN_XREF does not exist" \
				|mailx -s "The TXT file does not exist for `date +m%d`" ${EMAIL}
				exit 1
			else
				for file in ${PROCFILE[@]}
					do
						export FILE_NAME=${PROCFILE[@]}
						RC_CNT=`wc -l ${PROCFILE[@]}|nawk '{printf "%2d\n", $1}'`
						export FILE_DATE=${PARM_DT}
						printf " Files: \n ${FILE_NAME} \n Respective record count:\n ${RC_CNT} Records to load and are dated as ${FILE_DATE}."
					done
		fi
		return $?
}


################################
# Main Function
################################
function main
{
 
	#set -x
	if [ ! -d ${INDIR} ]
	then
			echo "The ${INDIR} directory does not exist!"
			echo "Exiting $(SCRIPT)"
		exit 99
	fi


if [ -z ${PARM_DT} ]
then
		msg_box "ERROR - PARMETER PARM_DT not passed into script (format: YYYYMMDD)"
		exit 1
fi
	check file
 
	echo "Running the load job for LG_AR_SCRN_TYPE table.."
	cd ${INDIR}
		FILESIN=`ls -1 ${FILE_NAME}`
		for file in ${FILESIN[@]}
	do
		if [[ -f ${INDIR}/${file} ]]
		then
			if [ ! -s ${INDIR}/${file}];
			then

			 echo "Zero byte file encountered, moving to backup directory "
			 mv ${INDIR}/${file} ${BKUPDIR}
			else
			 export FILEIN=${INDIR}/${file} 
			 dw_log ${0} "Mloading $FILEIN "
			 cd ${MLOADDIR}
			 LG_AR_SCRN_XREF.mld
			 ERRCD=$?
			if [ $ERRCD = 0 ]
				then
			 dw_log ${0} "LG_AR_SCRN_XREF MLOAD successful"
				else
			 dw_log ${0} "LG_AR_SCRN_XREF MLOAD failed"
			 exit 3
			fi

			 dw_log ${0} "Merging into the Target table from the staging table..."

			 cd ${BTEQDIR}
			 CM_30.btq
			 ERRCD=$?
			if [ $ERRCD = 0 ]
				then
			 dw_log ${0} "LG_AR_SCRN_XREF BTEQ successfull"
				else
			 dw_log ${0} "LG_AR_SCRN_XREF BTEQ failed"
			 exit 4
			fi
                         cd ${BTEQDIR}
			 CJC_10.btq
			 ERRCD=$?
			if [ $ERRCD = 0 ]
				then
			 dw_log ${0} "LG_AR_SCRN_XREF BTEQ successfull"
				else
			 dw_log ${0} "LG_AR_SCRN_XREF BTEQ failed"
			 exit 4
			fi
			fi
		fi
	done

		dw log ${0}	"Archiving the Data file..."
		archivefiles
		dw log ${0} "Archiving the Data file Successful"
	dw log ${0} "Saving the logfile"
		save_log_file
	echo "SAVING THE LOG FILE.."
		return $EXITCD
}
################################
# Start of script
################################

main > $lf 2>&1 
return $?
