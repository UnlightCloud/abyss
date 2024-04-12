# frozen_string_literal: true

Abyss.app.register_provider :flipper do
  start do
    target.start :database

    require 'flipper-sequel'
    require 'flipper-dalli'

    adapter = Flipper::Adapters::Sequel.new
    adapter = Flipper::Adapters::Dalli.new(adapter, Abyss::Cache.current, 600)

    Flipper.configure do |config|
      config.adapter { adapter }
    end

    register :feature, Flipper.new(adapter)
  end
end
