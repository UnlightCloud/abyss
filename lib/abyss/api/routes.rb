# frozen_string_literal: true

module Abyss
  module Api
    # The API routes
    #
    # @since 0.1.0
    class Routes
      # The delegator to cache the routes
      #
      # @since 0.1.0
      class Builder < DelegateClass(Proc)
        def self.empty
          new(proc {}, empty: true)
        end

        def initialize(target, empty: false)
          @empty = empty
          super(target)
        end

        def empty?
          !!@empty
        end
      end

      class << self
        # @api private
        def routes
          @routes ||= build_routes # rubocop:disable ThreadSafety/InstanceVariableInClassMethod
        end

        # @api private
        def build_routes(definitions = self.definitions)
          return Builder.empty if definitions.empty?

          routes = proc do
            definitions.each do |(name, args, kwargs, block)|
              if block
                public_send(name, *args, **kwargs, &block)
              else
                public_send(name, *args, **kwargs)
              end
            end
          end

          Builder.new(routes)
        end

        # @api private
        def definitions
          @definitions ||= [] # rubocop:disable ThreadSafety/InstanceVariableInClassMethod
        end

        private

        # @api private
        def supported_methods
          @supported_methods ||= Router.public_instance_methods # rubocop:disable ThreadSafety/InstanceVariableInClassMethod
        end

        # @api private
        def respond_to_missing?(name, include_private = false)
          supported_methods.include?(name) || super
        end

        # @api private
        def method_missing(name, *args, **kwargs, &block)
          return super unless supported_methods.include?(name)

          definitions << [name, args, kwargs, block]
          self
        end
      end
    end
  end
end
