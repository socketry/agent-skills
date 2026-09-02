# frozen_string_literal: true

require_relative "lib/agent/skills/version"

Gem::Specification.new do |spec|
	spec.name = "agent-skills"
	spec.version = Agent::Skills::VERSION
	
	spec.summary = "Install and manage agent skills from Ruby gems."
	spec.authors = ["Samuel Williams", "Shopify Inc."]
	spec.license = "MIT"
	
	release_certificate = File.expand_path("release.cert", __dir__)
	release_key = File.expand_path("~/.gem/release.pem")
	if File.exist?(release_certificate) && File.exist?(release_key)
		spec.cert_chain = [release_certificate]
		spec.signing_key = release_key
	end
	
	spec.homepage = "https://github.com/socketry/agent-skills"
	
	spec.metadata = {
		"documentation_uri" => "https://socketry.github.io/agent-skills/",
		"funding_uri" => "https://github.com/sponsors/ioquatix/",
		"source_code_uri" => "https://github.com/socketry/agent-skills.git",
	}
	
	spec.files = Dir.glob(["{bake,context,lib}/**/*", "*.md"], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.2"
	
	spec.add_dependency "bake", ">= 0.23"
end
