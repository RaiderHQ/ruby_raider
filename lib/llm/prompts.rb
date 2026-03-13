# frozen_string_literal: true

module Llm
  # Centralized prompt templates for LLM-enhanced code generation.
  # All prompts instruct the model to return JSON matching specific schemas.
  module Prompts
    module_function

    def analyze_page(html, url)
      <<~PROMPT
        Analyze this HTML page and extract all interactive elements that would be useful for a page object model in UI test automation.

        URL: #{url}

        HTML:
        #{html[0..8000]}

        Return a JSON object with this exact structure:
        {
          "elements": [
            {
              "name": "descriptive_snake_case_name",
              "type": "input|select|textarea|button|submit|link",
              "locator": {"type": "id|name|css|xpath", "value": "the_locator"},
              "purpose": "brief description of what this element does",
              "input_type": "text|email|password|etc (only for inputs)",
              "text": "visible text (only for buttons/links)"
            }
          ]
        }

        Guidelines:
        - Use semantic, descriptive names (e.g., "email_field" not "input_1", "submit_login" not "button_1")
        - Prefer ID locators, then name, then CSS, then XPath
        - Skip hidden inputs and purely decorative elements
        - Include up to 5 important links
        - The "purpose" field should be a brief, clear description

        Return ONLY the JSON object, no other text.
      PROMPT
    end

    def generate_test_scenarios(class_name, methods, automation, framework)
      methods_desc = methods.map do |m|
        params = m[:params].empty? ? '' : "(#{m[:params].join(', ')})"
        "  - #{m[:name]}#{params}"
      end.join("\n")

      <<~PROMPT
        Generate meaningful test scenarios for this page object class used in UI test automation.

        Class: #{class_name}
        Automation: #{automation}
        Framework: #{framework}
        Public methods:
        #{methods_desc}

        Return a JSON object with this exact structure:
        {
          "scenarios": [
            {
              "method": "method_name",
              "description": "human-readable test description",
              "assertion_hint": "what to assert after calling this method"
            }
          ]
        }

        Guidelines:
        - Generate one scenario per method
        - Descriptions should read naturally (e.g., "fills in the login form with valid credentials")
        - Assertion hints should be specific (e.g., "expect page to redirect to dashboard")
        - Consider the class name for context about what page this is

        Return ONLY the JSON object, no other text.
      PROMPT
    end

    def system_prompt
      'You are a UI test automation expert. You generate clean, idiomatic Ruby code ' \
        'for page object models and test specs. Always return valid JSON when asked for JSON.'
    end
  end
end
