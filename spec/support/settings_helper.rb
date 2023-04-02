# :reek:FeatureEnvy { enabled: false }
# :reek:UtilityFunction { enabled: false }

module SettingsHelper
  def create_settings(options)
    automation = options[:automation]
    examples = options[:examples]
    visual = options[:visual]
    framework = options[:framework]
    {
      automation: automation,
      examples: examples,
      framework: framework,
      name: "#{framework}_#{automation}#{'_visual' if visual}#{'_without_examples' unless examples}",
      visual: visual
    }
  end
end
