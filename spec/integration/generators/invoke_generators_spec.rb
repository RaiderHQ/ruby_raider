# frozen_string_literal: true

require 'fileutils'
require 'open3'
require_relative '../spec_helper'

describe InvokeGenerators do
  after { FileUtils.rm_rf(Dir.glob('case_*')) }

  context 'with option values in a different case' do
    it 'accepts framework:Cucumber and automation:Selenium' do
      described_class.generate_framework(framework: 'Cucumber', automation: 'Selenium', name: 'case_mixed')
      expect(File).to exist('case_mixed/cucumber.yml')
    end

    it 'accepts upper-case values' do
      described_class.generate_framework(framework: 'RSPEC', automation: 'WATIR', name: 'case_upper')
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
      _out, status = Open3.capture2e('ruby', "#{root}/bin/raider", 'new', 'case_cli', '-p', 'framework:Cucumber',
                                     'automation:Selenium')
      expect(status.exitstatus).to eq(0)
      expect(File).to exist('case_cli/cucumber.yml')
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

    it 'keeps the examples for watir, whose templates are frozen' do
      expect(described_class.collect_flags(automation: 'watir', examples: false)).not_to include('no_examples')
    end
  end

  context 'with the Watir deprecation notice' do
    let(:notice) do
      'Watir is deprecated and will be removed in the next major version of ruby_raider; new projects should use Selenium.'
    end

    it 'prints it for watir' do
      expect { described_class.generate_framework(framework: 'rspec', automation: 'watir', name: 'case_dep') }
        .to output(/#{Regexp.escape(notice)}/).to_stdout
    end

    it 'does not print it for selenium' do
      expect { described_class.generate_framework(framework: 'rspec', automation: 'selenium', name: 'case_nodep') }
        .not_to output(/Watir is deprecated/).to_stdout
    end

    it 'still prints it for raider new with automation:watir' do
      root = File.expand_path('../../..', __dir__)
      out, status = Open3.capture2e('ruby', "#{root}/bin/raider", 'new', 'case_cli_watir', '-p',
                                    'framework:rspec', 'automation:watir')
      expect(status.success?).to be(true)
      expect(out).to include(notice)
      expect(File).to exist('case_cli_watir/.rspec')
    end
  end

  context 'with examples false for watir' do
    it 'says the examples are kept' do
      expect { described_class.generate_framework(framework: 'rspec', automation: 'watir', name: 'case_watir', examples: false) }
        .to output(/Watir projects always include the example tests/).to_stdout
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

  it 'gives a Selenium project named watir the wait helper it wires in' do
    InvokeGenerators.generate_framework(automation: 'selenium', framework: 'cucumber', name: 'watir')
    expect(File).to exist('watir/helpers/wait_helper.rb')
    expect(File.read('watir/features/support/env.rb')).not_to include('Watir')
    expect(File.read('watir/page_objects/abstract/page.rb')).to include('include WaitHelper')
  end

  it 'keeps a Watir project named selenium on Watir' do
    InvokeGenerators.generate_framework(automation: 'watir', framework: 'rspec', name: 'selenium')
    expect(File).not_to exist('selenium/helpers/wait_helper.rb')
    expect(File.read('selenium/page_objects/abstract/page.rb')).to include('browser.element')
    expect(File.read('selenium/page_objects/abstract/page.rb')).not_to include('find_element')
  end
end
