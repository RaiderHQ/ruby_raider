# frozen_string_literal: true

require_relative '../generator'

class GitlabGenerator < Generator
  def generate_gitlab_file
    return unless web?

    template('gitlab.tt', "#{name}/gitlab-ci.yml")
  end
end
