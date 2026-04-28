# frozen_string_literal: true

require 'yaml'

ARGV.each do |filename|
  # warn filename
  content = File.read(filename)
  match = content.split(/^## .+/)[0].match(/^# .+$/)

  unless match
    # warn "#{filename}: no heading, defaulting to filename"
  end

  is_index = File.basename(filename) == 'index.md'

  edit_url = "https://gitlab.com/gitlab-com/runbooks/-/edit/master/docs/#{filename.sub(%r{^src/content/docs/}, '').gsub(/index\.md$/, 'README.md')}"

  # infer title from captured h1.
  # slug is filename without suffix.
  header = {
    'title' => match ? match[0].sub(/^#/, '').strip : File.basename(filename, '.md'),
    'editUrl' => edit_url,
    'slug' => filename.sub('src/content/docs/', '').sub(/\.md$/, '')
  }

  # remove the h1 header
  content = content.sub(/^# .+$/, '')

  # find all links, except images
  content = content.gsub(/(?<=[^!])\[(.+?)\]\((.+?)\)/) do
    m = Regexp.last_match
    label = m[1]
    target = m[2]

    # only consider relative links, skip anchor links in current file (those can stay as-is)
    if target !~ %r{^(https?)://} && target !~ /^#/
      # foo/README.md becomes foo/index.md/ which becomes /foo/ -- fix the links accordingly
      target = target.gsub(/(README)?\.md($|#)/, '\\2').gsub(%r{^docs/}, '')
      # if current file is foo/index.md, it becomes /foo/
      # but if current file is foo/bar.md, it becomes /foo/bar/, so we need another traversal.
      target = "../#{target}" unless is_index
    end

    "[#{label}](#{target})"
  end
  content = "#{header.to_yaml}---\n\n#{content}"

  File.write(filename, content)
end
