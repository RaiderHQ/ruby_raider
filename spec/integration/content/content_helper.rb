# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../frozen_string_literal_matcher'

module ContentHelper
  def read_generated(project, relative_path)
    File.read(File.join(project, relative_path))
  end

  def project(framework, automation)
    "#{framework}_#{automation}"
  end
end

RSpec::Matchers.define :have_valid_ruby_syntax do
  match do |content|
    RubyVM::InstructionSequence.compile(content)
    true
  rescue SyntaxError
    false
  end
  failure_message { |_content| "expected valid Ruby syntax but got SyntaxError: #{$ERROR_INFO&.message}" }
end

RSpec.configure do |config|
  config.include(ContentHelper)
end
