# frozen_string_literal: true

module Unlight
  module Servers
    module Legacies
      # :nodoc:
      class GlobalChat < Unlight::Servers::Legacy
        require 'protocol/globalchatserver'

        def server_class
          Unlight::Protocol::GlobalChatServer
        end

        def start(*)
          super(*) do
            ensure_connection
            publish_raid_help
            auto_create_profound
            publish_auto_create_profound
          end
        end

        private

        def ensure_connection
          EventMachine::PeriodicTimer.new(60) do
            server_class.check_connection
          rescue StandardError => e
            logger.fatal('Check connection failed', e)
          end
        end

        def publish_raid_help
          EventMachine::PeriodicTimer.new(Unlight::RAID_HELP_SEND_TIME) do
            server_class.sending_help_list
          rescue StandardError => e
            logger.fatal('Sending help list failed', e)
          end
        end

        def auto_create_profound
          return unless Unlight::PRF_AUTO_CREATE_EVENT_FLAG

          EventMachine::PeriodicTimer.new(Unlight::PRF_AUTO_CREATE_INTERVAL) do
            Unlight::GlobalChatController.auto_create_prf
          rescue StandardError => e
            logger.fatal('Auto create profound failed', e)
          end
        end

        def publish_auto_create_profound
          return unless Unlight::PRF_AUTO_CREATE_EVENT_FLAG

          EventMachine::PeriodicTimer.new(Unlight::PRF_AUTO_HELP_INTERVAL) do
            Unlight::GlobalChatController.auto_prf_send_help
          rescue StandardError => e
            logger.fatal('Send profound help failed', e)
          end
        end
      end
    end
  end
end
