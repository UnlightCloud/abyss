# frozen_string_literal: true

module Abyss
  # :nodoc:
  module Commands
    require_relative 'readiness/database'
    require_relative 'readiness/migration'
    require_relative 'readiness/cache'

    register 'readiness', aliases: %w[r ready] do |prefix|
      prefix.register 'database', Readiness::Database, aliases: ['db']
      prefix.register 'migration', Readiness::Migration, aliases: ['m']
      prefix.register 'cache', Readiness::Cache, aliases: ['c']
    end
  end
end
