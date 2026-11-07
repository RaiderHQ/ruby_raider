# frozen_string_literal: true

require 'rspec'
require_relative '../../../lib/ruby_raider/runtime'
require_relative '../../../lib/ruby_raider/runtime/rspec'
require_relative '../support/browser'

RSpec.describe 'Raider matchers in a real browser', :browser do
  include Raider::Matchers

  let(:driver) { Raider::Spec::Browser.driver }
  let(:heading) { driver.find_element(id: 'heading') }

  before do
    Raider.timeout = 2
    Raider::Spec::Browser.open('matchers.html')
  end

  after do
    Raider.reset
  end

  after(:all) { Raider::Spec::Browser.quit } # rubocop:disable RSpec/BeforeAfterAll

  it 'waits for the heading text to change' do
    expect(heading).to have_text('Ready')
  end

  it 'waits for a button to hide after a click' do
    button = driver.find_element(id: 'hide-me')
    button.click
    expect(button).to be_hidden
  end

  it 'reads an input value and its attributes' do
    field = driver.find_element(id: 'name')
    expect(field).to have_value('Ann')
    expect(field).to have_attribute('type', 'text')
    expect(field).to be_enabled
  end

  it 'waits for the list to grow to three items' do
    expect { driver.find_elements(css: 'li') }.to have_count(3)
  end

  it 'waits for the title and url after a click' do
    driver.find_element(id: 'finish').click
    expect(driver).to have_title('Done')
    expect(driver).to have_url(/#done$/)
  end

  it 'passes a negated matcher once the text has moved on' do
    expect(heading).not_to have_text('Loading')
  end

  it 'works in a plain class that mixes in both matcher modules' do
    world = Class.new do
      include RSpec::Matchers
      include Raider::Matchers

      def check(element)
        expect(element).to have_text('Ready', wait: 2)
      end
    end
    expect(world.new.check(heading)).to be(true)
  end
end
