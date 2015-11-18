#!/bin/nsh
# Header_start
#################################################################################
#																				#
#	Script de verification de la date d'expiration des comptes Unix				#
#	Ce script s execute sur un serveur et n'envoie un mail au support que si	#
#	au moins un des comptes listés dans le fichier UserList.txt ou leur mot		#
#   de passe est expiré ou en voie d'expiration.            					#
# ----------------------------------------------------------------------------- #
# 	Author: Alfred TCHONDJO - DCB SM3P											#
# 	Date: 2015-10-30															#
# ----------------------------------------------------------------------------- #
# Revisions																		#
#																				#
#	G1R0C0 : 	Creation du script le 30/10/2015 (AT)							#
#	G1R0C1 : 	Amelioration des expressions regulires le 10/11/2015 (AT)		#
#	G1R0C2 : 	Prise en charge toute version AIX le 16/11/2015 (AT)			#
#	G1R0C3 : 	Mise en forme de la sortie HTML(email) le 18/11/2015 (AT)		#
#																				#
#################################################################################
# Header_end
# set -x
####################
# Initialisation des variables
####################
SERVER=${NSH_RUNCMD_HOST}
REPO_SERVER="$2"
REPO_FILE_PATH="$3"
REPO_ENDPOINT="//${REPO_SERVER}${REPO_FILE_PATH}"
MAIL_SERVER="$4"
MAIL_RECIPIENT="$5"
MAIL_FROM="server.expertunix@mydomain.com"
POLE="$6"
CURRDATE=`date '+%C%y%m%d'`
MAIL_FILE_PATH="/var/tmp/AUDIT_COMPTES_${POLE}_${SERVER}_${CURRDATE}.html"
MAIL_FILE_ENDPOINT="//${MAIL_SERVER}${MAIL_FILE_PATH}"
PASSWORD_CHG_PATTERN="Last"
PASSWORD_EXPIRE_PATTERN="expires"
PASSWORD_LIFETIME_PATTERN="Maximum"
ACCOUNT_EXPIRE_PATTERN="Account"
TIMELESS_PATTERN="never"
OK_STATUS="OK"
KO_STATUS="Expiré"
####################
# declaration des fonctions
####################
function isTimelessAccount(){
local userexpirationdate="${1}"
local pwdexpiration="${2}"
local true=0
local false=1
! isTimelessItem "${userexpirationdate}"  && return $false
! isTimelessItem "${pwdexpiration}"  && return $false
return $true
}
function isTimelessItem(){
local item="${1}"
local pattern="${TIMELESS_PATTERN}"
local true=0
local false=1
[ "`echo ${item} | tr '[A-Z]' '[a-z]'`" != "$pattern" ] && return $false
return $true
}
function noExpirationFound(){
local userstatus="${1}"
local pwdstatus="${2}"
local true=0
local false=1
[ "${userstatus}" = "${KO_STATUS}" ]  && return $false
[ "${pwdstatus}" = "${KO_STATUS}" ]  && return $false
return $true
}
function writeLog(){
local message="$1"
echo "$(date '+%d/%m/%Y %H:%M:%S') - ${SERVER}: ${message}"
}
function getUserInfo(){
local username="$1"
local pattern="$2"
local output=""
local ostype=`echo $(getOSType ${SERVER})`
case "$ostype" in
	  'AIX')
	  	lastupdate=`nexec ${SERVER} "pwdadm -q $username"|grep -i "lastupdate"| awk -F'=' '{print $2}'`
		maxage=`nexec ${SERVER} "lsuser -a maxage $username"|awk -F'=' '{print $2}'`
		maxage_sec=`expr $maxage \* 604800`
		maxage_days=`expr $maxage \* 7`
		maxexpired=`nexec ${SERVER} "lsuser -a maxexpired $username"|awk -F'=' '{print $2}'`
		account_locked=`nexec ${SERVER} "lsuser -a account_locked $username"|awk -F'=' '{print $2}'`
		expire=`echo $((lastupdate + maxage_sec))`
		if [ "$pattern" = "${PASSWORD_CHG_PATTERN}" ]; then
		output=`echo $(perl -e 'print scalar(localtime(${lastupdate})), "\n"')`
		elif [ "$pattern" = "${PASSWORD_EXPIRE_PATTERN}" ]; then
			if [ "${maxage}" -eq 0 ]; then
				output=`echo ${TIMELESS_PATTERN}`
			else
				output=`echo $(perl -e 'print scalar(localtime(${expire})), "\n"')`
			fi
		elif [ "$pattern" = "${PASSWORD_LIFETIME_PATTERN}" ]; then
			output=`echo ${maxage_days}`
		elif [ "$pattern" = "${ACCOUNT_EXPIRE_PATTERN}" ]; then
			if [ "${account_locked}" = "false" -a "${maxexpired}" -eq 0 ]; then
				output=`echo ${TIMELESS_PATTERN}`
			else
				output=`echo $(perl -e 'print scalar(localtime(${expire})), "\n"')`
			fi
		else
		echo "${SERVER} - $username : invalid user info value ($pattern)"
	  			exit 1 
		fi
		;;
	  *) output=`nexec ${SERVER} "chage -l ${username}" |grep -i ${pattern} | head -n 1 | awk -F':' '{print $2}'` ;;
	esac
