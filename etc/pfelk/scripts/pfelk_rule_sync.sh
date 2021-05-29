#!/bin/sh
# pfELK Firewall rules description sync

# pfELK variables
ini=/usr/local/opnsense/scripts/pfelk/pfelk_rule_sync.ini
. $ini

# Color Codes 
normal=`echo "\033[0;0m"`
blwhite=`echo "\033[0;01m"`
blue=`echo "\033[0;36m"` #Blue
yellow=`echo "\033[0;33m"` #yellow
red=`echo "\033[0;31m"`
green=`echo "\033[0;32m"`  # Green

script_logo() {
cat << "EOF"
        ________________.____     ____  __. 
_______/ ____\_   _____/|    |   |    |/ _|
\____ \   __\ |    __)_ |    |   |      <  
|  |_> >  |   |        \|    |___|    |  \ 
|   __/|__|  /_______  /|_______ \____|__ \ 
|__|                 \/         \/       \/
EOF
echo "    pfELK auto-sync rule description ${version}
"
}

input-text(){
	clear
	script_logo
	help_script
}

help_script() {
echo -e "Script usage:
pfelk_rule_sync.sh ${yellow}--sync	${normal}Synchronize rule descriptions to ${blue}pfELK${normal} (${pfelk_ip})
pfelk_rule_sync.sh ${yellow}--update	${normal}Update the auto-sync script
"
}

opnsense_pfctl(){
	pfctl -vv -sr | grep label | sed -r 's/@([[:digit:]]+).*"([^"]{32})"/"\2","\1"/g' | sort -k 1.1 > /tmp/pfelk_rules_pfctl.tmp
}

opnsense_opt1(){
	cat /tmp/rules.debug | egrep -o '(\w{32}).*' | sed -r 's/([[:alnum:]]{32})(" # : |" # )(.*)/"\1","\3"/g' | sort -t, -u -k1.1 > /tmp/pfelk_rules_opt1.tmp
}

opnsense_join(){
	join -t "," -o 1.2,2.2 /tmp/pfelk_rules_pfctl.tmp /tmp/pfelk_rules_opt1.tmp | sort -V | awk 'NR==1{$0="\"Rule\",\"Label\""RS$0}7' > /tmp/rule-names.csv
	rm /tmp/pfelk_rules*
}

pfelk_sync(){
	count=`grep -c ^ /tmp/rule-names.csv`
	. $ini
	printf "${blue}${count}${normal} rules have been sync to ${blue}pfELK ${yellow}(${pfelk_ip})${normal}\n";
	scp /tmp/rule-names.csv root@${pfelk_ip}:/etc/logstash/conf.d/databases/rule-names.csv
}

pfelk_update(){
	FILE=/usr/local/opnsense/service/conf/actions.d/actions_filter.conf
	# Updated file actions_filter.conf to start the script when modifying firewall rules
	echo -e "Backup ${yellow}actions_filter.conf${normal} to ${yellow}actions_filter.conf.bak${normal}"
	cp $FILE $FILE.bak
	echo -e "Update ${yellow}actions_filter.conf${normal} to integrate the pfELK script"
	sed -i '' 's/command:\/usr\/local\/etc\/rc\.filter_configure.*/command:\/usr\/local\/etc\/rc\.filter_configure;\/usr\/local\/opnsense\/scripts\/pfelk\/pfelk_rule_sync.sh --sync/' $FILE
	echo -e "Restart the ${yellow}configd service${normal}"
	service configd restart
	echo -e "Start the ${yellow}OPNSense filter service${normal}"
	OUTPUT=$(configctl filter reload)
	if [ ${OUTPUT} = "OK" ]; then
		echo -e "Everything is ${green}Good${normal} !"
	else
		echo -e "Something is ${red}Wrong${normal} !"
	fi
	echo -e "You will now see the message ${yellow}\"Reloading filter\"${normal} in the OPNsense log view here ${blue}System > Log Files > Backend${normal}"
}

while [ -n "$1" ]; do
	case "$1" in
	--sync)
		opnsense_pfctl 2> /dev/null
		opnsense_opt1
		pfelk_sync
		exit;;
	--update)
		pfelk_update
		exit;;
	*)
		input-text
		printf "${red}option $1 is unknown${normal}\n";
		exit;;
	esac
	shift
done

input-text
