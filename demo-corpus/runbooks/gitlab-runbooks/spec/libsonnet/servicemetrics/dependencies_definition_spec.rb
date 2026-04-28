# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/DescribeClass
describe 'libsonnet/servicemetrics/dependencies_definition.libsonnet' do
  describe '#generateInhibitionRules' do
    context 'when valid dependsOn' do
      it 'returns inhibit rule' do
        expect(
          <<~JSONNET
            local dependencies = import 'servicemetrics/dependencies_definition.libsonnet';

            dependencies.new("web", "workhorse", [{ component: 'rails_primary_sql', type: 'patroni'}]).generateInhibitionRules()
          JSONNET
        ).to render_jsonnet([
          'equal' => %w[env environment pager],
          'source_matchers' => ['component="rails_primary_sql"', 'type="patroni"'],
          'target_matchers' => ['component="workhorse"', 'type="web"']
        ])
      end
    end

    context 'when dependsOn.type does not exist' do
      it 'raises an error' do
        expect(
          <<~JSONNET
            local dependencies = import 'servicemetrics/dependencies_definition.libsonnet';

            dependencies.new("web", "workhorse", [{ component: 'rails_primary_sql', type: 'non-exists'}]).generateInhibitionRules()
          JSONNET
        ).to reject_jsonnet(/`dependsOn.type` field invalid for "workhorse": service "non-exists" does not exist/i)
      end
    end

    context 'when dependsOn.component does not exist' do
      it 'raises an error' do
        expect(
          <<~JSONNET
            local dependencies = import 'servicemetrics/dependencies_definition.libsonnet';

            dependencies.new("web", "workhorse", [{ component: 'non-exists', type: 'patroni'}]).generateInhibitionRules()
          JSONNET
        ).to reject_jsonnet(/`dependsOn.component` field invalid for "workhorse": component "non-exists" does not exist for service "patroni"/i)
      end
    end

    context 'when type and dependsOn.type are the same' do
      it 'raises an error' do
        expect(
          <<~JSONNET
            local dependencies = import 'servicemetrics/dependencies_definition.libsonnet';

            dependencies.new("web", "workhorse", [{ component: 'imagescaler', type: 'web'}]).generateInhibitionRules()
          JSONNET
        ).to reject_jsonnet(/inhibit rule creation failed: `dependsOn.type` for the sli "web.workhorse" cannot depend on an sli of the same service/i)
      end
    end

    context 'when type does not exist' do
      it 'raises an error' do
        expect(
          <<~JSONNET
            local dependencies = import 'servicemetrics/dependencies_definition.libsonnet';

            dependencies.new("non-exists", "workhorse", [{ component: 'rails_primary_sql', type: 'patroni'}]).generateInhibitionRules()
          JSONNET
        ).to reject_jsonnet(/dependency definition failed: type "non-exists" does not exist/i)
      end
    end

    context 'when sliName does not exist' do
      it 'raises an error' do
        expect(
          <<~JSONNET
            local dependencies = import 'servicemetrics/dependencies_definition.libsonnet';

            dependencies.new("web", "non-exists", [{ component: 'rails_primary_sql', type: 'patroni'}]).generateInhibitionRules()
          JSONNET
        ).to reject_jsonnet(/dependency definition failed: sliName "non-exists" does not exist/i)
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass
