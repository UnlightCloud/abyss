# frozen_string_literal: true

module Abyss
  # :nodoc:
  module Commands
    # Start the server
    #
    # @since 0.1.0
    class Server < Dry::CLI::Command
      TYPE_ALIASES = {
        'auth' => 'authentication'
      }.freeze

      desc 'Start the server'

      argument :type, required: true, desc: 'The server type'
      option :port, type: :integer, default: 12_000, desc: 'The port to bind to', aliases: ['-p']
      option :hostname, type: :string, default: 'localhost', desc: 'The hostname to bind to', aliases: ['-h']

      def call(type:, **options)
        command = Abyss.root.join('bin', TYPE_ALIASES[type] || type)
        exec("#{command} -p #{options[:port]} -h #{options[:hostname]}")
      end
    end

    register 'server', Server, aliases: ['s']
  end
end
