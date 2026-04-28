#!/bin/bash
# shellcheck disable=SC2089,SC2016,SC2155,SC2162,SC2029,SC2086,SC2090

# TODO: consider adding a dry-run mode

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo >&2 "usage: redis-reconfigure.sh env cluster [bootstrap]"
  echo >&2 ""
  echo >&2 "  e.g. redis-reconfigure.sh gstg redis-cache"
  echo >&2 ""
  exit 65
fi

export gitlab_env=$1
export gitlab_redis_service=$2

if [[ $# -eq 3 && $3 == "bootstrap" ]]; then
  export bootstrap="yes"
else
  export bootstrap="no"
fi

case $gitlab_env in
pre)
  export gitlab_project=gitlab-pre
  ;;
gstg)
  export gitlab_project=gitlab-staging-1
  ;;
gprd)
  export gitlab_project=gitlab-production
  ;;
*)
  echo >&2 "error: unknown environment: $gitlab_env"
  exit 1
  ;;
esac

export redis_cli='sudo gitlab-redis-cli'
export sentinel="${gitlab_redis_service}-01-db-${gitlab_env}.c.${gitlab_project}.internal"

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

failover_if_master() {
  export i=$1
  export fqdn="${gitlab_redis_service}-$i-db-${gitlab_env}.c.${gitlab_project}.internal"

  echo "> failover_if_master $fqdn"

  role=$(ssh "$fqdn" "$redis_cli role | head -n1")
  echo $role

  # if role is master, perform failover
  if [[ $role == "master" ]]; then
    echo failing over
    wait_for_input
    ssh "$sentinel" "/opt/redis/redis-cli -p 26379 sentinel failover mymaster"

    # TODO: remove when gitlab-redis cookbook resolves secret parsing
    # sentinel failover reformats the redis.conf file, affecting how passwords are extracted
    run_chef_client
  fi

  # wait for master to step down and sync (expect "slave" [sic] and "connected")
  while ! [[ "$(ssh "$fqdn" "$redis_cli role" | head -n1)" == "slave" ]]; do
    echo waiting for stepdown
    sleep 30
  done
  while ! [[ "$(ssh "$fqdn" "$redis_cli --raw role" | tail -n +4 | head -n1)" == "connected" ]]; do
    echo waiting for sync
    sleep 30
  done

  # wait for sentinel to ack the master change
  while [[ "$(ssh "$sentinel" "/opt/redis/redis-cli -p 26379 --raw sentinel master mymaster" | grep -A1 ^ip$ | tail -n +2 | awk '{ print substr($0, length($0)-1) }')" == "$i" ]]; do
    echo waiting for sentinel
    sleep 1
  done

  echo "< failover_if_master $fqdn"
}

check_sentinel_quorum() {
  # check sentinel quorum
  echo sentinel ckquorum

  quorum=$(ssh "$sentinel" "/opt/redis/redis-cli -p 26379 sentinel ckquorum mymaster")
  echo $quorum

  if [[ $quorum != "OK 3 usable Sentinels. Quorum and failover authorization can be reached" ]]; then
    echo >&2 "error: sentinel quorum to be ok"
    exit 1
  fi
}

run_chef_client() {
  echo chef-client
  wait_for_input
  ssh "$fqdn" "sudo chef-client"
}

restart_redis() {
  # this _will_ restart processes
  echo "Restarting $fqdn Redis server to apply config changes"
  wait_for_input
  ssh "$fqdn" 'sudo systemctl restart redis-server.service && sleep 30'
}

reconfigure() {
  export i=$1
  export fqdn="${gitlab_redis_service}-$i-db-${gitlab_env}.c.${gitlab_project}.internal"

  echo "> reconfigure $fqdn"

  # double check that we are dealing with a replica
  echo checking role
  ssh "$fqdn" "$redis_cli --no-raw role"

  if [[ "$(ssh "$fqdn" "$redis_cli role | head -n1")" == "master" ]]; then
    echo >&2 "error: expected $fqdn to be replica, but it was a master"
    exit 1
  fi

  if [[ "$(ssh "$fqdn" "$redis_cli --raw role" | tail -n +4 | head -n1)" != "connected" ]]; then
    echo >&2 "error: expected $fqdn to be in state connected"
    exit 1
  fi

  check_sentinel_quorum

  run_chef_client

  # temporarily disable rdb saving to allow for fast restart
  echo config get save
  ssh "$fqdn" "$redis_cli config get save"

  echo config set save
  ssh "$fqdn" "$redis_cli config set save ''"

  restart_redis

  # TODO: remove when gitlab-redis cookbook resolves secret parsing
  # fixes changes to redis.conf
  run_chef_client

  # wait for master to step down and sync (expect "slave" [sic] and "connected")
  while ! [[ "$(ssh "$fqdn" "$redis_cli role" | head -n1)" == "slave" ]]; do
    echo waiting for stepdown
    sleep 30
  done
  while ! [[ "$(ssh "$fqdn" "$redis_cli --raw role" | tail -n +4 | head -n1)" == "connected" ]]; do
    echo waiting for sync
    sleep 30
  done

  # ensure config change took effect
  echo config get save
  ssh "$fqdn" "$redis_cli config get save"

  # check sync status
  echo check redis role for each node
  for host in $(seq -f "${gitlab_redis_service}-%02g-db-${gitlab_env}.c.${gitlab_project}.internal" 1 3); do
    ssh "$host" 'hostname; '$redis_cli' role | head -n1; echo'
  done

  # check sentinel status
  check_sentinel_quorum

  echo "< reconfigure $fqdn"
}

check_bootstrapped() {
  uniques=()
  while IFS='' read -r line; do uniques+=("$line"); done < <(
    for host in $(seq -f "${gitlab_redis_service}-%02g-db-${gitlab_env}.c.${gitlab_project}.internal" 1 3); do
      ssh "$host" "$redis_cli role | head -n1"
    done | sort
  )

  if [ "${uniques[*]}" == 'master slave slave' ]; then
    echo >&2 "error: already bootstrapped"
    exit 1
  fi
}

bootstrap() {
  export i=$1
  export fqdn="${gitlab_redis_service}-$i-db-${gitlab_env}.c.${gitlab_project}.internal"
  export primary="${gitlab_redis_service}-01-db-${gitlab_env}.c.${gitlab_project}.internal"

  echo "> bootstrapping $fqdn"

  # Make everything work

  run_chef_client

  if [ $i != 01 ]; then
    echo "> setting $fqdn as replica of $primary"
    ssh $fqdn "$redis_cli replicaof $primary 6379"
  fi
}

for i in 01 02 03; do

  if [[ $bootstrap == "yes" ]]; then
    check_bootstrapped
    bootstrap $i
  else
    failover_if_master $i
    reconfigure $i
  fi

  echo
done
