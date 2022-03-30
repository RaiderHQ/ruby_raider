require_relative 'template'

class AbstractPageTemplate < Template
  def body
    browser = "def browser
    Raider::BrowserHelper.browser
  end"
    driver = "def driver
    Raider::DriverHelper.driver
  end"

    visit = @automation == 'watir' ? 'browser.goto full_url(page.first)' : 'driver.navigate.to full_url(page.first)'
    raider = if @framework == 'rspec'
               "require_relative '../../helpers/raider'"
             else
               "require_relative '../../features/support/helpers/raider'"
             end

    <<~EOF
        require 'rspec'
        #{raider}

        class AbstractPage

          include RSpec::Matchers
          extend Raider::PomHelper

          #{@automation == 'watir' ? browser : driver}

          def visit(*page)
            #{visit}
          end

          def full_url(*page)
            "#\{base_url}#\{url(*page)}"
          end

          def base_url
            'https://automationteststore.com/'
          end

          def url(_page)
            raise 'Url must be defined on child pages'
          end
        end
    EOF
  end
end
