# frozen_string_literal: true

require_relative 'name_normalizer'

# :reek:TooManyStatements { enabled: false }
class CrudGenerator
  ACTIONS = %w[list create detail edit].freeze

  def initialize(base_name, scaffolding_class, config_loader)
    @base_name = NameNormalizer.normalize(base_name)
    @scaffolding_class = scaffolding_class
    @config_loader = config_loader
  end

  def generate
    generated = []
    ACTIONS.each do |action|
      name = "#{@base_name}_#{action}"
      generate_page(name)
      generate_test(name)
      generated << name
    end
    generate_model
    generated
  end

  def planned_files
    files = []
    ACTIONS.each do |action|
      name = "#{@base_name}_#{action}"
      files << "page_objects/pages/#{name}.rb"
      files << test_path(name)
    end
    files << "models/data/#{@base_name}.yml"
    files
  end

  private

  def generate_page(name)
    path = @config_loader.call('page')
    @scaffolding_class.new([name, path]).generate_page
  end

  def generate_test(name)
    if Dir.exist?('features')
      path = @config_loader.call('feature')
      @scaffolding_class.new([name, path]).generate_feature
      path = @config_loader.call('steps')
      @scaffolding_class.new([name, path]).generate_steps
    elsif Dir.exist?('test')
      path = @config_loader.call('spec')
      @scaffolding_class.new([name, path]).generate_spec
    else
      path = @config_loader.call('spec')
      @scaffolding_class.new([name, path]).generate_spec
    end
  end

  def generate_model
    model_path = "models/data/#{@base_name}.yml"
    return if File.exist?(model_path)

    FileUtils.mkdir_p(File.dirname(model_path))
    File.write(model_path, model_content)
  end

  def model_content
    <<~YAML
      # Data model for #{@base_name}
      # Used with ModelFactory for test data generation
      default:
        name: 'Test #{@base_name.capitalize}'
        email: 'test@example.com'

      valid:
        name: 'Valid #{@base_name.capitalize}'
        email: 'valid@example.com'

      invalid:
        name: ''
        email: 'invalid'
    YAML
  end

  def test_path(name)
    if Dir.exist?('features')
      "features/#{name}.feature"
    elsif Dir.exist?('test')
      "test/test_#{name}.rb"
    else
      "spec/#{name}_page_spec.rb"
    end
  end
end
