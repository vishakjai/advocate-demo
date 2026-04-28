#!/bin/bash
#
# Used to examine bootstrap logs from a single day and calculate the total duration
# including any reboots that may have occured between bootstrap script executions.
#
# This can be run against a remote machine by providing it's hostname as a single arg
# or on the machine directly by running without any arguments.
#
# It defaults to the current date, but can be overridden by setting a DATE_OVERRIDE var
# in the format of DATE_OVERRIDE=YYYYMMDD
#
set -eo pipefail

host="$1"

date="$(date "+%F" | tr -d '-')"

if [[ -n $DATE_OVERRIDE ]]; then
  date="$DATE_OVERRIDE"
fi

if [[ -n $host ]]; then
  ## If the remote script exists, remove it
  ssh -o StrictHostKeyChecking=no "$host" 'if [[ -f /tmp/find-bootstrap.sh ]]; then sudo rm -f /tmp/find-bootstrap.sh; fi' 2>/dev/null
  ## Install a new version of the script to the remote host
  scp -o StrictHostKeyChecking=no -q "$0" "$host:/tmp/find-bootstrap.sh"
  ## Execute and remove the remote script
  ssh -o StrictHostKeyChecking=no "$host" "DATE_OVERRIDE=$DATE_OVERRIDE bash /tmp/find-bootstrap.sh; rm -f /tmp/find-bootstrap.sh"
  exit 0
fi

file_prefix="/var/tmp/bootstrap-$date"

echo "Processing host: $host"
echo "Looking for bootstrap logs from $date..."

start_date="$(grep -h 'Bootstrap start' "$file_prefix"* | grep -v echo | head -n1 | sed 's/: Bootstrap start//')"
if [[ -z $start_date ]]; then
  echo "Error: Could not find bootstrap start date in logs" >&2
  exit 1
fi
echo "Found bootstrap start: $start_date"
start_seconds="$(date --date="$start_date" "+%s")"

end_date="$(grep -h 'Bootstrap finished' "$file_prefix"* | grep -v echo | tail -n1 | sed 's/: Bootstrap finished.*//')"
if [[ -z $end_date ]]; then
  echo "Error: Could not find bootstrap end date in logs" >&2
  exit 1
fi
echo "Found bootstrap end: $end_date"
end_seconds="$(date --date="$end_date" "+%s")"

chef_durations="$(grep -E '^(Chef|Cinc) Client finished' "$file_prefix"* | awk -F'in ' '{print $2}' | awk '{print $1":"$3}')"
chef_seconds=0
chef_minutes=0

for duration in $chef_durations; do
  seconds="$(awk -F':' '{print $2}' <<<"$duration")"

  if [[ -z $seconds ]]; then
    seconds="$(awk -F':' '{print $1}' <<<"$duration")"
    chef_seconds=$((chef_seconds + 10#$seconds))
    continue
  fi

  minutes="$(awk -F':' '{print $1}' <<<"$duration")"
  chef_seconds=$((chef_seconds + 10#$seconds))
  chef_minutes=$((chef_minutes + 10#$minutes))
done

chef_seconds=$((chef_seconds + chef_minutes * 60))

echo "$HOSTNAME: Bootstrap duration: total: $((end_seconds - start_seconds))s, Chef: ${chef_seconds}s at $(date --date="$end_date" "+%Y-%m-%d %T")"
