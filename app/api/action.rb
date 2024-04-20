# frozen_string_literal: true

require 'hanami/action'

module Unlight
  module API
    # :nodoc:
    class Action < Hanami::Action
      include HasAuth

      format :json
    end
  end
end
