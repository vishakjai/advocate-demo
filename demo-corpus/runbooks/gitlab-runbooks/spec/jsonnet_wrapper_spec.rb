# frozen_string_literal: true

require 'spec_helper'

require_relative '../lib/jsonnet_wrapper'

describe JsonnetWrapper do
  let(:jsonnet_file_path) do
    File.join(Dir.mktmpdir, 'jsonnet-file.jsonnet')
  end

  describe '#initialize' do
    it 'raises an error when jsonnet is not found' do
      expect { described_class.new(executable_name: 'hargl') }
        .to raise_error(/jsonnet not found/i)
    end
  end

  describe '#evaluate' do
    it 'evaluates a jsonnet file' do
      File.write(
        jsonnet_file_path, <<~JSONNET
          {
            hello: std.join('', ['w', 'o', 'r', 'l', 'd'])
          }
        JSONNET
      )

      expect(subject.evaluate(jsonnet_file_path)).to eq(
        <<~JSON
        {
           "hello": "world"
        }
        JSON
      )
    end

    it 'raises including the error message when failing to evaluate' do
      File.write(
        jsonnet_file_path, <<~JSONNET
          {
            hello: {
              assert false : 'broken'
            }
          }
        JSONNET
      )

      expect { subject.evaluate(jsonnet_file_path) }
        .to raise_error(/failed to compile #{jsonnet_file_path}.*broken/im)
    end

    it 'raises an error when the file is missing' do
      expect { subject.evaluate("not-here.jsonnet") }
        .to raise_error(/failed to compile not-here.jsonnet.*no such file or directory/im)
    end

    it 'evaluates using the libs' do
      File.write(
        jsonnet_file_path, <<~JSONNET
          local strings = import 'utils/strings.libsonnet';

          {
            hello: strings.capitalizeFirstLetter('world')
          }
        JSONNET
      )

      expect(subject.evaluate(jsonnet_file_path)).to eq(
        <<~JSON
        {
           "hello": "World"
        }
        JSON
      )
    end

    it 'evaluates using external strings' do
      wrapper = described_class.new(ext_str: { hello_world: 'from ruby' })
      File.write(
        jsonnet_file_path, <<~JSONNET
          local helloFromRuby = std.extVar('hello_world');

          {
            greeting: helloFromRuby,
          }
        JSONNET
      )

      expect(wrapper.evaluate(jsonnet_file_path)).to eq(
        <<~JSON
        {
           "greeting": "from ruby"
        }
        JSON
      )
    end
  end

  describe '#parse' do
    it 'returns the evaluated context parsed into a ruby object' do
      allow(subject).to receive(:evaluate).with('path').and_return('{ "hello": "world" }')

      expect(subject.parse('path')).to eq({ 'hello' => 'world' })
    end
  end
end
