#!/bin/bash
##################################################################
##### Restic Better Backup #######################################
##### Auth: Shan Destromp ########################################
##### Date: 2024.07.07 ###########################################
##### Desc: Wrapper script to handle multiple restic repos #######
#####       and handle basic functions, while also being #########
#####       compatible with cron usage. ##########################
#####       (its "better" than my last attempt) ##################
##################################################################

VER=0.1.0

# Better backup script using restic
# Requires:  restic, wakeonlan, nc
# ASSUMES you have pubkey for ssh access otherwise automated actions will likely fail


# Select your desired compression level off/auto/max
export RESTIC_COMPRESSION=max
# Set to password for existing repos, otherwise will be used when initializing new repos
export RESTIC_PASSWORD=8675309Jenny

# WakeOnLan settings
MAC=00:00:00:00:00:00 # MAC address of the host to wake
Broadcast=192.168.1.255 # Broadcast of the host network

# SSH
HOSTNAME="collective" # hostname of the remote host (if none set same as $HOST)
HOST=192.168.1.2 # IP address of the remote host
PORT=22 # SSH/SFTP port

# Repository settings
USER="root" # ssh user
RESPATH="/hive/" # path to repository WITHOUT final directory name
REPFMT="sftp:$USER@$HOSTNAME:$RESPATH" # Probably shouldn't modify unless you know what you're doing
MLOC="/mnt/restic" # local mount location for remote repository

# Options for snapshot retention
KEEP="\
	--keep-weekly 4 \
	--keep-monthly 2 \
	--keep-yearly 1"

# Locations to backup
# Full path on local machine
# Last segment will become repository name
# ex "/nexus/cloud" will become "/hive/cloud" on remote host
BACLOC=( "/nexus/cloud"
	"/nexus/common"
	"/nexus/dalek"
	"/nexus/docker"
	"/nexus/tardis"
)

# List of things to exclude from backups
# see https://restic.readthedocs.io/en/latest/040_backup.html#excluding-files
EXCL="/opt/common/restic_excludes.txt"

# Additional *GLOBAL* options to restic to include in commands
# Multiple "verbose" lines increase output (upto 3x)
# Generally we want to be quiet (backup does not use this flag)
OPTS=(
#	"--verbose"
#	"--verbose"
	"--quiet"
)

FIL='########################################################################'

# SPECIAL actions
# The following function is performed at the end of any cron action, 
# enabling you to add additional commands to be performed, such as
# starting a zfs scrub or shutting down the remote server.
function f_special {
	# Checks if this is an even/odd week and initiates scrub accordingly
	WEEK=$(date +%U)
	if [ $(( WEEK % 2)) -eq 0 ]
	then
		echo $FIL
		echo "#### Initiating Scrub                                               ####"
		echo -e $FIL "\n"
		ssh $USER@$HOSTNAME "zpool scrub hive"
	else
		echo $FIL
		echo "#### Shutting Down                                                  ####"
		echo -e $FIL "\n"

		ssh $USER@$HOSTNAME "shutdown now"
	fi
}

#####################################################
#### Below Here be demons, Edit at your own Risk ####
#####################################################

RES=$(which restic)

MODE="$(echo "$1" | tr '[:upper:]' '[:lower:]')" #mode in lowercase for ease
OPT="$(echo "$2" | tr '[:upper:]' '[:lower:]' | sed 's:/*$::')"

# Self Updater
function f_update {
		$RES self-update
	exit 0
}

# Host check
function f_hostcheck {
	echo "Checking $HOSTNAME status"

	j=0
	while ! nc -n -z -w 1 $HOST $PORT; do
        printf "."
        sleep 10
        j=$((j+1))
		# 600 second timeout
        if [ $j -ge 60 ]; then
                echo ""
                echo >&2 $HOSTNAME @ $HOST:$PORT unreachable, aborting
                exit 1
        fi
	done
}

# WoL remote machine
function f_wakeup {
	WOL=$(which wakeonlan)

	echo $FIL
	echo "#### Wake $HOSTNAME                                                  ####"
	echo -e $FIL "\n"
	$WOL -i $Broadcast $MAC
	echo -e "\n"

	echo $FIL
	echo "#### Sleeping until $HOSTNAME awakens                                  ####"
	echo -e $FIL "\n"

	f_hostcheck
	if [ "$MODE" != "cron" ]; then exit 0; fi
}

# list repositories
function f_list {
	for LOC in "${BACLOC[@]}"; do
		echo "$LOC"
	done
}

# select Repository
function f_repository {
	REPLOC=$(echo "$OPT" | rev | cut -d '/' -f 1 | rev)
	export RESTIC_REPOSITORY=$REPFMT$REPLOC
}

# restic options combiner
function f_ropts {
	ROPTS=""
	for i in "${OPTS[@]}"; do
		ROPTS="$ROPTS $i"
	done
}

# initialize repo
function f_init {
	f_ropts

	# Loops repositories
	for LOC in "${BACLOC[@]}"; do
		OPT=$LOC
		f_repository

		# New Repository, init it
		if ! restic cat config > /dev/null
		then
			echo $FIL
			echo "#### Repository $RESTIC_REPOSITORY missing, creating ####"
			echo -e $FIL "\n"

			$RES "$ROPTS" init
		# Existing Repo, move on
		else
			echo $FIL
			echo "#### Repository $RESTIC_REPOSITORY found, proceeding ####"
			echo -e $FIL "\n"
		fi
	done
	if [ "$MODE" != "cron" ]; then exit 0; fi
}

