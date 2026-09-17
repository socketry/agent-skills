# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.

describe Agent::Skills do
	it "has a version number" do
		expect(Agent::Skills::VERSION).to be =~ /^\d+\.\d+\.\d+$/
	end
end
