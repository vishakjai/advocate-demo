#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require_relative '../lib/jsonnet_wrapper'

# For basic type validations, use JSON Schema in https://gitlab.com/gitlab-com/runbooks/-/blob/master/services/service-catalog-schema.json
class ServiceCatalogValidator
  DEFAULT_RAW_CATALOG_PATH = File.join(__dir__, "..", "services", "raw-catalog.jsonnet")

  def initialize(raw_catalog_path = DEFAULT_RAW_CATALOG_PATH)
    @service_catalog = JsonnetWrapper.new.parse(raw_catalog_path).freeze
    @validators = [ValidateServiceMappings, ValidateStageGroupMapping]
  end

  def validate
    errors = @validators.flat_map do |validator|
      validator.new(@service_catalog).validate.map { |error| "#{validator.name}: #{error}" }
    end

    raise errors.join("\n") if errors.any?
  end
end

class ValidateServiceMappings
  attr_reader :service_catalog

  def initialize(service_catalog)
    @service_catalog = service_catalog
  end

  def validate
    teams = service_catalog["teams"]
    services = service_catalog["services"]

    team_map = teams.each_with_object({}) { |team, map| map[team["name"]] = team }

    labels_downcase_set = Set.new
    errors = []

    services.each do |service|
      service_name = service["name"]

      # team
      service_team = service["team"]
      errors << "'#{service_name}' | unknown team: '#{service_team}''" unless service_team.nil? || team_map[service_team]

      # label
      service_label = service["label"]
      service_label_downcase = service_label.downcase
      errors << "'#{service_label}' | duplicated labels found in service catalog. Label field must be unique (case insensitive)" if labels_downcase_set.include?(service_label_downcase)

      labels_downcase_set << service_label_downcase

      # owner
      service_owner = service["owner"]
      errors << "'#{service_name}' | unknown owner: '#{service_owner}''" unless service_owner.nil? || team_map[service_owner]
    end

    errors
  end
end

class ValidateStageGroupMapping
  DEFAULT_STAGE_GROUP_MAPPING_PATH = File.join(__dir__, "..", "services", "stage-group-mapping-with-overrides.jsonnet")
  DEFAULT_STAGE_GROUP_MAPPING = JsonnetWrapper.new.parse(DEFAULT_STAGE_GROUP_MAPPING_PATH).freeze

  KNOWN_GROUPS_WITHOUT_TEAM = %w[
    ci_platform contributor_success custom_models design_system distribution_build
    editor_extensions engineering_analytics gdk hosted_runners infrastructure not_owned
    pubsec_services quality secret_detection switchboard technical_writing ux_paper_cuts
    accessibility cloud_cost_utilization
  ].freeze

  def initialize(service_catalog, stage_group_mapping = DEFAULT_STAGE_GROUP_MAPPING)
    @service_catalog = service_catalog
    @stage_group_mapping = stage_group_mapping
  end

  def validate
    groups_in_mapping = @stage_group_mapping.keys
    teams_in_catalog = @service_catalog["teams"].map { |team| team["product_stage_group"] }.compact

    errors = []

    missing_in_catalog = groups_in_mapping - teams_in_catalog - KNOWN_GROUPS_WITHOUT_TEAM
    if missing_in_catalog.any?
      errors << <<~MSG
        #{missing_in_catalog.inspect} don't have an entry in `services/teams.yml`.
        This means that these groups have not specified a channel to route alerts to.

        Add them to the `services/teams.yml` for alert routing, or add the group to
        the `KNOWN_GROUPS_WITHOUT_TEAM` constant in `scripts/validate-service-catalog.rb`
      MSG
    end

    in_catalog_without_feature_categories = teams_in_catalog - groups_in_mapping
    if in_catalog_without_feature_categories.any?
      errors << <<~MSG
        "#{in_catalog_without_feature_categories.inspect} are in `services/teams.yml` but don't have any feature categories in `services/stage-group-mapping.jsonnet`
        Should they be removed from `services/teams.yml`?
      MSG
    end

    errors
  end
end

begin
  ServiceCatalogValidator.new.validate if __FILE__ == $PROGRAM_NAME
rescue StandardError => e
  warn [e.message, *e.backtrace].join("\n")
  exit 1
end
