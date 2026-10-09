# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.

require "fileutils"
require "rubygems"
require "yaml"

require_relative "definition"
require_relative "registry"

module Agent
	module Skills
		# Discovers and installs skills provided by Ruby gems.
		class Installer
			NAME_PATTERN = Registry::NAME_PATTERN
			MAXIMUM_NAME_LENGTH = 100
			MAXIMUM_DESCRIPTION_LENGTH = 500
			
			# Base error for skill discovery and installation failures.
			class Error < StandardError
			end
			
			# Raised when a provider contains an invalid skill.
			class InvalidSkill < Error
			end
			
			# Raised when a skill would overwrite content owned by another source.
			class Conflict < Error
			end
			
			# Initialize a skill installer.
			#
			# @parameter root [String] The consuming project root.
			# @parameter specifications [Gem::Specification] The gem specifications to scan.
			def initialize(root: Dir.pwd, specifications: ::Gem::Specification)
				@root = File.expand_path(root)
				@skills_path = File.join(@root, ".agents", "skills")
				@specifications = specifications
			end
			
			attr_reader :root
			attr_reader :skills_path
			
			# Find installed gems which provide one or more valid skills.
			#
			# @parameter skip_local [Boolean] Whether to skip a gem loaded from the consuming project root.
			def find_gems_with_skills(skip_local: true)
				@specifications.filter_map do |specification|
					next if skip_local && same_path?(specification.full_gem_path, @root)
					
					build_gem_information(specification)
				end
			end
			
			# Find a named gem which provides skills.
			#
			# @parameter gem_name [String] The gem name to find.
			def find_gem_with_skills(gem_name)
				specification = @specifications.find{|candidate| candidate.name == gem_name}
				return unless specification
				
				build_gem_information(specification)
			end
			
			# List skills provided by a named gem.
			#
			# @parameter gem_name [String] The gem name.
			def list_skills(gem_name)
				gem = find_gem_with_skills(gem_name)
				gem && gem[:skills]
			end
			
			# Read the instruction file for a skill provided by a gem.
			#
			# @parameter gem_name [String] The provider gem name.
			# @parameter skill_name [String] The declared skill name.
			def show_skill(gem_name, skill_name)
				skills = list_skills(gem_name)
				return unless skills
				
				definition = skills.find{|skill| skill.name == skill_name}
				File.read(definition.skill_file) if definition
			end
			
			# Install all skills provided by a named gem.
			#
			# @parameter gem_name [String] The provider gem name.
			# @returns [Array(String), nil] Installed skill names, or `nil` if the gem provides no skills.
			def install_gem_skills(gem_name)
				gem = find_gem_with_skills(gem_name)
				return unless gem
				
				install_gems([gem])
			end
			
			# Install skills from every discovered gem.
			#
			# @parameter skip_local [Boolean] Whether to skip a gem loaded from the consuming project root.
			# @returns [Array(String)] Installed skill names.
			def install_all_skills(skip_local: true)
				install_gems(find_gems_with_skills(skip_local: skip_local))
			end
			
			private
			
			def build_gem_information(specification)
				source_path = File.join(specification.full_gem_path, "skills")
				return unless Dir.exist?(source_path)
				
				skills = discover_skills(source_path, specification.name, specification.version.to_s)
				return if skills.empty?
				
				{
					name: specification.name,
					version: specification.version.to_s,
					summary: specification.summary,
					metadata: specification.metadata,
					path: source_path,
					skills: skills,
				}
			end
			
			def discover_skills(source_path, provider_name, provider_version)
				Dir.children(source_path).sort.filter_map do |entry|
					skill_path = File.join(source_path, entry)
					next unless File.directory?(skill_path)
					
					skill_file = File.join(skill_path, "SKILL.md")
					next unless File.file?(skill_file)
					
					metadata = load_skill_metadata(skill_file)
					validate_skill_metadata(metadata, entry, skill_file)
					
					Definition.new(
						name: metadata["name"],
						description: metadata["description"],
						path: skill_path,
						provider_name: provider_name,
						provider_version: provider_version,
					)
				end
			end
			
			def load_skill_metadata(skill_file)
				content = File.read(skill_file)
				match = content.match(/\A---\s*\n(.*?)\n---\s*(?:\n|\z)/m)
				
				unless match
					raise InvalidSkill, "Skill must begin with YAML frontmatter: #{skill_file}"
				end
				
				metadata = YAML.safe_load(match[1], aliases: false)
				unless metadata.is_a?(Hash)
					raise InvalidSkill, "Skill frontmatter must be a mapping: #{skill_file}"
				end
				
				metadata
			rescue Psych::Exception => error
				raise InvalidSkill, "Invalid skill frontmatter in #{skill_file}: #{error.message}"
			end
			
			def validate_skill_metadata(metadata, directory_name, skill_file)
				name = metadata["name"]
				description = metadata["description"]
				
				unless name.is_a?(String) && name.match?(NAME_PATTERN) && name.length <= MAXIMUM_NAME_LENGTH
					raise InvalidSkill, "Invalid skill name in #{skill_file}: #{name.inspect}"
				end
				
				unless name == directory_name
					raise InvalidSkill, "Skill name #{name.inspect} must match its directory #{directory_name.inspect}"
				end
				
				unless description.is_a?(String) && !description.strip.empty? && description.length <= MAXIMUM_DESCRIPTION_LENGTH
					raise InvalidSkill, "Invalid skill description in #{skill_file}"
				end
			end
			
			def install_gems(gems)
				definitions = gems.flat_map{|gem| gem[:skills]}
				return [] if definitions.empty?
				
				validate_unique_skills(definitions)
				
				registry = Registry.new(File.join(@skills_path, Registry::FILE_NAME))
				definitions.each{|definition| validate_destination(definition, registry)}
				
				stale_skills = gems.flat_map do |gem|
					current_names = gem[:skills].map(&:name)
					registry.skills_for(gem[:name]).keys - current_names
				end
				
				definitions.each do |definition|
					registry.claim(definition.name, definition.provider_name, definition.provider_version)
				end
				stale_skills.each{|skill_name| registry.release(skill_name)}
				registry.save
				
				definitions.each{|definition| copy_skill(definition)}
				stale_skills.each{|skill_name| remove_skill(skill_name)}
				
				definitions.map(&:name)
			end
			
			def validate_unique_skills(definitions)
				duplicates = definitions.group_by(&:name).select{|_name, matches| matches.length > 1}
				return if duplicates.empty?
				
				details = duplicates.map do |name, matches|
					providers = matches.map(&:provider_name).uniq.join(", ")
					"#{name} (#{providers})"
				end
				
				raise Conflict, "Multiple gems provide the same skill: #{details.join('; ')}"
			end
			
			def validate_destination(definition, registry)
				destination = File.join(@skills_path, definition.name)
				owner = registry.owner(definition.name)
				
				if owner && owner["gem"] != definition.provider_name
					raise Conflict, "Skill #{definition.name.inspect} is owned by gem #{owner['gem'].inspect}"
				end
				
				if path_exists?(destination) && !owner
					raise Conflict, "Skill #{definition.name.inspect} already exists and is not managed by agent-skills"
				end
			end
			
			def copy_skill(definition)
				FileUtils.mkdir_p(@skills_path)
				destination = File.join(@skills_path, definition.name)
				FileUtils.rm_rf(destination) if path_exists?(destination)
				FileUtils.cp_r(definition.path, destination, preserve: true)
			end
			
			def remove_skill(skill_name)
				destination = File.join(@skills_path, skill_name)
				FileUtils.rm_rf(destination) if path_exists?(destination)
			end
			
			def path_exists?(path)
				File.exist?(path) || File.symlink?(path)
			end
			
			def same_path?(left, right)
				File.expand_path(left) == File.expand_path(right)
			end
		end
	end
end
