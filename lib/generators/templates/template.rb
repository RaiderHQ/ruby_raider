require 'erb'

class Template
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
