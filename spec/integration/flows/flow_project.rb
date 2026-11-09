# frozen_string_literal: true

require 'erb'
require 'fileutils'

# A project with the flow files `raider flow init` writes and a stand-in helpers/spec_helper.rb:
# no browser and no raider_reporter. FAKE_DRIVER_FAIL makes the driver fail in before(:each);
# FAKE_STEPS writes a run.json whose desktop step map names step 2 of flows/recorded_flow.rb.
module FlowProject
  TEMPLATES = File.expand_path('../../../lib/generators/templates/flows', __dir__)

  STUB_SPEC_HELPER = <<~RUBY
    # frozen_string_literal: true

    require 'json'
    require 'rspec'

    module RaiderReporter
      Config = Struct.new(:output_dir, :clean_output_dir)
      def self.configuration = (@configuration ||= Config.new)
      def self.configure = yield(configuration)
    end

    module DriverHelper
      def driver
        raise 'the driver could not start' if ENV['FAKE_DRIVER_FAIL']

        @driver ||= Object.new
      end
    end

    RSpec.configure do |config|
      config.include(DriverHelper)
      config.before(:each) { driver }
      # The real reporter writes run.json when it closes; the desktop sidecar names the failed step there
      config.after(:suite) do
        dir = RaiderReporter.configuration.output_dir
        steps = { 'items' => [{ 'id' => 's1', 'title' => 'open' }, { 'id' => 's2', 'title' => 'click "Export"' }], 'failed' => 1 }
        results = [{ 'file_path' => 'flows/recorded_flow.rb', 'status' => 'failed', 'steps' => steps }]
        File.write(File.join(dir, 'run.json'), JSON.generate('results' => results)) if dir && ENV['FAKE_STEPS']
      end
    end
  RUBY

  module_function

  def build(dir, flows)
    FileUtils.mkdir_p(File.join(dir, 'flows/support'))
    FileUtils.mkdir_p(File.join(dir, 'helpers'))
    File.write(File.join(dir, 'flows/flow_helper.rb'), render('flow_helper.tt'))
    File.write(File.join(dir, 'flows/support/run.rb'), render('run.tt'))
    File.write(File.join(dir, 'helpers/spec_helper.rb'), STUB_SPEC_HELPER)
    File.write(File.join(dir, '.rspec'), "-I .\n--require helpers/spec_helper\n")
    flows.each { |name, source| File.write(File.join(dir, "flows/#{name}_flow.rb"), source) }
  end

  def render(name) = ERB.new(File.read(File.join(TEMPLATES, name)), trim_mode: '-').result
end
