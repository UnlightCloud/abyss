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

        option :wait, type: :boolean, default: false, desc: 'Wait until the database migration is ready'

        def call(**options)
          while Dawn::Database.pending?
            puts 'Waiting for database migration...'
            exit 1 unless options[:wait]
            sleep 1
          end

          puts 'Database migration is ready.'
        end
      end
    end
  end
end