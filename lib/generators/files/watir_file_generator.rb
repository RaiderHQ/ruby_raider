require_relative 'file_generator'

module RubyRaider
  class WatirFileGenerator < FileGenerator
    def self.generate_watir_files(name)
      generate_file('abstract_page.rb', "#{name}/page_objects/abstract", abstract_page)
      generate_file('abstract_component.rb', "#{name}/page_objects/abstract", abstract_component)
      generate_file('login_page.rb', "#{name}/page_objects/pages", example_page)
      generate_file('header_component.rb', "#{name}/page_objects/components", example_component)
    end

    def self.example_page
      page_file = ERB.new <<~EOF
        require_relative '../abstract/abstract_page'
        require_relative '../components/header_component'

        class LoginPage < AbstractPage

          using Raider::WatirHelper

          def url(_page)
            'index.php?rt=account/login'
          end

          # Actions

          def login(username, password)
            username_field.set username
            password_field.set password
            login_button.click_when_present
          end

          # Components

          def header
            HeaderComponent.new(browser.element(class: 'menu_text'))
          end

          private

          # Elements

          def username_field
            browser.text_field(id: 'loginFrm_loginname')
          end

          def password_field
            browser.text_field(id: 'loginFrm_password')
          end

          def login_button
            browser.button(visible_text: 'Login')
          end
        end
      EOF
      page_file.result(binding)
    end

    def self.abstract_page
      abstract_file = ERB.new <<~EOF
        require 'rspec'
        require_relative '../../helpers/raider'

        class AbstractPage

          include RSpec::Matchers
          extend Raider::PomHelper

          def browser
            Raider::BrowserHelper.browser
          end

          def visit(*page)
            browser.goto full_url(page.first)
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

    def self.abstract_component
      abstract_file = ERB.new <<~EOF
        require_relative '../../helpers/raider'

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