echo "${output}"
}
function isNotEmptyPasswordUser(){
local username="$1"
local true=0
local false=1
local pwdfile='/etc/shadow'
local ostype=`echo $(getOSType ${SERVER})`
case "$ostype" in
	  'AIX')  local name=`nexec ${SERVER} "grep -wp ${username} /etc/security/passwd"|grep "password"|awk -F"=" '($2 == "!" || $2 == "*"|| $2 == ""|| $2 == " ") {print $username}'` ;;
	  *) local name=`nexec ${SERVER} "cat ${pwdfile}"|grep -i "\<${username}\>"|awk -F":" '($2 == "!" || $2 == "*"|| $2 == ""|| $2 == " ") {print $1}'` ;;
	esac
[ ! -z "$name" ] && return $false || return $true
}
function isAlreadyExpired(){
local endDate="$1"
local pattern=`date '+%C%y%m%d'`
local true=0
local false=1
[ "$endDate" -le "$pattern" ] && return $true || return $false
}
function getOSType(){
local server="$1"
local typeOS='WINDOWS'
local OS=$(agentinfo "${server}" | grep -i 'Operating System'|awk '{ print $3 }'| grep -i "windows")
if [ -z "${OS}" ]; then
	check=`echo $(nexec $server "uname -s")`
	case "$check" in
	  *[Dd][Aa][Rr][Ww][Ii]Nn]*)  typeOS="OSX" ;;
	  *[Ll][Ii][Nn][Uu][Xx]*)   typeOS="LINUX" ;;	   
	  *[Ss][Uu][Nn][Oo][Ss]*) typeOS="SOLARIS" ;;	  
  	  *[Hh][Pp]-[Uu][Xx]*)   typeOS="HP-UX" ;;
	  *[Aa][Ii][Xx]*)   typeOS="AIX" ;;
	  *[Bb][Ss][Dd]*) typeOS="BSD" ;;
	  *)     typeOS="UNKNOWN" ;;
	esac
fi
echo "${typeOS}"
}
function isUnixServer(){
local server="$1"
local true=0
local false=1
local type=`echo $(getOSType $server)`
case "$type" in
  LINUX|SOLARIS|AIX)  return $true;;
  *)    return $false ;;
esac
}
function fileHasHostname(){
local server="$1"
local true=0
local false=1
assertion=`nexec ${MAIL_SERVER} "cat ${MAIL_FILE_PATH}"|grep "\<${server}\>"`
[ ! -z "$name" ] && return $true || return $false
}
function userNotExistsOnHost(){
local server="$1"
local username="$2"
local true=0
local false=1
local ostype=`echo $(getOSType ${server})`
case "$ostype" in
	  'AIX') local check=`nexec ${server} "lsuser -a  ALL" | grep -iw ${username}` ;;
	  *)  local check=`nexec ${server} "cat /etc/passwd" | awk -F: '{print $1}'|grep -i "\<${username}\>"`
	esac
