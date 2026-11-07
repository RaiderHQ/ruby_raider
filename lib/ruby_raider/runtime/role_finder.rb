# frozen_string_literal: true

require 'selenium-webdriver'

module Raider
  # The in-page role engine and the query that calls it.
  module RoleFinder
    ENGINE = File.read(File.join(__dir__, 'js', 'role_engine.js')).freeze
    QUERY = "if (!(window.__raider && window.__raider.role)) throw new Error('__raider not installed'); " \
            'return window.__raider.role(arguments[0] || document, arguments[1], arguments[2])'
  end

  # Runs a role query through the bridge, installing the engine on first use.
  module RoleQuery
    module_function

    def run(bridge, scope, role, options)
      options_js = options_js(options)
      bridge.execute_script(RoleFinder::QUERY, scope, role, options_js)
    rescue Selenium::WebDriver::Error::JavascriptError => e
      raise unless e.message.include?('__raider')

      bridge.execute_script("#{RoleFinder::ENGINE}\n#{RoleFinder::QUERY}", scope, role, options_js)
    end

    def options_js(options)
      {
        'name' => options[:name],
        'exact' => options[:exact] ? true : false,
        'includeHidden' => options[:include_hidden] ? true : false
      }
    end
  end
end
