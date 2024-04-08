# frozen_string_literal: true

require 'flipper'

Flipper.configure do |config|
  config.adapter do
    # Ensure database connection
    Dawn::Database.current

    require 'flipper-sequel'
    require 'flipper-dalli'

    adapter = Flipper::Adapters::Sequel.new
    Flipper::Adapters::Dalli.new(adapter, Abyss::Cache.current, 600)
  end
end
