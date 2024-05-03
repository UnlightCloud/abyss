# frozen_string_literal: true

require 'factory_bot'

FactoryBot.define do
  # For Sequel
  to_create(&:save_changes)
end
FactoryBot.find_definitions

World(FactoryBot::Syntax::Methods)
