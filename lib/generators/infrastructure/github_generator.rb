# frozen_string_literal: true

require_relative '../generator'

class GithubGenerator < Generator
  def generate_actions_file
    return unless web?

    template('github.tt', "#{name}/.github/workflows/test_pipeline.yml")
  end

  def generate_appium_pipeline
    return unless mobile?

    template('github_appium.tt', "#{name}/.github/workflows/appium_pipeline.yml")
  end
end
