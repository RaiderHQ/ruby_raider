require 'thor'
require_relative 'infrastructure/github_generator'
require_relative 'infrastructure/azure_generator'
require_relative 'automation/automation_generator'
require_relative 'common_generator'
require_relative 'cucumber/cucumber_generator'
require_relative 'helper_generator'
require_relative 'rspec/rspec_generator'

module InvokeGenerators
  FRAMEWORKS = %w[rspec cucumber].freeze
  AUTOMATIONS = %w[selenium watir appium ios android cross_platform].freeze

  module_function

  def generate_framework(structure = {})
    structure = normalise_options(structure)
    validate_option(:framework, structure[:framework], FRAMEWORKS)
    validate_option(:automation, structure[:automation], AUTOMATIONS)
    validate_ci(structure[:ci])
    generators = %w[Automation Common Helpers]
    framework = structure[:framework]
    add_generator(generators, framework.capitalize)
    add_generator(generators, 'Github', 'Azure')
    extra_args = collect_flags(structure)
    generators.each do |generator|
      invoke_generator({
                         automation: structure[:automation],
                         framework:,
                         generator:,
                         name: structure[:name],
                         extra_args:
                       })
    end
    print_mobile_azure_notice(structure)
  end

  def normalise_options(structure)
    structure.merge(
      framework: structure[:framework].to_s.downcase,
      automation: structure[:automation].to_s.downcase
    )
  end

  def validate_option(key, value, allowed)
    return if allowed.include?(value.to_s)

    raise Thor::Error, "Invalid #{key} #{value.to_s.inspect}. Allowed values: #{allowed.join(', ')}"
  end

  def validate_ci(provider)
    return if [nil, '', 'github', 'azure'].include?(provider&.to_s)

    raise Thor::Error, 'ci must be github or azure'
  end

  def print_mobile_azure_notice(structure)
    return unless structure[:ci].to_s == 'azure' && mobile_automation?(structure[:automation])

    puts 'Azure Pipelines template for mobile projects is not available yet; see the README.'
  end

  def add_generator(generators, *gens)
    gens.each { |generator| generators.push generator }
  end

  # Generator class lookup cache — avoids repeated Object.const_get string interpolation
  GENERATOR_CLASSES = Hash.new { |h, k| h[k] = Object.const_get("#{k}Generator") }

  def invoke_generator(structure = {})
    args = [structure[:automation], structure[:framework], structure[:name]]
    args.concat(structure[:extra_args] || [])
    generator_class = GENERATOR_CLASSES[structure[:generator]]
    generator = generator_class.new(args)
    # Enable batch mode on the template cache to skip mtime checks during generation
    generator.class.template_renderer.batch_mode = true if generator.class.respond_to?(:template_renderer)
    generator.invoke_all
  end

  def collect_flags(structure)
    flags = []
    flags << 'axe_addon' if structure[:accessibility] && !mobile_automation?(structure[:automation])
    flags << 'azure' if structure[:ci].to_s == 'azure'
    flags
  end

  def mobile_automation?(automation)
    %w[ios android cross_platform].include?(automation)
  end

  def to_bool(string)
    return unless string.is_a? String

    string.downcase == 'true'
  end
end
