# frozen_string_literal: true

require 'rspec'
require_relative '../../lib/ruby_raider'

RSpec.describe RubyRaider::Raider do
  describe 'new command' do
    context 'with parameters' do
      it 'calls InvokeGenerators.generate_framework with parsed hash' do
        allow(InvokeGenerators).to receive(:generate_framework)

        described_class.new.invoke(:new, nil, %w[my_project -p framework:rspec automation:selenium])

        expect(InvokeGenerators).to have_received(:generate_framework).with(
          hash_including(framework: 'rspec', automation: 'selenium', name: 'my_project')
        )
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

    it 'maps a to adopt' do
      expect(described_class.map['a']).to eq('adopt')
    end

    it 'maps g to generate' do
      expect(described_class.map['g']).to eq('generate')
    end

    it 'maps u to utility' do
      expect(described_class.map['u']).to eq('utility')
    end

    it 'maps pm to plugin_manager' do
      expect(described_class.map['pm']).to eq('plugin_manager')
    end
  end

  describe 'registered subcommands' do
    let(:subcommands) { described_class.subcommands }

    it 'includes adopt' do
      expect(subcommands).to include('adopt')
    end

    it 'includes generate' do
      expect(subcommands).to include('generate')
    end

    it 'includes utility' do
      expect(subcommands).to include('utility')
    end

    it 'includes plugin_manager' do
      expect(subcommands).to include('plugin_manager')
    end
  end
end

RSpec.describe AdoptCommands do
  let(:source_dir) { 'tmp_cmd_adopt_source' }
  let(:output_dir) { 'tmp_cmd_adopt_output' }

  before do
    FileUtils.mkdir_p(source_dir)
    File.write("#{source_dir}/Gemfile", "gem 'rspec'\ngem 'selenium-webdriver'\n")
    FileUtils.mkdir_p("#{source_dir}/spec")
  end

  after do
    FileUtils.rm_rf(source_dir)
    FileUtils.rm_rf(output_dir)
  end

  describe 'project command with parameters' do
    it 'calls AdoptMenu.adopt with parsed params' do
      result = { plan: double(warnings: [], output_path: output_dir), results: { pages: 0, tests: 0, features: 0, steps: 0, errors: [] } } # rubocop:disable RSpec/VerifiedDoubles
      allow(Adopter::AdoptMenu).to receive(:adopt).and_return(result)

      expect do
        described_class.new.invoke(:project, nil, [source_dir, '-p',
                                                   "output_path:#{output_dir}",
                                                   'target_automation:selenium',
                                                   'target_framework:rspec'])
      end.to output(/Adoption complete/).to_stdout

      expect(Adopter::AdoptMenu).to have_received(:adopt).with(
        hash_including(source_path: source_dir, target_automation: 'selenium', target_framework: 'rspec')
      )
    end
  end

  describe 'project command without parameters' do
    it 'calls AdoptMenu#run' do
      menu = instance_double(Adopter::AdoptMenu, run: nil)
      allow(Adopter::AdoptMenu).to receive(:new).and_return(menu)

      described_class.new.invoke(:project, nil, [source_dir])

      expect(menu).to have_received(:run)
    end
  end
end
