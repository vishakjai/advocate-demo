# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/periodic_queries/storage'

describe PeriodicQueries::Storage do
  describe '#create_file' do
    it "stores files in a bucket based on the file's basename" do
      keyfile_path = '/path/to/keyfile.json'
      gcp_project = 'gcp-project-123'
      bucket_name = 'periodic-query-bucket'

      bucket = instance_double(Google::Cloud::Storage::Bucket)
      gcs = instance_double(Google::Cloud::Storage::Project)

      allow(Google::Cloud::Storage).to receive(:new)
        .with(project_id: gcp_project, credentials: keyfile_path).and_return(gcs)
      allow(gcs).to receive(:bucket)
        .with(bucket_name, skip_lookup: true).and_return(bucket)

      storage = described_class.new(keyfile_path, gcp_project, bucket_name)

      expect(bucket).to receive(:create_file)
        .with('/path/to/20210531_13:28:21/results.json', '20210531_13:28:21/results.json')

      storage.create_file('/path/to/20210531_13:28:21/results.json')
    end
  end
end
