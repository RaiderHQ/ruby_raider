require_relative 'file_generator'

module RubyRaider
  class AutomationFileGenerator < FileGenerator
    def self.generate_automation_files(name, automation, framework)
      generate_file('abstract_page.rb', "#{name}/page_objects/abstract", abstract_page(automation, framework))
      generate_file('abstract_component.rb', "#{name}/page_objects/abstract", abstract_component(framework))
      generate_file('login_page.rb', "#{name}/page_objects/pages", example_page(automation))
      generate_file('header_component.rb', "#{name}/page_objects/components", example_component)
    end

    def self.example_page(automation)
      element = automation == 'watir' ? 'browser.element' : 'driver.find_element'
      page_file = ERB.new <<~EOF
        require_relative '../abstract/abstract_page'
        require_relative '../components/header_component'

        class LoginPage < AbstractPage

          using #{automation == 'watir' ? 'Raider::WatirHelper' : 'Raider::SeleniumHelper'}

          def url(_page)
            'index.php?rt=account/login'
          end

          # Actions

          def login(username, password)
            username_field.send_keys username
            password_field.send_keys password
            login_button.click_when_present
          end

          # Components

          def header
            HeaderComponent.new(#{element}(class: 'menu_text'))
          end

          private

          # Elements

          def username_field
            #{element}(id: 'loginFrm_loginname')
          end

          def password_field
            #{element}(id: 'loginFrm_password')
          end

          def login_button
            #{element}(xpath: "//button[@title='Login']")
          end
        end
      EOF
      page_file.result(binding)
    end

    def self.abstract_page(automation, framework)
      browser = "def browser
    Raider::BrowserHelper.browser
  end"
      driver = "def driver
    Raider::DriverHelper.driver
  end"
      visit = automation == 'watir' ? 'browser.goto full_url(page.first)' : 'driver.navigate.to full_url(page.first)'
      raider = if framework == 'rspec'
                 "require_relative '../../helpers/raider'"
               else
                 "require_relative '../../features/support/helpers/raider'"
               end
      abstract_file = ERB.new <<~EOF
        require 'rspec'
        #{raider}

        class AbstractPage

          include RSpec::Matchers
          extend Raider::PomHelper

          #{automation == 'watir' ? browser : driver}

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
      abstract_file.result(binding)
    end

    def self.example_component
      page_file = ERB.new <<~EOF
        require_relative '../abstract/abstract_component'

        class HeaderComponent < AbstractComponent

          def customer_name
            @component.text
          end
        end
      EOF
      page_file.result(binding)
    end

    def self.abstract_component(framework)
      raider = if framework == 'rspec'
                 "require_relative '../../helpers/raider'"
               else
                 "require_relative '../../features/support/helpers/raider'"
               end
      abstract_file = ERB.new <<~EOF
        #{raider}

        class AbstractComponent

            def initialize(component)
              @component = component
            end
        end
      EOF
      abstract_file.result(binding)
    end
  end
end
