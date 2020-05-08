#!/bin/bash
#Copyright 2017-2018 William Stearns and Active Countermeasures
#v0.5.2


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

check_zeek_path () {
	if [ -d /usr/local/zeek/etc/ -o -d /opt/zeek/etc/ ]; then
		return 0
	fi
	return 1
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
		echo -n '? ' >&2
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


#======== Main ========

PATH="/bin:/sbin:/usr/bin:/usr/sbin:$PATH"
export PATH

ids_name=""
if check_zeek_path; then
	ids_name="zeek"
else
	ids_name="bro"
fi


echo -e "\e[96mNote\e[0m: It is now time to select capture interface(s). Keep the following in mind when making selections:"
echo -e "      \e[1m1. The interfaces you most likely want to use for capturing start with \"eth\" or \"en\" (e.g. eth0, eno1, enp1s0, enx78e7d1ea46da)\e[0m."
echo -e "      \e[1m   You will generally NOT want to use loopback, bridged, or virtual interfaces (e.g. lo, br-c446eb08dde, veth582437d)\e[0m."
echo -e "      \e[1m   If you choose to select interfaces belonging to the latter category, proceed at your own risk\e[0m."
echo
echo -e "      \e[1m2. Ensure that your capture interfaces are up before continuing\e[0m."
echo
echo -n "Would you like to continue running the $ids_name configuration script and generate a new node.cfg file? (y/n) "

if ! askYN ; then
	echo "Will not continue creating node.cfg.  Exiting."
	exit 1
fi


require_file /proc/cpuinfo				|| fail "Missing /proc/cpuinfo ; is this a Linux system? "
require_util awk cp date egrep grep mv sed tr ip wc	|| fail "A needed tool is missing"

if [ ! -d /usr/local/$ids_name/etc/ -a ! -d /opt/$ids_name/etc/ ]; then
	fail "Missing $ids_name configuration dir /opt/$ids_name/etc/ or /usr/local/$ids_name/etc "
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

if [ -d /usr/local/$ids_name/etc/ ]; then
	node_cfg="/usr/local/$ids_name/etc/node.cfg"
elif [ -d /opt/$ids_name/etc/ ]; then
	node_cfg="/opt/$ids_name/etc/node.cfg"
else
	fail "Unable to find $ids_name configuration file node.cfg in either /usr/local/$ids_name/etc/ or /opt/$ids_name/etc/ "
fi

Now=`/bin/date +%Y%m%d%H%M%S`

avail_if_list=`available_interfaces`
avail_cores=`available_cores`
echo "This system has $avail_cores cores."
if [ `echo "$avail_if_list" | wc -w` -eq 0 ]; then
	fail "There are no potentially sniffable interfaces.  This script will not be able to generate a node.cfg file as at least one interface is required"
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
	echo "This configuration has no sniff interfaces, so $ids_name will not be able to run.  Exiting $ids_name configuration script."
	exit 1
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

if [ -e "$node_cfg" ]; then
	cp -p "$node_cfg" "$node_cfg.$Now"
	echo "A backup has been made for the existing $node_cfg ."
else
	echo "$node_cfg does not exist, creating one from scratch."
fi


cat "$this_script_path/node.cfg-template" | sed -e 's/@@InterfaceConfig@@/'"$node_configuration_block"'/' >"${node_cfg}.tmp"
echo "Here is the proposed new node.cfg:"
cat "$node_cfg.tmp"
echo
echo -n "Would you like to replace the existing node.cfg with the above file"
if askYN ; then
	mv "${node_cfg}.tmp" "$node_cfg"
else
	echo "No change has been made to node.cfg."
fi