# snapshot action
function f_snapshot {
	echo $FIL
	echo "#### Backing up ""$OPT""                                       ####"
	echo -e $FIL "\n"

	$RES backup --iexclude-file="$EXCL" "$OPT"
}

# backup sequence
function f_backup {
	f_ropts

	if [ "$OPT" = "list" ]
	then
		f_list
	elif [ -d "$OPT" ]
	then
		f_repository
		f_snapshot
	else
		for LOC in "${BACLOC[@]}"; do
			OPT=$LOC
			f_repository
			f_snapshot
		done
	fi
	if [ "$MODE" != "cron" ]; then exit 0; fi
}

# prune action
function f_prune {
	# Runs a prune in accordance of the $KEEP settings
	echo $FIL
	echo "#### Pruning $OPT                                          ####"
	echo -e $FIL "\n"

	$RES "$ROPTS" forget "$KEEP" --prune
	# Checks for unreferenced data
	$RES "$ROPTS" check
	# Prunes above
	$RES "$ROPTS" prune
}

# clean sequence
function f_cleanup {
	f_ropts

	if [ "$OPT" = "list" ]
	then
		f_list
	elif [ -d "$OPT" ]
	then
		f_repository
		f_prune
	else
		for LOC in "${BACLOC[@]}"; do
			OPT=$LOC
			f_repository
			f_prune
		done
	fi
	if [ "$MODE" != "cron" ]; then exit 0; fi
}

# repository statistics
function f_stats {

	echo $FIL

	for LOC in "${BACLOC[@]}"; do
		OPT=$LOC
		f_repository
		echo "#### $LOC Statistics                                        ####"
		$RES stats latest
		echo ""
	done
	echo -e $FIL "\n"
	if [ "$MODE" != "cron" ]; then exit 0; fi
}

# mount repo
function f_mount {
	if [ "$OPT" = "list" ] || [ -z "$OPT" ]
	then
		f_list
	else

		f_repository

		if [ ! -d $MLOC ]
		then
			mkdir $MLOC
		fi

		if [ -d $MLOC ]
		then
			$RES mount $MLOC 2>&1 > /dev/null &
			sleep 2
			echo "When unmounting, it is safe to ignore the \"unable to umount\" error"
			exit 0
		else
			echo "Unwriteable location"
			exit 1
		fi
	fi
	exit 0
}

# unmount repo
function f_unmount {
	umount $MLOC
	exit 0
}

# help screen
function f_help {
	echo "$0 version $VER"
	echo ""

	echo "Useage:"
	echo "$0 [command] [options]"
	echo ""

	echo "Commands:"

	printf "\nhelp\n\t\t prints this screen"
	printf "\n\t\t\t no options"

	printf "\nupdate\n\t\t %s self-updater" "$RES"
	printf "\n\t\t\t no options"

	printf "\nwakeup\n\t\t Manually wakeup %s %s then exit" "$HOSTNAME" "$HOST"
	printf "\n\t\t\t no options"

	printf "\nlist\n\t\t Lists all available repositories."
	printf "\n\t\t\t no options"

	printf "\ninit\n\t\t Initalizes all configured repositories."
	printf "\n\t\t\t no options"

	printf "\nbackup [options]\n\t\t executes a repository backup"
	printf "\n\t\t\t [none] :  Executes a complete backup of all stored repositories."
	printf "\n\t\t\t list : Lists all available repositories."
	printf "\n\t\t\t [repository] : Only executes on selected repository."

	printf "\ncleanup [options]\n\t\t executes a repository cleanup"
	printf "\n\t\t\t [none] :  Executes a complete cleanup of all stored repositories."
	printf "\n\t\t\t list : Lists all available repositories."
	printf "\n\t\t\t [repository] : Only executes on selected repository."

	printf "\nmount [options]\n\t\t mounts a repository to the local fs for browsing"
	printf "\n\t\t\t list : Lists all available repositories."
	printf "\n\t\t\t [repository] : mounts selected repository."

	printf "\numount\n\t\t unmounts a repository to the local fs for browsing"
	printf "\n\t\t\t no options"

	printf "\nstats\n\t\t Prints repository statistics."
	printf "\n\t\t\t no options"

	printf "\ncron\n\t\t Special operations mode specific for cron usage.  Runs in sequence "
	printf "\n\t\t\t wakeup, init, backup, cleanup, stats and *special* for all repositories "
	printf "\n\t\t\t configured.  Read script for special actions"

	printf "\n"
	exit 0
}

# Never a third option, send them to help
if [ -n "$3" ]; then MODE="help"; fi


case $MODE in

	update)
		f_update
	;;

	wakeup)
		f_wakeup
	;;

	list)
		f_list
	;;

	backup)
		f_hostcheck
		f_backup
	;;

	cleanup)
		f_hostcheck
		f_cleanup
	;;

	mount)
		f_hostcheck
		f_mount
	;;

	umount)
		f_unmount
	;;

	stats)
		f_hostcheck
		f_stats
	;;

	cron)
		f_wakeup
		f_init
		f_backup
		f_cleanup
		f_stats
		f_special
	;;

	help|*)
		f_help
	;;

esac