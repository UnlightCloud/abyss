# frozen_string_literal: true

module Unlight
  module API
    # :nodoc:
    module HasParamValidation
      def self.included(action)
        action.before :validate_params!
      end

      private

      def validate_params!(req, *)
        pp req.params
        return if req.params.valid?

        halt :bad_request, { error: req.params.error_messages.first }.to_json
      end
    end
  end
end
