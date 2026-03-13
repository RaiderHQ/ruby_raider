require_relative 'infrastructure/github_generator'
require_relative 'infrastructure/gitlab_generator'
require_relative 'automation/automation_generator'
require_relative 'common_generator'
require_relative 'cucumber/cucumber_generator'
require_relative 'helper_generator'
require_relative 'minitest/minitest_generator'
require_relative 'rspec/rspec_generator'

# :reek:FeatureEnvy { enabled: false }
# :reek:UtilityFunction { enabled: false }
# :reek:ControlParameter { enabled: false }
# :reek:DuplicateMethodCall { enabled: false }
# :reek:ManualDispatch { enabled: false }
# :reek:UncommunicativeVariableName { enabled: false }
module InvokeGenerators
  module_function

  def generate_framework(structure = {})
    generators = %w[Automation Common Helpers]
    framework = structure[:framework]
    add_generator(generators, framework.capitalize)
    add_generator(generators, structure[:ci_platform].capitalize) if !structure[:skip_ci] && (structure[:ci_platform])
    extra_args = collect_skip_flags(structure)
    generators.each do |generator|
      invoke_generator({
                         automation: structure[:automation],
                         framework:,
                         generator:,
                         ci_platform: structure[:ci_platform],
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
    args = [structure[:automation], structure[:framework], structure[:name], structure[:ci_platform]]
    args.concat(structure[:extra_args] || [])
    generator_class = GENERATOR_CLASSES[structure[:generator]]
    generator = generator_class.new(args)
    # Enable batch mode on the template cache to skip mtime checks during generation
    generator.class.template_renderer.batch_mode = true if generator.class.respond_to?(:template_renderer)
    generator.invoke_all
  end

  def collect_skip_flags(structure)
    flags = []
    flags << 'skip_allure' if structure[:skip_allure]
    flags << 'skip_video' if structure[:skip_video]
    flags << 'axe_addon' if structure[:accessibility] && !mobile_automation?(structure[:automation])
    flags << 'visual_addon' if structure[:visual] && !mobile_automation?(structure[:automation])
    flags << 'lighthouse_addon' if structure[:performance] && !mobile_automation?(structure[:automation])
    flags.concat(reporter_flags(structure[:reporter]))
    flags
  end

  def reporter_flags(reporter)
    case reporter
    when 'allure' then ['reporter_allure']
    when 'junit' then ['reporter_junit']
    when 'json' then ['reporter_json']
    when 'both' then %w[reporter_allure reporter_junit]
    when 'all' then %w[reporter_allure reporter_junit reporter_json]
    when 'none' then ['reporter_none']
    else []
    end
  end

  def mobile_automation?(automation)
    %w[ios android cross_platform].include?(automation)
  end

  def to_bool(string)
    return unless string.is_a? String

    string.downcase == 'true'
  end
end
