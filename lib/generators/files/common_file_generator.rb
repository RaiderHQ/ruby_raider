require_relative 'file_generator'

module RubyRaider
  class CommonFileGenerator < FileGenerator
    def self.generate_common_files(name)
      generate_file('config.yml', "#{name}/config", config_file)
      generate_file('Rakefile', name.to_s, rake_file)
      generate_file('Readme.md', name.to_s, readme_file)
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
        #{'   '}
          end
        #{'  '}
          describe 'A user cannot' do
            it 'login with the wrong credentials' do
            end
          end
        end
        ```
        #{'    '}
        This is readed as 'On the login page a user can login with the right credentials' and 'On the login page a user cannot login with the wrong credentials'

        # How pages are organized:

        ```ruby#{' '}
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
  end
end