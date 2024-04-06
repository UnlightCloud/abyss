# frozen_string_literal: true

module Abyss
  # :nodoc:
  module Commands
    require_relative 'readiness/database'

    register 'readiness', aliases: %w[r ready] do |prefix|
      prefix.register 'database', Readiness::Database, aliases: ['db']
    end
  end
end
