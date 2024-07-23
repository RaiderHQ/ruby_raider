require_relative '../../lib/ruby_raider'

describe 'Selenium and Rspec framework' do
  before do
    RubyRaider::Raider.new.invoke(:new, nil, %w[selenium_rspec -p framework:rspec automation:selenium])
  end

  after do
    FileUtils.rm_rf('selenium_rspec')
  end

  it 'creates a selenium and rspec framework' do
    system('cd selenium_rspec && bundle install && raider utility browser_options chrome headless && bundle exec rspec')
  end
end
