# frozen_string_literal: true

require_relative 'file_generator'

module RubyRaider
  class RspecFileGenerator < FileGenerator
    argument :automation, value: 'hi'
    argument :framework, value: 'heyo'
    argument :name, value: 'bye'

    def generate_spec
      template('templates/rspec/spec.tt', "#{name}/spec/login_page_spec.rb")
    end

    def generate_base_spec
      template('templates/rspec/base_spec.tt', "#{name}/spec/base_spec.rb")
    end
  end
end
