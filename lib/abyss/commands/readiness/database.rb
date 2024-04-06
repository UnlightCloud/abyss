# frozen_string_literal: true

module Abyss
  module Commands
    module Readiness
      # Check the database readiness
      #
      # @since 0.1.0
      class Database < Dry::CLI::Command
        require 'dawn/database'

        desc 'Check the database is ready'

        def call(*)
          puts 'Check database connection...'
          Dawn::Database.current.test_connection
          puts 'Database connection is ready.'
        rescue Sequel::DatabaseConnectionError
          sleep 1
          retry
        end
      end
    end
  end
end
