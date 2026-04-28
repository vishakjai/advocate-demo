# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/DescribeClass
describe 'libsonnet/servicemetrics/service_definition.libsonnet' do
  let(:base_service_definition) do
    {
      serviceLevelIndicators: {
        sidekiq_execution: {
          name: 'sidekiq_execution',
          kinds: 'apdex',
          description: '',
          significantLabels: ['world'],
          featureCategory: 'error_budgets',
          requestRate: {},
          userImpacting: true
        },
        some_sli: {
          shardLevelMonitoring: false,
          name: 'sidekiq_execution',
          kinds: 'apdex',
          description: '',
          significantLabels: ['world'],
          featureCategory: 'error_budgets',
          requestRate: {},
          userImpacting: true
        }
      }
    }
  end

  let(:jsonnet_content) do
    <<~JSONNET
        local serviceDefinition = import './servicemetrics/service_definition.libsonnet';

        serviceDefinition.serviceDefinition(#{base_service_definition.merge(monitoring_object).to_json}).monitoring
    JSONNET
  end

  describe 'defaults for serviceDefinition.monitoring.shard' do
    let(:default_monitoring) do
      {
        monitoring: {
          node: { enabled: false, overrides: {}, thresholds: {} },
          shard: { enabled: false, overrides: {} }
        }
      }
    end

    where(:monitoring_object, :expected) do
      [
        [{}, ref(:default_monitoring)],
        [{ monitoring: {} }, ref(:default_monitoring)],
        [{ monitoring: { shard: {} } }, ref(:default_monitoring)],
        [{ monitoring: { shard: { enabled: true } } }, { monitoring: { node: { enabled: false, overrides: {}, thresholds: {} }, shard: { enabled: true, overrides: {} } } }],
        [{ monitoring: { shard: { enabled: false } } }, ref(:default_monitoring)],
        [{ monitoring: { shard: { enabled: true, overrides: {} } } }, { monitoring: { node: { enabled: false, overrides: {}, thresholds: {} }, shard: { enabled: true, overrides: {} } } }],
        [
          {
            monitoring: {
              shard: {
                enabled: true,
                overrides: {
                  sidekiq_execution: {
                    'urgent-authorized-projects': {
                      apdexScore: 0.97
                    }
                  }
                }
              }
            }
          },
          {
            monitoring: {
              node: { enabled: false, overrides: {}, thresholds: {} },
              shard: {
                enabled: true,
                overrides: {
                  sidekiq_execution: {
                    'urgent-authorized-projects': {
                      apdexScore: 0.97
                    }
                  }
                }
              }
            }
          }
        ]
      ]
    end

    with_them do
      it 'renders serviceDefinition.monitoring with the default fields' do
        expect(jsonnet_content).to render_jsonnet(JSON.parse(expected[:monitoring].to_json))
      end
    end
  end

  describe 'validation for serviceDefinition.monitoring.shard' do
    where do
      {
        "enabled without overrides object" => {
          monitoring_object: {
            monitoring: {
              shard: { enabled: true }
            }
          },
          is_valid?: true
        },
        "empty monitoring object" => {
          monitoring_object: {
            monitoring: {}
          },
          is_valid?: true
        },
        "undefined monitoring object" => {
          monitoring_object: {},
          is_valid?: true
        },
        "enabled with SLI overrides" => {
          monitoring_object: {
            monitoring: {
              shard: {
                enabled: true,
                overrides: {
                  sidekiq_execution: {
                    'urgent-authorized-projects': {
                      apdexScore: 0.97
                    }
                  }
                }
              }
            }
          },
          is_valid?: true
        },
        "enabled with SLI overrides on non-existing SLI" => {
          monitoring_object: {
            monitoring: {
              shard: {
                enabled: true,
                overrides: {
                  foobar: {
                    'urgent-authorized-projects': {
                      apdexScore: 0.97
                    }
                  }
                }
              }
            }
          },
          is_valid?: false,
          error_message: /field monitoring.shard.overrides: SLI must be present and has shardLevelMonitoring enabled. Supported SLIs: sidekiq_execution/i
        },
        "enabled with SLI overrides on SLI with shardLevelMonitored = false" => {
          monitoring_object: {
            monitoring: {
              shard: {
                enabled: true,
                overrides: {
                  some_sli: {
                    'urgent-authorized-projects': {
                      apdexScore: 0.97
                    }
                  }
                }
              }
            }
          },
          is_valid?: false,
          error_message: /field monitoring.shard.overrides: SLI must be present and has shardLevelMonitoring enabled. Supported SLIs: sidekiq_execution/i
        }
      }
    end

    with_them do
      if params[:is_valid?]
        it 'validates successfully' do
          expect(jsonnet_content).to render_jsonnet(be_truthy)
        end
      else
        it 'raises an error' do
          expect(jsonnet_content).to reject_jsonnet(error_message)
        end
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass
