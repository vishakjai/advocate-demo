#!/usr/bin/env ruby
# frozen_string_literal: true

require 'erb'
require 'optimist'
require 'git'
require 'json'
require 'mixlib/shellout'
require 'google/cloud/compute/v1'

opts = Optimist.options do
  opt :environment, "Environment to perform on", type: :string
  opt :zone, "Zone to replace", type: :string
  opt :branch, "Branch name for changes", type: :string, default: "gstg-gitaly-zonal-outage-recovery-#{Time.now.strftime('%F')}"
  opt :commit, "Commit changes?", type: :bool, default: false
  opt :push, "Push Git changes?", type: :bool, default: false
  opt :app_config, "Update application configs pointing to these nodes?", type: :bool, default: false
  opt :all_zones, "Comma seperated list of all zones", type: :string, default: 'us-east1-b,us-east1-c,us-east1-d'
  opt :chef_repo_repo, "Git checkout URL for chef-repo", type: :string, default: 'git@gitlab.com:gitlab-com/gl-infra/chef-repo.git'
  opt :config_mgmt_repo, "Git checkout URL for config-mgmt repo", type: :string, default: 'git@ops.gitlab.net:gitlab-com/gl-infra/config-mgmt.git'
  opt :gitlab_com_repo, "Get checkout URL for k8s-workloads/gitlab-com repo", type: :string, default: 'git@gitlab.com:gitlab-com/gl-infra/k8s-workloads/gitlab-com.git'
  opt :working_dir, "Working directory to checkout repositories", type: :string, default: '/tmp/'
  opt :dr_restore, "Push config-mgmt changes to the dr-testing environment instead of the active env", type: :bool, default: false
  opt :os_snapshot_host_identifier, 'The Gitaly node to use OS disk snapshots from. This is the short name as written in the Terraform configs.', type: :string, default: 'gitaly-01'
  opt :node_to_replace, 'Set this flag to move a single node. It must be in the zone specified by --zone.', type: :string
end

module DisasterRecoveryHelper
  class GoogleClient
    def initialize(env)
      @environment = env
      @projects = all_projects
    end

    def instances_client
      @client ||= Google::Cloud::Compute::V1::Instances::Rest::Client.new

      @client
    end

    attr_reader :projects

    private

    # TODO swap these shellouts out with ruby client calls.
    def all_projects
      gcloud_command = "gcloud projects list --filter \"name=.*gitlab.*\" --filter=\"labels.environment=#{@environment}\" --format=\"json(projectId, labels)\""
      command = Mixlib::ShellOut.new(gcloud_command).run_command
      command.error!

      results = JSON.parse(command.stdout).reject { |p| p['labels'].nil? }

      if results.empty?
        # Our query for gitaly projects was empty... permission error is likely. Lets take a guess.
        likely_gitaly_projects
      else
        results
      end
    end

    def likely_gitaly_projects
      project_ids = {
        'gstg' => %w[164c 380a],
        'gprd' => %w[0fe1 256e 2e35 5a25 6688 7ebd 83fd 87a9 93cb a606 ccb0 cdaf d1a2 e493 f33d]
      }

      project_list = []
      project_ids[@environment].map do |id|
        project_list << { 'projectId' => "gitlab-gitaly-#{@environment}-#{id}" }
      end

      project_list
    end
  end

  class GitalyConfig
    TEMPLATE = 'templates/gitaly-recovery-nodes.tf.erb'
    OUTFILE_NAME = 'gitaly-recovery-nodes.tf'

    def initialize(repo, env, node_map, dr_restore)
      @template = ERB.new(File.read(TEMPLATE))
      @repo = repo
      @env = env
      @node_map = node_map
      @dr_restore = dr_restore
    end

    def render_template
      @template.result(binding)
    end

    def write_template_file
      Dir.chdir("#{@repo}/#{relative_output_path}") do
        new_file = File.open(OUTFILE_NAME, 'w')
        new_file.write(render_template)
        new_file.close

        `terraform fmt`

        break new_file.path
      end
    end

    def relative_output_path
      env = @dr_restore ? 'dr-restore' : @env
      map = {
        'gstg' => 'environments/gitaly-gstg',
        'gprd' => 'environments/gitaly-gprd',
        'dr-restore' => 'environments/dr-testing'
      }

      raise StandardError, 'Unknown gitaly config environment path' unless map[env]

      map[env]
    end
  end

  class ConfigUpdate
    def initialize(path)
      @glob = path
      @repository_updates = {}
      @protected_strings = [' name: ', ' "name": ', ': {', '"path":']
    end

    def set_path(path)
      @glob = path
    end

    def find_and_replace_string(existing, new)
      matching_files.each do |file|
        content = File.read(file)
        new_content = replace_lines(content, existing, new)
        next unless content != new_content

        File.open(file, 'w') { |f| f.write new_content }

        repo = git_repo(file)
        @repository_updates[repo] ||= []
        @repository_updates[repo] << file unless @repository_updates[repo].include? file
      end
    end

    attr_reader :repository_updates

    private

    def replace_lines(content, existing, new)
      new_content = []
      content.each_line do |line|
        skipped = false
        @protected_strings.each do |ps|
          next unless line.include? ps

          skipped = true
          new_content << line
          break
        end
        new_content << line.gsub(existing, new) unless skipped
      end

      new_content.join('')
    end

    def git_repo(file)
      directory = File.dirname(file)
      repo = nil
      Dir.chdir(directory) do
        repo = `git rev-parse --show-toplevel`.strip

        raise StandardError, 'Not a git repository....' if repo.nil?
      end

      repo
    end

    def matching_files
      Dir[@glob]
    end
  end

  class GitalyNodeReplacements
    def initialize(environment, all_zones, zone, dr_restore, os_snapshot_host_identifier, node_to_replace = nil)
      @environment = environment
      @google_client = DisasterRecoveryHelper::GoogleClient.new(@environment)
      @zones = all_zones.strip.split(',')
      @zone_to_replace = zone
      @surviving_zones = @zones.reject { |z| z == @zone_to_replace }
      @projects = find_projects
      @single_node_to_replace = node_to_replace
      @all_nodes = get_all_nodes
      @nodes_to_replace = find_nodes_to_replace
      @dr_restore = dr_restore
      @os_snapshot_host_identifier = os_snapshot_host_identifier
    end

    def find_projects
      projects = []
      @google_client.projects.each do |project|
        projects << project['projectId']
      end

      projects
    end

    def replacement_map
      @replacement_map ||= generate_replacement_map
      @replacement_map
    end

    private

    def find_nodes_to_replace
      nodes = []
      @all_nodes.map do |_z, a|
        nodes += a.select do |n|
          if n.zone =~ /#{@zone_to_replace}/
            if @single_node_to_replace
              true if n.name == @single_node_to_replace
            else
              true
            end
          end
        end
      end

      nodes.flatten
    end

    def generate_replacement_map
      map = {}
      deletion_protection = @environment == 'gprd'
      @nodes_to_replace.each do |node|
        map[node_id(node.name)] = { 'name' => new_node_id(node.name),
                                    'zone' => choose_zone,
                                    'environment' => @environment,
                                    'deletion_protection' => deletion_protection,
                                    'dr_restore' => @dr_restore,
                                    'os_snapshot_host_identifier' => @os_snapshot_host_identifier }

        map[node_id(node.name)]['snapshot_project'] = @projects.first if @dr_restore
      end

      map
    end

    def choose_zone
      if @allocated_zone_counts.nil?
        @allocated_zone_counts = {}
        @surviving_zones.each do |z|
          @allocated_zone_counts[z] = @all_nodes[z].length || 0
        end
      end

      selected_zone = @allocated_zone_counts.sort_by { |_zone, count| count }.to_h.keys.first
      @allocated_zone_counts[selected_zone] += 1

      selected_zone
    end

    def node_id(node)
      name_parts = node.split('-')

      "#{name_parts[0]}-#{name_parts[1]}"
    end

    def new_node_id(node)
      name_parts = node.split('-')
      # if we already have a letter ID, increment that instead of appending one.
      if match = name_parts[1].match(/([0-9]+)([a-z])$/i)
        return "#{name_parts[0]}-#{match.captures[0]}#{match.captures[1].next}"
      end

      "#{name_parts[0]}-#{name_parts[1]}a"
    end

    def get_all_nodes
      client = @google_client.instances_client
      gitaly_nodes = {}
      @projects.each do |project|
        @zones.each do |zone|
          gitaly_nodes[zone] ||= []

          nodes = client.list(zone:, project:)
          gitaly_nodes[zone] += nodes.select do |node|
            node.labels['type'] == 'gitaly' && gitaly_nodes[zone].select do |gn|
              gn.name == node.name
            end.empty?
          end
        end
      end

      gitaly_nodes
    end
  end

  class GitRepos
    def initialize(working_dir, repos, branch = nil)
      @working_dir = working_dir
      @repo_map = repos
      @branch = branch
      perform_checkouts
    end

    attr_reader :repo_map

    def commit(message)
      @repo_map.each_key do |path|
        repo = Git.open("#{@working_dir}/#{path}")

        repo.add(all: true)
        repo.commit_all(message)
      end
    end

    def push
      @repo_map.each_key do |path|
        repo = Git.open("#{@working_dir}/#{path}")

        repo.push(repo.remote('origin'), @branch)
      end
    end

    private

    def perform_checkouts
      @repo_map.each do |path, url|
        clone_dir = "#{@working_dir}/#{path}"
        next if Dir.exist?(clone_dir) && Dir.exist?(File.join(clone_dir, '.git'))

        repo = Git.clone(url, clone_dir)
        repo.branch(@branch).checkout if @branch
      end
    end
  end
