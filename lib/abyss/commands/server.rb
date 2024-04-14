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
        'raid' => 'Unlight::Protocol::RaidServer',
        'game' => 'Unlight::Protocol::GameServer',
        'global_chat' => 'Unlight::Protocol::GlobalChatServer',
        'matching' => 'Unlight::Protocol::MatchServer'
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
        'raid' => 'raid_server',
        'game' => 'gameserver',
        'global_chat' => 'globalchatserver',
        'matching' => 'matchserver'
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

        require Abyss.root.join('src', 'protocol', class_path)
        server_class = Abyss.app.inflector.constantize(class_name)
        run_server(server_class, **) { extra_workers(server_class) }
      end

      private

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
        when 'Unlight::Protocol::RaidServer', 'Unlight::Protocol::QuestServer'
          quest_workers(server_class)
        when 'Unlight::Protocol::GameServer' then game_workers(server_class)
        when 'Unlight::Protocol::GlobalChatServer' then global_chat_workers(server_class)
        when 'Unlight::Protocol::MatchServer' then match_workers(server_class)
        end
      end

      def connection_check(server)
        EventMachine::PeriodicTimer.new(60) do
          server.check_connection
        rescue StandardError => e
          Abyss.logger.fatal('Check connection failed', e)
        end
      end

      def connection_check_sec(server)
        EventMachine::PeriodicTimer.new(60 / Unlight::GAME_CHECK_CONNECT_INTERVAL) do
          server.check_connection_sec
        rescue StandardError => e
          Abyss.logger.fatal('Check connection failed', e)
        end
      end

      def duel_update(_server)
        EventMachine::PeriodicTimer.new(0.3) do
          Unlight::MultiDuel.update
        rescue StandardError => e
          Abyss.logger.fatal('MultiDuel update failed', e)
        end

        EventMachine::PeriodicTimer.new(1) do
          Unlight::AI.update
        rescue StandardError => e
          Abyss.logger.fatal('AI update failed', e)
        end
      end

      def watch_workers(server)
        EventMachine::PeriodicTimer.new(1) do
          server.all_duel_update
        rescue StandardError => e
          Abyss.logger.fatal('All duel update failed', e)
        end

        connection_check(server)
      end

      def quest_workers(server)
        duel_update(server)
        connection_check(server)
      end

      def game_workers(server)
        duel_update(server)
        connection_check_sec(server)
      end

      def global_chat_workers(server)
        EventMachine::PeriodicTimer.new(Unlight::RAID_HELP_SEND_TIME) do
          server.sending_help_list
        rescue StandardError => e
          Abyss.logger.fatal('Sending help list failed', e)
        end

        connection_check(server)

        return unless Unlight::PRF_AUTO_CREATE_EVENT_FLAG

        EventMachine::PeriodicTimer.new(Unlight::PRF_AUTO_CREATE_INTERVAL) do
          Unlight::GlobalChatController.auto_create_prf
        rescue StandardError => e
          Abyss.logger.fatal('Auto create profound failed', e)
        end

        EventMachine::PeriodicTimer.new(Unlight::PRF_AUTO_HELP_INTERVAL) do
          Unlight::GlobalChatController.auto_prf_send_help
        rescue StandardError => e
          Abyss.logger.fatal('Send profound help failed', e)
        end
      end

      def match_workers(server)
        current_time = 0

        EventMachine::PeriodicTimer.new(Unlight::CPU_POP_TIME) do
          h = Time.now.utc.hour
          if current_time != h
            c = Unlight::CPU_SPAWN_NUM[h]
            c.times { Unlight::MatchController.cpu_room_update }
            current_time = h
          end
        rescue StandardError => e
          Abyss.logger.fatal('Pop CPU failed', e)
        end

        EventMachine::PeriodicTimer.new(60) do
          server.check_boot
          server.update_login_count
        rescue StandardError => e
          Abyss.logger.fatal('Check boot failed', e)
        end

        connection_check_sec(server)

        EventMachine::PeriodicTimer.new(5) do
          server.radder_match_update
        rescue StandardError => e
          Abyss.logger.fatal('Radder match update failed', e)
        end

        EventMachine::PeriodicTimer.new(Unlight::RADDER_CPU_POP_TIME) do
          Unlight::MatchController.cpu_radder_match_update if Unlight::RADDER_CPU_POP_ENABLE && rand(Unlight::RADDER_CPU_POP_RAND).zero?
        rescue StandardError => e
          Abyss.logger.fatal('Radder CPU POP failed', e)
        end
      end
    end

    register 'server', Server, aliases: ['s']
  end
end
