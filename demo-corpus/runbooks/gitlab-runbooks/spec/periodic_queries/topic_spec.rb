# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/periodic_queries/topic'

describe PeriodicQueries::Topic do
  subject(:topic) { described_class.new(path, query_info) }

  let(:query_info) do
    {
      'error_budget_availability' => {
        'type' => 'instant',
        'tenantId' => 'gitlab-gprd',
        'requestParams' => {
          'query' => 'promql'
        }
      },
      'error_budget_seconds_remaining' => {
        'type' => 'instant',
        'tenantId' => 'gitlab-gprd',
        'requestParams' => {
          'query' => 'promql'
        }
      }
    }
  end

  let(:path) { 'path/to/thing.queries.jsonnet' }

  describe '.parse!' do
    it 'initializes an instances by evaluating jsonnet' do
      wrapper = instance_double(JsonnetWrapper)

      expect(JsonnetWrapper).to receive(:new).with(ext_str: a_hash_including(current_time: an_instance_of(String))).and_return(wrapper)
      expect(wrapper).to receive(:parse).with(path).and_return({})

      expect(described_class.parse!(path)).to be_a(described_class)
    end
  end

  describe '#initialize' do
    it 'initializes the name' do
      expect(topic.name).to eq('thing')
    end

    it 'initializes the queries' do
      expect(topic.queries.map(&:name)).to contain_exactly(*query_info.keys)
    end

    it 'raises an error with an incorrect name' do
      expect { described_class.new('not correct', {}) }.to raise_error(/end in `#{described_class::EXT}`/i)
    end
  end

  describe '#to_result' do
    it 'merges the results of all queries' do
      stubbed_queries = [
        instance_double(PeriodicQueries::Query, to_result: { 'query1' => 'result1' }),
        instance_double(PeriodicQueries::Query, to_result: { 'query2' => 'result2' })
      ]
      expected_result = {
        'query1' => 'result1',
        'query2' => 'result2'
      }

      allow(topic).to receive(:queries).and_return(stubbed_queries)

      expect(topic.to_result).to eq(expected_result)
    end
  end

  describe '#summary' do
    it 'summarizes all queries with the topic name' do
      stubbed_queries = [
        instance_double(PeriodicQueries::Query, summary: 'query1 did well'),
        instance_double(PeriodicQueries::Query, summary: 'query2 failed')
      ]
      expected_summary = <<~SUMMARY.strip
        thing
        -- query1 did well
        -- query2 failed
      SUMMARY

      allow(topic).to receive(:queries).and_return(stubbed_queries)

      expect(topic.summary).to eq(expected_summary)
    end
  end

  describe "#success?" do
    it 'is true when the topic had no queries' do
      allow(topic).to receive(:queries).and_return([])

      expect(topic.success?).to be(true)
    end

    it 'is true when all queries succeeded' do
      stubbed_queries = [
        instance_double(PeriodicQueries::Query, success?: true),
        instance_double(PeriodicQueries::Query, success?: true)
      ]

      allow(topic).to receive(:queries).and_return(stubbed_queries)

      expect(topic.success?).to be(true)
    end

    it 'is false when the topic had a failing query' do
      stubbed_queries = [
        instance_double(PeriodicQueries::Query, success?: true),
        instance_double(PeriodicQueries::Query, success?: false)
      ]

      allow(topic).to receive(:queries).and_return(stubbed_queries)

      expect(topic.success?).to be(false)
    end
  end
end
