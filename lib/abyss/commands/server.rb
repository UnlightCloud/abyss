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
        'authentication' => 'Unlight::Protocol::AuthServer',
        'chat' => 'Unlight::Protocol::ChatServer',
        'data_lobby' => 'Unlight::Protocol::DataServer',
        'lobby' => 'Unlight::Protocol::LobbyServer',
        'raid_chat' => 'Unlight::Protocol::RaidChatServer',
        'raid_data' => 'Unlight::Protocol::RaidDataServer',
        'raid_rank' => 'Unlight::Protocol::RaidRankServer',
        'watch' => 'Unlight::Protocol::WatchServer',
        'quest' => 'Unlight::Protocol::QuestServer',
        'raid' => 'Unlight::Protocol::RaidServer'
      }.freeze

      SERVER_FILE = {
        'auth' => 'authserver',
        'authentication' => 'authserver',
        'chat' => 'chatserver',
        'data_lobby' => 'dataserver',
        'lobby' => 'lobbyserver',
        'raid_chat' => 'raidchatserver',
        'raid_data' => 'raiddataserver',
        'raid_rank' => 'raidrankserver',
        'watch' => 'watchserver',
        'quest' => 'quest_server',
        'raid' => 'raid_server'
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

        class_path = SERVER_FILE[type]
        class_name = SERVER_CLASSES[type]
        return execute(type:, **) unless class_name && class_path

        require Abyss.root.join('src', 'protocol', class_path)
        server_class = Abyss.app.inflector.constantize(class_name)
        run_server(server_class, **) { extra_workers(server_class) }
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

      # Extra Works
      def extra_workers(server_class)
        case server_class.name
        when 'Unlight::Protocol::WatchServer' then watch_workers(server_class)
        when 'Unlight::Protocol::RaidServer' then quest_workers(server_class)
        when 'Unlight::Protocol::QuestServer' then quest_workers(server_class)
        end
      end

      def watch_workers(server)
        EventMachine::PeriodicTimer.new(1) do
          server.all_duel_update
        rescue StandardError => e
          Abyss.logger.fatal('All duel update failed', e)
        end

        EventMachine::PeriodicTimer.new(60) do
          server.check_connection
        rescue StandardError => e
          Abyss.logger.fatal('Check connection failed', e)
        end
      end

      def quest_workers(server)
        EM::PeriodicTimer.new(0.3) do
          Unlight::MultiDuel.update
        rescue StandardError => e
          Abyss.logger.fatal('MultiDuel update failed', e)
        end

        EM::PeriodicTimer.new(1) do
          Unlight::AI.update
        rescue StandardError => e
          Abyss.logger.fatal('AI update failed', e)
        end

        EM::PeriodicTimer.new(60) do
          server.check_connection
        rescue StandardError => e
          Abyss.logger.fatal('Check connection failed', e)
        end
      end
    end

    register 'server', Server, aliases: ['s']
  end
end
