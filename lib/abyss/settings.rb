# frozen_string_literal: true

require 'dry/configurable'

require_relative 'constants'

module Abyss
  #  Provides user-defined settings for Abyss
  #
  #  @since 0.1.0
  class Settings
    class << self
      def load(app)
        settings_path = File.join(app.root, SETTINGS_PATH)

        require settings_path
        klass = app.namespace.const_get(SETTINGS_CLASS_NAME)
        klass.new
      rescue LoadError => e
        raise e unless e.path == settings_path
      end
    end

    EMPTY_STORE = Dry::Core::Constants::EMPTY_HASH

    include Dry::Configurable

    def initialize(store = EMPTY_STORE, delimiter: '__')
      values = config._settings.to_h do |setting|
        [setting.name, read_as_hash(store, setting, delimiter:)]
      end

      update(values)
      config.finalize!
    end

    private

    def read_as_hash(store, setting, delimiter:, prefix: [])
      name = setting.name

      if setting.children.any?
        return setting.children.each do |child|
          [child.name, read_as_hash(store, child, prefix: [*prefix, name], delimiter:)]
        end.to_h
      end

      store.fetch([*prefix, name].join(delimiter), setting.default)
    end

    def method_missing(method, *, &)
      return super unless config.respond_to?(method)

      config.send(method, *, &)
    end

    def respond_to_missing?(method, *)
      config.respond_to?(method) || super
    end
  end
end
