# frozen_string_literal: true

require 'spec_helper'

require_relative '../scripts/validate-service-catalog'

describe ServiceCatalogValidator do
  let(:tmp_dir) { Dir.mktmpdir }
  let(:raw_catalog_path) { "#{tmp_dir}/raw-catalog.jsonnet" }
  let(:raw_catalog_jsonnet) { JSON.dump(JSON.parse(base_catalog)) }

  let(:base_catalog) do
    <<-JSONNET
        {
          "teams": [
            {
              "name": "sre_reliability"
            }
          ],
          "tiers": [
            {
              "name": "sv"
            }
          ]
        }
    JSONNET
  end

  before do
    File.write(raw_catalog_path, raw_catalog_jsonnet)
  end

  after do
    FileUtils.remove_entry tmp_dir
  end

  describe "#validate" do
    subject(:service_catalog_validator) { described_class.new(raw_catalog_path).validate }

    it "calls all validators with the expected catalog" do
      expected_catalog = {
        "teams" => [
          {
            "name" => "sre_reliability"
          }
        ],
        "tiers" => [
          {
            "name" => "sv"
          }
        ]
      }

      expected_validations = [ValidateServiceMappings, ValidateStageGroupMapping]
      expected_validations.each do |validation_class|
        validator = instance_double(validation_class)

        expect(validation_class).to receive(:new).with(expected_catalog).and_return(validator)
        expect(validator).to receive(:validate).and_return([])
      end

      service_catalog_validator
    end
  end

  describe ValidateServiceMappings do
    describe "#validate" do
      let(:validator) { described_class.new(service_catalog.merge("teams" => [])) }

      where(:service_catalog, :error_message) do
        [
          [
            {
              "services" => [
                {
                  "name" => "Foo",
                  "tier" => "sv",
                  "friendly_name" => "mr_foo",
                  "label" => "Foo"
                },
                {
                  "name" => "Bar",
                  "tier" => "sv",
                  "friendly_name" => "mr_bar",
                  "label" => "Bar"
                }
              ]
            },
            nil
          ],

          # Label not unique (same case)
          [
            {
              "services" => [
                {
                  "name" => "Foo",
                  "tier" => "sv",
                  "friendly_name" => "mr_foo",
                  "label" => "Foo"
                },
                {
                  "name" => "Bar",
                  "tier" => "sv",
                  "friendly_name" => "mr_bar",
                  "label" => "Foo"
                }
              ]
            },
            "'Foo' | duplicated labels found in service catalog. Label field must be unique (case insensitive)"
          ],

          # Label not unique (different case)
          [
            {
              "services" => [
                {
                  "name" => "Foo",
                  "tier" => "sv",
                  "friendly_name" => "mr_foo",
                  "label" => "Foo"
                },
                {
                  "name" => "Bar",
                  "tier" => "sv",
                  "friendly_name" => "mr_bar",
                  "label" => "foO"
                }
              ]
            },
            "'foO' | duplicated labels found in service catalog. Label field must be unique (case insensitive)"
          ]
        ]
      end

      with_them do
        it "returns the expected errors" do
          expect(validator.validate).to eq([error_message].compact)
        end
      end
    end
  end

  describe ValidateStageGroupMapping do
    describe "#validate" do
      def build_team(name)
        {
          "product_stage_group" => name
        }
      end

      def build_stage_group(name)
        {
          name => {
            "product_stage" => "stage",
            "feature_categories" => ["duo_chat"]
          }
        }
      end

      subject(:validate) { described_class.new(service_catalog, stage_group_mapping).validate }

      let(:service_catalog) { { "teams" => [build_team("duo_chat"), build_team("ai_model_validation")] } }
      let(:stage_group_mapping) { build_stage_group("duo_chat").merge(build_stage_group("ai_framework")) }

      it "lists groups in the stage group mapping but missing from teams.yml" do
        expect(validate).to include(a_string_matching(%r{\["ai_framework"\] don't have an entry in `services/teams.yml`}))
      end

      it "lists groups in teams.yml that are not part of the stage group mapping" do
        expect(validate).to include(a_string_matching(%r{\["ai_model_validation"\] are in `services/teams.yml` but don't have any feature categories in `services/stage-group-mapping.jsonnet`}))
      end
    end
  end
end
