# :reek:FeatureEnvy { enabled: false }
# :reek:UtilityFunction { enabled: false }

module SettingsHelper
  def create_settings(options)
    automation = options[:automation]
    framework = options[:framework]
    {
      automation:,
      framework:,
      name: "#{framework}_#{automation}"
    }
  end
end
