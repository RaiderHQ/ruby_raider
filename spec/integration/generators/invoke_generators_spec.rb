# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'open3'
require_relative '../spec_helper'

describe InvokeGenerators do
  after { FileUtils.rm_rf(Dir.glob('case_*')) }

  context 'with option values in a different case' do
    it 'accepts framework:Rspec and automation:Selenium' do
      described_class.generate_framework(framework: 'Rspec', automation: 'Selenium', name: 'case_mixed')
      expect(File).to exist('case_mixed/.rspec')
    end

    it 'accepts upper-case values' do
      described_class.generate_framework(framework: 'RSPEC', automation: 'SELENIUM', name: 'case_upper')
      expect(File).to exist('case_upper/.rspec')
    end

    it 'accepts symbols' do
      described_class.generate_framework(framework: :rspec, automation: :selenium, name: 'case_symbol')
      expect(File).to exist('case_symbol/.rspec')
    end
  end

  context 'with raider new and capitalised options' do
    it 'generates the project and exits zero' do
      root = File.expand_path('../../..', __dir__)
      _out, status = Open3.capture2e('ruby', "#{root}/bin/raider", 'new', 'case_cli', '-p', 'framework:Rspec',
                                     'automation:Selenium')
      expect(status.exitstatus).to eq(0)
      expect(File).to exist('case_cli/.rspec')
    end
  end

  context 'with invalid values' do
    it 'raises a Thor::Error for an unknown framework' do
      expect { described_class.generate_framework(framework: 'minitest', automation: 'selenium', name: 'case_bad') }
        .to raise_error(Thor::Error, /Invalid framework "minitest"/)
    end

    it 'sends an invalid ci to stderr and exits non-zero' do
      root = File.expand_path('../../..', __dir__)
      _out, err, status = Open3.capture3('ruby', "#{root}/bin/raider", 'new', 'case_bad_ci', '-p',
                                         'framework:rspec', 'automation:selenium', 'ci:gitlab')
      expect(status.exitstatus).to eq(1)
      expect(err).to include('ci must be github or azure')
      expect(File).not_to exist('case_bad_ci')
    end
  end

  describe '.collect_flags' do
    it 'adds no_examples when examples is false' do
      expect(described_class.collect_flags(automation: 'selenium', examples: false)).to include('no_examples')
    end

    it 'keeps the examples by default' do
      expect(described_class.collect_flags(automation: 'selenium')).not_to include('no_examples')
    end
  end

  context 'with an unsupported automation' do
    it 'lists the supported automations only' do
      expect(described_class::AUTOMATIONS).to eq(%w[selenium ios android cross_platform])
    end

    it 'raises the Invalid automation error and writes nothing' do
      expect { described_class.generate_framework(framework: 'rspec', automation: 'watir', name: 'case_watir') }
        .to raise_error(Thor::Error, 'Invalid automation "watir". Allowed values: selenium, ios, android, cross_platform')
      expect(File).not_to exist('case_watir')
    end
  end

  context 'with the RSpec-only framework choice' do
    it 'lists rspec as the only framework' do
      expect(described_class::FRAMEWORKS).to eq(%w[rspec])
    end

    it 'rejects framework minitest with the allowed values' do
      expect { described_class.generate_framework(framework: 'minitest', automation: 'selenium', name: 'case_min') }
        .to raise_error(Thor::Error, 'Invalid framework "minitest". Allowed values: rspec')
    end

    it 'rejects framework cucumber like any unknown framework' do
      expect { described_class.generate_framework(framework: 'Cucumber', automation: 'selenium', name: 'case_cuke') }
        .to raise_error(Thor::Error, 'Invalid framework "cucumber". Allowed values: rspec')
      expect(File).not_to exist('case_cuke')
    end

    %w[framework:cucumber framework:Cucumber].each do |arg|
      it "exits 1 for raider new with #{arg} and leaves no directory" do
        root = File.expand_path('../../..', __dir__)
        Dir.mktmpdir do |dir|
          _out, err, status = Open3.capture3('ruby', "#{root}/bin/raider", 'new', 'x', '-p', arg,
                                             'automation:selenium', chdir: dir)
          expect(status.exitstatus).to eq(1)
          expect(err).to include('Invalid framework "cucumber". Allowed values: rspec')
          expect(File).not_to exist(File.join(dir, 'x'))
        end
      end
    end

    it 'defaults to rspec when no framework is given' do
      root = File.expand_path('../../..', __dir__)
      Dir.mktmpdir do |dir|
        _out, _err, status = Open3.capture3('ruby', "#{root}/bin/raider", 'new', 'x', '-p',
                                            'automation:selenium', chdir: dir)
        expect(status.exitstatus).to eq(0)
        expect(File).to exist(File.join(dir, 'x/spec'))
        expect(File).not_to exist(File.join(dir, 'x/features'))
      end
    end
  end
