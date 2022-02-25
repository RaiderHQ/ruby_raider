require_relative 'file_generator'

module RubyRaider
  class WatirFileGenerator < FileGenerator
    def self.generate_watir_files(name)
      generate_file('abstract_page.rb', "#{name}/page_objects/abstract", abstract_page)
      generate_file('abstract_component.rb', "#{name}/page_objects/abstract", abstract_component)
      generate_file('login_page.rb', "#{name}/page_objects/pages", example_page)
      generate_file('header_component.rb', "#{name}/page_objects/components", example_component)
      generate_file('Gemfile', name.to_s, gemfile_template)
    end

    def self.gemfile_template
      gemfile = ERB.new <<~EOF
        # frozen_string_literal: true

        source 'https://rubygems.org'

        gem 'activesupport'
        gem 'allure-rspec'
        gem 'allure-ruby-commons'
        gem 'parallel_split_test'
        gem 'parallel_tests'
        gem 'rake'
        gem 'rspec'
        gem 'selenium-webdriver'
        gem 'watir'
        gem 'webdrivers'
      EOF
      gemfile.result(binding)
    end

    def self.example_page
      page_file = ERB.new <<~EOF
        require_relative '../abstract/abstract_page'
        require_relative '../components/header_component'

        class LoginPage < BasePage

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
        require_relative '../components/header_component'
        require_relative '../../helpers/raider'

        class BasePage

          include HeaderComponent
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

        module HeaderComponent

          include BaseComponent

          def customer_name
            sleep 2
            customer_menu.text
          end

          private

          # Elements

          def customer_menu
            browser.element(id: 'customer_menu_top')
          end
        end
      EOF
      page_file.result(binding)
    end

    def self.abstract_component
      abstract_file = ERB.new <<~EOF
        require_relative '../../helpers/raider'

        module BaseComponent; end
      EOF
      abstract_file.result(binding)
    end
  end
end
