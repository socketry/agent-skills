# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025-2026, by Samuel Williams.

describe Agent::Skills do
	it "has a version number" do
		expect(Agent::Skills::VERSION).to be =~ /^\d+\.\d+\.\d+$/
	end
end
