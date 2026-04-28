#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'pathname'

require_relative '../lib/jsonnet_wrapper'

##
# Compile an arbitrary Jsonnet file in this runbook project to JSON, and dump
# to STDOUT. All the necessary libraries, paths, required external variables
# are already setup by default.
class CompileJsonnet
  def initialize(output = $stdout)
    @output = output
    @options = {}
  end

  def run(argv = ARGV)
    parse_options(argv)
    wrapper = JsonnetWrapper.new(libs: JsonnetWrapper::DEFAULT_LIBS + jsonnet_libs)
    @output.write wrapper.evaluate(@options[:target_file])
  end

  private

  def parse_options(argv)
    OptionParser.new do |opts|
      opts.banner = <<~BANNER
      Compile an arbitrary Jsonnet file in this runbook project to JSON, and dump to STDOUT. All the necessary libraries, paths, required external variables are already setup by default.

      Usage: scripts/compile_jsonnet.rb [options] [file path]"
      BANNER

      opts.on("-I lib_a,lib_b,lib_c", "--libs=lib_a,lib_b,lib_c", Array, "Libraries to be included when compiling the Jsonnet files") do |libs|
        @options[:libs] = libs
      end
    end.parse!(argv)

    raise "Please provide exactly one target file!" if argv.nil? || argv.length != 1

    @options[:target_file] = File.expand_path(argv.first)
  end

  def jsonnet_libs
    return [] if @options[:libs].nil? || @options[:libs].empty?

    repo_dir = File.expand_path(File.join(File.dirname(__FILE__), '..')).freeze
    @options[:libs].map do |lib|
      if Pathname.new(lib).absolute?
        lib
      else
        File.join(repo_dir, lib)
      end
    end
  end
end

CompileJsonnet.new.run if $PROGRAM_NAME == __FILE__
