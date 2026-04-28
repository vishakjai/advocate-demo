# frozen_string_literal: true

require 'spec_helper'

require_relative join_root_path('lib/redis_trace/tcpflow_parser')

RSpec.describe RedisTrace::TcpflowParser do
  let(:idx_file) { join_root_path('spec/fixtures/redis_trace/127.000.000.001.60140-127.000.000.001.06379.findx') }
  let(:recording_time) { Time.new(2021, 10, 22, 6, 50, 23).to_i }

  it 'parses Redis trace correctly' do
    parser = described_class.new(idx_file)

    traces = []
    parser.call { |trace| traces << trace }

    expect(traces.map { |t| [t.request, t.response, t.cmd, t.keys] }).to eql(
      [
        [
          %w[set key1 hello],
          ["+OK"],
          'set',
          ['key1']
        ],
        [
          %w[get key1],
          ["hello"],
          'get',
          ['key1']
        ],
        [
          %w[set key2 hi],
          ["+OK"],
          'set',
          ['key2']
        ],
        [
          %w[get key2],
          ["hi"],
          'get',
          ['key2']
        ],
        [
          %w[set key3 1234],
          ["+OK"],
          'set',
          ['key3']
        ],
        [
          %w[get key3],
          ["1234"],
          'get',
          ['key3']
        ],
        [
          %w[set key4 A really longgggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg text],
          ["ERR syntax error"],
          "set",
          ["key4"]
        ],
        [
          ["set", "key4", "A really longgggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg text"],
          ["+OK"],
          'set',
          ['key4']
        ],
        [
          %w[get key4],
          ["A really longgggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg text"],

          'get',
          ['key4']
        ],
        [
          %w[get key5],
          [nil],
          'get',
          ['key5']
        ],
        [
          ["get"],
          ["ERR wrong number of arguments for 'get' command"],
          'get',
          [nil]
        ],
        [
          %w[zadd key5 1 Hello 2 123],
          [2],
          'zadd',
          ['key5']
        ],
        [
          %w[zrangebyscore 2 3],
          ["ERR wrong number of arguments for 'zrangebyscore' command"],
          'zrangebyscore',
          ['2']
        ],
        [
          %w[zrangebyscore key5 2 3],
          ["123"],
          'zrangebyscore',
          ['key5']
        ],
        [
          %w[incr key6],
          [1],
          'incr',
          ['key6']
        ],
        [
          %w[incrby key6 5],
          [6],
          'incrby',
          ['key6']
        ],
        [
          %w[get key6],
          ["6"],
          'get',
          ['key6']
        ],
        [
          %w[hset key7 field1 hello field2 world],
          [2],
          'hset',
          ['key7']
        ],
        [
          %w[hget key7 field 1],
          ["ERR wrong number of arguments for 'hget' command"],
          'hget',
          ['key7']
        ],
        [
          %w[hgetall key7],
          %w[field1 hello field2 world],
          'hgetall',
          ['key7']
        ],
        [
          %w[sadd key8 1 2 3],
          [3],
          'sadd',
          ['key8']
        ],
        [
          %w[sadd key8 four five],
          [2],
          'sadd',
          ['key8']
        ],
        [
          %w[sadd key8 four five],
          [0],
          'sadd',
          ['key8']
        ],
        [
          %w[smembers key8],
          %w[1 3 five 2 four],
          'smembers',
          ['key8']
        ],
        [
          %w[lpush key9 1],
          [1],
          'lpush',
          ['key9']
        ],
        [
          %w[lpush key9 Hello],
          [2],
          'lpush',
          ['key9']
        ],
        [
          %w[lpop key9],
          ["Hello"],
          'lpop',
          ['key9']
        ],
        [
          %w[lrange key9 1 10],
          [],
          'lrange',
          ['key9']
        ],
        [
          ["lpop"],
          ["ERR wrong number of arguments for 'lpop' command"],
          'lpop',
          [nil]
        ],
        [
          ["multi"],
          ["+OK"],
          'multi',
          []
        ],
        [
          %w[set key1 hello],
          ["+QUEUED"],
          'set',
          ['key1']
        ],
        [
          %w[set key2 hi],
          ["+QUEUED"],
          'set',
          ['key2']
        ],
        [
          ["exec"],
          ["+OK", "+OK"],
          "exec",
          []
        ],
        [
          ["multi"],
          ["+OK"],
          "multi",
          []
        ],
        [
          %w[set key2 hi],
          ["+QUEUED"],
          "set",
          ['key2']
        ],
        [
          ["set"],
          ["ERR wrong number of arguments for 'set' command"],
          "set",
          [nil]
        ],
        [
          ["exec"],
          ["EXECABORT Transaction discarded because of previous errors."],
          "exec",
          []
        ],
        [
          ["exec"],
          ["ERR EXEC without MULTI"],
          "exec",
          []
        ]
      ]
    )
    # The tcpdump file was captured for 2 minutes. The timestamp of captured
    # traces should be within 2 minutes since the recording time
    acceptable_range = 2 * 60 * 1000
    expect(traces.map { |t| t.timestamp.to_time.to_i }).to all(be_within(acceptable_range).of(recording_time))
  end
end
