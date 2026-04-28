#! /usr/bin/env ruby
# frozen_string_literal: true

# vi: set ft=ruby :

# -*- mode: ruby -*-

#
# A sidekick for Sidekiq
#
# A command-line tool for managing Sidekiq jobs and queues.
#
# If you need to run this on a Omnibus GitLab machine, run:
#
# sudo gitlab-rails runner /full_pathname/sq.rb [count|show|kill_worker|kill_job] <worker name or Job ID> --dry-run=yes
#
# To kill a job by its ID:
#
# sudo gitlab-rails runner /var/opt/gitlab/scripts/sq.rb kill_job <job_id> --verbose --dry-run=yes
#
# One may also query by job type:
#
# sudo gitlab-rails runner /var/opt/gitlab/scripts/sq.rb kill_worker BackgroundMigrationWorker --job-type='BackfillJiraTrackerDeploymentType' --limit=10 --verbose --dry-run=yes
#
# Or:
#
# BUNDLE_GEMFILE=/opt/gitlab/embedded/service/gitlab-rails/Gemfile /opt/gitlab/embedded/bin/bundle exec /opt/gitlab/embedded/bin/ruby sq.rb -h <hostname> -a <password> [count|show|kill_worker|kill_job] <worker name or Job ID> --dry-run=yes
#

require 'logger'
require 'optparse'
require 'sidekiq/api'

