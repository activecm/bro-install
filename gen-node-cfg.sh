#!/bin/bash
#Copyright 2017-2018 William Stearns and Active Countermeasures
#v0.5.2

#Returns 0 if node.cfg was successfully set up.
#Returns 1 if an unexpected error arrises.
#Returns 2 if node.cfg was not set up (due to user choice or lack of resources)

#This and node.cfg-template should be in the same directory.
#This will create a new node.cfg, but will ask the user to confirm replacement before doing so.
#To test with different numbers of interfaces:
#	sudo modprobe dummy numdummies=30
#	for oneif in `ifconfig -a | grep '^dummy' | awk '{print $1}'` ; do sudo /sbin/ifconfig "$oneif" up ; done
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


require_util () {
	#Returns true if all binaries listed as parameters exist somewhere in the path, False if one or more missing.
        while [ -n "$1" ]; do
                if ! type -path "$1" >/dev/null 2>/dev/null ; then
                        echo Missing utility "$1". Please install it. >&2
                        return 1        #False, app is not available.
                fi
                shift
        done
        return 0        #True, app is there.
} #End of requireutil


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
	raw_if_list=`ip -o link | egrep '(state UP|state UNKNOWN|state DORMANT)' | awk '{print $2}' | sed -e 's/:$//' | egrep -v '(^lo$)'`
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
		echo -n '?' >&2
		read TESTYN <&2 || :
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


fail () {
	echo "$*, exiting." >&2
	exit 1
}

exit_no_node_cfg () {
	echo "$*, exiting." >&2
	exit 2
}

#======== Main ========

PATH="/bin:/sbin:/usr/bin:/usr/sbin:$PATH"
export PATH


echo 'If you need to check or change your network interfaces, please do so now'
echo 'by switching to a different terminal and making any changes.  Please note'
echo 'that any interfaces you would like to use for packet capture must be up'
echo 'and configured before you continue.  When the interfaces are ready,'
echo 'please return to this terminal.'
echo
echo 'Would you like to continue running the Bro configuration script? '
echo 'You might answer no if you know you have already created a working'
echo 'node.cfg and do not wish to replace it.  Otherwise we recommend'
echo 'continuing with this script.'
echo -n '(y/n)'
if askYN ; then
	:
else
	exit_no_node_cfg "Will not continue creating node.cfg"
fi



require_file /proc/cpuinfo				|| fail "Missing /proc/cpuinfo ; is this a Linux system? "
require_util awk cp date egrep grep mv sed tr ip wc	|| fail "A needed tool is missing"
if [ ! -d /usr/local/bro/etc/ -a ! -d /opt/bro/etc/ ]; then
	fail "Missing bro configuration dir /opt/bro/etc/ or /usr/local/bro/etc "
fi
echo Continuing, all requirements met

this_script_path=$(dirname "${BASH_SOURCE[0]}")

require_file "$this_script_path/node.cfg-template"	|| fail "There is no node.cfg-template in the current directory"

#Not needed at the moment as we ask the user whether to replace node.cfg before doing so.
#while [ -n "$1" ]; do
#	if [ "z$1" = "z--dry-run" ]; then
#		DryRun='True'
#	fi
#	shift
#done

if [ -d /usr/local/bro/etc/ ]; then
	bro_node_cfg='/usr/local/bro/etc/node.cfg'
elif [ -d /opt/bro/etc/ ]; then
	bro_node_cfg='/opt/bro/etc/node.cfg'
else
	fail "Unable to find bro configuration file node.cfg in either /usr/local/bro/etc/ or /opt/bro/etc/ "
fi

Now=`/bin/date +%Y%m%d%H%M%S`

avail_if_list=`available_interfaces`
avail_cores=`available_cores`
echo "This system has $avail_cores cores."
if [ `echo "$avail_if_list" | wc -w` -eq 0 ]; then
	exit_no_node_cfg "There are no potentially sniffable interfaces.  This script will not be able to generate a node.cfg file as at least one interface is required"
elif [ `echo "$avail_if_list" | wc -w` -eq 1 ]; then
	echo "The potentially sniffable interface is: $avail_if_list"
else
	echo "The potentially sniffable interfaces are: $avail_if_list"
fi

approved_ifs=''
for one_if in $avail_if_list ; do
	echo 'Here are the stats for '"$one_if"
	if_stats_for "$one_if"
	echo -n 'Would you like to include it as a sniff interface (y/n)'
	if askYN ; then
		approved_ifs="$approved_ifs $one_if"
	fi
done
approved_if_count=`echo $approved_ifs | wc -w`
echo ; echo

node_configuration_block=''
node_count=0
if [ $approved_if_count -eq 0 ]; then
	exit_no_node_cfg "This configuration has no sniff interfaces, so bro will not be able to run"
else
	cores_per_if=$[ ( $avail_cores - 4 ) / $approved_if_count ]
fi
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


