require 'thor'
require_relative '../open_ai/open_ai'

class OpenAiCommands < Thor
  desc 'open_ai [REQUEST]', 'Uses open AI to create a file or generate output'
  option :path,
         type: :string, required: false, desc: 'The path where your file will be created', aliases: '-p'
  option :edit,
         type: :string, required: false, desc: 'Path to the file you want to edit', aliases: '-e'

  def make(request, path = nil)
    path ||= options[:path]
    if options[:edit]
      pp 'Editing File...'
      OpenAi.edit_file(options[:edit], request)
      pp "File #{options[:edit]} edited"
    elsif path
      pp 'Generating File...'
      OpenAi.create_file(path, request)
      pp "File created in #{path}"
    else
      puts OpenAi.output(request)
    end
  end

  desc 'cucumber [NAME]', 'Creates feature and step files only using open ai'
  option :prompt,
         type: :string,
         required: false, desc: 'The prompt for open ai', aliases: '-p'

  def cucumber(name)
    feature_path = "features/#{name}.feature"
    make(options[:prompt], feature_path)
    prompt_step = "create cucumber steps for the following scenarios in ruby #{File.read(feature_path)}"
    make(prompt_step, "features/step_definitions/#{name}_steps.rb")
  end

  desc 'steps [NAME]', 'Creates a new step definitions file'
  option :path,
         type: :string,
         required: false, desc: 'The path where your steps will be created', aliases: '-p'
  option :prompt,
         type: :string, required: false,
         desc: 'This will create the selected steps based on your prompt using open ai', aliases: '-pr'
  option :input,
         type: :string,
         required: false, desc: 'It uses a file as input to create the steps', aliases: '-i'

  def steps(name)
    path = 'features/step_definitions'
    if options[:input]
      prompt = options[:prompt] || 'create cucumber steps for the following scenarios in ruby'
      content = "#{prompt} #{File.read(options[:input])}"
      make(content, "#{path}/#{name}_steps.rb")
    else
      make(options[:open_ai], "#{path}/#{name}_steps.rb")
    end
  end
end
