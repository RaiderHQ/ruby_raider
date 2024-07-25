# frozen_string_literal: true

require_relative '../generator'

module RubyRaider
  class ActionsGenerator < Generator
    def generate_actions_file
      return unless web?

      template('actions.tt', "#{name}/.github/workflows/test_pipeline.yml")
    end
  end
end
