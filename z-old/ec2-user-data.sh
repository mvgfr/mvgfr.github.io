#!/bin/bash
# use directly as "user data" OR (ex: if too big) like so (WITH a shebang line):
# set -x; myScript='ec2-user-data.sh'; wget https://mvgfr.com/$myScript; chmod u+x $myScript; bash -x $myScript

# simple EC2 startup script to init an instance w/ desired pkgs & cfg
# inspired by <http://alestic.com/2009/06/ec2-user-data-scripts>

# NB:
# - only SOME portions are up-to-date wrt CentOS/yum vs Ubuntu/apt-get
# - (re)bundle AMI resets some things!? and re-runs orig user-data!?
# - see "TBD"s (if any) noted inline

# History:
# 20190206 mvr: let's see if this can still be useful... (last mod 20120112!)

# ToDo:
# email no longer valid method (generally blocked), so commment it out, and notify some other way...

# some vars to customize:
#myHostname='mvgfr2.dyndns.org' # not necessarily valid; handy for ID, ex: via outgoing email
#myNotifyAddr="mvgfr1@gmail.com"
userAcct="ec2-user" # acct to customize bash for
homePath='/home' # full path to directory where homes are found
# reminders? ex: for stuff that's left to be done manually, like credentials
# (can set here and/or add to it throughout the script)
myReminders=""
countdown=10 # minutes to give minute-ly warnings of imminent auto-shutdown

# handy strings:
myNewline='\n'

# 20190206 mvr: aparently obsolete; definitely problematic:
## redirect output to a few places:
#exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

set -x # get running feedback
#set -e # stop on err

# show external IP addr
dig +short myip.opendns.com @resolver1.opendns.com

# set hostname:
#hostname $myHostname

# find out what flavor system we're running on & cfg accordingly:
if which yum
then # we're using something like RedHat/Fedora/CentOS or AWS Linux AMI
	sysUpdCmd="yum -y update"
	installCmd="yum -y install"
	remvCmd="yum -y remove"
	syslogPath="/var/log/messages"
#	installPkgNames="make gcc libstdc++-devel gcc-c++ curl curl-devel libxml2 libxml2-devel openssl-devel mailcap"
else # we're using something like Debian/Ubuntu
	sysUpdCmd="apt-get update; apt-get -y upgrade"
	installCmd="apt-get -y install"
	remvCmd="#" # TBD: not sure how this'd work via apt-get yet
	syslogPath="/var/log/syslog"
#	installPkgNames="build-essential libfuse-dev fuse-utils libcurl4-openssl-dev libxml2-dev mime-support"
	export DEBIAN_FRONTEND=noninteractive # no equiv needed for rpm
fi

# use mutt to notify, w/syslog (ex: for this instance's key fingerprints & genl debugging):
#$installCmd mutt

# notify right away, since installs may take awhile:
#mutt -s "$(hostname) online at $(date '+%Y%m%d-%H%M%S')" -a $syslogPath -- $myNotifyAddr < /dev/null

## apply latest system updates:
# (use eval since may be multiple cmds)
eval $sysUpdCmd

## install my ssh key:
su $userAcct bash -c '
mkdir -p ~/.ssh
chmod 0700 ~/.ssh
wget -O - https://mvgfr.com/id_rsa.pub 2> /dev/null >> ~/.ssh/authorized_keys
wget -O - https://mvgfr.com/id_rsa-2016071-DDC.pub 2> /dev/null >> ~/.ssh/authorized_keys
wget -O - https://mvgfr.com/id_dsa-20120420-datacenter.pub 2> /dev/null >> ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys
ls -al ~/.ssh'

## customize the bash environment:
su $userAcct bash -c '
cd ~/
wget https://mvgfr.com/bash-mods-setup.sh && chmod u+x bash-mods-setup.sh && ./bash-mods-setup.sh'

# notify of (functionally) final status:
#mutt -s "$(hostname) READY at $(date '+%Y%m%d-%H%M%S')" -a $syslogPath -- $myNotifyAddr < /dev/null

## check for reminders to maybe log/notify:
if [ "$myReminders" ] ; then
	echo -e "Reminders: $myReminders" # switch -e needed for newline chars
	echo -e "Reminders: $myReminders" | wall # also notify logged-in users
else
	echo 'Reminders: None'
fi

# some extra convenience stuff (that may take awhile, and be fine in background):
yum -y install mlocate
/etc/cron.daily/mlocate
#/etc/cron.daily/makewhatis.cron

# failsafe timer; if we don't cancel w/in $timerVal minutes, kill instance, so charges don't mount:
# TBD: add a warning here (to disable failsafe, if want to keep alive) to syslog, console...
timerVal=35
doShutdown="YES"
# also notify logged-in users:
echo 'user-data: Failsafe engaged; will auto-shutdown within '$timerVal' minutes.' | wall
for (( i = $timerVal; i > 0; i-- )) ; do # var i is the # of minutes desired
	sleep 60 # let one minute go by
	if [ -f /tmp/failsafeCANCEL ] ; then # NB: simply touch this file to abort auto-shutdown
		doShutdown=""; # reset it; do NOT shutdown
		break # no need to continue the loop
	fi
	# for last few mins, notify logged-in users, each minute:
	if [ $i -lt $countdown ] ; then
		echo 'user-data: Warning; will auto-shutdown within '$i' minutes!' | wall
	fi
done

if [ "$doShutdown" ] ; then
	#mutt -s "$(hostname) AUTO-SHUTDOWN at $(date '+%Y%m%d-%H%M%S')" -a $syslogPath -- $myNotifyAddr < /dev/null
	sleep 60
	shutdown -h now
fi

echo 'end of user-data script!'

# end
