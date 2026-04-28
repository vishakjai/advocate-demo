#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'optparse'
require 'time'
require 'csv'

# Script to add overrides to all layers of an incident.io on-call schedule
#
# Usage:
#   # Single override
#   ruby scripts/incident_io_schedule_override.rb \
#     --schedule-id SCHEDULE_ID \
#     --email user@example.com \
#     --start "2025-01-15T09:00:00Z" \
#     --end "2025-01-15T17:00:00Z" \
#     [--api-key API_KEY] \
#     [--dry-run]
#
#   # Multiple overrides from CSV
#   ruby scripts/incident_io_schedule_override.rb \
#     --schedule-id SCHEDULE_ID \
#     --csv-file overrides.csv \
#     [--api-key API_KEY] \
#     [--dry-run]
#
# Environment Variables:
#   INCIDENT_API_KEY - API key for incident.io (required if --api-key not provided)
#
# CSV File Format:
#   The CSV file should have the following columns (with header row):
#   email,start_time,end_time
#
#   Example CSV:
#   email,start_time,end_time
#   user1@example.com,2025-01-15T09:00:00Z,2025-01-15T17:00:00Z
#   user2@example.com,2025-01-16T09:00:00Z,2025-01-16T17:00:00Z
#
# Examples:
#   # Add single override for all layers in a schedule
#   ruby scripts/incident_io_schedule_override.rb \
#     --schedule-id 01HQXYZ123 \
#     --email user@example.com \
#     --start "2025-01-15T09:00:00Z" \
#     --end "2025-01-15T17:00:00Z"
#
#   # Add multiple overrides from CSV file
#   ruby scripts/incident_io_schedule_override.rb \
#     --schedule-id 01HQXYZ123 \
#     --csv-file overrides.csv
#
#   # Dry run to see what would be created
#   ruby scripts/incident_io_schedule_override.rb \
#     --schedule-id 01HQXYZ123 \
#     --csv-file overrides.csv \
#     --dry-run

class IncidentIOClient
  BASE_URL = 'https://api.incident.io'
  API_VERSION = 'v2'

  def initialize(api_key)
    @api_key = api_key
    raise ArgumentError, 'API key is required' if @api_key.nil? || @api_key.empty?
  end

  # Get schedule details including all rotations/layers
  def get_schedule(schedule_id)
    uri = URI("#{BASE_URL}/#{API_VERSION}/schedules/#{schedule_id}")
    request = Net::HTTP::Get.new(uri)
    make_request(uri, request)
  end

  # Create an override for a specific layer using Schedules V2 endpoint
  def create_override(schedule_id, rotation_id, layer_id, email, start_time, end_time)
    uri = URI("#{BASE_URL}/#{API_VERSION}/schedule_overrides")
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'

    body = {
      schedule_id: schedule_id,
      layer_id: layer_id,
      rotation_id: rotation_id,
      user: {
        email: email
      },
      start_at: start_time,
      end_at: end_time
    }

    request.body = JSON.generate(body)

    make_request(uri, request)
  end

  # Get user details by ID
  def get_user(user_id)
    uri = URI("#{BASE_URL}/#{API_VERSION}/users/#{user_id}")
    request = Net::HTTP::Get.new(uri)
    make_request(uri, request)
  end

  # List all users and find by email
  def find_user_by_email(email)
    page = 1
    per_page = 100

    loop do
      uri = URI("#{BASE_URL}/#{API_VERSION}/users?page_size=#{per_page}&after=#{(page - 1) * per_page}")
      request = Net::HTTP::Get.new(uri)
      response = make_request(uri, request)

      users = response['users'] || []

      # Search for user with matching email
      user = users.find { |u| u['email']&.downcase == email.downcase }
      return user if user

      # Check if there are more pages
      break unless response['pagination_meta'] && response['pagination_meta']['after']

      page += 1

      # Safety limit to prevent infinite loops
      break if page > 100
    end

    nil
  end

  private

  def make_request(uri, request)
    request['Authorization'] = "Bearer #{@api_key}"
    request['Accept'] = 'application/json'

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    response = http.request(request)

    case response.code.to_i
    when 200, 201
      JSON.parse(response.body)
    when 400
      error_body = begin
        JSON.parse(response.body)
      rescue StandardError
        response.body
      end
      raise "Bad Request (400): #{error_body}"
    when 401
      raise "Unauthorized (401): Invalid API key"
    when 403
      raise "Forbidden (403): Insufficient permissions"
    when 404
      raise "Not Found (404): Resource not found - #{uri}"
    when 422
      error_body = begin
        JSON.parse(response.body)
      rescue StandardError
        response.body
      end
      raise "Unprocessable Entity (422): #{error_body}"
    when 429
      raise "Rate Limited (429): Too many requests"
    else
      raise "HTTP Error #{response.code}: #{response.body}"
    end
  end
