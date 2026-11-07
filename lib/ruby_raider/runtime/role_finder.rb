# frozen_string_literal: true

require 'selenium-webdriver'

module Raider
  # The in-page role engine and the query that calls it.
  module RoleFinder
    ENGINE = File.read(File.join(__dir__, 'js', 'role_engine.js')).freeze
    QUERY = "if (!(window.__raider && window.__raider.role)) throw new Error('__raider not installed'); " \
            'return window.__raider.role(arguments[0] || document, arguments[1], arguments[2])'

    NATIVE_MESSAGE = 'by_role needs a web context; use accessibility_id on native screens'

    # Prepended to SearchContext: sends the :role key to the engine, everything else to Selenium.
    def find_elements(*args)
      role, options = RoleFinder.parse(args)
      return super unless role

      raise NotSupported, NATIVE_MESSAGE unless Context.web?(bridge)

      RoleQuery.run(bridge, is_a?(Selenium::WebDriver::Driver) ? nil : self, role, options)
    end

    def find_element(*args)
      return super unless RoleFinder.role_args?(args)

      find_elements(*args).first or
        raise Selenium::WebDriver::Error::NoSuchElementError, "no such element: #{Locator.describe(args)}"
    end

    def self.role_args?(args)
      key = args.size == 1 && args.first.is_a?(Hash) ? args.first.keys.first : args.first
      key.to_s == 'role'
    end

    # Returns [role, symbol-keyed options] for a role locator, nil for any other.
    def self.parse(args)
      return unless role_args?(args)

      value = args.size == 1 ? args.first.values.first : args[1]
      role, options = value.is_a?(Array) ? value : [value, nil]
      raise ArgumentError, 'role: needs a role name and an optional options Hash' unless options.nil? || options.is_a?(Hash)

      options = (options || {}).transform_keys(&:to_sym)
      raise ArgumentError, "role: name must be a String, got #{options[:name].class}" unless [NilClass, String].include?(options[:name].class)

      token = validated(role)
      RoleLocator.validated_level(token, options[:level])
      [token, options]
    end

    def self.validated(role)
      raise ArgumentError, "role: needs a role name, got #{role.inspect}" unless role.is_a?(String) || role.is_a?(Symbol)

      RoleLocator.validated_role(role)
    end
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
        'includeHidden' => options[:include_hidden] ? true : false,
        'level' => options[:level]
      }
    end
  end
end

Selenium::WebDriver::SearchContext.prepend(Raider::RoleFinder)
