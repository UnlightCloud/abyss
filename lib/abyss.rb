# frozen_string_literal: true

require 'zeitwerk'

# Abyss is open-source Unlight server
#
# @since 0.1.0
module Abyss
  module_function

  # @api private
  #
  # @since 0.1.0
  def loader
    @loader ||= Zeitwerk::Loader.for_gem.tap do |loader| # rubocop:disable ThreadSafety/InstanceVariableInClassMethod
      loader.ignore("#{__dir__}/dawn.rb")
      loader.ignore("#{__dir__}/{dawn,ruby_inline,tasks}/")
    end
  end

  # @return [Pathname] project root
  #
  # @since 0.1.0
  def root
    Bundler.root
  end

  loader.setup
end
