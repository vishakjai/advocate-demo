# frozen_string_literal: true

require_relative './key_pattern'

# rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity,Lint/DuplicateBranch
module RedisTrace
  class Trace
    attr_accessor :timestamp, :request, :cmd, :keys, :key_patterns, :value, :args, :response, :successful

    def initialize(timestamp, request)
      @timestamp = timestamp
      @request = request
      parse_request(request)
      @response = []
    end

    def value_size
      @value.to_s.size
    end

    def response_size
      @response.compact.map { |r| r.to_s.size }.sum
    end

    def to_s
      success = @successful ? '[SUCCESSFUL]' : '[ERROR]'
      "#{@timestamp} #{@request.join(' ')}\n#{success} #{@response.map(&:to_s).join(' ')}"
    end

    private

    def parse_request(request)
      @args = request.dup
      @cmd = @args.shift.downcase
      @keys = []
      @value = nil

      case @cmd
      when "get"
        @keys = [@args.shift]
      when "exists"
        @keys = @args
        @args = []
      when "expire"
        @keys = [@args.shift]
      when "pexpire"
        @keys = [@args.shift]
      when "del"
        @keys = @args
        @args = []
      when "mget"
        @keys = @args
        @args = []
      when "set"
        @keys = [@args.shift]
        @value = @args.join(" ")
        @args = []
      when "smembers"
        @keys = [@args.shift]
      when "multi"
        @keys = []
      when "exec"
        @keys = []
      when "auth"
        @keys = []
      when "role"
        @keys = []
      when "info"
        @keys = []
      when "memory"
        # MEMORY USAGE key [SAMPLES count]
        @args.shift
        @keys = @args
        @args = []
      when "replconf"
        @keys = []
      when "ping"
        @keys = []
      when "client"
        @keys = []
      when "sismember"
        @keys = [@args.shift]
      when "incr"
        @keys = [@args.shift]
      when "incrby"
        @keys = [@args.shift]
        @value = @args.shift
      when "incrbyfloat"
        @keys = [@args.shift]
        @value = @args.shift
        @value_type = "float"
      when "hincrby"
        @keys = [@args.shift]
        @value = @args.shift
      when "hdel"
        @keys = [@args.shift]
      when "setex"
        @keys = [@args.shift]
        @value = @args.shift
      when "hmget"
        @keys = [@args.shift]
      when "hmset"
        @keys = [@args.shift]
        # Technically there could be an array of field names and @values ( HMSET key field @value [field @value ...] )
        # but GitLab doesn't use it AFAICT so i'm going to ignore that and hope.
        @value = @args.shift
      when "unlink"
        @keys = @args
        @args = []
      when "ttl"
        @keys = [@args.shift]
      when "sadd"
        @keys = [@args.shift]
        # Could be more than one; let's just grab the first, we only seem to use a single key in GitLab
        @value = @args.shift
      when "hset"
        @keys = [@args.shift]
        @value = @args.shift
      when "publish"
        @keys = [@args.shift]
        @value = @args.shift
      when "eval"
        @keys = []
        # Could be more than one key though
        @value = @args.shift
      when "strlen"
        @keys = [@args.shift]
      when "pfadd"
        @keys = [@args.shift]
      when "srem"
        @keys = [@args.shift]
      when "hget"
        @keys = [@args.shift]
      when "zadd"
        @keys = [@args.shift]
        # well, "member" but that's sort of relevant
        @value = @args[-1]
      when "zcard"
        @keys = [@args.shift]
      when "decr"
        @keys = [@args.shift]
      when "scard"
        @keys = [@args.shift]
      when "subscribe"
        @keys = @args
        @args = []
      when "unsubscribe"
        @keys = @args
        @args = []
      when "zrangebyscore"
        @keys = [@args.shift]
      when "zrevrange"
        @keys = [@args.shift]
      when "zremrangebyrank"
        @keys = [@args.shift]
      when "zremrangebyscore"
        @keys = [@args.shift]
      when "blpop"
        @keys = @args[0..-2]
        @value = @args[-1]
      when "hgetall"
        @keys = [@args.shift]
      when "lpush"
        @keys = [@args.shift]
      else
        # Best guess
        @keys = [@args.shift]
      end

      @value_type = @value.match(/^[0-9]+$/) ? "int" : "string" if @value && !@value_type

      @key_patterns = Hash.new { |h, k| h[k] = [] }
      @keys.compact.each do |key|
        @key_patterns[patternize(key)].append(key)
      end
    end

    def patternize(key)
      RedisTrace::KeyPattern.filter_key(key).gsub(' ', '_')
    end
  end
end
# rubocop:enable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity,Lint/DuplicateBranch
