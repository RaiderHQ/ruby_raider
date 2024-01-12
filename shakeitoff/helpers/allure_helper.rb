# frozen_string_literal: true

require 'allure-ruby-commons'
require 'allure-rspec'

module AllureHelper
  class << self
    def configure
      AllureRspec.configure do |config|
        config.results_directory = 'allure-results'
        config.clean_results_directory = true
      end
    end

    def add_screenshot(name, file)
      Allure.add_attachment(
        name:,
        source: file,
        type: Allure::ContentType::PNG,
        test_case: true
       )
     end

    def formatter
      AllureRspecFormatter
    end
  end
end
