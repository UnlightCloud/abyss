# frozen_string_literal: true

Abyss.app.register_provider :logger do
  start do
    require 'semantic_logger'
    require 'semantic_logger/sync'

    formatter = ENV.fetch('ABYSS_LOG_FORMAT') { ENV.fetch('DAWN_LOG_FORMAT', :color) }.to_sym
    to_stdout = ENV.fetch('ABYSS_LOG_TO_STDOUT') { ENV.fetch('DAWN_LOG_TO_STDOUT', false) }
    use_stdout = %w[true yes 1].include?(to_stdout)

    SemanticLogger.add_appender(file_name: "log/#{Abyss.env}.log", formatter:)
    SemanticLogger.add_appender(io: $stdout, formatter:) if use_stdout || Abyss.env?(:development)

    SemanticLogger.environment = Abyss.env

    register :logger, SemanticLogger[Abyss.app]
  end

  stop do
    SemanticLogger.flush
  end
end
