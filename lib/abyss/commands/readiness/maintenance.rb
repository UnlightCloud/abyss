# frozen_string_literal: true

module Abyss
  module Commands
    module Readiness
      # Check the maintenance mode is disabled
      #
      # @since 0.1.0
      class Maintenance < Dry::CLI::Command
        desc 'Check the maintenance mode is disabled'

        option :delay, type: :integer, default: 0, desc: 'The delay in seconds before checking the readiness'
        option :wait, type: :boolean, default: false, desc: 'Wait until the maintenance mode is disabled'

        def call(**options)
          delay = options.fetch(:delay, 0).to_i
          sleep delay if delay.positive?

          while Abyss::Maintenance.enabled?
            puts 'The server is in maintenance mode'
            exit 1 unless options[:wait]
            sleep 1
          end

          puts 'The server is ready'
        end
      end
    end
  end
end
