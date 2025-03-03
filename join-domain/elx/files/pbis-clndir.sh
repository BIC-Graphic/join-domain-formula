#!/bin/sh
#
# Under least-privileges security models, the PBIS installer can
# have problems joining a client to the domain if the domain 
# already contains a matching computer object (even if join-
# account has add/modify/delete permissions to the object). This
# Script is designed to look for conflicting objects in the
# target directory and attempt to delete them. If conflicting
# object exists but is not deletable, this script will exit with
# a salt-compatible failure message.
#
# This script uses the PBIS-included tool, `adtool` to do the
# heavy-lifting. The lookup-routine looks like:
#
#    /opt/pbis/bin/adtool -d DOMAIN.F.Q.D.N -s SERVER \
#      -n <USERID>@<DOMAIN.F.Q.D.N> -x '<PASSWORD>' \
#      -a search-computer --name cn=<NODENAME> -t
#
# This script requires the positional input-parameters
# 1) DOMAIN.F.Q.D.N
# 2) USERID
# 3) PASSWORD
#
# Note: This utility assumes that domain-joiner account's UPN 
#       takes the form "USERID@DOMAIN.F.Q.D.N"
#
#################################################################

# Check if enoug args were passed
if [[ ${#@} -ge 4 ]]
then
  # Positional parameters (we'd use getopts, but humans shouldn't 
  # be directly invoking this script)
   DOMAIN=${1}
   USERID=${2}
   PASSCRYPT=${3}
   PASSULOCK=${4}
else
   printf "Usage: ${0} <DOMAIN.F.Q.D.N> <JOIN_USER> " > /dev/stderr
   printf "<PASSWORD_CRYPT> <PASSWORD_UNLOCK>"  > /dev/stderr
   exit 1
fi

# Generic vars
ADTOOL=$(rpm -ql pbis-open | grep adtool$)
NODENAME=$(hostname -s)


#########################
## Function definitions
#########################

# Decrypt Join Password
function PWdecrypt() {
   local PWCLEAR=$(echo "${PASSCRYPT}" | openssl enc -aes-256-ecb -a -d \
                   -salt -pass pass:"${PASSULOCK}")

   echo ${PWCLEAR}
}


# Check for object-collisions
function CheckObject() {
   local EXISTS=$(${ADTOOL} -d ${DOMAIN} -n ${USERID}@${DOMAIN} \
                  -x "${PASSWORD}" -a search-computer \
                  --name cn="${NODENAME}" -t)
   
   if [[ -z ${EXISTS} ]]
   then
      echo "NONE"
   else
      echo "${EXISTS}"
   fi
}

# Kill the collision
function NukeCollision() {
   if [[ $(${ADTOOL} -d ${DOMAIN} -n ${USERID}@${DOMAIN} \
           -x "${PASSWORD}" -a delete-object --dn="$(CheckObject)" \
           --force > /dev/null 2>&1)$? -eq 0 ]]
   then
      printf "\n"
      printf "changed=yes comment='Deleted ${NODENAME} from "
      printf "the directory'\n"
      exit 0
   else
      printf "\n"
      printf "changed=no comment='Faile to delete ${NODENAME} "
      printf "from the directory'\n"
      exit 1
   fi

}
##
#########################


######################
## Main program flow
######################
PASSWORD=$(PWdecrypt)

if [[ $(CheckObject) = NONE ]]
then
   printf "\n"
   printf "changed=no comment='No collisions for ${NODENAME} found "
   printf "in the directory'\n"
   exit 0
else
   NukeCollision
fi
