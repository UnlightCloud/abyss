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
    require_relative 'commands/console'
    require_relative 'commands/server'
    require_relative 'commands/api'
    require_relative 'commands/readiness'
    require_relative 'commands/upgrade'
    require_relative 'commands/rake'
    require_relative 'commands/maintenance'

    module_function

    def run
      Dry::CLI.new(self).call
    end
  end
end