end

class ScheduleOverrideManager
  def initialize(client, dry_run: false)
    @client = client
    @dry_run = dry_run
  end

  def add_overrides_from_csv(schedule_id, csv_file)
    raise ArgumentError, "CSV file not found: #{csv_file}" unless File.exist?(csv_file)

    puts "Reading overrides from CSV file: #{csv_file}"

    overrides = []
    CSV.foreach(csv_file, headers: true) do |row|
      unless row['email'] && row['start_time'] && row['end_time']
        puts "Warning: Skipping row with missing data: #{row}"
        next
      end

      overrides << {
        email: row['email'].strip,
        start_time: row['start_time'].strip,
        end_time: row['end_time'].strip
      }
    end

    if overrides.empty?
      puts "No valid overrides found in CSV file"
      return []
    end

    puts "Found #{overrides.length} override(s) in CSV file"
    puts

    all_results = []

    overrides.each_with_index do |override, idx|
      puts "=" * 80
      puts "Processing override #{idx + 1} of #{overrides.length}"
      puts "=" * 80

      results = add_overrides_to_all_layers(
        schedule_id,
        override[:email],
        override[:start_time],
        override[:end_time]
      )

      all_results.concat(results)
      puts
    end

    print_csv_summary(overrides, all_results)
    all_results
  end

  def collect_and_print_schedule(schedule_id)
    puts "Fetching schedule details for: #{schedule_id}"
    schedule_response = @client.get_schedule(schedule_id)

    schedule = schedule_response['schedule']
    schedule_name = schedule['name'] || 'Unknown Schedule'
    puts "Schedule: #{schedule_name}"
    puts
    schedule
  end

  def collect_layers_from_rotations(rotations)
    all_layers = []
    rotations.each do |rotation|
      rotation_id = rotation['id']
      rotation_name = rotation['name'] || 'Unnamed Rotation'
      layers = rotation['layers'] || []

      layers.each do |layer|
        all_layers << {
          rotation_id: rotation_id,
          rotation_name: rotation_name,
          layer_id: layer['id'],
          layer_name: layer['name'] || 'Unnamed Layer'
        }
      end
    end

    if all_layers.empty?
      puts "No layers found in any rotation."
      return []
    end

    puts "Found #{all_layers.length} layer(s) across #{rotations.length} rotation(s)"
    puts
    all_layers
  end

  def add_overrides_to_all_layers(schedule_id, email, start_time, end_time)
    schedule = collect_and_print_schedule(schedule_id)

    rotations = schedule['config']['rotations']

    if rotations.empty?
      puts "No rotations found in this schedule."
      return []
    end

    # Collect all layers from all rotations
    all_layers = collect_layers_from_rotations(rotations)

    # Validate time range
    validate_time_range(start_time, end_time)

    results = []

    all_layers.each_with_index do |layer_info, index|
      rotation_id = layer_info[:rotation_id]
      rotation_name = layer_info[:rotation_name]
      layer_id = layer_info[:layer_id]
      layer_name = layer_info[:layer_name]

      puts "=" * 80
      puts "Layer #{index + 1}: #{rotation_name} - #{layer_name}"
      puts "  Rotation ID: #{rotation_id}"
      puts "  Layer ID: #{layer_id}"
      puts "  Override User: (#{email})"
      puts "  Start: #{start_time}"
      puts "  End: #{end_time}"

      if @dry_run
        puts "  [DRY RUN] Would create override"
        results << {
          rotation_id: rotation_id,
          layer_id: layer_id,
          layer_name: "#{rotation_name} - #{layer_name}",
          status: 'dry_run',
          message: 'Would create override'
        }
      else
        begin
          override = @client.create_override(schedule_id, rotation_id, layer_id, email, start_time, end_time)
          override_id = override[1]['id']
          puts "  ✓ Override created successfully (ID: #{override_id})"
          results << {
            rotation_id: rotation_id,
            layer_id: layer_id,
            layer_name: "#{rotation_name} - #{layer_name}",
            status: 'success',
            override_id: override_id
          }
        rescue StandardError => e
          puts "  ✗ Failed to create override: #{e.message}"
          results << {
            rotation_id: rotation_id,
            layer_id: layer_id,
            layer_name: "#{rotation_name} - #{layer_name}",
            status: 'error',
            error: e.message
          }
        end
      end

      puts
    end

    print_summary(results)
    results
  end

  private

  def validate_time_range(start_time, end_time)
    start_dt = Time.parse(start_time)
    end_dt = Time.parse(end_time)

    raise ArgumentError, "End time must be after start time" if end_dt <= start_dt

    puts "Warning: Start time is in the past" if start_dt < Time.now
  rescue ArgumentError => e
    raise ArgumentError, "Invalid time format: #{e.message}"
  end

  def print_summary(results)
    puts "=" * 80
    puts "SUMMARY"
    puts "=" * 80

    success_count = results.count { |r| r[:status] == 'success' }
    error_count = results.count { |r| r[:status] == 'error' }
    dry_run_count = results.count { |r| r[:status] == 'dry_run' }

    puts "Total layers: #{results.length}"
    puts "Successful: #{success_count}" if success_count > 0
    puts "Failed: #{error_count}" if error_count > 0
    puts "Dry run: #{dry_run_count}" if dry_run_count > 0
    puts

    return unless error_count > 0

    puts "Failed layers:"
    results.select { |r| r[:status] == 'error' }.each do |result|
      puts "  - #{result[:layer_name]}: #{result[:error]}"
    end
    puts
  end

  def print_csv_summary(overrides, all_results)
    puts "=" * 80
    puts "CSV PROCESSING SUMMARY"
    puts "=" * 80

    success_count = all_results.count { |r| r[:status] == 'success' }
    error_count = all_results.count { |r| r[:status] == 'error' }
    dry_run_count = all_results.count { |r| r[:status] == 'dry_run' }

    puts "Total overrides processed: #{overrides.length}"
    puts "Total layer overrides created: #{all_results.length}"
    puts "Successful: #{success_count}" if success_count > 0
    puts "Failed: #{error_count}" if error_count > 0
    puts "Dry run: #{dry_run_count}" if dry_run_count > 0
    puts
  end
