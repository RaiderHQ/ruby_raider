# :reek:FeatureEnvy { enabled: false }
# :reek:UtilityFunction { enabled: false }

module SettingsHelper
  def create_settings(options)
    automation = options[:automation]
    framework = options[:framework]
    ci_platform = options[:ci_platform]
    {
      automation:,
      framework:,
      ci_platform:,
      name: ci_platform ? "#{framework}_#{automation}_#{ci_platform}" : "#{framework}_#{automation}",
    }
  end
end
