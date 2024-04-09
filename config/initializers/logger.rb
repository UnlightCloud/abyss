# frozen_string_literal: true

require 'semantic_logger'

LOG_TO_STDOUT = ENV.fetch('ABYSS_LOG_TO_STDOUT') { ENV.fetch('DAWN_LOG_TO_STDOUT', false) }

# TODO: Allow multiple output
if LOG_TO_STDOUT == 'true' || LOG_TO_STDOUT == 'yes' || LOG_TO_STDOUT == '1' || Abyss.env?(:development)
  $stdout.sync = true
  $stderr.sync = true

  SemanticLogger.add_appender(io: $stdout, formatter: Dawn.logger_format)
else
  SemanticLogger.add_appender(file_name: "log/#{Abyss.env}.log", formatter: Dawn.logger_format)
end

SemanticLogger.environment = Abyss.env
# TODO: Set hostname
