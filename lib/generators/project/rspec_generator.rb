require_relative 'project_generator'

module RubyRaider
  class RspecGenerator < ProjectGenerator
    def self.generate_rspec_project(name)
      rspec_folder_structure name
      rspec_files name
    end

    def self.rspec_folder_structure(name)
      Dir.mkdir name.to_s
      folders = %w[config data page_objects helpers spec]
      create_children_folders(name, folders)
      pages = %w[pages abstract]
      create_children_folders("#{name}/page_objects", pages)
    end

    def self.rspec_files(name)
      generate_file('config.yml', "#{name}/config", config_file)
      generate_file('Gemfile', name.to_s, gemfile_template)
      generate_file('Rakefile', name.to_s, rake_file)
      generate_file('Readme.md', name.to_s, readme_file)
      generate_file('asbstract_page.rb', "#{name}/page_objects/abstract", example_abstract)
      generate_file('login_page.rb', "#{name}/page_objects", example_page)
      generate_file('login_spec.rb', "#{name}/spec", example_spec)
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

    def self.example_spec
      spec = ERB.new <<~EOF
        require_relative 'base_spec'
        require_relative '../page_objects/pages/login_page'

        class LoginSpec < BaseSpec
          context 'On the Login Page' do

            before(:each) do
              LoginPage.visit
            end

            describe 'A user can' do
              it 'login with the right credentials', :JIRA_123 do
                LoginPage.login('aguspe', '12341234')
                expect(LoginPage.customer_name).to eq 'Welcome back Agustin'
              end
            end

            describe 'A user cannot' do
              it 'login with the wrong credentials', :JIRA_123 do
                expect(LoginPage.customer_name).to eq 'Login or register'
              end
            end
          end
        end
      EOF
      spec.result(binding)
    end

    def self.example_page
      page_file = ERB.new <<~EOF
        require_relative '../abstract/base_page'
        require_relative '../components/header_component'

        class LoginPage < BasePage

          using Flaske::WatirHelper

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

    def self.example_abstract
      abstract_file = ERB.new <<~EOF
        require_relative '../components/header_component'
        require 'rspec'
        require_relative '../../spec/helpers/flaske'

        class BasePage

          include HeaderComponent
          include RSpec::Matchers
          extend Flaske::PomHelper

          def browser
            Flaske::BrowserHelper.browser
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

    def self.config_file
      config_file = ERB.new <<~EOF
        browser: chrome
      EOF
      config_file.result(binding)
    end

    def self.rake_file
      rake_file = ERB.new <<~EOF
        require 'yaml'

        desc 'Selects browser for automation run'
        task :select_browser, [:browser] do |_t, args|
          config = YAML.load_file('config/config.yml')
          config['browser'] = args.browser
          File.write('config/config.yml', config.to_yaml)
        end
      EOF
      rake_file.result(binding)
    end

    def self.readme_file
      rake_file = ERB.new <<~EOF
                What is Flaske?
        ===========

        Flaske is a web automation framework based on rspec, watir and ruby, I'm currently working on a gem with the same name, to make the generation and building of test frameworks like this one easier and more accessible.

        # Pre-requisites:

        Install RVM:
        https://rvm.io/rvm/install

        # How to use the framework:

        Clone the github repository, and in that folder run bundle or bundle install to install all the gem dependencies

        If you want to run all the tests from your terminal do:
        *rspec spec/*

        If you want to run all the tests in parallel do:
        *parallel_rspec spec/*

        # How are specs organized:

        We use 'context' as the highest grouping level to indicate in which part of the application we are as an example:

        *context 'On the login page'/*

        We use 'describe' from the user perspective to describe an action that the user can or cannot take:

        *describe 'A user can'/*

        or

        *describe 'A user cannot'/*

        This saves us repetition and forces us into an structure

        At last we use 'it' for the specific action the user can or cannot perform:

        it 'login with right credentials'

        If we group all of this together it will look like

        ```ruby
        context 'On the login page' do
          describe 'A user can' do
            it 'login with the right credentials' do
            end
           
          end
          
          describe 'A user cannot' do
            it 'login with the wrong credentials' do
            end
          end
        end
        ```
            
        This is readed as 'On the login page a user can login with the right credentials' and 'On the login page a user cannot login with the wrong credentials'

        # How pages are organized:

        ```ruby 
        require_relative '../abstract/base_page'

        class MainPage < BasePage

          using Flaske::WatirHelper

          def url(_page)
            '/'
          end

          # Actions

          def change_currency(currency)
            currency_dropdown.select currency
          end

          # Validations

          def validate_currency(currency)
            expect(currency_dropdown.include?(currency)).to be true
          end

          private

          # Elements

          def currency_dropdown
            browser.select(class: %w[dropdown-menu currency])
          end
        end
        ```

        Pages are organized in Actions (things a user can perform on the page), Validations (assertions), and Elements.
        Each page has to have a url define, and each page is using the module WatirHelper to add methods on runtime to the Watir elements

      EOF
      rake_file.result(binding)
    end
  end
end
