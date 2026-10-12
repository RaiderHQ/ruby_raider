# frozen_string_literal: true

require_relative '../generator'

class AzureGenerator < Generator
  def generate_azure_pipeline
    return unless azure? && web?

    template('azure_pipelines.tt', "#{name}/azure-pipelines.yml")
  end
end
