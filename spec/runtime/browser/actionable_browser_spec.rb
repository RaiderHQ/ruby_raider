# frozen_string_literal: true

require 'rspec'
require_relative '../../../lib/ruby_raider/runtime'
require_relative '../support/browser'

RSpec.describe 'Raider::Actionable in a real browser', :browser do
  let(:driver) { Raider::Spec::Browser.driver }

  before do
    Raider.reset
    Raider.timeout = 1
    Raider::Spec::Browser.open('actionability.html')
  end

  after { Raider.reset }

  after(:all) { Raider::Spec::Browser.quit } # rubocop:disable RSpec/BeforeAfterAll

  def element(id)
    driver.find_element(id: id)
  end

  it 'refuses to click a button the overlay covers' do
    expect { element('covered').click }
      .to raise_error(Raider::NotActionable, /receive events; `div#overlay` covers it/)
  end

  it 'skips the checks with force: true and leaves the covered click to Selenium' do
    expect { element('covered').click(force: true) }
      .to raise_error(Selenium::WebDriver::Error::ElementClickInterceptedError)
  end

  it 'scrolls to and clicks an off-screen button' do
    element('far').click
    expect(element('far').attribute('data-clicked')).to eq('1')
  end

  it 'refuses a button in a disabled fieldset' do
    expect { element('in-fieldset').click }.to raise_error(Raider::NotActionable, /to be enabled/)
  end

  it 'refuses a button inside a closed details' do
    expect { element('in-details').click }.to raise_error(Raider::NotActionable, /to be visible/)
  end

  it 'names the sticky header covering a button' do
    expect { element('under-header').click }.to raise_error(Raider::NotActionable, /`header#top` covers it/)
  end

  it 'refuses to type into a readonly input' do
    expect { element('readonly').send_keys('x') }.to raise_error(Raider::NotActionable, /to be editable/)
  end

  it 'types into a contenteditable element' do
    element('editable').send_keys('hello')
    expect(element('editable').text).to include('hello')
  end

  it 'refuses a moving button' do
    expect { element('moving').click }.to raise_error(Raider::NotActionable, /to be stable/)
  end

  it 'lets Selenium select an option by text' do
    Selenium::WebDriver::Support::Select.new(element('choices')).select_by(:text, 'Blue')
    expect(element('choices').attribute('value')).to eq('blue')
  end

  it 'leaves the covered click to Selenium when actionability is off' do
    Raider.actionability = false
    expect { element('covered').click }.to raise_error(Selenium::WebDriver::Error::ElementClickInterceptedError)
  end

  it 'costs under 50 ms per click on a visible button', :slow do
    mean_ms = lambda do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      20.times { element('plain').click }
      (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) / 20 * 1000
    end
    Raider.actionability = true
    on_mean = mean_ms.call
    Raider.actionability = false
    off_mean = mean_ms.call
    puts format('actionability on %<on>.1f ms, off %<off>.1f ms, difference %<diff>.1f ms per click',
                on: on_mean, off: off_mean, diff: on_mean - off_mean)
    expect(on_mean - off_mean).to be < 50
  end
end
