#!/bin/bash
# shellcheck disable=SC2162,SC2013

set -e
set -o pipefail

if [[ $# -lt 1 ]]; then
  echo >&2 "usage: redis-cluster-reconfigure.sh filepath"
  echo >&2 ""
  echo >&2 "  e.g. redis-cluster-reconfigure.sh nodes.txt"
  exit 65
fi

export redis_nodelist_filepath=$1

wait_for_input() {
  declare input
  while read -n 1 -p "Continue (y/n): " input && [[ $input != "y" && $input != "n" ]]; do
    echo
  done
  if [[ $input != "y" ]]; then
    echo
    echo >&2 "error: aborting"
    exit 1
  fi
  echo
}

run_chef_client() {
  echo chef-client
  wait_for_input
  ssh "$fqdn" "sudo chef-client"
}

run_failover() {
  echo "Failover $fqdn if it is a primary node"
  wait_for_input
  ssh "$fqdn" 'sudo redis-cluster-failover-if-primary && sleep 30'
}

restart_redis() {
  echo "Restarting $fqdn Redis server to apply config changes"
  wait_for_input
  ssh "$fqdn" 'sudo systemctl restart redis-server.service && sleep 30'
}

reconfigure() {
  export fqdn=$1

  echo "Starting reconfigure process for $fqdn"

  run_chef_client

  run_failover

  restart_redis

  ssh "$fqdn" 'sudo gitlab-redis-cli cluster nodes'
}

IFS=$'\n'
for line in $(cat "$redis_nodelist_filepath"); do
  reconfigure "$line"
  echo "Finished failover and restart of $line"
  echo >&2 ""
done
