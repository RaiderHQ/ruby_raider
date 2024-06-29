require_relative 'actions/actions_generator'
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
    generators = %w[Automation Actions Common Helpers]
    framework = structure[:framework]
    add_generator(generators, framework.capitalize)
    generators.each do |generator|
      invoke_generator({
                         automation: structure[:automation],
                         framework:,
                         generator:,
                         name: structure[:name],
                         visual: to_bool(structure[:visual]),
                         axe_support: to_bool(structure[:axe_support])
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
                structure[:visual],
                structure[:axe_support]]).invoke_all
  end

  def to_bool(string)
    return unless string.is_a? String

    string.downcase == 'true'
  end
end
