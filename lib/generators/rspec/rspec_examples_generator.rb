# frozen_string_literal: true

require_relative '../generator'

class RspecExamplesGenerator < Generator
  def generate_login_spec
    return unless mobile_platform?

    template('spec.tt', "#{name}/spec/login_page_spec.rb")
  end

  def generate_pdp_spec
    return if mobile_platform?

    template('spec.tt', "#{name}/spec/pdp_page_spec.rb")
  end

  def generate_model_factory
    return if args.include?(%w[selenium watir])

    template('factory.tt', "#{name}/models/model_factory.rb")
  end

  def generate_model_data
    return if args.include?(%w[selenium watir])

    template('data.tt', "#{name}/models/data/users.yml")
  end
end
