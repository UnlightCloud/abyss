# frozen_string_literal: true

Abyss.app.register_provider :database do
  prepare do
    require 'sequel'
  end

  start do
    settings = target[:settings]
    database = Sequel.connect(settings[:database_url], logger: target[:logger])

    register :database, database
  end

  stop do
    container[:database].disconnect
  end
end
