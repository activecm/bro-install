#!/bin/bash
#Copyright 2017 William Stearns and Offensive Countermeasures


#This and node.cfg-template should be in the same directory.
#To test with different numbers of interfaces:
#	sudo modprobe dummy numdummies=30
#To remove these:
#	sudo rmmod dummy
#Once removed, one can rerun modprobe with a different number of dummies.
#To see the available interfaces, run:
#	sudo ip -o link

require_file () {
	#Returns true if all files or directories listed on the command line exist, False if one or more missing.

	while [ -n "$1" ]; do
		if [ ! -e "$1" ]; then
			echo "Missing object $1. Please install it. Exiting." >&2
			return 1					#False, at least one file or dir missing
		fi
		shift
	done
	return 0							#True, all objects are here
}


subtract_lists () {
	#Returns all lines in the first list ("$1", one line per entry, surround by double quotes when passing in) that aren't in the second (same notes).

	(
		echo "${1}" | sort -u
		echo "${2}"
		echo "${2}"
	) \
	 | sort \
	 | uniq -u
}


available_cores () {
	#Returns the number of available processor cores.

	grep '^processor\W\W*:\W[0-9]' /proc/cpuinfo | wc -l
}


available_interfaces () {
	#Returns a list of all non-loopback interfaces, one per line
	raw_if_list=`ip -o link | awk '{print $2}' | sed -e 's/:$//' | egrep -v '(^lo$)'`
	default_ifs=`/sbin/ip route | grep '^default ' | sed -e 's/^.* dev //' -e 's/  *$//'`
	non_default_ifs=`subtract_lists "$raw_if_list" "$default_ifs"`
	echo "$non_default_ifs" | tr '\n' ' '
}

if_stats_for () {
	#Returns the send/receive stats for the sole interface supplied as a parameter.
	if [ -n "$1" ]; then
		ip -s -o link | grep ' '"$1"':' | sed -e 's/\\/\n/g'		#Note; can't use "-h" for human readable as older versions of ip don't support it.
	else
		echo "No interface name supplied to if_stats_for."
	fi
}

askYN () {
	TESTYN=""
	while [ "$TESTYN" != 'Y' ] && [ "$TESTYN" != 'N' ] ; do
		echo -n '? ' >&2
		read TESTYN || :
		case $TESTYN in
		T*|t*|Y*|y*)		TESTYN='Y'	;;
		F*|f*|N*|n*)		TESTYN='N'	;;
		esac
	done

	if [ "$TESTYN" = 'Y' ]; then
		return 0 #True
	else
		return 1 #False
	fi
} #End of askYN


#======== Main ========

PATH="/bin:/sbin:/usr/bin:/usr/sbin:$PATH"
export PATH

require_file /bin/awk /bin/cp /bin/date /bin/egrep /bin/sed /bin/tr /proc/cpuinfo /sbin/ip || exit 1
#FIXME - restoreme
#require_file /usr/local/bro/etc/ || exit 1
#echo Continuing, all requirements met

this_script_path="$(dirname "$BASH_SOURCE[0]")"

while [ -n "$1" ]; do
	if [ "z$1" = "z--dry-run" ]; then
		DryRun='True'
	fi
	shift
done

if [ -d /usr/local/bro/etc/ ]; then
	bro_node_cfg='/usr/local/bro/etc/node.cfg'
elif [ -d /opt/bro/etc/ ]; then
	bro_node_cfg='/opt/bro/etc/node.cfg'
else
	echo "Unable to find bro configuration file node.cfg in either /usr/local/bro/etc/ or /opt/bro/etc/ ; exiting." >&2
	exit 1
fi

Now=`/bin/date +%Y%m%d%H%M%S`

avail_if_list=`available_interfaces`
avail_cores=`available_cores`
echo "This system has $avail_cores cores."
if [ `echo "$avail_if_list" | wc -w` -eq 0 ]; then
	echo "There are no potentially sniffable interfaces."
	echo "This script will not be able to generate a node.cfg file as at least one interface is required.  Exiting."
	exit 1
elif [ `echo "$avail_if_list" | wc -w` -eq 1 ]; then
	echo "The potentially sniffable interface is: $avail_if_list"
else
	echo "The potentially sniffable interfaces are: $avail_if_list"
fi

approved_ifs=''
for one_if in $avail_if_list ; do
	echo 'Here are the stats for '"$one_if"
	if_stats_for "$one_if"
	echo -n 'Would you like to include it as a sniff interface'
	if askYN ; then
		approved_ifs="$approved_ifs $one_if"
	fi
done
approved_if_count=`echo approved_ifs | wc -w`
echo ; echo

node_configuration_block=''
node_count=0
cores_per_if=$[ ( $avail_cores - 2 ) / $approved_if_count ]
if [ $cores_per_if -lt 1 ]; then
	echo "Warning: there are more interfaces than available cores.  Setting CoresPerInterface to 1." >&2
	cores_per_if=1
fi
for one_if in $approved_ifs ; do
	node_count=$[ $node_count + 1 ]
	node_configuration_block="$node_configuration_block\n\n[worker-${node_count}]\ntype=worker\nhost=127.0.0.1\ninterface=$one_if\nlb_method=pf_ring\nlb_procs=$cores_per_if\n"

done

if [ -e "$bro_node_cfg" ]; then
	cp -p "$bro_node_cfg" "$bro_node_cfg.$Now"
	echo "A backup has been made for the existing $bro_node_cfg ."
else
	echo "$bro_node_cfg does not exist, creating one from scratch."
fi


cat "$this_script_path/node.cfg-template" | sed -e 's/@@InterfaceConfig@@/'"$node_configuration_block"'/' >"${bro_node_cfg}.tmp"
echo "Here is the proposed new node.cfg:"
cat "$bro_node_cfg.tmp"
echo
echo -n "Would you like to replace the existing node.cfg with the above file"
if askYN ; then
	mv "${bro_node_cfg}.tmp" "$bro_node_cfg"
else
	echo "No change has been made to node.cfg."
fi


