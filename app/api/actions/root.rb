# frozen_string_literal: true

module Unlight
  module API
    module Actions
      # :nodoc:
      class Root < Action
        def handle(*, res)
          res.body = { message: 'Powered by UnlightCloud' }.to_json
        end
      end
    end
  end
end
