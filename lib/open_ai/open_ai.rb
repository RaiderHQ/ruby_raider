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

    def create_file(options)
      path, request, choice = options.values_at(:path, :request, :choice)
      File.write(path, output(request: request, choice: choice))
    end

    def output(options)
      request, choice = options.values_at(:request, :choice)
      choice ||= 0
      extract_text(input(request), 'choices', choice, 'message', 'content')
    end

    def edit_file(options)
      path, request, choice = options.values_at(:path, :request, :choice)
      content = File.read(path)
      response = edit(content: content, request: request)
      File.write(path, extract_text(response, 'choices', choice, 'text'))
    end

    def edit(options)
      content, request, model = options.values_at(:content, :request, :model)
      model ||= 'text-davinci-edit-001'
      client.edits(
        parameters: {
          model: model,
          input: content,
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
