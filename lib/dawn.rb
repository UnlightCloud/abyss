# frozen_string_literal: true

require 'semantic_logger'

require 'dawn/version'

# Dawn
#
# The OpenUnlight Version Unlight server implemented
#
# @since 0.1.0
module Dawn
  module_function

  # @return [Pathname] project root
  def root
    Bundler.root
  end

  # @return [String] current environment
  def env
    ENV['DAWN_ENV'] || 'development'
  end
end
