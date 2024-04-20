# frozen_string_literal: true

module Unlight
  module API
    module Actions
      # :nodoc:
      class Root < Action
        def handle(*, res)
          res.body = 'Hello, Unlight API!'
        end
      end
    end
  end
end
