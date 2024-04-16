# frozen_string_literal: true

module Unlight
  module Servers
    module Legacies
      # :nodoc:
      class GlobalChat < Unlight::Servers::Legacy
        require 'protocol/globalchatserver'

        include Liveiness

        def server_class
          Unlight::Protocol::GlobalChatServer
        end

        def start(*)
          super(*) do
            every(1.minute) { check_connection }
            every(settings.raid.help_send_interval) { publish_raid_help }
            every(settings.raid.auto_create_profound_interval) { auto_create_profound } if settings.raid.auto_create_profound
            every(settings.raid.auto_help_prodound_interval) { publish_auto_create_profound } if settings.raid.auto_create_profound
          end
        end

        private

        def publish_raid_help
          server_class.sending_help_list
        rescue StandardError => e
          logger.fatal('Sending help list failed', e)
        end

        def auto_create_profound
          Unlight::GlobalChatController.auto_create_prf
        rescue StandardError => e
          logger.fatal('Auto create profound failed', e)
        end

        def publish_auto_create_profound
          Unlight::GlobalChatController.auto_prf_send_help
        rescue StandardError => e
          logger.fatal('Send profound help failed', e)
        end
      end
    end
  end
end
