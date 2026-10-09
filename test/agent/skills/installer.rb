# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.

require "agent/skills/installer"
require "tmpdir"

describe Agent::Skills::Installer do
	let(:consumer_root) {Dir.mktmpdir}
	let(:provider_root) {Dir.mktmpdir}
	let(:specifications) {[build_specification("fake-gem", "1.0.0", provider_root)]}
	let(:installer) {subject.new(root: consumer_root, specifications: specifications)}
	
	def around
		write_skill(provider_root, "ruby-testing", description: "Test Ruby projects with Sus.")
		yield
	ensure
		FileUtils.rm_rf(consumer_root)
		FileUtils.rm_rf(provider_root)
	end
	
	def build_specification(name, version, root)
		specification = Gem::Specification.new do |spec|
			spec.name = name
			spec.version = version
			spec.summary = "A gem providing agent skills."
		end
		specification.instance_variable_set(:@full_gem_path, root)
		specification
	end
	
	def write_skill(root, name, description:, directory_name: name, body: "# Instructions\n\nFollow these instructions.\n")
		directory = File.join(root, "skills", directory_name)
		FileUtils.mkdir_p(directory)
		File.write(File.join(directory, "SKILL.md"), <<~MARKDOWN)
			---
			name: #{name}
			description: #{description}
			---
			
			#{body}
		MARKDOWN
		directory
	end
	
	it "finds gems which provide skills" do
		gems = installer.find_gems_with_skills
		
		expect(gems.length).to be == 1
		expect(gems.first[:name]).to be == "fake-gem"
		expect(gems.first[:skills].map(&:name)).to be == ["ruby-testing"]
	end
	
	it "lists skills provided by a gem" do
		skills = installer.list_skills("fake-gem")
		
		expect(skills.length).to be == 1
		expect(skills.first).to have_attributes(
			name: be == "ruby-testing",
			description: be == "Test Ruby projects with Sus."
		)
	end
	
	it "shows a skill instruction file" do
		content = installer.show_skill("fake-gem", "ruby-testing")
		
		expect(content).to be(:include?, "name: ruby-testing")
		expect(content).to be(:include?, "# Instructions")
	end
	
	it "returns nil for a gem without skills" do
		expect(installer.find_gem_with_skills("missing-gem")).to be_nil
		expect(installer.install_gem_skills("missing-gem")).to be_nil
	end
	
	it "ignores directories which do not contain SKILL.md" do
		FileUtils.mkdir_p(File.join(provider_root, "skills", "notes"))
		
		expect(installer.list_skills("fake-gem").map(&:name)).to be == ["ruby-testing"]
	end
	
	it "skips a gem loaded from the consuming project by default" do
		write_skill(consumer_root, "local-development", description: "Develop the local gem.")
		local_specification = build_specification("local-gem", "1.0.0", consumer_root)
		local_installer = subject.new(root: consumer_root, specifications: [local_specification])
		
		expect(local_installer.find_gems_with_skills).to be == []
		expect(local_installer.find_gems_with_skills(skip_local: false).map{|gem| gem[:name]}).to be == ["local-gem"]
	end
	
	with "installation" do
		it "installs skills relative to the consuming project root" do
			installed = installer.install_gem_skills("fake-gem")
			destination = File.join(consumer_root, ".agents", "skills", "ruby-testing")
			
			expect(installed).to be == ["ruby-testing"]
			expect(File).to be(:exist?, File.join(destination, "SKILL.md"))
		end
		
		it "records ownership in the registry" do
			installer.install_gem_skills("fake-gem")
			registry_path = File.join(consumer_root, ".agents", "skills", ".agent-skills.yaml")
			registry = Agent::Skills::Registry.new(registry_path)
			
			expect(registry.owner("ruby-testing")).to be == {
				"gem" => "fake-gem",
				"version" => "1.0.0",
			}
		end
		
		it "updates a skill owned by the same gem" do
			installer.install_gem_skills("fake-gem")
			write_skill(provider_root, "ruby-testing", description: "Updated description.", body: "# Updated\n")
			installer.install_gem_skills("fake-gem")
			
			content = File.read(File.join(consumer_root, ".agents", "skills", "ruby-testing", "SKILL.md"))
			expect(content).to be(:include?, "# Updated")
		end
		
		it "removes skills no longer provided by the same gem" do
			write_skill(provider_root, "documentation", description: "Write documentation.")
			installer.install_gem_skills("fake-gem")
			FileUtils.rm_rf(File.join(provider_root, "skills", "documentation"))
			installer.install_gem_skills("fake-gem")
			
			expect(File).not.to be(:exist?, File.join(consumer_root, ".agents", "skills", "documentation"))
		end
		
		it "refuses to overwrite an unmanaged skill" do
			destination = File.join(consumer_root, ".agents", "skills", "ruby-testing")
			FileUtils.mkdir_p(destination)
			File.write(File.join(destination, "SKILL.md"), "project-owned")
			
			expect do
				installer.install_gem_skills("fake-gem")
			end.to raise_exception(Agent::Skills::Installer::Conflict)
			
			expect(File.read(File.join(destination, "SKILL.md"))).to be == "project-owned"
		end
		
		it "refuses duplicate skill names from different gems before installation" do
			second_root = Dir.mktmpdir
			write_skill(second_root, "ruby-testing", description: "Another implementation.")
			duplicate_specifications = specifications + [build_specification("other-gem", "1.0.0", second_root)]
			duplicate_installer = subject.new(root: consumer_root, specifications: duplicate_specifications)
			
			expect do
				duplicate_installer.install_all_skills
			end.to raise_exception(Agent::Skills::Installer::Conflict)
			
			expect(File).not.to be(:exist?, File.join(consumer_root, ".agents", "skills", "ruby-testing"))
		ensure
			FileUtils.rm_rf(second_root) if second_root
		end
		
		it "installs uniquely named skills from multiple gems" do
			second_root = Dir.mktmpdir
			write_skill(second_root, "documentation", description: "Write project documentation.")
			all_specifications = specifications + [build_specification("other-gem", "2.0.0", second_root)]
			all_installer = subject.new(root: consumer_root, specifications: all_specifications)
			
			expect(all_installer.install_all_skills.sort).to be == ["documentation", "ruby-testing"]
			expect(File).to be(:exist?, File.join(consumer_root, ".agents", "skills", "documentation", "SKILL.md"))
		ensure
			FileUtils.rm_rf(second_root) if second_root
		end
	end
	
	with "validation" do
		it "requires the declared name to match the directory" do
			FileUtils.rm_rf(File.join(provider_root, "skills", "ruby-testing"))
			write_skill(provider_root, "different-name", directory_name: "ruby-testing", description: "Invalid skill.")
			
			expect do
				installer.find_gems_with_skills
			end.to raise_exception(Agent::Skills::Installer::InvalidSkill)
		end
		
		it "requires YAML frontmatter" do
			File.write(File.join(provider_root, "skills", "ruby-testing", "SKILL.md"), "# Missing metadata\n")
			
			expect do
				installer.find_gems_with_skills
			end.to raise_exception(Agent::Skills::Installer::InvalidSkill)
		end
	end
end
