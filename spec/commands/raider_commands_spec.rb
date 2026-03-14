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
end
