# frozen_string_literal: true

module Abyss
  # :nodoc:
  module Commands
    # Toggle maintenance mode
    #
    # @since 0.1.0
    class Maintenance < Dry::CLI::Command
      ENABLE_MODE_NAMES = %w[enable on].freeze
      DISABLE_MODE_NAMES = %w[disable off].freeze

      desc 'Toggle maintenance mode'

      argument :mode, required: true, desc: 'The mode to set'

      def call(mode:)
        enabled = ENABLE_MODE_NAMES.include?(mode)
        return puts 'Invalid mode' unless enabled || DISABLE_MODE_NAMES.include?(mode)

        enabled ? Abyss::Maintenance.enable : Abyss::Maintenance.disable
        puts "Maintenance mode #{enabled ? 'enabled' : 'disabled'}"
      end
    end

    register 'maintenance', Maintenance, aliases: ['m']
  end
end
