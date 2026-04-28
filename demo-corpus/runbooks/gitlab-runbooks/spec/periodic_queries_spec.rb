# frozen_string_literal: true

require 'spec_helper'
require_relative '../lib/periodic_queries'

describe PeriodicQueries do
  describe ".perform_queries" do
    it 'calls the api and adds the response to each query', :aggregate_failures do
      topic1 = instance_double(
        PeriodicQueries::Topic,
        name: 'set1',
        queries: [
          query1 = instance_double(PeriodicQueries::Query, name: 'q1'),
          query2 = instance_double(PeriodicQueries::Query, name: 'q2')
        ]
      )
      topic2 = instance_double(
        PeriodicQueries::Topic,
        name: 'set2',
        queries: [
          query3 = instance_double(PeriodicQueries::Query, name: 'q3')
        ]
      )
      api = instance_double(PeriodicQueries::PrometheusApi)

      expect(api).to receive(:perform_query).with(query1).and_return('response 1')
      expect(api).to receive(:perform_query).with(query2).and_return('response 2')
      expect(api).to receive(:perform_query).with(query3).and_return('response 3')
      expect(query1).to receive(:response=).with('response 1')
      expect(query2).to receive(:response=).with('response 2')
      expect(query3).to receive(:response=).with('response 3')

      described_class.perform_queries([topic1, topic2], api, StringIO.new)
    end
  end

  describe '.write_results' do
    it 'stores a json file with a timestamp for all topics' do
      target_directory = File.join(Dir.mktmpdir, 'test-periodic-queries')
      topic1 = instance_double(
        PeriodicQueries::Topic,
        name: 'set1',
        to_result: { 'query1' => { success: false } }
      )
      topic2 = instance_double(
        PeriodicQueries::Topic,
        name: 'set2',
        to_result: { 'query2' => { success: true } }
      )
      time = Time.parse("2021-05-31 15:28:21 +0200")

      described_class.write_results(
        [topic1, topic2], target_directory, time, StringIO.new
      )

      resulting_files = Dir.glob(File.join(target_directory, '*/*.json'))
      expected_files = %w[20210531132821/set1.json 20210531132821/set2.json].map do |name|
        File.join(target_directory, name)
      end

      expect(resulting_files).to contain_exactly(*expected_files)
      expect(File.read(expected_files.first)).to eq(topic1.to_result.to_json)
      expect(File.read(expected_files.last)).to eq(topic2.to_result.to_json)
    end
  end

  describe '.upload_results' do
    it 'stores all json files in a directory in a bucket' do
      base_dir = Dir.mktmpdir
      directory = File.join(base_dir, '20210531_13:28:21')
      FileUtils.mkdir_p(directory)

      local_files = %w[f1.json f2.json].map { |f| File.join(directory, f) }
      local_files.each { |f| File.write(f, '{}') }
      remote_file = instance_double(
        'Remote File',
        public_url: 'https://https://storage.googleapis.com/the-bucket/the-file.json'
      )
      storage = instance_double(PeriodicQueries::Storage)

      local_files.each do |local_file|
        expect(storage).to receive(:create_file).with(local_file).and_return(remote_file)
      end

      described_class.upload_results(base_dir, storage, StringIO.new)
    end
  end
end
