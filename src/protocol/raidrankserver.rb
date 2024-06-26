# Unlight
# Copyright(c)2019 CPA
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php

require 'protocol/ulserver'
require 'protocol/command/command'
require 'controller/raid_rank_controller'

module Unlight
  module Protocol
    class RaidRankServer < ULServer
      include RaidRankController

      attr_accessor :player, :avatar

      # クラスの初期化
      def self.setup(*_args)
        super
        # コマンドクラスをつくる
        @@receive_cmd = Command.new(self, :RaidRank)
      end

      def online_list
        @@online_list
      end

      # 切断時
      def unbind
        # 例外をrescueしないのAbortするので注意
        begin
          if @player
            logout
            @player = nil
          end
        rescue StandardError => e
          Sentry.capture_exception(e)
        end
        SERVER_LOG.info("#{@@class_name}: Connection unbind >> #{@ip}.player#{@player.id}") if @player
      end
    end
  end
end
