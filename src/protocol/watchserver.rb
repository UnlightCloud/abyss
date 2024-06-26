# Unlight
# Copyright(c)2019 CPA
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php

require 'protocol/ulserver'
require 'protocol/command/command'
require 'controller/watch_controller'

module Unlight
  module Protocol
    class WatchServer < ULServer
      include WatchController
      attr_accessor :player, :matching, :duel, :opponent_player, :match_log, :watch_duel

      # クラスの初期化
      def self.setup(_id, _ip, _port)
        super()
        # コマンドクラスをつくる
        @@receive_cmd = Command.new(self, :Watch)
        WatchController.init
        CharaCardDeck.preload_CPU_deck
      end

      # 切断時
      def unbind
        # 例外をrescueしないとAbortするので注意
        begin
          if @player
            delete_connection
            logout
          end
        rescue StandardError => e
          Sentry.capture_exception(e)
        end
        SERVER_LOG.info("#{@@class_name}: Connection unbind >> #{@ip}")
      end

      def online_list
        @@online_list
      end

      def self.all_duel_update
        WatchController.all_duel_update
      end

      # サーバを終了する
    end
  end
end
