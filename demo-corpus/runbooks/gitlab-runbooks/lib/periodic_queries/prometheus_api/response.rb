# frozen_string_literal: true

require 'json'

module PeriodicQueries
  class PrometheusApi
    class Response
      def initialize(raw_http_response)
        @raw = raw_http_response
      end

      def status
        raw.code
      end

      def message
        raw.message
      end

      def parsed_body
        @parsed_body ||= parse_body
      end

      def success?
        status.to_s == '200' && !parsed_body.empty? && error.empty?
      end

      private

      attr_reader :raw

      def error
        parsed_body.slice('error', 'errorType')
      end

      def parse_body
        JSON.parse(raw.body.to_s)
      rescue JSON::ParserError => e
        {
          'errorType' => e.class.to_s,
          'error' => e.message
        }
      end
    end
  end
end
