# frozen_string_literal: true

require_relative '../generator'

class CucumberGenerator < Generator
  def generate_env_file
    template('env.tt', "#{name}/features/support/env.rb")
  end

  def generate_world
    template('world.tt', "#{name}/world.rb")
  end
end
