# frozen_string_literal: true

require 'json'
require 'fileutils'

require_relative './jsonnet_wrapper'

module MonitoredServices
  class << self
    def get_service_names
      JsonnetWrapper.new.parse(File.join(__dir__, "..", "metrics-catalog", "all-services.jsonnet"))
    end

    def has_dashboard?(service)
      File.exist?(File.join(__dir__, "..", "dashboards", service, "main.dashboard.jsonnet"))
    end
  end
end
