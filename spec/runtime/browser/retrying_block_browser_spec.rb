# frozen_string_literal: true

require 'rspec'
require_relative '../../../lib/ruby_raider/runtime'
require_relative '../../../lib/ruby_raider/runtime/rspec'
require_relative '../support/browser'

RSpec.describe 'Raider block expectations in a real browser', :browser do
  include Raider::Matchers

  let(:driver) { Raider::Spec::Browser.driver }

  before do
    Raider.reset
    Raider.timeout = 3
    Raider::Spec::Browser.open('actionability.html')
  end

  after { Raider.reset }

  after(:all) { Raider::Spec::Browser.quit } # rubocop:disable RSpec/BeforeAfterAll

  it 'waits for text set after 300 ms' do
    driver.execute_script(<<~JS)
      document.body.insertAdjacentHTML('beforeend', '<p id="status">pending</p>');
      setTimeout(() => { document.getElementById('status').textContent = 'done'; }, 300);
    JS
    expect { driver.find_element(id: 'status').text }.to eq('done')
  end

  it 'finds an element inserted after 300 ms through have_element' do
    driver.execute_script(<<~JS)
      setTimeout(() => document.body.insertAdjacentHTML('beforeend', '<p id="late-p">x</p>'), 300);
    JS
    expect(driver).to have_element(id: 'late-p')
  end
end
