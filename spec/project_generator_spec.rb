require_relative '../lib/generators/project/project_generator'
require_relative '../lib/ruby_raider'

include RubyRaider

describe 'A folder is generated' do
  it 'creates a folder' do
    RubyRaider.generate_project 'test'
  end
end
