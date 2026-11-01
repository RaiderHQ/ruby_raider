# frozen_string_literal: true

require 'rspec'
require_relative '../../lib/ruby_raider'

# Command specs are grouped by CLI area under spec/commands, not by constant path
RSpec.describe RubyRaider::Raider do # rubocop:disable RSpec/FilePath
  describe 'new command' do
    context 'with parameters' do
      it 'calls InvokeGenerators.generate_framework with parsed hash' do
        allow(InvokeGenerators).to receive(:generate_framework)

        described_class.new.invoke(:new, nil, %w[my_project -p framework:rspec automation:selenium])

        expect(InvokeGenerators).to have_received(:generate_framework).with(
          hash_including(framework: 'rspec', automation: 'selenium', name: 'my_project')
        )
      end

      it 'passes examples:false through as false' do
        allow(InvokeGenerators).to receive(:generate_framework)

        described_class.new.invoke(:new, nil, %w[my_project -p framework:rspec automation:selenium examples:false])

        expect(InvokeGenerators).to have_received(:generate_framework).with(hash_including(examples: false))
      end

      it 'keeps the examples by default' do
        allow(InvokeGenerators).to receive(:generate_framework)

        described_class.new.invoke(:new, nil, %w[my_project -p framework:rspec automation:selenium])

        expect(InvokeGenerators).to have_received(:generate_framework).with(hash_excluding(:examples))
      end

      it 'keeps the examples for any value other than false' do
        allow(InvokeGenerators).to receive(:generate_framework)

        described_class.new.invoke(:new, nil, %w[my_project -p framework:rspec automation:selenium examples:true])

        expect(InvokeGenerators).to have_received(:generate_framework).with(hash_including(examples: true))
      end
    end

    context 'without parameters' do
      it 'calls MenuGenerator.generate_choice_menu' do
        menu = instance_double(MenuGenerator, generate_choice_menu: nil)
        allow(MenuGenerator).to receive(:new).and_return(menu)

        described_class.new.invoke(:new, nil, %w[my_project])

        expect(menu).to have_received(:generate_choice_menu)
      end
    end
  end

  describe 'version command' do
    it 'outputs the version from lib/version' do
      expected_version = File.read(File.expand_path('../../lib/version', __dir__)).strip
      expect { described_class.new.invoke(:version) }.to output(/#{Regexp.escape(expected_version)}/).to_stdout
    end
  end

  describe 'subcommand aliases' do
    it 'maps n to new' do
      expect(described_class.map['n']).to eq('new')
    end

    it 'maps v to version' do
      expect(described_class.map['v']).to eq('version')
    end

    it 'maps g to generate' do
      expect(described_class.map['g']).to eq('generate')
    end

    it 'maps u to utility' do
      expect(described_class.map['u']).to eq('utility')
    end
  end

  describe 'registered subcommands' do
    let(:subcommands) { described_class.subcommands }

    it 'includes generate' do
      expect(subcommands).to include('generate')
    end

    it 'includes utility' do
      expect(subcommands).to include('utility')
    end
  end

  describe 'CLI exit status' do
    require 'open3'
    require 'tmpdir'

    let(:raider_bin) { File.expand_path('../../bin/raider', __dir__) }

    def run_raider(*args, chdir: Dir.pwd)
      Open3.capture3(RbConfig.ruby, raider_bin, *args, chdir:)
    end

    it 'exits non-zero for an unknown command' do
      _out, err, status = run_raider('u', 'debug', 'on')

      expect(status.exitstatus).not_to eq(0)
      expect(err).to include('Could not find command "debug"')
    end

    it 'exits zero for version' do
      _out, _err, status = run_raider('version')

      expect(status.exitstatus).to eq(0)
    end

    it 'rejects an unknown framework without creating the project' do
      Dir.mktmpdir do |dir|
        out, err, status = run_raider('new', 'x', '-p', 'framework:minitest', 'automation:selenium', chdir: dir)

        expect(status.exitstatus).not_to eq(0)
        expect(out + err).to include('framework', 'rspec', 'cucumber')
        expect(File.exist?(File.join(dir, 'x'))).to be(false)
      end
    end

    it 'rejects an unknown automation without creating the project' do
      Dir.mktmpdir do |dir|
        out, err, status = run_raider('new', 'x', '-p', 'framework:rspec', 'automation:playwright', chdir: dir)

        expect(status.exitstatus).not_to eq(0)
        expect(out + err).to include('automation', 'selenium', 'cross_platform')
        expect(File.exist?(File.join(dir, 'x'))).to be(false)
      end
    end

    it 'rejects automation:appium and points to the mobile platforms' do
      Dir.mktmpdir do |dir|
        out, err, status = run_raider('new', 'x', '-p', 'framework:rspec', 'automation:appium', chdir: dir)

        expect(status.exitstatus).not_to eq(0)
        expect(out + err).to include('automation', 'ios', 'android', 'cross_platform')
        expect(File.exist?(File.join(dir, 'x'))).to be(false)
      end
    end
  end
end
