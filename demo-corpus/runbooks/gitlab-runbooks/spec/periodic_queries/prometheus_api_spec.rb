# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/periodic_queries/prometheus_api'
require_relative '../../lib/periodic_queries/query'

describe PeriodicQueries::PrometheusApi do
  subject(:api) { described_class.new(url) }

  let(:url) { "https://url-to-thanos.gitlab.internal" }

  describe "#with_connection" do
    it 'starts and finishes a connection' do
      api.with_connection do
        connection = api.__send__(:active_connection)
        expect(connection).to be_a(Net::HTTP)
        expect(connection).to be_started
        expect(connection).to receive(:finish)
      end
    end
  end

  describe '#perform_query' do
    # This should be validated when defining queries in jsonnet to give early
    # feedback. So here the exception can bubble up.
    it 'raises an error for unknown query types' do
      query = instance_double(PeriodicQueries::Query, type: 'unknown')

      expect { api.perform_query(query) }.to raise_error(KeyError)
    end

    it 'makes requests for instant queries' do
      uri = URI(url)
      query = instance_double(
        PeriodicQueries::Query,
        type: 'instant',
        tenant_id: 'gitlab-gprd',
        params: {
          query: 'promql'
        }
      )
      stubbed_request = stub_request(
        :get, "#{uri.host}:#{uri.port}/api/v1/query?query=promql"
      ).to_return(status: 200, body: "")

      response = api.with_connection { |connected_api| connected_api.perform_query(query) }

      expect(stubbed_request).to have_been_made
      expect(response).to be_a(PeriodicQueries::PrometheusApi::Response)
    end
  end
end
