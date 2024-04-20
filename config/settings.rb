# frozen_string_literal: true

module Unlight
  # :nodoc:
  class Settings < Abyss::Settings
    setting :database_url, constructor: Types::String.optional

    # Server settings
    setting :check_database, default: false, constructor: Types::Params::Bool

    # CPU_POP_TIME = 60
    setting :cpu_pop_interval, default: 1.minute, constructor: Types::Params::Float

    # RADDER_CPU_POP_TIME = 2
    setting :radder_cpu_pop_interval, default: 2.seconds, constructor: Types::Params::Float

    setting :game do
      # GAME_CHECK_CONNECT_INTERVAL = 10
      # for game server is 60 / 10 = 6 seconds
      setting :check_connect_interval, default: 6.seconds, constructor: Types::Params::Float
    end

    setting :raid do
      # RAID_HELP_SEND_TIME = 10
      setting :help_send_interval, default: 10.seconds, constructor: Types::Params::Float

      # PRF_AUTO_CREATE_EVENT_FLAG = false
      setting :auto_create_profound, default: 'false', constructor: Types::Params::Bool

      # PRF_AUTO_CREATE_INTERVAL = 60 * 180
      setting :auto_create_profound_interval, default: 180.minutes, constructor: Types::Params::Float

      # PRF_AUTO_HELP_INTERVAL = 60 * 3
      setting :auto_help_prodound_interval, default: 3.minutes, constructor: Types::Params::Float
    end
  end
end
