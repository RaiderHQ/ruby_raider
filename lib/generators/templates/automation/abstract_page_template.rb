require_relative '../template'

class AbstractPageTemplate < Template

  def raider
    if @framework == 'rspec'
      "require_relative '../../helpers/raider'"
    else
      "require_relative '../../features/support/helpers/raider'"
    end
  end

  def helper_selector
    if @automation == 'watir'
      <<~EOF

        def browser
          Raider::BrowserHelper.browser
        end
      EOF
    else
      <<~EOF

        def driver
          Raider::DriverHelper.driver
        end
      EOF
    end
  end

  def visit
    if %w[selenium watir].include?(@automation)
      <<~EOF

        def visit(*page)
          #{@automation == 'selenium' ? 'driver.navigate.to full_url(page.first)' : 'browser.goto full_url(page.first)'}
        end
      EOF
    end
  end

  def url_methods
    methods = <<~EOF

      def full_url(*page)
        "#\{base_url}#\{url(*page)}"
      end

      def base_url
        'https://automationteststore.com/'
      end

      def url(_page)
        raise 'Url must be defined on child pages'
      end
    EOF

    if %w[selenium watir].include?(@automation)
      methods
    else
      ''
    end
  end

  def body
    <<~EOF
      require 'rspec'
      #{raider}
      class AbstractPage

        include RSpec::Matchers
        extend Raider::PomHelper
        #{helper_selector}
        #{visit}
        #{url_methods}
      end
    EOF
  end
end
