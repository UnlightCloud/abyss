# Unlight
# Copyright(c)2019 CPA
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php

require 'protocol/ulserver'
require 'protocol/command/command'
require 'controller/data_controller'

module Unlight
  module Protocol
    class DataServer < ULServer
      include DataController
      attr_accessor :player, :avatar

      # クラスの初期化
      def self.setup(*_args)
        super
        # コマンドクラスをつくる
        @@receive_cmd = Command.new(self, :Data)
      end

      # 切断時
      def unbind
        # 例外をrescueしないのAbortするので注意
        begin
          if @player
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
    end
  end
end
