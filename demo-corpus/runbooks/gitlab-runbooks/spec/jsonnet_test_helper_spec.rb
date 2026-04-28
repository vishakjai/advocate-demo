# frozen_string_literal: true

# Of course, a test to test a test matcher :monocle:

require 'spec_helper'

describe 'Jsonnet Matcher' do
  describe 'render_jsonnet' do
    it 'supports hash matching' do
      matcher = render_jsonnet({ 'a' => 'hello' })
      result = matcher.matches?(
        <<~JSONNET.strip
          local hello = "he" + "llo";
          {
            a: hello
          }
        JSONNET
      )
      expect(result).to be(true)
      expect(matcher.description).to eql('render jsonnet successfully')
    end

    it 'supports string matching' do
      matcher = render_jsonnet('hello')
      result = matcher.matches?(
        <<~JSONNET.strip
          local hello = "he" + "llo";
          hello
        JSONNET
      )
      expect(result).to be(true)
      expect(matcher.description).to eql('render jsonnet successfully')
    end

    it 'supports another expectation' do
      matcher = render_jsonnet(a_hash_including({ 'a' => 'hello' }))
      result = matcher.matches?(
        <<~JSONNET.strip
          {
            a: 'hello',
            b: [1, 2, 3]
          }
        JSONNET
      )
      expect(result).to be(true)
      expect(matcher.description).to eql('render jsonnet successfully')
    end

    it 'supports nested expectations' do
      matcher = render_jsonnet do |data|
        expect(data['a']).to eql('hello')
        expect(data['b']).to include(1)
      end
      result = matcher.matches?(
        <<~JSONNET.strip
          {
            a: 'hello',
            b: [1, 2, 3]
          }
        JSONNET
      )
      expect(result).to be(true)
      expect(matcher.description).to eql('render jsonnet successfully')
    end

    it 'renders jsonnet rendering failure' do
      matcher = render_jsonnet({ 'a' => 1 })
      result = matcher.matches?(
        <<~JSONNET.strip
        {
          a = 1
        }
        JSONNET
      )
      expect(result).to be(false)
      expect(matcher.failure_message).to starting_with(
        <<~ERROR.strip
        Failed to render jsonnet content.

        >>> Jsonnet content:
        {
          a = 1
        }

        >>> Error:
        Failed to compile
        ERROR
      )
    end

    it 'renders jsonnet assertion failure' do
      matcher = render_jsonnet({ 'a' => 1 })
      result = matcher.matches?(
        <<~JSONNET.strip
          assert false : "A random assertion failure";
          {}
        JSONNET
      )
      expect(result).to be(false)
      expect(matcher.failure_message).to starting_with(
        <<~ERROR.strip
        Failed to render jsonnet content.

        >>> Jsonnet content:
        assert false : "A random assertion failure";
        {}

        >>> Error:
        Failed to compile
        ERROR
      )
    end

    it 'renders error details intensively' do
      matcher = render_jsonnet({ 'a' => 'hi' })
      result = matcher.matches?(
        <<~JSONNET.strip
          local hello = "he" + "llo";
          {
            a: hello
          }
        JSONNET
      )
      expect(result).to be(false)
      expect(matcher.failure_message).to start_with(
        <<~ERROR.strip
        Jsonnet rendered content does not match expectations.

        >>> Jsonnet content:
        local hello = "he" + "llo";
        {
          a: hello
        }

        >>> Jsonnet compiled data:
        {"a" => "hello"}


        >>> Expected:
        {"a" => "hi"}


        >>> Diff:
        ERROR
      )
    end

    it 'renders long error intensively' do
      matcher = render_jsonnet(
        'title' => 'Group dashboard: enablement (Geo)',
        'links' => [
          { 'title' => 'API Detail', 'type' => "dashboards", 'tags' => "type:api" },
          { 'title' => 'Web Detail', 'type' => "dashboards", 'tags' => "type:web" },
          { 'title' => 'Git Detail', 'type' => "dashboards", 'tags' => "type:git" }
        ]
      )
      result = matcher.matches?(
        <<~JSONNET.strip
        local title = "Group dashboard: enablement (Geo)";
        local links = std.map(
          function(type)
            { title: "%s Detail" % type, type: "dashboards", tags: "type:%s" % type },
          ['api', 'web', 'git'],
        );
        { title: title, links: links }
        JSONNET
      )
      expect(result).to be(false)
      expect(matcher.failure_message).to starting_with(
        <<~ERROR.strip
        Jsonnet rendered content does not match expectations.

        >>> Jsonnet content:
        local title = "Group dashboard: enablement (Geo)";
        local links = std.map(
          function(type)
            { title: "%s Detail" % type, type: "dashboards", tags: "type:%s" % type },
          ['api', 'web', 'git'],
        );
        { title: title, links: links }

        >>> Jsonnet compiled data:
        {"links" =>
          [{"tags" => "type:api", "title" => "api Detail", "type" => "dashboards"},
           {"tags" => "type:web", "title" => "web Detail", "type" => "dashboards"},
           {"tags" => "type:git", "title" => "git Detail", "type" => "dashboards"}],
         "title" => "Group dashboard: enablement (Geo)"}


        >>> Expected:
        {"title" => "Group dashboard: enablement (Geo)",
         "links" =>
          [{"title" => "API Detail", "type" => "dashboards", "tags" => "type:api"},
           {"title" => "Web Detail", "type" => "dashboards", "tags" => "type:web"},
           {"title" => "Git Detail", "type" => "dashboards", "tags" => "type:git"}]}


        >>> Diff:
        ERROR
      )
    end
  end

  describe 'reject_jsonnet' do
    it 'supports compiling failure' do
      matcher = reject_jsonnet(/failed to compile/i)
      result = matcher.matches?(
        <<~JSONNET.strip
          {
            a = 1
          }
        JSONNET
      )
      expect(result).to be(true)
      expect(matcher.description).to eql('reject jsonnet content with reason: /failed to compile/i')
    end

    it 'supports jsonnet assertions' do
      matcher = reject_jsonnet(/random assertion failure/i)
      result = matcher.matches?(
        <<~JSONNET.strip
          assert false : "A random assertion failure";
          {}
        JSONNET
      )
      expect(result).to be(true)
      expect(matcher.description).to eql('reject jsonnet content with reason: /random assertion failure/i')
    end

    it 'renders errors if jsonnet compiles successfully' do
      matcher = reject_jsonnet(/failed to compile/i)
      result = matcher.matches?(
        <<~JSONNET.strip
          {
            a: 1
          }
        JSONNET
      )
      expect(result).to be(false)
      expect(matcher.failure_message).to eql('Jsonnet content renders successfully. Expecting an error!')
    end

    it 'renders errors if the error does not match' do
      matcher = reject_jsonnet(/another assertion/i)
      result = matcher.matches?(
        <<~JSONNET.strip
          assert false : "A random assertion failure";
          {}
        JSONNET
      )
      expect(result).to be(false)
      expect(matcher.failure_message).to match(/Jsonnet error does not match/i)
    end
  end
end