[ -z "$check" ] && return $true || return $false
}
####################
# debut du traitement
####################
[ -z "${SERVER}" ] && continue 
if ! isUnixServer "${SERVER}"; then
	echo "- serveur ${SERVER}: The Operating System \"`echo $(getOSType ${SERVER})`\" is not supported"
	exit 1
fi
if [ ! -f "${REPO_ENDPOINT}" ]; then
	echo "ALERTE : - The user list file ${REPO_ENDPOINT} is not found"
	exit 1
fi
REPO_USERSLIST=$(cat ${REPO_ENDPOINT} | tr ' ' '\n' |LC_ALL=C sort -u | tr '\n' ' ')
if [ -z "${REPO_USERSLIST[@]}" ]; then
	echo "ALERTE : - The user list file ${REPO_ENDPOINT} is empty. No user found"
	 exit 1
fi
#++++++++ VERIFICATION DES COMPTES ++++++++++
for user in ${REPO_USERSLIST[@]}
do
	# does the user exist on our server?
	userNotExistsOnHost "${SERVER}" "${user}" && continue
	ACCOUNTEXPIRE=`echo $(getUserInfo "${user}" "${ACCOUNT_EXPIRE_PATTERN}")` #date
	PASSEXPIRE=`echo $(getUserInfo "${user}" "${PASSWORD_EXPIRE_PATTERN}")` #date
	PASSWORDSTATUS="${OK_STATUS}" 
	ACCOUNTSTATUS="${OK_STATUS}" 
	CREDENTIAL=40
	ACC_DELTA=-1
	PWD_DELTA=-1
	isTimelessAccount "${ACCOUNTEXPIRE}" "${PASSEXPIRE}" && continue
	#+++++++++++++++++++ ACCOUNT STATUS CHECK+++++++++++++++++++++++
	if [ "`echo ${ACCOUNTEXPIRE} | tr '[A-Z]' '[a-z]'`" != "${TIMELESS_PATTERN}" ] ; then
		ACCOUNTEXPIRE=`date -d "${ACCOUNTEXPIRE}" '+%C%y%m%d'`
		if [ "${ACCOUNTEXPIRE}" -le "${CURRDATE}" ]; then
			ACCOUNTSTATUS="${KO_STATUS}"
		else
			ACC_DELTA=`echo $((ACCOUNTEXPIRE - CURRDATE))`
			[ "${ACC_DELTA}" -lt "${CREDENTIAL}" ] && ACCOUNTSTATUS="${KO_STATUS}"
		fi	
	fi
	#+++++++++++++++++++ PASSWORD STATUS CHECK+++++++++++++++++++++++
 
	if [ "`echo ${PASSEXPIRE} | tr '[A-Z]' '[a-z]'`" != "${TIMELESS_PATTERN}" ] ; then
		if isNotEmptyPasswordUser "${user}" ; then
			PASSEXPIRE=`date -d "${PASSEXPIRE}" '+%C%y%m%d'`
			if [ "${PASSEXPIRE}" -le "${CURRDATE}" ]; then
				PASSWORDSTATUS="${KO_STATUS}" 
			else
				PWD_DELTA=`echo $((PASSEXPIRE - CURRDATE))`
				[ "${PWD_DELTA}" -lt "${CREDENTIAL}" ] && PASSWORDSTATUS="${KO_STATUS}"
			fi
		fi
	fi
	noExpirationFound "${ACCOUNTSTATUS}" "${PASSWORDSTATUS}" && continue
