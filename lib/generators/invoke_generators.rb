require_relative 'actions/actions_generator'
require_relative 'automation/automation_generator'
require_relative 'common_generator'
require_relative 'cucumber/cucumber_generator'
require_relative 'helper_generator'
require_relative 'rspec/rspec_generator'

# :reek:FeatureEnvy { enabled: false }
# :reek:UtilityFunction { enabled: false }
module InvokeGenerators
  def generate_framework(structure = {})
    generators = %w[Automation Actions Common Helpers]
    framework = structure[:framework]
    add_generator(generators, framework.capitalize)
    generators.each do |generator|
      invoke_generator({
                         automation: structure[:automation],
                         framework: framework,
                         generator: generator,
                         name: structure[:name],
                         visual: structure[:visual]
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
                structure[:visual]]).invoke_all
  end
end
