# frozen_string_literal: true

require 'factory_bot'

FactoryBot.define do
  # For Sequel
  to_create(&:save_changes)
end

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    pp 'FactoryBot.find_definitions'
    FactoryBot.find_definitions
  end
end
