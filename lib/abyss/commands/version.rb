# frozen_string_literal: true

module Abyss
  # :nodoc:
  module Commands
    # Print version
    #
    # @since 0.1.0
    class Version < Dry::CLI::Command
      desc 'Print version'

      def call(*)
        puts Abyss::VERSION
      end
    end

    register 'version', Version
  end
end
