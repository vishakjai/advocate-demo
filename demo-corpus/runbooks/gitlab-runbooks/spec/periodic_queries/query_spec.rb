# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/periodic_queries/query'
require_relative '../../lib/periodic_queries/prometheus_api'

describe PeriodicQueries::Query do
  subject(:query) do
    described_class.new(
      'error_budget_availability',
      {
        'type' => 'instant',
        'tenantId' => 'gitlab-gprd',
        'requestParams' => {
          'query' => 'promql',
          'time' => '123'
        }
      }
    )
  end

  let(:name) { 'error_budget_availability' }

  describe '#params' do
    it 'excludes the type and tenant_id from the passed info' do
      expected_params = { 'query' => 'promql', 'time' => '123' }

      expect(query.params).to eq(expected_params)
    end
  end

  describe '#to_result' do
    it 'returns an unsuccessful result when the response is missing' do
      expected_result = {
        name => {
          success: false,
          status_code: nil,
          message: nil,
          body: nil
        }
      }

      expect(query.to_result).to eq(expected_result)
    end
  end

  describe '#summary' do
    let(:expected_text) { "#{name} (instant, params: [\"query\", \"time\"], tenant_id: gitlab-gprd)" }

    it 'returns a summary of the query state' do
      expected = "➖ #{expected_text}"

      expect(query.summary).to eq(expected)
    end

    context 'with a response' do
      it 'includes a successful status' do
        query.response = instance_double(PeriodicQueries::PrometheusApi::Response, success?: true)

        expected = "✔ #{expected_text}"

        expect(query.summary).to eq(expected)
      end

      it 'includes a failed status' do
        query.response = instance_double(PeriodicQueries::PrometheusApi::Response, success?: false, parsed_body: { error: "broken" })

        expected = "❌ #{expected_text}\n{error: \"broken\"}"

        expect(query.summary).to eq(expected)
      end
    end
  end

  describe "#success?" do
    it 'is false without a response' do
      expect(query.success?).to be(false)
    end

    it 'is true with a successful response' do
      query.response = instance_double(PeriodicQueries::PrometheusApi::Response, success?: true)

      expect(query.success?).to be(true)
    end

    it 'is false with a failed response' do
      query.response = instance_double(PeriodicQueries::PrometheusApi::Response, success?: false)

      expect(query.success?).to be(false)
    end
  end
end