module Runbooks
  module Sidekiq
    JOB_TIMESTAMP_FORMAT = '%Y-%m-%d_%H%M%S'
    ApplicationError = Class.new(StandardError)

    module CommandLineSupport
      Options = Struct.new(
        :command, :parameters, :dry_run, :log_level, :job_type, :fetch_limit, :limit, :hostname, :password, :socket
      )
      DEFAULTS = [nil, [], true, Logger::INFO, nil, 100, -1, nil, nil, nil].freeze

      def parse_options(argv)
        options = ::Runbooks::Sidekiq::CommandLineSupport::Options.new(
          *::Runbooks::Sidekiq::CommandLineSupport::DEFAULTS
        )

        option_parser = OptionParser.new do |parser|
          parser.banner = "Usage: #{$PROGRAM_NAME} [options] [count|show|kill|kill_jid] <worker name or job ID>"

          parser.on('-a', '--auth=<password>', 'Redis password') do |password|
            options.password = password
          end

          parser.on('--hostname=<hostname>', 'Redis hostname') do |hostname|
            options.hostname = hostname
          end

          parser.on('-s', '--socket=<unix_socket_path>', 'Redis UNIX socket') do |socket|
            options.socket = socket
          end

          parser.on('--job-type=<job_type>', 'Filter jobs by type') do |job_type|
            options.job_type = job_type
          end

          parser.on('--limit=<limit>', Integer, 'Limit of jobs to show or kill; incompatible with count') do |limit|
            options.limit = limit.to_i
          rescue StandardError => _e
            raise OptionParser::InvalidArgument, 'Bad value for argument: --limit'
          end

          parser.on('--fetch-limit=<limit>', Integer, 'Limit of jobs on which to operate at a time') do |fetch_limit|
            options.fetch_limit = fetch_limit.to_i
          rescue StandardError => _e
            raise OptionParser::InvalidArgument, 'Bad value for argument: --fetch-limit'
          end

          parser.on('-d', '--dry-run=[yes/no]', 'Show what would have been done; default: yes') do |dry_run|
            options[:dry_run] = !dry_run.match?(/^(no|false)$/i)
          end

          parser.on('-v', '--verbose', 'Increase logging verbosity') do
            options.log_level -= 1
          end

          parser.on('-h', '--help', 'Print help message') do
            puts parser
            exit
          end
        end

        option_parser.parse!(argv)

        # Command is the first remaining value
        options.command = argv.shift
        # Parameters are all remaining values
        loop do
          parameter = argv.shift
          break if parameter.nil?

          options.parameters << parameter
        end

        options
      end

      def dry_run_notice
        log.info '[Dry-run] This is only a dry-run -- write operations will be logged but not ' \
          'executed'
      end
    end
    # module CommandLineSupport

    module Logging
      LOG_TIMESTAMP_FORMAT = '%Y-%m-%d %H:%M:%S'
      LOG_FORMAT = "%<timestamp>s %-5<level>s %<msg>s\n"

      def formatter_procedure(format_template = ::Runbooks::Sidekiq::Logging::LOG_FORMAT)
        proc do |level, t, _name, msg|
          format(
            format_template,
            timestamp: t.strftime(::Runbooks::Sidekiq::Logging::LOG_TIMESTAMP_FORMAT),
            level:, msg:)
        end
      end

      def initialize_log(formatter = formatter_procedure)
        $stdout.sync = true
        log = Logger.new($stdout)
        log.level = Logger::INFO
        log.formatter = formatter
        log
      end

      def log
        @log ||= initialize_log
      end
    end

    class Sidekick
      include ::Runbooks::Sidekiq::Logging

      attr_reader :options

      def initialize(options)
        @options = options
        log.level = options.log_level
      end

      def redis_url
        if options.socket
          "unix://#{options.socket}"
        elsif options.hostname
          "redis://#{options.hostname}"
        else
          'redis://localhost:6379'
        end
      end

      def configure_sidekiq
        return if options.socket.nil? || options.socket.empty? || options.hostname.nil? || options.hostname.empty?

        redis_config = {
          namespace: 'resque:gitlab',
          url: redis_url
        }
        redis_config[:password] = options.password unless options.password.nil? || options.password.empty?

        ::Sidekiq.configure_client do |config|
          config.redis = redis_config
        end
      end

      def when_valid_timestamp(timestamp)
        return unless timestamp.respond_to?(:to_f)

        yield Time.at(timestamp.to_f).strftime(::Runbooks::Sidekiq::JOB_TIMESTAMP_FORMAT)
      end

      def job_to_s(job)
        "#{job.klass}:#{job.args.first}:#{job.jid}" + when_valid_timestamp(job.enqueued_at) do |timestamp|
          ":#{timestamp}"
        end
      end

      def selected?(job, query)
        job.klass == query[:worker_name] || job.args.first == query[:job_type] || query[:job_type] == '*'
      end

      def for_each_job(query = {})
        ::Sidekiq::Queue.all.each do |queue|
          queue.each do |job|
            yield job if selected?(job, query)
          end
        end
      end

      def find_job(query = {})
        return nil if query[:job_id].nil? || query[:job_id].empty?

        ::Sidekiq::Queue.all.each do |queue|
          queue.each do |job|
            return job if job.jid == query[:job_id]
          end
        end
        nil
      end

      def load_sidekiq_queue_data(query = {})
        class_type = Hash.new { |hash, key| hash[key] = 1 }
        class_by_args = Hash.new { |hash, key| hash[key] = 1 }

        for_each_job(query) do |job|
          class_type[job.klass] += 1
          class_by_args[[job.klass, job.args]] += 1
        end

        [class_type, class_by_args]
      end

      def count_jobs(query = {})
        count = 0
        message = "Counting all jobs of class #{query[:worker_name]}"
        message = "#{message} and type #{query[:job_type]}" unless query[:job_type].nil?
        log.info message
        for_each_job(query) do |_job|
          count += 1
        end

        count
      end

      def delete_jobs(jobs)
        count = 0
        log.debug "Deleting #{jobs.length} jobs"
        jobs.each do |job|
          if options.dry_run
            log.debug "[Dry-run] Would have killed job with ID: #{job.jid}"
          else
            log.debug "Killing job: #{job_to_s(job)}"
            job.delete
          end

          count += 1
        end
        count
      end

      def get_jobs(query)
        jobs = []
        for_each_job(query) do |job|
          jobs << job

          break if safely_meets_or_exceeds?(jobs.length, options.fetch_limit) ||
            safely_meets_or_exceeds?(jobs.length, options.limit)
        end
        jobs
      end

      def discard_excess(items, previous_total, limit)
        return items unless safely_meets_or_exceeds?(previous_total + items.length, limit)

        items.slice(0, [limit - previous_total, 0].max)
      end

      def kill_jobs_by_worker_name(query = {})
        when_limited(options.limit) { |limit| log.info "Killing #{limit} jobs" }

        deleted_jobs_count = 0
        loop do
          jobs_to_delete = discard_excess(get_jobs(query), deleted_jobs_count, options.limit)
          log.debug "Selected #{jobs_to_delete.length} jobs for deletion"
          break if jobs_to_delete.empty?

          deleted_jobs_count += delete_jobs(jobs_to_delete)
        end

        deleted_jobs_count
      end

      def kill_job_by_id(query = {})
        job = find_job(query)
        raise ApplicationError, "Could not find job ID #{query[:job_id]}" if job.nil?

        if options.dry_run
          log.info "[Dry-run] Would have killed job with ID: #{query[:job_id]}"
        else
          log.info "Killing job: #{job_to_s(job)}"
          job.delete
        end
      end

      def pretty_print(data)
        data.sort_by { |_key, value| value }.reverse.each do |key, value|
          log.info "#{key}: #{value}"
        end
      end

      def when_limited(limit)
        yield limit if safely_positive?(limit)
      end

      def safely_meets_or_exceeds?(value, other)
        safely_positive?(other) && value >= other
      end

      def safely_positive?(value)
        !value.nil? && value.respond_to?(:positive?) && value.positive?
      end

      def show_sidekiq_data
        return if options.command != 'show' || options.command.empty?

        queue_data, job_data = load_sidekiq_queue_data(job_type: options.job_type)
        log.info '-----------'
        log.info 'Queue size:'
        log.info '-----------'

        if queue_data.empty?
          log.info "None"
        else
          pretty_print(queue_data)
        end

        log.info '------------------------------'
        log.info 'Top job counts with arguments:'
        log.info '------------------------------'

        if job_data.empty?
          log.info "None"
        else
          pretty_print(job_data)
        end
      end

      def handle(command, parameters)
        show_sidekiq_data
        case command
        when 'count'
          worker_name = parameters.first
          job_type = options.job_type
          count = count_jobs(worker_name:, job_type:)
          log.info "Total jobs: #{count}"
        when 'kill_jid', 'kill_job'
          job_id = parameters.first
          abort 'Specify a job ID to kill' if job_id.nil? || job_id.empty?

          kill_job_by_id(job_id:)
        when 'kill', 'kill_worker'
          worker_name = parameters.first
          job_type = options.job_type
          if worker_name.nil? || worker_name.empty?
            abort 'Specify a job/worker name to kill (e.g. ' \
              'RepositoryUpdateMirrorWorker)'
          end

          count = kill_jobs_by_worker_name(worker_name:, job_type:)
          if options.dry_run
            log.info "[Dry-run] Would have killed #{count} jobs"
          else
            log.info "Killed #{count} jobs"
          end
        end
      end
    end
    # class Sidekick

    module Script
      include ::Runbooks::Sidekiq::CommandLineSupport
      include ::Runbooks::Sidekiq::Logging
      def main(args = parse_options(ARGV))
        sidekick = ::Runbooks::Sidekiq::Sidekick.new(args)
        sidekick.configure_sidekiq
        dry_run_notice if args.dry_run
        sidekick.handle(args.command, args.parameters)
      rescue ApplicationError => e
        abort e.message
      rescue StandardError => e
        log.error e.message
        e.backtrace.each { |trace| log.error trace }
        exit(1)
      end
    end
    # module Script
  end
  # Sidekiq module
end
# Runbooks module

# Anonymous object prevents namespace pollution
Object.new.extend(::Runbooks::Sidekiq::Script).main if $PROGRAM_NAME == __FILE__
