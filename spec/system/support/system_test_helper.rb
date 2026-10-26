# frozen_string_literal: true

require 'open3'

module SystemTestHelper
  def test_command_for(framework)
    case framework
    when 'cucumber' then 'bundle exec cucumber features --format pretty'
    else 'bundle exec rspec spec --format documentation'
    end
  end

  def run_tests_with(framework, automation)
    project = "#{automation}_#{framework}"

    Bundler.with_unbundled_env do
      Dir.chdir(project) do
        use_checkout_ruby_raider
        use_checkout_raider_reporter
        result = run_command('bundle install --quiet')
        return result unless result[:success]

        run_command(test_command_for(framework), env: { 'HEADLESS' => 'true' })
      end
    end
  end

  private

  # The generated Gemfile pins ruby_raider to this gem's major.minor, which may not be
  # published yet. Resolve it from this checkout; the pin itself is covered by content specs.
  def use_checkout_ruby_raider(root = File.expand_path('../../..', __dir__))
    gemfile = File.read('Gemfile')
    File.write('Gemfile', gemfile.sub(/^gem 'ruby_raider'.*$/, "gem 'ruby_raider', path: '#{root}'"))
  end

  # Mirrors use_checkout_ruby_raider: raider_reporter ~> 0.10 is not published yet, so use a local
  # checkout (RAIDER_REPORTER_PATH or a sibling directory) when there is one; otherwise RubyGems.
  def use_checkout_raider_reporter(path = ENV.fetch('RAIDER_REPORTER_PATH', File.expand_path('../../../../raider_reporter', __dir__)))
    return unless File.exist?(File.join(path, 'raider_reporter.gemspec'))

    gemfile = File.read('Gemfile')
    File.write('Gemfile', gemfile.sub(/^gem 'raider_reporter'.*$/, "gem 'raider_reporter', path: '#{path}'"))
  end

  def run_command(command, env: {})
    stdout, stderr, status = Open3.capture3(env, command)
    { success: status.success?, stdout:, stderr: }
  end
end
