#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'date'
require "csv"
require 'optparse'
require 'terminal-table'
require 'open3'

module SubCmd
  LIST = 'list'
  DURATIONS = 'durations'
  SIZES = 'sizes'
end

SNAPSHOT_LIST_LOOKBACK = 1

InvalidEnvError = Class.new(StandardError)
InvalidBucketDurationError = Class.new(StandardError)
GcloudError = Class.new(StandardError)

def project_for_env(env)
  case env
  when 'gstg'
    'gitlab-staging-1'
  when 'gprd'
    'gitlab-production'
  when 'dr'
    'gitlab-dr-testing'
  when 'pre'
    'gitlab-pre'
  else
    raise InvalidEnvError, "Invalid environment '#{env}'!"
  end
end

def gcloud(options, cmd:)
  out, status = Open3.capture2e("gcloud --project='#{project_for_env(options[:env])}' --format='json' #{cmd.join(' ')}")
  raise GcloudError, "gcloud execution failed! ret=#{status.exitstatus} out=#{out}" unless status.success?

  JSON.parse(out)
end

def start_date(options)
  (Date.today - options[:days].to_i).strftime('%Y-%m-%dT00:00:00Z')
end

def fmt_for_bucket_duration(options)
  case options[:bucket_duration]
  when 'hour'
    "%m-%d\n%H:00"
  when 'day'
    '%m-%d'
  else
    raise InvalidBucketDurationError, "Invalid bucket duration '#{options[:bucket_duration]}'!"
  end
end

def table_sizes(options)
  snapshot_filter = "status=\"READY\" AND creationTimestamp>=\"#{start_date(options)}\" AND sourceDisk~\"#{options[:filter]}\""

  json_data = gcloud(options, cmd: %W[
    compute snapshots list
    --filter='#{snapshot_filter}'
    --sort-by='~creationTimestamp'
  ])

  timestamps = json_data.map { |j| DateTime.parse(j['creationTimestamp']).strftime(fmt_for_bucket_duration(options)) }.sort.uniq
  csv_data = {}

  json_data.each do |j|
    timestamp = DateTime.parse(j['creationTimestamp']).strftime(fmt_for_bucket_duration(options))
    storage_gigabytes = j['storageBytes'].to_f / 1024 / 1024 / 1024

    disk_name = File.basename(j['sourceDisk']).gsub(/-\w+?-\w+?-data$/, '')

    csv_data[disk_name] ||= timestamps.clone.to_h { |i| [i, 0] }
    csv_data[disk_name][timestamp] += storage_gigabytes
  end

  rows = csv_data.map { |k, v| [k, *v.values.map { |v| v.round(2) }] }.sort
  rows += [['TOTALS'] + csv_data.values.map(&:values).transpose.map { |i| i.reduce(:+) }.map { |s| s.round(1) }]
  headings = ['disk'] + timestamps

  [headings, rows]
end

def table_durations(options)
  snapshot_log_filter = "protoPayload.response.status=\"DONE\" AND protoPayload.response.operationType=\"createSnapshot\" AND protoPayload.response.progress=\"100\" AND timestamp>=\"#{start_date(options)}\" AND protoPayload.response.targetLink=~\"#{options[:filter]}\""

  json_data = gcloud(options, cmd: %W[
    logging read
    '#{snapshot_log_filter}'
  ])

  timestamps = json_data.map { |j| DateTime.parse(j['timestamp']).strftime(fmt_for_bucket_duration(options)) }.sort.uniq
  csv_data = {}

  json_data.each do |j|
    response = j['protoPayload']['response']
    timestamp = DateTime.parse(j['timestamp']).strftime(fmt_for_bucket_duration(options))

    disk_name = File.basename(response['targetLink']).gsub(/-\w+?-\w+?-data$/, '')
    # "insertTime" is when the operation is requested, "startTime" is when the system started processing it
    start = DateTime.parse(response['insertTime']).new_offset(0)
    finish = DateTime.parse(response['endTime']).new_offset(0)
    secs = (finish.to_time - start.to_time).round

    csv_data[disk_name] ||= timestamps.clone.to_h { |i| [i, 0] }
    csv_data[disk_name][timestamp] = [csv_data[disk_name][timestamp], secs].max
  end

  rows = csv_data.map { |k, v| [k, *v.values] }.sort
  headings = ['disk'] + timestamps

  [headings, rows]
