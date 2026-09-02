# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025-2026, by Samuel Williams.

require "agent/skills/registry"
require "tmpdir"

describe Agent::Skills::Registry do
	let(:temporary_directory) {Dir.mktmpdir}
	let(:registry_path) {File.join(temporary_directory, ".agent-skills.yaml")}
	
	def around
		yield
	ensure
		FileUtils.rm_rf(temporary_directory)
	end
	
	it "records and reloads skill ownership" do
		registry = subject.new(registry_path)
		registry.claim("ruby-testing", "sus", "1.0.0")
		registry.save
		
		reloaded = subject.new(registry_path)
		expect(reloaded.owner("ruby-testing")).to be == {
			"gem" => "sus",
			"version" => "1.0.0",
		}
	end
	
	it "lists skills owned by a gem" do
		registry = subject.new(registry_path)
		registry.claim("ruby-testing", "sus", "1.0.0")
		registry.claim("http-server", "falcon", "2.0.0")
		
		expect(registry.skills_for("sus").keys).to be == ["ruby-testing"]
	end
	
	it "releases ownership" do
		registry = subject.new(registry_path)
		registry.claim("ruby-testing", "sus", "1.0.0")
		registry.release("ruby-testing")
		
		expect(registry.owner("ruby-testing")).to be_nil
	end
	
	it "rejects an invalid registry" do
		File.write(registry_path, {"version" => 99, "skills" => {}}.to_yaml)
		
		expect do
			subject.new(registry_path)
		end.to raise_exception(Agent::Skills::Registry::Invalid)
	end
end
