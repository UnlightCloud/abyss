# frozen_string_literal: true

module Abyss
  module Commands
    module Readiness
      # Check cache server is ready
      #
      # @since 0.1.0
      class Cache < Dry::CLI::Command
        desc 'Check cache server is ready'

        def call(*)
          until Abyss::Cache.ready?
            puts 'Waiting for cache server...'
            sleep 1
          end

          puts 'Cache server is ready.'
        end
      end
    end
  end
end
