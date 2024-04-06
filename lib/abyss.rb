# frozen_string_literal: true

require_relative 'abyss/version'
require_relative 'abyss/commands'
require_relative 'abyss/cache'

# Abyss is open-source Unlight server
#
# @since 0.1.0
module Abyss
  module_function

  # @return [Pathname] project root
  #
  # @since 0.1.0
  def root
    Bundler.root
  end
end
