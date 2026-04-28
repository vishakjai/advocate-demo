# frozen_string_literal: true

require 'redis'
require 'yaml'
require 'redis-clustering'

def get_data(key, ktype, datastore)
  case ktype
  when 'string'
    datastore.get(key)
  when 'hash'
    datastore.hgetall(key)
  when 'set'
    datastore.smembers(key)
  else
    'Unsupported'
  end
end

# This file requires the `redis` gems.
#
# On a VM node, run the following to setup
# ```
# gem install redis -v '~> 4.8.0'
# ```
#
# Usage: ruby redis_key_compare.rb <KEY_1> <KEY_2>
#
# Pre-requisite: Create 2 files, source.yml and destination.yml with details of
# the source and destination redis instances.
# option 1: url: redis://<username>:<password>@<host>:<port>
# if cluster, define cluster(list of objects with host and port keys) + username + password

src = ::Redis.new(YAML.load_file('source.yml').transform_keys(&:to_sym))
dst = ::Redis::Cluster.new(YAML.load_file('destination.yml').transform_keys(&:to_sym).merge({ concurrency: { model: :none } }))

ARGV.each do |key|
  ktype = src.type(key)

  puts "#{key} is a #{ktype}"
  puts "Source data"
  puts get_data(key, ktype, src)
  puts "Destination data"
  puts get_data(key, ktype, dst)

  puts "-----------------"
  puts ""
end
