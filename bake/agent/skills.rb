# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025-2026, by Samuel Williams.

require_relative "../../lib/agent/skills/installer"

include Agent::Skills

def initialize(context)
	super(context)
	
	@installer = Installer.new(root: context.root)
end

attr :installer

# List gems and the skills they provide.
# @parameter gem [String] Optional gem name to inspect.
def list(gem: nil)
	if gem
		skills = @installer.list_skills(gem)
		if skills
			puts "Skills provided by gem '#{gem}':"
			skills.each do |skill|
				puts "  #{skill.name} - #{skill.description}"
			end
		else
			puts "No skills found for gem '#{gem}'"
		end
	else
		gems = @installer.find_gems_with_skills
		if gems.any?
			puts "Gems with skills available:"
			gems.each do |gem_information|
				names = gem_information[:skills].map(&:name).join(", ")
				puts "  #{gem_information[:name]} (#{gem_information[:version]}): #{names}"
			end
		else
			puts "No gems with skills found"
		end
	end
end

# Show the `SKILL.md` content for a provided skill.
# @parameter gem [String] The provider gem name.
# @parameter skill [String] The skill name.
def show(gem:, skill:)
	content = @installer.show_skill(gem, skill)
	if content
		puts content
	else
		puts "Skill '#{skill}' not found in gem '#{gem}'"
	end
end

# Install skills from gems into `.agents/skills`.
# @parameter gem [String] Optional gem name to install from.
def install(gem: nil)
	if gem
		installed = @installer.install_gem_skills(gem)
		if installed
			puts "Installed #{installed.length} skills from gem '#{gem}':"
			installed.each {|skill_name| puts "  #{skill_name}"}
		else
			puts "No skills found for gem '#{gem}'"
		end
	else
		installed = @installer.install_all_skills
		if installed.any?
			puts "Installed #{installed.length} skills:"
			installed.each {|skill_name| puts "  #{skill_name}"}
		else
			puts "No gems with skills found"
		end
	end
end
