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
			registry_path = File.join(consumer_root, ".agents", "skills", Agent::Skills::Registry::FILE_NAME)
			registry = Agent::Skills::Registry.new(registry_path)
			
			expect(registry.owner("ruby-testing")).to be == {
				"ecosystem" => "gem",
				"package" => "fake-gem",
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
	it "installs context-declared skills with metadata and opaque resources" do
		context = File.join(provider_root, "context")
		FileUtils.mkdir_p(File.join(context, "workflow/references"))
		File.write(File.join(context, "workflow.md"), "---\ntype: skill\ndescription: Run workflow.\nlicense: MIT\nmetadata:\n  author: Provider\n---\n\n# Workflow\n")
		File.write(File.join(context, "workflow/references/data.md"), "---\nnot valid: [yaml\n---\n")
		expect(installer.install_gem_skills("fake-gem").sort).to be == ["fake-gem-workflow", "ruby-testing"]
		content = File.read(File.join(consumer_root, ".agents/skills/fake-gem-workflow/SKILL.md"))
		expect(content).to be(:include?, "name: fake-gem-workflow")
		expect(content).to be(:include?, "license: MIT")
		expect(content).to be(:include?, "author: Provider")
		expect(File).to be(:exist?, File.join(consumer_root, ".agents/skills/fake-gem-workflow/references/data.md"))
	end
	
	it "removes a provider's last skill and cleans disappeared gem providers" do
		installer.install_all_skills
		FileUtils.rm_rf(File.join(provider_root, "skills"))
		expect(installer.install_gem_skills("fake-gem")).to be == []
		expect(File).not.to be(:exist?, File.join(consumer_root, ".agents/skills/ruby-testing"))
		write_skill(provider_root, "ruby-testing", description: "Test projects.")
		installer.install_all_skills
		subject.new(root: consumer_root, specifications: []).install_all_skills
		expect(File).not.to be(:exist?, File.join(consumer_root, ".agents/skills/ruby-testing"))
	end
	
	it "preserves Cargo skills during a full Ruby refresh" do
		registry_path = File.join(consumer_root, ".agents/skills", Agent::Skills::Registry::FILE_NAME)
		registry = Agent::Skills::Registry.new(registry_path)
		registry.claim("cargo-workflow", "fake-gem", "2.0.0", ecosystem: "cargo")
		registry.save
		cargo = File.join(consumer_root, ".agents/skills/cargo-workflow/SKILL.md")
		FileUtils.mkdir_p(File.dirname(cargo))
		File.write(cargo, "Cargo instructions")
		installer.install_all_skills
		expect(File.read(cargo)).to be == "Cargo instructions"
		expect(Agent::Skills::Registry.new(registry_path).owner("cargo-workflow")["ecosystem"]).to be == "cargo"
	end
	
	it "refuses a matching name owned by Cargo even when the package names match" do
		registry = Agent::Skills::Registry.new(File.join(consumer_root, ".agents/skills", Agent::Skills::Registry::FILE_NAME))
		registry.claim("ruby-testing", "fake-gem", "1.0.0", ecosystem: "cargo")
		registry.save
		expect do
			installer.install_all_skills
		end.to raise_exception(Agent::Skills::Installer::Conflict)
	end
	
	it "preserves the previous skills and registry when resource copying fails" do
		installer.install_all_skills
		registry_path = File.join(consumer_root, ".agents/skills", Agent::Skills::Registry::FILE_NAME)
		previous = File.read(registry_path)
		destination = File.join(consumer_root, ".agents/skills/ruby-testing/SKILL.md")
		instructions = File.read(destination)
		write_skill(provider_root, "ruby-testing", description: "Updated workflow.", body: "# Updated\n")
		File.symlink("missing", File.join(provider_root, "skills/ruby-testing/broken"))
		expect do
			installer.install_all_skills
		end.to raise_exception(Agent::Skills::Installer::InvalidSkill)
		expect(File.read(registry_path)).to be == previous
		expect(File.read(destination)).to be == instructions
	end
	
	it "preserves unselected skills when installing one named skill" do
		write_skill(provider_root, "documentation", description: "Write docs.")
		installer.install_all_skills
		FileUtils.rm_rf(File.join(provider_root, "skills/documentation"))
		installer.install(skill: "ruby-testing")
		expect(File).to be(:exist?, File.join(consumer_root, ".agents/skills/documentation/SKILL.md"))
	end
	
	it "accepts the common metadata limits and rejects overlong descriptions" do
		write_skill(provider_root, "a" * 64, description: "d" * 1024)
		expect(installer.list_skills("fake-gem").length).to be == 2
		write_skill(provider_root, "a" * 64, description: "d" * 1025)
		expect do
			installer.list_skills("fake-gem")
		end.to raise_exception(Agent::Skills::Installer::InvalidSkill)
	end
	
	it "migrates legacy Ruby ownership without resurrecting removed skills" do
		installer.install_all_skills
		shared = File.join(consumer_root, ".agents/skills", Agent::Skills::Registry::FILE_NAME)
		File.delete(shared)
		legacy = File.join(consumer_root, ".agents/skills/.agent-skills.yaml")
		File.write(legacy, {"version" => 1, "skills" => {"ruby-testing" => {"gem" => "fake-gem", "version" => "1.0.0"}}}.to_yaml)
		FileUtils.rm_rf(File.join(provider_root, "skills"))
		installer.install_all_skills
		installer.install_all_skills
		expect(File).not.to be(:exist?, legacy)
		expect(File).not.to be(:exist?, File.join(consumer_root, ".agents/skills/ruby-testing"))
		expect(Agent::Skills::Registry.new(shared).owners).to be == {}
	end
	
	it "rejects nested skill declarations outside a skill resource directory" do
		context = File.join(provider_root, "context/nested")
		FileUtils.mkdir_p(context)
		File.write(File.join(context, "workflow.md"), "---\ntype: skill\ndescription: Run workflow.\n---\n\n# Workflow\n")
		expect do
			installer.install_all_skills
		end.to raise_exception(Agent::Skills::Installer::InvalidSkill)
		expect(File).not.to be(:exist?, File.join(consumer_root, ".agents/skills/ruby-testing"))
	end
	
	it "trims descriptions before enforcing the shared character limit" do
		context = File.join(provider_root, "context")
		FileUtils.mkdir_p(context)
		metadata = {"type" => "skill", "description" => "  #{"é" * 1024}  "}
		File.write(File.join(context, "workflow.md"), "#{metadata.to_yaml}---\n\n# Workflow\n")
		installer.install_all_skills
		content = File.read(File.join(consumer_root, ".agents/skills/fake-gem-workflow/SKILL.md"))
		expect(installer.list_skills("fake-gem").first.description).to be == "é" * 1024
		expect(content).not.to be(:include?, "  é")
	end
	
	it "restores skills, legacy ownership, and exclusions when the registry commit fails" do
		system("git", "init", "--quiet", consumer_root, exception: true)
		write_skill(provider_root, "documentation", description: "Write docs.")
		installer.install_all_skills
		registry = File.join(consumer_root, ".agents/skills", Agent::Skills::Registry::FILE_NAME)
		exclude = File.join(consumer_root, ".git/info/exclude")
		previous_registry = File.read(registry)
		previous_exclude = File.read(exclude)
		destination = File.join(consumer_root, ".agents/skills/ruby-testing/SKILL.md")
		previous_instructions = File.read(destination)
		legacy = File.join(consumer_root, ".agents/skills/.agent-skills.yaml")
		legacy_content = {"version" => 1, "skills" => {"ruby-testing" => {"gem" => "fake-gem", "version" => "1.0.0"}}}.to_yaml
		File.write(legacy, legacy_content)
		write_skill(provider_root, "ruby-testing", description: "Updated workflow.", body: "# Updated\n")
		FileUtils.rm_rf(File.join(provider_root, "skills/documentation"))
		mock(File).before(:rename) do |_source, target|
			raise Errno::EACCES, "Injected registry failure" if target == registry
		end
		expect do
			installer.install_all_skills
		end.to raise_exception(Errno::EACCES)
		expect(File.read(registry)).to be == previous_registry
		expect(File.read(exclude)).to be == previous_exclude
		expect(File.read(destination)).to be == previous_instructions
		expect(File.read(legacy)).to be == legacy_content
		expect(File).to be(:exist?, File.join(consumer_root, ".agents/skills/documentation/SKILL.md"))
	end
	
	it "keeps plain guides out of skills and rejects invalid context skill metadata" do
		context = File.join(provider_root, "context")
		FileUtils.mkdir_p(context)
		guide = File.join(context, "guide.md")
		File.write(guide, "# Plain Guide\n\nOrdinary guidance.\n")
		expect(installer.list_skills("fake-gem").map(&:name)).to be == ["ruby-testing"]
		File.write(guide, "---\ntype: skill\ndescription: [invalid\n---\n")
		expect do
			installer.install_all_skills
		end.to raise_exception(Agent::Skills::Installer::InvalidSkill)
		write_skill(provider_root, "Bad_Name", description: "Invalid name.")
		File.delete(guide)
		expect do
			installer.install_all_skills
		end.to raise_exception(Agent::Skills::Installer::InvalidSkill)
	end
	
	it "refuses a reserved SKILL.md resource before changing installed skills" do
		installer.install_all_skills
		context = File.join(provider_root, "context")
		FileUtils.mkdir_p(File.join(context, "workflow"))
		File.write(File.join(context, "workflow.md"), "---\ntype: skill\ndescription: Run workflow.\n---\n")
		File.write(File.join(context, "workflow/SKILL.md"), "Conflicting instructions")
		expect do
			installer.install_all_skills
		end.to raise_exception(Agent::Skills::Installer::InvalidSkill)
		expect(File).not.to be(:exist?, File.join(consumer_root, ".agents/skills/fake-gem-workflow"))
		expect(File).to be(:exist?, File.join(consumer_root, ".agents/skills/ruby-testing/SKILL.md"))
	end
	
	it "works without Git and refuses malformed generated exclusion blocks" do
		mock(Open3).before(:capture2e){raise Errno::ENOENT, "Git unavailable"}
		expect(installer.install_all_skills).to be == ["ruby-testing"]
		mock(Open3).clear
		system("git", "init", "--quiet", consumer_root, exception: true)
		File.write(File.join(consumer_root, ".git/info/exclude"), "# BEGIN bake-agent-context\n")
		expect do
			installer.install_all_skills
		end.to raise_exception(Agent::Skills::Registry::Invalid)
	end
end
