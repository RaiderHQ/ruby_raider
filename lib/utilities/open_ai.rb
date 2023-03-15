require 'openai'
require 'fileutils'

module OpenAi
  class << self
    def create_client
      configure_client
      OpenAI::Client.new
    end

    def configure_client
      OpenAI.configure do |config|
        config.access_token = ENV.fetch('OPENAI_ACCESS_TOKEN') # Required
        config.organization_id = ENV.fetch('OPENAI_ORGANIZATION_ID') # Optional.
      end
    end

    def input(model = "gpt-3.5-turbo", temperature = 0.7, request)
      create_client.chat(
        parameters: {
          model: model,
          messages: [{ role: "user", content: request }],
          temperature: temperature
        })
    end

    def create_file(choice = 0, path, request)
      response = input(request)
      File.write(path, response.dig("choices", choice, "message", "content"))
    end
  end
end
