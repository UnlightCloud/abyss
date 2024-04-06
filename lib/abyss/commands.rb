# frozen_string_literal: true

require 'dry/cli'
require_relative 'version'

module Abyss
  # Define the CLI commands
  #
  # @since 0.1.0
  module Commands
    extend Dry::CLI::Registry

    require_relative 'commands/version'

    module_function

    def run
      Dry::CLI.new(self).call
    end
  end
end
