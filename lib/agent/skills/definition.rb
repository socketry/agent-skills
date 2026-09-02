# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025-2026, by Samuel Williams.

module Agent
	module Skills
		# A validated skill discovered in a provider gem.
		class Definition
			# Initialize a skill definition.
			#
			# @parameter name [String] The declared skill name.
			# @parameter description [String] A short description used for skill discovery.
			# @parameter path [String] The source directory containing `SKILL.md`.
			# @parameter provider_name [String] The source gem name.
			# @parameter provider_version [String] The source gem version.
			def initialize(name:, description:, path:, provider_name:, provider_version:)
				@name = name
				@description = description
				@path = path
				@provider_name = provider_name
				@provider_version = provider_version
			end
			
			attr_reader :name
			attr_reader :description
			attr_reader :path
			attr_reader :provider_name
			attr_reader :provider_version
			
			# The path to the skill's required instruction file.
			def skill_file
				File.join(@path, "SKILL.md")
			end
		end
	end
end
