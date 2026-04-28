# frozen_string_literal: true

require_relative '../jsonnet_wrapper'
require_relative './query'
require 'time'

module PeriodicQueries
  class Topic
    EXT = '.queries.jsonnet'

    def self.parse!(file_path)
      parsed = JsonnetWrapper.new(ext_str: { current_time: Time.now.utc.to_datetime.rfc3339 }).parse(file_path)
      new(file_path, parsed)
    end

    attr_reader :queries, :name

    def initialize(file_path, info)
      raise ArgumentError, "#{file_path} should end in `#{EXT}`" unless file_path.end_with?(EXT)

      @name = File.basename(file_path, EXT)
      @queries = build_queries(info)
    end

    def to_result
      queries.map(&:to_result).inject(&:merge)
    end

    def summary
      [name, queries.map { |q| "-- #{q.summary}" }].flatten.join("\n")
    end

    def success?
      queries.all?(&:success?)
    end

    private

    attr_reader :info, :file_path

    def build_queries(info)
      info.map { |name, query_info| Query.new(name, query_info) }
    end
  end
end
