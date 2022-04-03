require_relative '../template'

class AllureHelperTemplate < Template
  def body
    if @framework == 'cucumber'
      gems = "require 'allure-cucumber'"
      allure = 'AllureCucumber'
    else
      gems = "require 'allure-ruby-commons'
require 'allure-rspec'"
      allure = 'AllureRspec'
    end
    <<~EOF
            #{gems}

            module Raider
              module AllureHelper
                class << self

                  def configure
                    #{allure}.configure do |config|
                      config.results_directory = 'allure-results'
                      config.clean_results_directory = true
                    end
                  end

                  def add_screenshot(screenshot_name)
                    Allure.add_attachment(
                      name: name,
                      source: "File.open(allure-results/screenshots/\#{screenshot_name}.png)",
                      type: Allure::ContentType::PNG,
                      test_case: true
                    )
                  end

                  #{
      if @framework == 'rspec'
        'def formatter
            AllureRspecFormatter
          end'
      end }
                end
              end
            end
    EOF
  end
end
