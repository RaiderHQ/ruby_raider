# frozen_string_literal: true

require_relative '../generator'

class MinitestGenerator < Generator
  def generate_login_test
    return unless web?

    template('test.tt', "#{name}/test/test_login_page.rb")
  end

  def generate_pdp_test
    return unless mobile?

    template('test.tt', "#{name}/test/test_pdp_page.rb")
  end

  def generate_visual_test
    return unless visual_addon? && web?

    template('visual_test.tt', "#{name}/test/test_visual.rb")
  end

  def generate_accessibility_test
    return unless axe_addon? && web?

    template('accessibility_test.tt', "#{name}/test/test_accessibility.rb")
  end

  def generate_performance_test
    return unless lighthouse_addon? && web?

    template('performance_test.tt', "#{name}/test/test_performance.rb")
  end
end