end

def table_list(options)
  # Look back 1 day to find at least one successful snapshot for each disk
  start_date = (Date.today - SNAPSHOT_LIST_LOOKBACK).strftime('%Y-%m-%dT%H:%M:%SZ')
  now_ts = Time.now.utc.to_i

  snapshot_list_filter = "status=\"READY\" AND creationTimestamp>=\"#{start_date}\" AND sourceDisk~\"#{options[:filter]}\""

  json_data = gcloud(options, cmd: %W[
    compute snapshots list
    --filter='#{snapshot_list_filter}'
    --sort-by='~creationTimestamp'
  ])

  csv_data = {}

  json_data.each do |j|
    next if options[:zone] && !j['sourceDisk'].match?(%r{/#{options[:zone]}/})

    timestamp = DateTime.parse(j['creationTimestamp']).new_offset(0)
    delta_m = ((60 * 60) % (now_ts - timestamp.to_time.to_i)) / 60
    delta_h = ((now_ts - timestamp.to_time.to_i) / (60 * 60)).to_s.rjust(2, "0")
    disk_name = File.basename(j['sourceDisk'])

    csv_data[disk_name] ||= [timestamp.strftime('%Y-%m-%dT%H:%M:%SZ'), "#{delta_h}h#{delta_m}m", j['selfLink']]
  end

  headings = %w[disk timestamp delta selfLink]
  rows = csv_data.map { |k, v| [k, *v] }.sort
  [headings, rows]
end

def disp_snapshots_for_tf(rows)
  # Outputs Terraform config that can be copied into the file module
  # to use the latest snapshot for corresponding file nodes.
  #
  # Example MR: https://ops.gitlab.net/gitlab-com/gl-infra/config-mgmt/-/merge_requests/4863
  #
  #   per_node_data_disk_snapshot = {
  #     1 = "https://www.google.../snapshots/file-01-stor...wmcs9" # file-01-stor-gstg-data
  #     2 = "https://www.google.../snapshots/file-02-stor...hdd10" # file-02-stor-gstg-data
  #     3 = "https://www.google.../snapshots/file-03-stor...kfe8b" # file-03-stor-gstg-data
  #   }
  ["per_node_data_disk_snapshot = {"] +
    rows.map.with_index { |r, index| "    #{index + 1} = \"#{r[-1]}\" # #{r[0]}" } +
    ["}"]
end

def subcommand_explanation(type, options)
  case type
  when SubCmd::DURATIONS
    <<~EXPLAIN
      Shows the maximum time in seconds that any given snapshot took to complete over one #{options[:bucket_duration]}.
    EXPLAIN
  when SubCmd::SIZES
    <<~EXPLAIN
      Shows the sum of the total snapshot size in GB, over one #{options[:bucket_duration]}.
    EXPLAIN

  when SubCmd::LIST
    <<~EXPLAIN
      Shows the most recent snapshot for each disk that matches the filter looking back #{SNAPSHOT_LIST_LOOKBACK} day, and provides the self link.
    EXPLAIN
  end
end

def subcommand_opts(type, options)
  case type
  when SubCmd::DURATIONS, SubCmd::SIZES
    OptionParser.new do |opts|
      cmd = "glsh snapshots #{type}"
      opts.banner = <<~USAGE
        Usage: #{cmd} [options] <filter>

        #{subcommand_explanation(type, options)}
        Examples:
          #{cmd} file                     # list for the past day for Gitaly storage disks
          #{cmd} -b day file              # list for the past day for Gitaly storage disks, aggregate by day
          #{cmd} -b hour file             # list for the past day for Gitaly storage disks, aggregate by hour
          #{cmd} -c file                  # list for the past day for Gitaly storage disks and print a csv
          #{cmd} -e gstg file             # list for the past day for Gitaly storage disk in Staging
          #{cmd} -d 7 file                # list for the past 7 days for Gitaly storage disks
          #{cmd} patroni                  # list for the past day for Patroni disks

      USAGE
      opts.on("-c", "--csv", TrueClass, "Generate a CSV instead of a table") do |v|
        options[:csv] = v
      end
      opts.on("-d", "--days DAYS", "Number of days to look back") do |v|
        options[:days] = v
      end
      opts.on("-b", "--bucket-duration BUCKET_DURATION", "Put results in a day or hour long bucket") do |v|
        options[:bucket_duration] = v
      end
      opts.on("-e", "--env ENV", "Environment") do |v|
        options[:env] = v
      end
    end
  when SubCmd::LIST
    OptionParser.new do |opts|
      cmd = "glsh snapshots list"
      opts.banner = <<~USAGE
        Usage: #{cmd} [options] <filter>

        #{subcommand_explanation(type, options)}
        Examples:
          #{cmd} file               # list all snapshots for Gitaly data disks
          #{cmd} -c file            # list all snapshots for Gitaly data disks in csv format
          #{cmd} -e gstg file       # list all snapshots for Gitaly data disks in staging
          #{cmd} -t file            # list all snapshots for Gitaly data disks, in all zones and output terraform "per_node_data_disk_snapshot" config
          #{cmd} -z us-east1-b file # list all snapshots for Gitaly data disks, in us-east1-b
          #{cmd} patroni              # list all snapshots for patroni servers, in all zones

      USAGE
      opts.on("-t", "--terraform", TrueClass, "Generate Terraform configuration") do |v|
        options[:terraform] = v
      end
      opts.on("-c", "--csv", TrueClass, "Generate a CSV instead of a table") do |v|
        options[:csv] = v
      end
      opts.on("-z", "--zone ZONE", "Availability zone") do |v|
        options[:zone] = v
      end
      opts.on("-e", "--env ENV", "Environment") do |v|
        options[:env] = v
      end
    end
  end
end

def table_for_command(options, command)
  case command
  when SubCmd::LIST
    table_list(options)
  when SubCmd::DURATIONS
    table_durations(options)
  when SubCmd::SIZES
    table_sizes(options)
  end
end

def parse_subcommands
  options = {
    env: 'gprd',
    days: '1',
    bucket_duration: 'hour'
  }

  subtext = <<~HELP
  USAGE:
    glsh snapshots [SUBCOMMAND]

  SUBCOMMANDS:
    #{SubCmd::LIST}           lists most recent snapshots
    #{SubCmd::DURATIONS}      lists snapshot durations
    #{SubCmd::SIZES}          lists snapshot sizes
  HELP

  global = OptionParser.new do |opts|
    opts.banner = "Usage: glsh snapshots [options] [subcommand [options]]"
    opts.separator ""
    opts.separator subtext
  end

  subcommands = {
    SubCmd::LIST => subcommand_opts(SubCmd::LIST, options),
    SubCmd::DURATIONS => subcommand_opts(SubCmd::DURATIONS, options),
    SubCmd::SIZES => subcommand_opts(SubCmd::SIZES, options)
  }

  begin
    global.order!
  rescue OptionParser::InvalidOption => e
    warn "Error: #{e}\n\n"
    warn global
    exit 1
  end

  [subcommands, options, global]
end

def main
  subcommands, options, global = parse_subcommands
  command = ARGV.shift

  unless command && subcommands[command]
    warn "Error: Invalid subcommand '#{command}'!\n\n"
    warn global
    exit 1
  end

  begin
    subcommands[command].order!
  rescue OptionParser::InvalidOption => e
    warn "Error: #{e}\n\n"
    warn subcommands[command]
    exit 1
  end

  options[:filter] = ARGV.pop

  unless ARGV.empty?
    warn "Extraneous arguments passed '#{ARGV.join(',')}'!"
    puts subcommands[command]
    exit 1
  end

  unless options[:filter]
    warn "You must add a filter!\n\n"
    puts subcommands[command]
    exit 1
  end

  warn "#{subcommand_explanation(command, options)}\n"
  warn "Fetching snapshot data, opts: #{options.map { |k, v| "#{k}=#{v}" }.join(' ')}..\n\n"

  headings, rows = table_for_command(options, command)

  if options[:csv]
    # Insert headings as the first element of rows
    rows.unshift(headings.map { |h| h.gsub("\n", ' ') })
    puts rows.map(&:to_csv).join
    exit
  end

  table = Terminal::Table.new(headings:, rows:)
  table.style = { border: Terminal::Table::UnicodeRoundBorder.new }
  puts table

  puts disp_snapshots_for_tf(rows).join("\n") if command == SubCmd::LIST && options[:terraform]
end

main
