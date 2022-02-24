require_relative '../lib/ruby_raider'

include RubyRaider

describe 'A folder is generated' do
  it 'creates a folder' do
    RubyRaider.generate_rspec_project 'test'
  end
end