end

repo_map = {
  'config-mgmt' => opts[:config_mgmt_repo]
}

if opts[:app_config]
  repo_map['gitlab-com'] = opts[:gitlab_com_repo]
  repo_map['chef-repo'] = opts[:chef_repo_repo]
end

working_dir = opts[:working_dir]
environment = opts[:environment]
all_zones = opts[:all_zones]
zone = opts[:zone]
branch = opts[:branch]

repos = DisasterRecoveryHelper::GitRepos.new(working_dir, repo_map, branch)

gitaly = DisasterRecoveryHelper::GitalyNodeReplacements.new(environment, all_zones, zone, opts[:dr_restore], opts[:os_snapshot_host_identifier], opts[:node_to_replace])
replacements = gitaly.replacement_map

gitaly_terraform = DisasterRecoveryHelper::GitalyConfig.new("#{working_dir}/config-mgmt", environment, replacements, opts[:dr_restore])
puts gitaly_terraform.render_template
gitaly_terraform.write_template_file
app_config = DisasterRecoveryHelper::ConfigUpdate.new("#{working_dir}/#{gitaly_terraform.relative_output_path}/*#{environment}*.tf*")
app_config.find_and_replace_string('DONOTEDIT', '')

if opts[:app_config]
  app_config.set_path("#{working_dir}/gitlab-com/**/*#{environment}*.yaml*")
  replacements.each do |existing, replacement|
    app_config.find_and_replace_string("#{existing}-", "#{replacement['name']}-")
  end

  app_config.set_path("#{working_dir}/chef-repo/roles/*#{environment}*.json")

  replacements.each do |existing, replacement|
    app_config.find_and_replace_string("#{existing}-", "#{replacement['name']}-")
  end
end

puts app_config.repository_updates

if opts[:commit] || opts[:push]
  repos.commit("[#{environment}] restoring Gitaly nodes from zone #{zone}")
  repos.push if opts[:push]
end
