# frozen_string_literal: true

require "google/cloud/storage"

module PeriodicQueries
  class Storage
    def initialize(keyfile, gcp_project, bucket)
      @storage = Google::Cloud::Storage.new(project_id: gcp_project, credentials: keyfile)
      # Skip the lookup, so the key does not need the `storage.buckets.list` permission
      @bucket = @storage.bucket(bucket, skip_lookup: true)
    end

    def create_file(path)
      directory = File.dirname(path).split(File::SEPARATOR).last
      remote_name = File.join(directory, File.basename(path))
      bucket.create_file(path, remote_name)
    end

    private

    attr_reader :bucket
  end
end
