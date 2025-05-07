# frozen_string_literal: true

require_relative '../generator'

class GithubGenerator < Generator
  def generate_actions_file
    return unless web?

    template('github.tt', "#{name}/.github/workflows/test_pipeline.yml")
  end
end
