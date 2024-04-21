# frozen_string_literal: true

module Abyss
  # :nodoc:
  module Commands
    # Start a console
    #
    # @since 0.1.0
    class Console < Dry::CLI::Command
      desc 'Start a console'

      def call(*)
        require 'irb'
        require 'irb/completion'

        require Abyss.root.join('src', 'unlight')
        Abyss.boot

        ARGV.clear

        IRB.start(__FILE__)
      end
    end

    register 'console', Console, aliases: ['c']
  end
end
