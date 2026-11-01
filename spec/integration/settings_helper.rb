module SettingsHelper
  def create_settings(options)
    automation = options[:automation]
    framework = options[:framework]
    settings = {
      automation:,
      framework:,
      name: "#{framework}_#{automation}"
    }
    return settings unless options[:examples] == false

    settings.merge(examples: false, name: "skeleton_#{framework}_#{automation}")
  end
end
