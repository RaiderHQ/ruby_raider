# frozen_string_literal: true

target :lib do
  signature 'sig'

  check 'lib'

  # External gem stubs (not typed)
  library 'yaml'
  library 'fileutils'
  library 'erb'
  library 'open3'
  library 'timeout'
  library 'uri'
  library 'net-http'
  library 'json'
  library 'logger'
  library 'forwardable'

  # Configure strictness — start lenient, tighten over time
  configure_code_diagnostics(Steep::Diagnostic::Ruby.lenient)
end
