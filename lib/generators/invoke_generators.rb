require_relative 'infrastructure/github_generator'
require_relative 'automation/automation_generator'
require_relative 'common_generator'
require_relative 'cucumber/cucumber_generator'
require_relative 'helper_generator'
require_relative 'rspec/rspec_generator'

module InvokeGenerators
  module_function

  def generate_framework(structure = {})
    generators = %w[Automation Common Helpers]
    framework = structure[:framework]
    add_generator(generators, framework.capitalize)
    add_generator(generators, 'Github')
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
