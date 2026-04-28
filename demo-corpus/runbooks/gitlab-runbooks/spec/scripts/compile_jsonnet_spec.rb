# frozen_string_literal: true

require 'spec_helper'

require_relative '../../scripts/compile_jsonnet'

describe CompileJsonnet do
  let(:executable_path) { File.expand_path(File.join(File.dirname(__FILE__), '../../scripts/compile_jsonnet.rb')) }

  let(:target_path) do
    File.join(Dir.mktmpdir, 'jsonnet-file.jsonnet')
  end

  let(:jsonnet_lib_dir) { Dir.mktmpdir }

  shared_examples 'compiles Jsonnet file' do
    subject(:compiler) { described_class.new(io) }

    let(:io) { StringIO.new }

    it 'compiles file successfully' do
      compiler.run(argv)
      expect(io.string).to eq(expected_result)
    end

    it 'compiles file successfully with executable file scripts/compile_jsonnet.rb' do
      command = [executable_path] + argv
      expect(IO.popen(Shellwords.join(command), &:read)).to eql(expected_result)
      expect($CHILD_STATUS.to_i).to be(0)
    end
  end

  describe '#run' do
    context 'when compile a single jsonnet file' do
      let(:argv) { [target_path] }
      let(:expected_result) do
        <<~JSON
          {
             "hello": "world"
          }
        JSON
      end

      before do
        File.write(
          target_path, <<~JSONNET
            {
              hello: std.join('', ['w', 'o', 'r', 'l', 'd'])
            }
          JSONNET
        )
      end

      it_behaves_like 'compiles Jsonnet file'
    end

    context 'when compile a jsonnet file using a library utility method' do
      let(:argv) { [target_path] }
      let(:expected_result) do
        <<~JSON
          {
             "hello": "world"
          }
        JSON
      end

      before do
        File.write(
          target_path, <<~JSONNET
            local strings = import 'utils/strings.libsonnet';
            {
              hello: strings.chomp("world\n\n\n")
            }
          JSONNET
        )
      end

      it_behaves_like 'compiles Jsonnet file'
    end

    context 'when compile a jsonnet file including custom libraries' do
      let(:lib_a_path) { File.join(jsonnet_lib_dir, 'lib_a.libsonnet') }
      let(:lib_b_path) { File.join(jsonnet_lib_dir, 'lib_b.libsonnet') }

      let(:argv) { ['-I', jsonnet_lib_dir, target_path] }
      let(:expected_result) do
        <<~JSON
          {
             "hello": "hello hello world"
          }
        JSON
      end

      before do
        File.write(
          lib_a_path, <<~JSONNET
            local concat(string_a, string_b) = string_a + " " + string_b;
            {
              concat: concat
            }
          JSONNET
        )

        File.write(
          lib_b_path, <<~JSONNET
            local double(str) = str + " " + str;
            {
              double: double
            }
          JSONNET
        )
        File.write(
          target_path, <<~JSONNET
            local strings = import 'utils/strings.libsonnet';
            local lib_a = import 'lib_a.libsonnet';
            local lib_b = import 'lib_b.libsonnet';

            {
              hello: lib_a.concat(lib_b.double("hello"), strings.chomp("world\n\n\n"))
            }
          JSONNET
        )
      end

      it_behaves_like 'compiles Jsonnet file'
    end
  end
end