####################################
# CONSTRUCTION DU CORPS DU MESSAGE #
####################################		
	if [ ! -f ${MAIL_FILE_ENDPOINT} ] ; then
		echo "To: ${MAIL_RECIPIENT}" > ${MAIL_FILE_ENDPOINT}
		echo "From: ${MAIL_FROM}" >> ${MAIL_FILE_ENDPOINT}
		echo "Subject: ${SERVER} - audit des comptes applicatifs et systemes" >> ${MAIL_FILE_ENDPOINT}
		echo "Mime-Version: 1.0" >> ${MAIL_FILE_ENDPOINT}
		echo "Content-Type: text/html; charset=utf-8" >> ${MAIL_FILE_ENDPOINT}
		echo "<br><br>" >> ${MAIL_FILE_ENDPOINT}
		fileHasHostname "[-]" || echo "[-] SERVEUR: ${SERVER} - Pôle/EDS: ${POLE}<br><br>" >> ${MAIL_FILE_ENDPOINT}
	fi
	MSG=""
	if isTimelessItem "${ACCOUNTEXPIRE}"; then #seul le mot de passe peut expirer
		if isAlreadyExpired "${PASSEXPIRE}"; then
			MSG="- Username:  ${user} | Account Status: ${OK_STATUS} | Password Status: ${KO_STATUS}"
		else
			MSG="- Username:  ${user} | Account Status: ${OK_STATUS} | Password Status: ${KO_STATUS} dans ${PWD_DELTA} jour(s)"
		fi
	elif isTimelessItem "${PASSEXPIRE}"; then #seul le compte peut expirer
		if isAlreadyExpired "${ACCOUNTEXPIRE}" ; then
			MSG="- Username:  ${user} | Account Status: ${KO_STATUS} | Password Status: ${OK_STATUS}"
		else
			MSG="- Username:  ${user} | Account Status: ${KO_STATUS} dans ${ACC_DELTA} jour(s) | Password Status: ${OK_STATUS}"
		fi
	else #le compte et le mot de passe peuvent expirer
		if [ "${ACCOUNTSTATUS}" = "${KO_STATUS}" -a "${PASSWORDSTATUS}" = "${KO_STATUS}" ] ; then #tous deux ont expiré
			if isAlreadyExpired "${ACCOUNTEXPIRE}" && isAlreadyExpired "${PASSEXPIRE}" ; then
				MSG="- Username:  ${user} | Account Status: ${KO_STATUS} | Password Status: ${KO_STATUS}"
			elif isAlreadyExpired "${ACCOUNTEXPIRE}" ; then
				MSG="- Username:  ${user} | Account Status: ${KO_STATUS} | Password Status: ${KO_STATUS} dans ${PWD_DELTA} jour(s)"
			elif isAlreadyExpired "${PASSEXPIRE}" ; then
				MSG="- Username:  ${user} | Account Status: ${KO_STATUS} dans ${ACC_DELTA} jour(s) | Password Status: ${KO_STATUS}"
			else
				MSG="- Username:  ${user} | Account Status: ${KO_STATUS} dans ${ACC_DELTA} jour(s) | Password Status: ${KO_STATUS} dans ${PWD_DELTA} jour(s)"
			fi
		elif [ "${ACCOUNTSTATUS}" = "${KO_STATUS}" -a "${PASSWORDSTATUS}" = "${OK_STATUS}" ] ; then # seul le compte a expiré
			if isAlreadyExpired "${ACCOUNTEXPIRE}" ; then
				MSG="- Username:  ${user} | Account Status: ${KO_STATUS} | Password Status: ${OK_STATUS}"
			else
				MSG="- Username:  ${user} | Account Status: ${KO_STATUS} dans ${ACC_DELTA} jour(s) | Password Status: ${OK_STATUS}"
			fi
		else	#seul le mot de passe a expiré
			if isAlreadyExpired "${PASSEXPIRE}" ; then
				MSG="- Username:  ${user} | Account Status: ${OK_STATUS} | Password Status: ${KO_STATUS}"
			else
				MSG="- Username:  ${user} | Account Status: ${OK_STATUS} | Password Status: ${KO_STATUS} dans ${PWD_DELTA} jour(s)"
			fi
		fi	
	fi		
	[ ! -z "${MSG}" ] && echo "&nbsp;&nbsp;${MSG} <br>" >> ${MAIL_FILE_ENDPOINT}
done		
############################
# ENVOI DU MAIL AU SUPPORT #
############################
if [ -f ${MAIL_FILE_ENDPOINT} ] ; then
	nexec "${MAIL_SERVER}" "/usr/sbin/sendmail -t < ${MAIL_FILE_PATH}"
	nexec "${MAIL_SERVER}" "wait"
	nexec "${MAIL_SERVER}" "rm -f ${MAIL_FILE_PATH}"	
fi
exit 0
