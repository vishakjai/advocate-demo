# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/DescribeClass
describe 'service-maturity/maturity.jsonnet' do
  let(:maturity_manifest) { File.read(join_root_path(self.class.top_level_description)) }

  it 'generates a validate manifest file' do
    expect(maturity_manifest).to render_jsonnet { |data|
      expect(data).to be_a(Hash)
      expect(data.values).to all(a_hash_including(
        'level' => match(/^Level [0-5]$/),
        'details' => all(a_hash_including(
          'name' => be_a(String),
          'passed' => be_one_of(true, false),
          'criteria' => all(a_hash_including(
            'name' => be_a(String),
            'result' => be_one_of("passed", "failed", "skipped", "unimplemented"),
            'evidence' => be_a(Object) # Anything
          ))
        ))
      ))
    }
  end
end
# rubocop:enable RSpec/DescribeClass
