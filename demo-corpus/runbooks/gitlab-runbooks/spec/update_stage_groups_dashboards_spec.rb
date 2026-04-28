# frozen_string_literal: true

require 'spec_helper'

require_relative '../scripts/update_stage_groups_dashboards'

describe UpdateStageGroupsDashboard do
  describe '.render_template' do
    context 'when input group key is empty' do
      it 'raises an exception' do
        expect do
          described_class.render_template(nil)
        end.to raise_error(/Group key is empty/i)
      end
    end

    context 'when input group key is nil' do
      it 'raises an exception' do
        expect do
          described_class.render_template('')
        end.to raise_error(/Group key is empty/i)
      end
    end
  end

  describe '#call' do
    let(:dashboard_dir) { Dir.mktmpdir }
    let(:mapping_path) { "#{dashboard_dir}/stage-group-mapping.jsonnet" }
    let(:output) { StringIO.new }

    let(:groups_jsonnet) do
      file_fixture('stage-group-mapping-fixtures.jsonnet')
    end

    let(:operation) { described_class.new(dashboards_dir: dashboard_dir, mapping_path:, output:) }

    after do
      FileUtils.remove_entry dashboard_dir
    end

    context 'when the mapping file does not exist' do
      it 'raises an exception' do
        expect { operation.call }.to raise_error(/does not exist/i)
      end
    end

    context 'when the mapping file is invalid' do
      it 'raises an exception' do
        File.write(mapping_path, 'A junk file')
        expect { operation.call }.to raise_error(/failed to compile/i)
      end
    end

    context 'when the mapping file is valid' do
      let(:should_remove_file) { "#{dashboard_dir}/should-remove.dashboard.jsonnet" }

      let(:should_remove_file_2) { "#{dashboard_dir}/should-remove-2.dashboard.jsonnet" }
      let(:should_remove_content_2) { "#{described_class.render_template('should-remove-2')}\nThis template is customized" }

      let(:ml_ai_file) { "#{dashboard_dir}/ml-ai.dashboard.jsonnet" }
      let(:ml_ai_template) { described_class.render_template('ml-ai') }

      let(:compliance_file) { "#{dashboard_dir}/compliance.dashboard.jsonnet" }
      let(:compliance_template) { "#{described_class.render_template('ml-ai')}\nThis template is customized" }

      let(:access_file) { "#{dashboard_dir}/access.dashboard.jsonnet" }
      let(:access_template) { described_class.render_template('access') }

      let(:project_management_file) { "#{dashboard_dir}/project-management.dashboard.jsonnet" }
      let(:project_management_template) { described_class.render_template('project-management') }

      let(:long_file) { "#{dashboard_dir}/this-is-really-long-long-lo.dashboard.jsonnet" }
      let(:long_template) { described_class.render_template('this-is-really-long-long-long-long-long-long-stage') }

      before do
        File.write(mapping_path, groups_jsonnet)

        File.write(should_remove_file, described_class.render_template('should-remove'))
        File.write(should_remove_file_2, should_remove_content_2)
        File.write(ml_ai_file, ml_ai_template)
        File.write(compliance_file, compliance_template)
      end

      it 'synchronizes groups into the dashboard dir' do
        operation.call

        expect(File.exist?(should_remove_file)).to be(false)
        expect(File.exist?(should_remove_file_2)).to be(false)

        expect(File.exist?(ml_ai_file)).to be(true)
        expect(File.read(ml_ai_file)).to eql(ml_ai_template)

        expect(File.exist?(compliance_file)).to be(true)
        expect(File.read(compliance_file)).to eql(compliance_template)

        expect(File.exist?(access_file)).to be(true)
        expect(File.read(access_file)).to eql(access_template)

        expect(File.exist?(project_management_file)).to be(true)
        expect(File.read(project_management_file)).to eql(project_management_template)

        expect(File.exist?(long_file)).to be(true)
        expect(File.read(long_file)).to eql(long_template)
      end
    end
  end
end
