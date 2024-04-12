# frozen_string_literal: true

module Abyss
  # @api private
  APP_PATH = 'config/application.rb'
  private_constant :APP_PATH

  # @api private
  APP_DIR = 'app'
  private_constant :APP_DIR

  # @api private
  CONFIG_DIR = 'config'
  private_constant :CONFIG_DIR

  # @api private
  MODULE_DELIMITER = '::'
  private_constant :MODULE_DELIMITER

  # @api private
  SETTINGS_PATH = 'config/settings.rb'
  private_constant :SETTINGS_PATH

  # @api private
  SETTINGS_CLASS_NAME = 'Settings'
  private_constant :SETTINGS_CLASS_NAME
end
