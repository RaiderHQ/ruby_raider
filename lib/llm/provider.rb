# frozen_string_literal: true

module Llm
  # Abstract base class for LLM providers
  # :reek:UtilityFunction { enabled: false }
  # :reek:UnusedParameters { enabled: false }
  class Provider
    def complete(prompt, system_prompt: nil)
      raise NotImplementedError, "#{self.class}#complete must be implemented"
    end

    def available?
      raise NotImplementedError, "#{self.class}#available? must be implemented"
    end

    def name
      self.class.name.split('::').last.sub('Provider', '').downcase
    end

    private

    def build_messages(prompt, system_prompt)
      messages = []
      messages << { role: 'system', content: system_prompt } if system_prompt
      messages << { role: 'user', content: prompt }
      messages
    end
  end
end
