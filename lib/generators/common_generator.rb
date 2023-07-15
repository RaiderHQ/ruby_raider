# frozen_string_literal: true

require_relative 'generator'

class CommonGenerator < Generator
  def generate_readme_file
    template('common/read_me.tt', "#{name}/Readme.md")
  end

  def generate_config_file
    return if single_platform?

    template('common/config.tt', "#{name}/config/config.yml")
  end

  def generate_rake_file
    template('common/rakefile.tt', "#{name}/Rakefile")
  end

  def generate_gemfile
    template('common/gemfile.tt', "#{name}/Gemfile")
  end

  def generate_reek_file
    template('common/reek.tt', "#{name}/.reek.yml")
  end

  def generate_rubocop_file
    template('common/rubocop.tt', "#{name}/.rubocop.yml")
  end

  def create_allure_folder
    empty_directory "#{name}/allure-results"
  end

  def create_screenshots_folder
    empty_directory "#{name}/allure-results/screenshots"
  end
end
