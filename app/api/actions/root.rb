# frozen_string_literal: true

module Unlight
  module API
    module Actions
      # :nodoc:
      class Root
        def call(_env)
          [200, { 'Content-Type' => 'text/plain' }, ['Hello, Unlight API!']]
        end
      end
    end
  end
end