end

# Parse command line arguments
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

  opts.on('--schedule-id ID', 'Schedule ID (required)') do |v|
    options[:schedule_id] = v
  end

  opts.on('--email EMAIL', 'User email address to assign override to (required for single override)') do |v|
    options[:email] = v
  end

  opts.on('--start TIME', 'Override start time in ISO 8601 format (required for single override)') do |v|
    options[:start_time] = v
  end

  opts.on('--end TIME', 'Override end time in ISO 8601 format (required for single override)') do |v|
    options[:end_time] = v
  end

  opts.on('--csv-file FILE', 'CSV file with email,start_time,end_time columns') do |v|
    options[:csv_file] = v
  end

  opts.on('--api-key KEY', 'incident.io API key (or use INCIDENT_API_KEY env var)') do |v|
    options[:api_key] = v
  end

  opts.on('--dry-run', 'Show what would be done without making changes') do
    options[:dry_run] = true
  end

  opts.on('-h', '--help', 'Show this help message') do
    puts opts
    exit
  end
end.parse!

# Validate required arguments
if options[:schedule_id].nil?
  puts "Error: --schedule-id is required"
  puts "Run with --help for usage information"
  exit 1
end

# Check if using CSV mode or single override mode
using_csv = !options[:csv_file].nil?
using_single = !options[:email].nil? || !options[:start_time].nil? || !options[:end_time].nil?

if using_csv && using_single
  puts "Error: Cannot use both CSV file and single override options together"
  puts "Use either --csv-file OR (--email, --start, --end)"
  exit 1
end

if !using_csv && !using_single
  puts "Error: Must provide either --csv-file OR (--email, --start, --end)"
  puts "Run with --help for usage information"
  exit 1
end

if using_single
  required_args = [:email, :start_time, :end_time]
  missing_args = required_args.select { |arg| options[arg].nil? }

  if missing_args.any?
    puts "Error: Missing required arguments for single override: #{missing_args.join(', ')}"
    puts "Run with --help for usage information"
    exit 1
  end
end

# Get API key from options or environment
api_key = options[:api_key] || ENV['INCIDENT_API_KEY']

if api_key.nil? || api_key.empty?
  puts "Error: API key is required. Provide via --api-key or INCIDENT_API_KEY environment variable"
  exit 1
end

# Run the script
begin
  client = IncidentIOClient.new(api_key)
  manager = ScheduleOverrideManager.new(client, dry_run: options[:dry_run])

  if options[:csv_file]
    # CSV mode - process multiple overrides
    manager.add_overrides_from_csv(
      options[:schedule_id],
      options[:csv_file]
    )
  else
    # Single override mode
    manager.add_overrides_to_all_layers(
      options[:schedule_id],
      options[:email],
      options[:start_time],
      options[:end_time]
    )
  end
rescue StandardError => e
  puts "Error: #{e.message}"
  puts e.backtrace if ENV['DEBUG']
  exit 1
end
