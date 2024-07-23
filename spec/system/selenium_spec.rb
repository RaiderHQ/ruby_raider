require_relative '../../lib/ruby_raider'

FRAMEWORKS = %w[cucumber rspec].freeze

describe 'Selenium based frameworks' do
  before do
    FRAMEWORKS.each do |framework|
      RubyRaider::Raider
        .new.invoke(:new, nil, %W[selenium_#{framework} -p framework:#{framework} automation:selenium])
    end
  end

  after do
    FRAMEWORKS.each do |framework|
      FileUtils.rm_rf("selenium_#{framework}")
    end
  end

  shared_examples 'creates web automation framework' do |type|
    it 'executes without errors' do
      run_tests_with(type)
      expect($stdout).not_to match(/StandardError/)
    end
  end

  context 'with rspec' do
    include_examples 'creates web automation framework', 'rspec'
  end

  context 'with cucumber' do
    include_examples 'creates web automation framework', 'cucumber'
  end

  private

  def run_tests_with(framework)
    folder = framework == 'rspec' ? 'spec' : 'features'
    system("cd selenium_#{framework} && bundle install && raider utility browser_options chrome headless && bundle exec #{framework} #{folder}")
  end
end
