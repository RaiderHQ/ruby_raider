# frozen_string_literal: true

require 'rspec'
require_relative '../../../lib/ruby_raider/runtime'
require_relative '../support/browser'

RSpec.describe 'Raider find waits in a real browser', :browser do
  let(:driver) { Raider::Spec::Browser.driver }

  before do
    Raider.reset
    Raider.timeout = 3
    Raider::Spec::Browser.open('actionability.html')
  end

  after { Raider.reset }

  after(:all) { Raider::Spec::Browser.quit } # rubocop:disable RSpec/BeforeAfterAll

  def insert_after(delay, html)
    driver.execute_script(<<~JS, delay, html)
      const [delay, html] = arguments;
      setTimeout(() => document.body.insertAdjacentHTML('beforeend', html), delay);
    JS
  end

  it 'finds and clicks a button inserted after 300 ms' do
    driver.execute_script('window.clicked = false')
    insert_after(300, '<button id="late" onclick="window.clicked = true">Late</button>')
    driver.find_element(id: 'late').click
    expect(driver.execute_script('return window.clicked')).to be(true)
  end

  it 'returns three rows inserted after 300 ms from find_elements' do
    insert_after(300, '<p class="late-row">1</p><p class="late-row">2</p><p class="late-row">3</p>')
    expect(driver.find_elements(css: '.late-row').size).to eq(3)
  end
end
