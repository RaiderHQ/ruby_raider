# frozen_string_literal: true

require 'open3'
require 'tmpdir'
require_relative '../../lib/ruby_raider'

RSpec.describe FlowCommands do
  let(:raider_bin) { File.expand_path('../../bin/raider', __dir__) }

  def run_raider(*args)
    Open3.capture3(RbConfig.ruby, raider_bin, *args)
  end

  it 'lists init, run and list in raider flow help' do
    out, _err, status = run_raider('flow', 'help')

    expect(status.exitstatus).to eq(0)
    expect(out).to include('flow init', 'flow run NAME', 'flow list')
  end

  it 'maps raider f to the flow commands' do
    out, _err, status = run_raider('f', 'help')

    expect(status.exitstatus).to eq(0)
    expect(out).to include('flow run NAME')
  end

  it 'is listed in raider help' do
    out, = run_raider('help')

    expect(out).to include('raider flow')
  end

  describe 'init' do
    it 'sets up flows in the --project folder from any working directory' do
      Dir.mktmpdir('flow-init') do |dir|
        File.write(File.join(dir, 'Gemfile'), "gem 'ruby_raider', '~> 4.0'\ngem 'selenium-webdriver'\n")
        FileUtils.mkdir_p(File.join(dir, 'helpers'))
        File.write(File.join(dir, 'helpers/driver_helper.rb'), "require 'ruby_raider/runtime'\n")

        out, _err, status = run_raider('flow', 'init', '--project', dir)

        expect(status.exitstatus).to eq(0)
        expect(out).to include('Created flows/flow_helper.rb', 'Run bundle install')
      end
    end

    it 'exits 2 for a project that cannot hold flows' do
      Dir.mktmpdir('flow-init') do |dir|
        _out, err, status = run_raider('flow', 'init', '--project', dir)

        expect(status.exitstatus).to eq(2)
        expect(err).to include('Flows need a Selenium web project made with Ruby Raider 4.0 or later')
      end
    end

    it 'exits 2 for a missing project folder' do
      _out, err, status = run_raider('flow', 'init', '--project', '/nonexistent/raider')

      expect(status.exitstatus).to eq(2)
      expect(err).to include('Project folder not found')
    end
  end

  describe 'schedules' do
    # Only paths refused before the OS scheduler is asked: this machine's launchd is real
    it 'lists schedule, unschedule and schedules in raider flow help' do
      out, _err, status = run_raider('flow', 'help')

      expect(status.exitstatus).to eq(0)
      expect(out).to include('flow schedule NAME', 'flow unschedule NAME', 'flow schedules')
    end

    it 'dispatches raider flow schedule NAME to schedule, not schedules' do
      Dir.mktmpdir('flow-schedule') do |dir|
        _out, err, status = run_raider('flow', 'schedule', 'x', '--every', 'day', '--at', '08:00', '--project', dir)

        expect(status.exitstatus).to eq(2)
        expect(err).to include('No flow x: flows/x_flow.rb not found')
      end
    end

    it 'exits 2 for an invalid name to unschedule' do
      Dir.mktmpdir('flow-schedule') do |dir|
        _out, err, status = run_raider('flow', 'unschedule', 'Bad-Name', '--project', dir)

        expect(status.exitstatus).to eq(2)
        expect(err).to include('Invalid flow name "Bad-Name"')
      end
    end

    it 'exits 2 with a message for an argument that is not valid UTF-8' do
      _out, err, status = run_raider('flow', 'schedule', "a\xFF".b, '--every', 'day')

      expect(status.exitstatus).to eq(2)
      expect(err).to eq("Invalid argument \"a\\xFF\": use valid UTF-8\n")
    end

    it 'says there are no schedules, as text and as JSON' do
      Dir.mktmpdir('flow-schedule') do |dir|
        text, = run_raider('flow', 'schedules', '--project', dir)
        json, = run_raider('flow', 'schedules', '--json', '--project', dir)

        expect([text, json]).to eq(["No schedules yet: raider flow schedule <name> --every day --at 08:00\n", "[]\n"])
      end
    end
  end
end
