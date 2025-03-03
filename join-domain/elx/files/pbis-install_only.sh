#!/bin/sh

#
# Salt state for downloading, installing and configuring PBIS,
# then joining # the instance to Active Directory
#
#################################################################
PBISPKG="${1:-UNDEF}"
INSTPBISVERS="$(rpm --qf '%{version}\n' -q pbis-open)"
ISINSTALLED=$(echo "${PBISPKG}" | grep -- "-${INSTPBISVERS}.")


if [[ "${INSTPBISVERS}" = "" ]] || [[ "${ISINSTALLED}" = "" ]]
then
   bash ${PBISPKG} -- --dont-join --legacy install > /dev/null 2>&1
   if [[ $? -eq 0 ]]
   then
      printf "\n"
      printf "changed=yes comment='Installed RPMs from ${PBISPKG}.'\n"
      exit 0
   else
      printf "\n"
      printf "changed=no comment='Installer ${PBISPKG} did not run "
      printf "as expected.'\n"
      exit 1
   fi
else
   printf "\n"
   printf "changed=no comment='RPMs from ${PBISPKG} already present.'\n"
   exit 0
fi
