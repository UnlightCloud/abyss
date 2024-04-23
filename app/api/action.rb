# frozen_string_literal: true

require 'hanami/action'

module Unlight
  module API
    # :nodoc:
    class Action < Hanami::Action
      include HasAuth
      include HasParamValidation

      format :json
    end
  end
end
