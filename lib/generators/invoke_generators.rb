require_relative 'infrastructure/github_generator'
require_relative 'automation/automation_generator'
require_relative 'common_generator'
require_relative 'cucumber/cucumber_generator'
require_relative 'helper_generator'
require_relative 'rspec/rspec_generator'

# :reek:FeatureEnvy { enabled: false }
# :reek:UtilityFunction { enabled: false }
module InvokeGenerators
  module_function

  def generate_framework(structure = {})
    generators = %w[Automation Common Helpers]
    framework = structure[:framework]
    add_generator(generators, framework.capitalize)
    add_generator(generators, structure[:ci_platform].capitalize) if structure[:ci_platform]
    generators.each do |generator|
      invoke_generator({
                         automation: structure[:automation],
                         framework:,
                         generator:,
                         ci_platform: structure[:ci_platform],
                         name: structure[:name]
                       })
    end
  end

  def add_generator(generators, *gens)
    gens.each { |generator| generators.push generator }
  end

  def invoke_generator(structure = {})
    Object.const_get("#{structure[:generator]}Generator")
          .new([structure[:automation],
                structure[:framework],
                structure[:name],
                structure[:ci_platform]]).invoke_all
  end

  def to_bool(string)
    return unless string.is_a? String

    string.downcase == 'true'
  end
end
