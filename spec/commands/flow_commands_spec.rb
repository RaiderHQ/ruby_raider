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
end
