require 'openai'
require 'fileutils'

module OpenAi
  class << self
    def client
      @client ||= create_client
    end

    def create_client
      configure_client
      OpenAI::Client.new
    end

    def configure_client
      OpenAI.configure do |config|
        config.access_token = ENV.fetch('OPENAI_ACCESS_TOKEN')
        config.organization_id = ENV.fetch('OPENAI_ORGANIZATION_ID', nil)
      end
    end

    def input(request, model = 'gpt-3.5-turbo', temperature = 0.7)
      client.chat(
        parameters: {
          model: model,
          messages: [{ role: 'user', content: request }],
          temperature: temperature
        })
    end

    def create_file(path, request, choice = 0)
      File.write(path, output(request, choice))
    end

    def output(request, choice = 0)
      extract_text(input(request), 'choices', choice, 'message', 'content')
    end

    def edit_file(path, request, choice = 0)
      content = File.read(path)
      response = edit(content, request)
      File.write(path, extract_text(response, 'choices', choice, 'text'))
    end

    def edit(input, request, model = 'text-davinci-edit-001')
      client.edits(
        parameters: {
          model: model,
          input: input,
          instruction: request
        }
      )
    end

    private

    def extract_text(response, *keys)
      response.dig(*keys)
    end
  end
end
