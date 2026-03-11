# frozen_string_literal: true

require 'open3'

# :reek:UtilityFunction
module SystemTestHelper
  # :reek:ControlParameter
  def test_command_for(framework)
    case framework
    when 'cucumber' then 'bundle exec cucumber features --format pretty'
    when 'minitest' then 'bundle exec ruby -Itest test/test_login_page.rb'
    else 'bundle exec rspec spec --format documentation'
    end
  end

  def run_tests_with(framework, automation)
    project = "#{automation}_#{framework}"

    Bundler.with_unbundled_env do
      Dir.chdir(project) do
        result = run_command('bundle install --quiet')
        return result unless result[:success]

        run_command(test_command_for(framework), env: { 'HEADLESS' => 'true' })
      end
    end
  end

  private

  def run_command(command, env: {})
    stdout, stderr, status = Open3.capture3(env, command)
    { success: status.success?, stdout:, stderr: }
  end
end
