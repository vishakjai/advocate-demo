#! /usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/periodic_queries'
require 'optparse'

config = Struct.new(
  :prometheus_url,
  :gcp_keyfile,
  :gcp_project,
  :gcs_bucket,
  :query_files,
  :target_directory,
  :dry_run,
  :prom_tenant_id,
  :prom_use_ssl,
  :prom_auth_header
).new

default_prom_url = 'https://mimir-internal.ops.gke.gitlab.net/prometheus'

prom_url_key = 'PERIODIC_QUERY_PROMETHEUS_URL'
prom_auth_header_key = 'PERIODIC_QUERY_PROMETHEUS_AUTH_HEADER'
ssl_key = 'PERIODIC_QUERY_SSL'

config.prometheus_url = ENV.fetch(prom_url_key, default_prom_url)
config.prom_use_ssl = ENV.fetch(ssl_key, 'true') == 'true'
config.prom_auth_header = ENV[prom_auth_header_key]

config.gcp_keyfile = ENV["PERIODIC_QUERY_GCP_KEYFILE_PATH"]
config.gcp_project = ENV["PERIODIC_QUERY_GCP_PROJECT"]
config.gcs_bucket = ENV["PERIODIC_QUERY_BUCKET"]

base_dir = Pathname.new(File.join(File.dirname(__FILE__), '..')).realpath
ext = PeriodicQueries::Topic::EXT
files = Dir.glob(File.join(base_dir, 'periodic-queries', "*#{ext}"))
config.query_files = files

config.target_directory = File.join(base_dir, 'periodic-query-results')

OptionParser.new do |options|
  options.banner = "Usage #{__FILE__} [options]"

  options.separator ""

  options.on('-d', '--dry-run', "Only compile the queries, don't execute them") do
    config.dry_run = true
  end

  options.on('-f', '--files=FILES', Array, "Comma separated list of files") do |list|
    config.query_files = list.map { |f| File.expand_path(f, base_dir) }
  end

  options.on('-n', '--no-upload', "Skip the upload even if GCS is configured") do
    config.gcp_project = config.gcs_bucket = config.gcp_keyfile = nil
  end

  options.separator ""

  options.on("-h", "--help", "Show this message") do
    puts options
    exit 0
  end

  options.separator ""

  options.separator "Environment variables"

  options.separator(<<~ENVIRONMENT_VARIABLES)
  #{options.summary_indent}#{prom_url_key}
  #{options.summary_indent * 2}The URL to the prometheus-like instance to query. Defaults to '#{default_prom_url}'
  #{options.summary_indent}#{prom_auth_header_key}
  #{options.summary_indent * 2}The authorization header to the prometheus-like instance.
  #{options.summary_indent}#{ssl_key}
  #{options.summary_indent * 2}The SSL setting to the prometheus-like instance. Defaults to 'true'
  #{options.summary_indent}PERIODIC_QUERY_GCP_KEYFILE_PATH
  #{options.summary_indent * 2}The keyfile to use to authenticate uploading to the GCS bucket.
  #{options.summary_indent}PERIODIC_QUERY_GCP_PROJECT
  #{options.summary_indent * 2}The GCP project id where the bucket to upload into resides.
  #{options.summary_indent}PERIODIC_QUERY_BUCKET
  #{options.summary_indent * 2}The name of the GCS bucket to upload the query results into.

  #{options.summary_indent * 2}When any of the upload environment variables is omitted, the upload is skipped.
  ENVIRONMENT_VARIABLES

  options.separator ""
end.parse!

topics = config.query_files.map { |f| PeriodicQueries::Topic.parse!(f) }

if config.dry_run
  puts topics.map(&:summary).join("\n")
  exit 0
end

prometheus = PeriodicQueries::PrometheusApi.new(
  config.prometheus_url,
  use_ssl: config.prom_use_ssl,
  auth_header: config.prom_auth_header
)
prometheus.with_connection do |api|
  PeriodicQueries.perform_queries(topics, api)
end

puts topics.map(&:summary).join("\n")
exit_code = topics.all?(&:success?) ? 0 : 1

PeriodicQueries.write_results(topics, config.target_directory, Time.now)

exit exit_code if config.gcp_project.nil? || config.gcs_bucket.nil? || config.gcp_keyfile.nil?

storage = PeriodicQueries::Storage.new(
  config.gcp_keyfile,
  config.gcp_project,
  config.gcs_bucket
)

PeriodicQueries.upload_results(config.target_directory, storage)

exit exit_code
