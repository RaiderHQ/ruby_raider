# frozen_string_literal: true

require_relative '../generator'

class ActionsGenerator < Generator
  def generate_actions_file
    return unless web?

    template('templates/actions.tt', "#{name}/.github/workflows/test_pipeline.yml")
  end
end
