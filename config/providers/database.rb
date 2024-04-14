# frozen_string_literal: true

Abyss.app.register_provider :database do
  prepare do
    require 'sequel'

    Sequel::Model.require_valid_table = false
    Sequel::Model.plugin :json_serializer
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
