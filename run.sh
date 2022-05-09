#!/bin/bash

set -uo pipefail

if [ "$EUID" -ne 0 ];then
	echo not running as root
	exit
fi

if [ $# != 1 ]; then
	echo choose from ffmpeg mysql redis mlperf
	exit
fi

if [ ! -e config ];then
	echo config not found
	exit
fi

function clean_env()
{

	if [[ -e /sys/fs/cgroup/memory/rmem ]]; then
		pids=$(cat /sys/fs/cgroup/memory/rmem/tasks)
		if [[ ! -z ${pids} ]]; then
			kill -9 ${pids}
		fi
	fi

	if [[ -e /sys/fs/cgroup/cpuset/rmem ]]; then
		pids=$(cat /sys/fs/cgroup/cpuset/rmem/tasks)
		if [[ ! -z ${pids} ]]; then
			kill -9 ${pids}
		fi
	fi

	sleep 1

	cgdelete cpuset,memory:rmem
}

function do_exit()
{
	echo "cleaning environment"
	clean_env
	exit
}

source config
clean_env

# setup CPU affinity
cpus=$(numactl --hardware | grep "node ${node} cpus" | awk '{print $4"-"$NF}')
mkdir /sys/fs/cgroup/cpuset/rmem
echo $mems > /sys/fs/cgroup/cpuset/rmem/cpuset.mems
echo $cpus > /sys/fs/cgroup/cpuset/rmem/cpuset.cpus

# setup global memory limit
mkdir /sys/fs/cgroup/memory/rmem
echo $global_mem_limit > /sys/fs/cgroup/memory/rmem/memory.limit_in_bytes
echo 1 > /sys/fs/cgroup/memory/rmem/memory.swappiness

# set local memory limit and start execution
echo $local_mem_limit > /proc/rmem/limit

if [ $1 == "mysql" ]; then
	cgexec -g cpuset,memory:rmem $mysqlcmd
elif [ $1 == "ffmpeg" ]; then
	cgexec -g cpuset,memory:rmem $ffmpegcmd
elif [ $1 == "redis" ]; then
	cgexec -g cpuset,memory:rmem $rediscmd
else
	echo not supported
fi

trap do_exit SIGINT
read -r -d '' _ </dev/tty

