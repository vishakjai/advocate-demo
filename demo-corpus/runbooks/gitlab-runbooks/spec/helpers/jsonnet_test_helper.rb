# frozen_string_literal: true

require_relative '../../lib/jsonnet_wrapper'

class JsonnetTestHelper
  attr_reader :data

  def self.render(content)
    new.tap { |helper| helper.render(content) }
  end

  def initialize
    @error = nil
  end

  def render(content)
    file = Tempfile.new('file.jsonnet')
    file.write(content)
    file.close

    @data = JsonnetWrapper.new.parse(file.path)
  rescue StandardError => e
    @error = e
  ensure
    file.unlink
  end

  def success?
    @error.nil?
  end

  def error_message
    @error.message
  end
end

# Matchers for jsonnet rendering
RSpec::Matchers.define :render_jsonnet do |expected|
  match do |jsonnet_content|
    raise 'render_jsonnet matcher supports either argument or block' if !block_arg.nil? && !expected.nil?

    @jsonnet_content = jsonnet_content
    @result = JsonnetTestHelper.render(jsonnet_content)
    next false unless @result.success?

    @actual = @result.data
    next block_arg.call(@result.data) unless block_arg.nil?

    if ::RSpec::Matchers.is_a_matcher?(expected)
      expected.matches?(@result.data)
    else
      @result.data == expected
    end
  end

  attr_reader :actual

  def inspect_data(data)
    io = StringIO.new
    ::PP.pp(data, io)
    output = io.string

    if output.length > 10_000
      f = Tempfile.create('jsonnet-dump')
      f.write(data.to_json)
      f.close
      "The generated Jsonnet data is too big to display on the screen. It is available at #{f.path}"
    else
      output
    end
  end

  def diff(actual, expected)
    SuperDiff::RSpec::Differ.diff(actual, expected)
  end

  description do
    "render jsonnet successfully"
  end

  failure_message do |actual|
    if @result.success?
      <<~DESCRIPTION.strip
      Jsonnet rendered content does not match expectations.

      >>> Jsonnet content:
      #{@jsonnet_content}

      >>> Jsonnet compiled data:
      #{inspect_data(actual)}

      >>> Expected:
      #{::RSpec::Matchers.is_a_matcher?(expected) ? expected.description : inspect_data(expected)}

      >>> Diff:
      #{diff(actual, expected)}
      DESCRIPTION
    else
      <<~DESCRIPTION.strip
      Failed to render jsonnet content.

      >>> Jsonnet content:
      #{@jsonnet_content}

      >>> Error:
      #{@result.error_message}
      DESCRIPTION
    end
  end
end

# Matchers for jsonnet rendering
RSpec::Matchers.define :reject_jsonnet do |expected|
  match do |actual|
    raise 'reject_jsonnet matcher argument should be a Regexp' unless expected.is_a?(Regexp)

    @result = JsonnetTestHelper.render(actual)
    next false if @result.success?

    @result.error_message.match?(expected)
  end

  description do
    "reject jsonnet content with reason: #{expected.inspect}"
  end

  failure_message do |_actual|
    if @result.success?
      'Jsonnet content renders successfully. Expecting an error!'
    else
      <<~DESCRIPTION.strip
        Jsonnet error does not match

        >>> Actual:
        #{@result.error_message}

        >>> Expected:
        #{expected.inspect}
      DESCRIPTION
    end
  end
end
