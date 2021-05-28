#!/bin/sh
# pfELK Firewall rules description sync

# pfELK variables
version=1.1
ini=/usr/local/opnsense/scripts/pfelk/pfelk_rule_sync.ini

# Color Codes 
normal=`echo "\033[0;0m"`
blwhite=`echo "\033[0;01m"`
blue=`echo "\033[0;36m"` #Blue
yellow=`echo "\033[0;33m"` #yellow
red=`echo "\033[0;31m"`
green=`echo "\033[0;32m"`  # Green

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

sync(){
	count=`grep -c ^ /tmp/rule-names.csv`
	. $ini
	printf "${blue}${count}${normal} rules have been sync to ${blue}pfELK ${yellow}(${pfelk_ip})${normal}\n";
	scp /tmp/rule-names.csv root@${pfelk_ip}:/etc/logstash/conf.d/databases/rule-names.csv
}

opnsense_pfctl 2> /dev/null
opnsense_opt1
opnsense_join
sync
