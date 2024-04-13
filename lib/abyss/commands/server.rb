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

      SERVER_CLASSES = {
        'auth' => 'Unlight::Protocol::AuthServer',
        'authentication' => 'Unlight::Protocol::AuthServer'
      }.freeze

      desc 'Start the server'

      argument :type, required: true, desc: 'The server type'
      option :id, type: :integer, default: 0, desc: 'The server id', aliases: ['-i']
      option :port, type: :integer, default: 12_000, desc: 'The port to bind to', aliases: ['-p']
      option :hostname, type: :string, default: 'localhost', desc: 'The hostname to bind to', aliases: ['-h']
      option :check_database, type: :boolean, default: false, desc: 'Check database connection', aliases: ['-c']

      def call(type:, **)
        require 'eventmachine'
        require Abyss.root.join('src', 'unlight')
        require Abyss.root.join('src', 'protocol', 'authserver')

        class_name = SERVER_CLASSES[type]
        return execute(type:, **) unless class_name

        server_class = Abyss.app.inflector.constantize(class_name)
        run_server(server_class, **)
      end

      private

      def execute(type:, **options)
        command = Abyss.root.join('bin', TYPE_ALIASES[type] || type)
        exec("#{command} -p #{options[:port]} -h #{options[:hostname]}")
      end

      def run_server(server_class, **, &)
        server = Abyss::Servers::Tcp.new(server_class, **)
        Signal.trap(:INT) { server.stop }
        Signal.trap(:TERM) { server.stop }

        server.start(&)
        Abyss.logger.info("Stopping #{server_class} server...")
        Abyss.shutdown
      end
    end

    register 'server', Server, aliases: ['s']
  end
end
