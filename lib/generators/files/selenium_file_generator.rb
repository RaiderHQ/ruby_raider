require_relative 'file_generator'

module RubyRaider
  class SeleniumFileGenerator < FileGenerator
    def self.generate_selenium_files(name)
      generate_file('abstract_page.rb', "#{name}/page_objects/abstract", abstract_page)
      generate_file('abstract_page_object.rb', "#{name}/page_objects/abstract", abstract_page_object)
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
        gem 'webdrivers'

      EOF
      gemfile.result(binding)
    end

    def self.example_page
      gemfile = ERB.new <<~EOF
        require_relative '../abstract/abstract_page'
        require_relative '../components/header_component'
        require_relative '../../helpers/selenium_helper'

        class LoginPage < AbstractPage

          def url(_page)
            'index.php?rt=account/login'
          end

          # Actions

          def login(username, password)
            username_field.send_keys username
            password_field.send_keys password
            login_button.click_when_present
          end

          def header
            HeaderComponent.new(driver.find_element(class: 'menu_text'))
          end

          private

          # Elements

          def username_field
            driver.find_element(id: 'loginFrm_loginname')
          end

          def password_field
            driver.find_element(id: 'loginFrm_password')
          end

          def login_button
            driver.find_element(xpath: "//button[@title='Login']")
          end
        end



      EOF
      gemfile.result(binding)
    end

    def self.abstract_page
      abstract_file = ERB.new <<~EOF
        require_relative '../components/header_component'
        require_relative 'abstract_page_object'
        require 'rspec'

        class AbstractPage < AbstractPageObject
          include RSpec::Matchers

          def visit(*page)
            driver.navigate.to full_url(page.first)
          end

          def full_url(*page)
            "\#{base_url}\#{url(*page)}"
          end

          def base_url
            'https://automationteststore.com/'
          end

          def url(_page)
            raise 'Url must be defined on child pages'
          end

          def header
            HeaderComponent.new(driver.find_element(css: 'header'))
          end
        end

      EOF
      abstract_file.result(binding)
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

    def self.abstract_page_object
      abstract_file = ERB.new <<~EOF
        require_relative '../../helpers/raider'

        class AbstractPageObject
          extend Raider::PomHelper

          def driver
            Raider::DriverHelper.driver
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
  end
end
