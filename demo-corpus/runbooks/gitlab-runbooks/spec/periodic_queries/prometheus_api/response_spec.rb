# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/periodic_queries/prometheus_api/response'
require_relative '../../../lib/periodic_queries/query'

describe PeriodicQueries::PrometheusApi::Response do
  subject(:response) { described_class.new(raw_response) }

  let(:code) { "200" }
  let(:message) { "OK" }
  let(:body) { '{ "queryname": "result" }' }

  let(:raw_response) do
    instance_double(Net::HTTPResponse, code:, message:, body:)
  end

  describe '#status' do
    specify { expect(response.status).to eq(code) }
  end

  describe '#message' do
    specify { expect(response.message).to eq(message) }
  end

  describe '#parsed_body' do
    specify { expect(response.parsed_body).to eq({ 'queryname' => 'result' }) }

    context 'when the body cannot be parsed as json' do
      let(:body) { 'not json' }

      it 'returns an error body' do
        expect(response.parsed_body['errorType']).to eq('JSON::ParserError')
        expect(response.parsed_body['error']).not_to be(nil)
      end
    end
  end

  describe '#success?' do
    it 'is true for a valid response' do
      expect(response.success?).to be(true)
    end

    context 'when the code is not 200' do
      let(:code) { '500' }

      specify { expect(response.success?).to be(false) }
    end

    context 'when the body is empty' do
      let(:body) { '{}' }

      specify { expect(response.success?).to be(false) }
    end

    context 'when the body contains an error' do
      let(:body) { '{ "errorType": "bad_data"}' }

      specify { expect(response.success?).to be(false) }
    end
  end
end
