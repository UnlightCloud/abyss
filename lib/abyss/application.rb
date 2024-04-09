# frozen_string_literal: true

require 'dry/system'

module Abyss
  # @since 0.1.0
  class Application
    @_mutex = Mutex.new

    class << self
      def inherited(subclass)
        super

        Abyss.app = subclass

        subclass.extend(ClassMethods)

        @_mutex.synchronize do
          subclass.class_eval do
            @_mutex = Mutex.new
            @autoloader = Zeitwerk::Loader.new
            @container = Class.new(Dry::System::Container)
          end
        end
      end
    end

    # Class methods defined on the application
    #
    # @since 0.1.0
    module ClassMethods
      # return abyss autoloader
      #
      # @return [Zeitwrk::Loader]
      #
      # @since 0.1.0
      attr_reader :autoloader

      # return abyss container
      #
      # @return [Dry::System::Container]
      #
      # @since 0.1.0
      attr_reader :container

      # return is booted
      #
      # @return [Boolean]
      #
      # @since 0.1.0
      def booted?
        !!@booted # rubocop:disable ThreadSafety/InstanceVariableInClassMethod
      end

      # boot the application
      #
      # @return [self]
      #
      # @since 0.1.0
      def boot
        return self if booted?

        container.finalize!
        @booted = true # rubocop:disable ThreadSafety/InstanceVariableInClassMethod

        self
      end
    end
  end
end
