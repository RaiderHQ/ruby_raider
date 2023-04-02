require 'dotenv'
require 'fileutils'
require 'pathname'
require 'yaml'
require_relative '../lib/generators/common_generator'
require_relative '../lib/commands/open_ai_commands'
require_relative '../lib/scaffolding/scaffolding'
require_relative 'spec_helper'

describe OpenAiCommands do
  let(:open_ai) { described_class }
  let(:name) { 'test' }

  orig_dir = Dir.pwd
  Dotenv.load

  after do
    Dir.chdir orig_dir
  end

  context 'without any project' do
    after do
      FileUtils.rm_rf('joke.txt')
    end

    # TODO: Enable test once the paid account is setup
    # it 'creates a file using open ai' do
    #   open_ai.new.invoke(:make, nil, ['tell me a joke', '--path', 'joke.txt'])
    #   expect(File).to be_size('joke.txt')
    # end

    it 'edits an existing file using open ai' do
      FileUtils.touch('joke.txt')
      open_ai.new.invoke(:make, nil, ['tell me a better joke', '--edit', 'joke.txt'])
    end
  end
end
