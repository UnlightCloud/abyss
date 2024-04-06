# frozen_string_literal: true

module Abyss
  module Commands
    module Readiness
      # Check database migration is ready
      #
      # @since 0.1.0
      class Migration < Dry::CLI::Command
        require 'dawn/database'

        desc 'Check database migration is ready'

        def call(*)
          while Dawn::Database.pending?
            puts 'Waiting for database migration...'
            sleep 1
          end

          puts 'Database migration is ready.'
        end
      end
    end
  end
end