end

describe 'Projects named like a generator option' do
  after { FileUtils.rm_rf(%w[no_examples watir selenium]) }

  it 'keeps the example tests in a project named no_examples' do
    InvokeGenerators.generate_framework(automation: 'selenium', framework: 'rspec', name: 'no_examples')
    expect(File).to exist('no_examples/spec/login_page_spec.rb')
    expect(File).to exist('no_examples/page_objects/pages/login.rb')
  end

  it 'gives a Selenium project named watir the runtime helpers and no wait helper' do
    InvokeGenerators.generate_framework(automation: 'selenium', framework: 'rspec', name: 'watir')
    expect(File).not_to exist('watir/helpers/wait_helper.rb')
    expect(File.read('watir/helpers/spec_helper.rb')).not_to include('Watir')
    expect(File.read('watir/page_objects/abstract/page.rb')).to include('include Raider::Helpers')
  end
end

describe 'Option-named projects generate what a neutral name generates' do
  option_names = %w[ios android rspec cross_platform axe_addon selenium watir no_examples azure]
  option_sets = [
    { automation: 'selenium', framework: 'rspec' },
    { automation: 'selenium', framework: 'rspec', accessibility: true },
    { automation: 'selenium', framework: 'rspec', examples: false, ci: 'azure' },
    { automation: 'ios', framework: 'rspec' },
    { automation: 'android', framework: 'rspec' },
    { automation: 'cross_platform', framework: 'rspec' }
  ].freeze

  def quietly
    result = nil
    expect { result = yield }.to output.to_stdout
    result
  end

  def snapshot(name, options)
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        InvokeGenerators.generate_framework(options.merge(name:))
        Dir.glob("#{name}/**/*", File::FNM_DOTMATCH).select { |f| File.file?(f) }
           .to_h { |f| [f.delete_prefix("#{name}/"), File.read(f)] }
      end
    end
  end

  option_sets.each do |options|
    context "with #{options}" do
      let(:neutral) { quietly { snapshot('demo', options) } }

      option_names.each do |name|
        it "generates the same files for a project named #{name}" do
          actual = quietly { snapshot(name, options) }
          expect(actual.keys.sort).to eq(neutral.keys.sort)
          expect(actual).to eq(neutral)
        end
      end
    end
  end
end

describe 'raider new -p examples: validation' do
  after { FileUtils.rm_rf(%w[bad_examples]) }

  let(:root) { File.expand_path('../../..', __dir__) }

  it 'rejects an unknown value, names the allowed values and generates nothing' do
    Dir.mktmpdir do |dir|
      _out, err, status = Open3.capture3('ruby', "#{root}/bin/raider", 'new', 'x', '-p',
                                         'framework:rspec', 'automation:selenium', 'examples:no', chdir: dir)
      expect(status.exitstatus).to eq(1)
      expect(err).to include('Invalid examples "no". Allowed values: true, false')
      expect(File).not_to exist(File.join(dir, 'x'))
    end
  end
end
