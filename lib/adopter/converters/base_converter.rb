# frozen_string_literal: true

module Adopter
  module Converters
    class BaseConverter
      RAIDER_BASE_CLASSES = %w[Page BasePage AbstractPage].freeze

      def convert_page(content, _page_info)
        content
      end

      def convert_test(content, _test_info)
        content
      end

      private

      def ensure_frozen_string_literal(content)
        return content if content.include?('frozen_string_literal')

        "# frozen_string_literal: true\n\n#{content}"
      end

      def update_base_class(content, target_base = 'Page')
        content.gsub(/class\s+(\w+)\s*<\s*([\w:]+)/) do
          class_name = ::Regexp.last_match(1)
          current_base = ::Regexp.last_match(2)
          if raider_compatible_base?(current_base)
            "class #{class_name} < #{target_base}"
          else
            "class #{class_name} < #{current_base}"
          end
        end
      end

      def raider_compatible_base?(base_class)
        RAIDER_BASE_CLASSES.include?(base_class) || base_class.include?('Page')
      end

      def update_require_paths(content, target_automation)
        result = content.dup
        result = update_page_requires(result)
        update_helper_requires(result, target_automation)
      end

      def update_page_requires(content)
        content.gsub(%r{require_relative\s+['"]\.*/(?:pages?|page_objects)/(\w+)['"]}) do
          page_name = ::Regexp.last_match(1)
          "require_relative '../page_objects/pages/#{page_name}'"
        end
      end

      def update_helper_requires(content, target_automation)
        case target_automation
        when 'capybara'
          content.gsub(%r{require_relative\s+['"]\.*/(?:helpers?|support)/(?:driver|browser)_?\w*['"]},
                       "require_relative '../helpers/capybara_helper'")
        when 'watir'
          content.gsub(%r{require_relative\s+['"]\.*/(?:helpers?|support)/(?:driver|capybara)_?\w*['"]},
                       "require_relative '../helpers/browser_helper'")
        else
          content.gsub(%r{require_relative\s+['"]\.*/(?:helpers?|support)/(?:browser|capybara)_?\w*['"]},
                       "require_relative '../helpers/driver_helper'")
        end
      end

      def remove_driver_arg(content)
        content.gsub(/(\w+)\.new\(\s*(?:driver|browser|page)\s*\)/, '\1.new')
      end

      def swap_driver_arg(content, target_arg)
        content.gsub(/(\w+)\.new\(\s*(?:driver|browser|page)\s*\)/, "\\1.new(#{target_arg})")
      end

      def driver_arg_for(target_automation)
        case target_automation
        when 'watir' then 'browser'
        when 'capybara' then nil
        else 'driver'
        end
      end
    end
  end
end
