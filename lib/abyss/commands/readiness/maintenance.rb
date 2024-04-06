# frozen_string_literal: true

module Abyss
  module Commands
    module Readiness
      # Check the maintenance mode is disabled
      #
      # @since 0.1.0
      class Maintenance < Dry::CLI::Command
        desc 'Check the maintenance mode is disabled'

        def call(*)
          while Abyss::Maintenance.enabled?
            puts 'The server is in maintenance mode'
            sleep 1
          end

          puts 'The server is ready'
        end
      end
    end
  end
end
