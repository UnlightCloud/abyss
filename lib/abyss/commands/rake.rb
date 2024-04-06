# frozen_string_literal: true

module Abyss
  # :nodoc:
  module Commands
    # Run Rake tasks
    #
    # @since 0.1.0
    class Rake < Dry::CLI::Command
      desc 'Run Rake tasks'

      def call(*)
        exec("bundle exec #{ARGV.join(' ')}")
      end
    end

    register 'rake', Rake
  end
end
