# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025-2026, by Samuel Williams.

require "fileutils"
require "yaml"

module Agent
	module Skills
		# Tracks which installed skills are owned by which gems.
		class Registry
			FILE_NAME = ".agent-skills.yaml"
			FORMAT_VERSION = 1
			NAME_PATTERN = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
			
			# Raised when the registry cannot be safely interpreted.
			class Invalid < StandardError
			end
			
			# Initialize a registry stored at the given path.
			#
			# @parameter path [String] The registry file path.
			def initialize(path)
				@path = path
				@data = load_data
			end
			
			attr_reader :path
			
			# Get ownership metadata for a skill.
			#
			# @parameter skill_name [String] The installed skill name.
			def owner(skill_name)
				@data["skills"][skill_name]
			end
			
			# Get all skills owned by a gem.
			#
			# @parameter gem_name [String] The provider gem name.
			def skills_for(gem_name)
				@data["skills"].select do |_skill_name, owner|
					owner["gem"] == gem_name
				end
			end
			
			# Record ownership of an installed skill.
			#
			# @parameter skill_name [String] The installed skill name.
			# @parameter gem_name [String] The provider gem name.
			# @parameter gem_version [String] The provider gem version.
			def claim(skill_name, gem_name, gem_version)
				@data["skills"][skill_name] = {
					"gem" => gem_name,
					"version" => gem_version,
				}
			end
			
			# Remove ownership information for a skill.
			#
			# @parameter skill_name [String] The installed skill name.
			def release(skill_name)
				@data["skills"].delete(skill_name)
			end
			
			# Persist the registry atomically.
			def save
				FileUtils.mkdir_p(File.dirname(@path))
				
				content = {
					"version" => FORMAT_VERSION,
					"skills" => @data["skills"].sort.to_h,
				}.to_yaml
				
				temporary_path = "#{@path}.#{Process.pid}.tmp"
				File.write(temporary_path, content)
				File.rename(temporary_path, @path)
			ensure
				FileUtils.rm_f(temporary_path) if temporary_path
			end
			
			private
			
			def load_data
				return default_data unless File.exist?(@path)
				
				data = YAML.safe_load(File.read(@path), aliases: false)
				validate_data(data)
				data
			rescue Psych::Exception => error
				raise Invalid, "Could not load skill registry #{@path}: #{error.message}"
			end
			
			def validate_data(data)
				unless data.is_a?(Hash) && data["version"] == FORMAT_VERSION && data["skills"].is_a?(Hash)
					raise Invalid, "Invalid skill registry format: #{@path}"
				end
				
				data["skills"].each do |skill_name, owner|
					unless skill_name.is_a?(String) && skill_name.match?(NAME_PATTERN)
						raise Invalid, "Invalid skill name in registry: #{skill_name.inspect}"
					end
					
					unless owner.is_a?(Hash) && owner["gem"].is_a?(String) && owner["version"].is_a?(String)
						raise Invalid, "Invalid owner for skill #{skill_name.inspect}"
					end
				end
			end
			
			def default_data
				{
					"version" => FORMAT_VERSION,
					"skills" => {},
				}
			end
		end
	end
end
