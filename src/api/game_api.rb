# Unlight
# Copyright (c) 2019 Open Unlight
# This software is released under the Apache 2.0 License.
# https://opensource.org/licenses/Apache2.0

# frozen_string_literal: true

require 'dawn/api'
require 'api/game/v1'

class GameAPI < Dawn::API::Base
  version 'v1', using: :path do
    mount Game::V1
  end
end
