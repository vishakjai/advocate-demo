# frozen_string_literal: true

require_relative './trace'

module RedisTrace
  class TcpflowParser
    def initialize(idx_filename)
      @idx_filename = idx_filename
    end

    def call
      request_index_keys, request_index_vals = parse_idx_file(@idx_filename)

      request_filename = @idx_filename.gsub(/\.findx$/, "")
      raise "Invalid file name #{request_filename}" unless File.basename(request_filename).match(/^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\.([0-9]+)-([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\.([0-9]+)$/)

      request_file = File.open(request_filename, 'r:ASCII-8BIT')

      response_filename = File.join(
        File.dirname(request_filename),
        File.basename(request_filename).split("-").reverse.join("-")
      )
      # Not ideal, but if we can't find the response file, give up (the original tcpdump probably just missed some packets, perhaps when shutting down)
      return unless File.exist?(response_filename)

      response_index_keys, response_index_vals = parse_idx_file("#{response_filename}.findx")
      response_file = File.open(response_filename, 'r:ASCII-8BIT')

      until request_file.eof?
        trace = parse_next_request(request_file, request_index_keys, request_index_vals)
        next if trace.nil?

        successful, response = parse_next_response(trace.timestamp, response_file, response_index_keys, response_index_vals)
        trace.successful = successful
        trace.response = response
        yield trace if block_given?
      end
    ensure
      request_file&.close
      response_file&.close
    end

    private

    def parse_idx_file(file)
      index_keys = []
      index_vals = []

      File.readlines(file).each do |line|
        offset, timestamp, _length = line.strip.split("|")

        index_keys << offset.to_i
        index_vals << timestamp.to_f
      end
      [index_keys, index_vals]
    end

    def request_timestamp(offset, index_keys, index_vals)
      i = index_keys.bsearch_index { |v| v >= offset }
      if i.nil?
        i = index_keys.size - 1
      elsif i.positive? && index_keys[i] != offset
        # bsearch rounds up, we want to round down
        i -= 1
      end

      Time.at(index_vals[i]).to_datetime.new_offset(0)
    end

    def parse_next_request(request_file, index_keys, index_vals)
      offset = request_file.tell
      line = request_file.readline.strip

      return unless line.match(/^\*([0-9]+)$/)

      # Parse request
      request = []
      argc = Regexp.last_match(1).to_i
      argc.times do
        line = request_file.readline.strip
        raise "Invalid line: #{line}" unless line.match(/^\$([0-9]+)$/)

        len = Regexp.last_match(1).to_i
        request << request_file.read(len)
        request_file.read(2) # \r\n
      end

      # Search index file for timestamps
      timestamp = request_timestamp(offset, index_keys, index_vals)

      Trace.new(timestamp, request)
    rescue EOFError
      nil
    end

    def parse_next_response(timestamp, response_file, index_keys, index_vals)
      # https://redis.io/topics/protocol
      line = nil
      loop do
        line = response_file.readline.strip
        next unless line.match(/^[*:\-+$].*/)

        offset = response_file.tell
        response_timestamp = request_timestamp(offset, index_keys, index_vals)
        break if response_timestamp >= timestamp
      end

      return [true, parse_array(Regexp.last_match(1).to_i, response_file)] if line.match(/^\*([0-9]+)$/)

      return [false, [Regexp.last_match(1)]] if line.match(/^-(.*)$/)

      [true, [parse_response_line(line, response_file)]]
    rescue EOFError
      [true, []]
    end

    def parse_array(argc, response_file)
      argc.times.map do
        line = response_file.readline.strip
        parse_response_line(line, response_file)
      end
    end

    def parse_response_line(line, response_file)
      # https://github.com/redis/redis/blob/cf860df59921efcc74be410bdf165abd784df502/src/server.c#L3492
      if ['+OK', '+QUEUED', '+PONG'].include?(line)
        line
      elsif line == '$-1'
        nil
      elsif line.match(/^:(-?[0-9]+)$/)
        Regexp.last_match(1).to_i
      elsif line.match(/^\$([0-9]+)$/)
        len = Regexp.last_match(1).to_i

        str = response_file.read(len)
        response_file.read(2) # \r\n
        str
      elsif line.match(/\*([0-9]+)$/)
        parse_array(Regexp.last_match(1).to_i, response_file)
      else
        raise "Unknown response: #{line} in #{response_file.path}"
      end
    end
  end
end
