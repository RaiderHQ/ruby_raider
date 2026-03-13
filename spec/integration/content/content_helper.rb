# frozen_string_literal: true

require_relative '../spec_helper'

module ContentHelper
  # :reek:UtilityFunction { enabled: false }
  def read_generated(project, relative_path)
    File.read(File.join(project, relative_path))
  end

  def project(framework, automation, ci_platform = nil)
    ci_platform ? "#{framework}_#{automation}_#{ci_platform}" : "#{framework}_#{automation}"
  end
end

RSpec::Matchers.define :have_frozen_string_literal do
  match { |content| content.include?('# frozen_string_literal: true') }
  failure_message { 'expected file to contain frozen_string_literal magic comment' }
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
