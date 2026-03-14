# frozen_string_literal: true

require_relative 'base_converter'

module Adopter
  module Converters
    class IdentityConverter < BaseConverter
      def initialize(target_automation)
        super()
        @target_automation = target_automation
      end

      def convert_page(content, _page_info)
        result = content.dup
        result = ensure_frozen_string_literal(result)
        result = update_base_class(result)
        result = add_page_require(result)
        update_page_instantiation(result)
      end

      def convert_test(content, _test_info)
        result = content.dup
        result = ensure_frozen_string_literal(result)
        result = update_require_paths(result, @target_automation)
        update_page_instantiation(result)
      end

      def convert_step(content)
        result = content.dup
        result = ensure_frozen_string_literal(result)
        result = update_require_paths(result, @target_automation)
        update_page_instantiation(result)
      end

      private

      def add_page_require(content)
        return content if content.include?("require_relative '../abstract/page'")

        content.sub(/^(class\s)/, "require_relative '../abstract/page'\n\n\\1")
      end

      def update_page_instantiation(content)
        arg = driver_arg_for(@target_automation)
        if arg
          swap_driver_arg(content, arg)
        else
          remove_driver_arg(content)
        end
      end
    end
  end
end
