# frozen_string_literal: true

require 'erb'

# General abstraction of templates
class Template
  attr_reader :automation
  attr_reader :framework
  attr_reader :name

  def initialize(args = {})
    @automation = args[:automation]
    @name = args[:name]
    @framework = args[:framework]
  end

  def parsed_body
    parsed_body = ERB.new body
    parsed_body.result(binding)
  end
end
