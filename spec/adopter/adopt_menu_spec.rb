# frozen_string_literal: true

require 'fileutils'
require 'rspec'
require_relative '../../lib/adopter/adopt_menu'

RSpec.describe Adopter::AdoptMenu do
  let(:source_dir) { 'tmp_adopt_menu_source' }
  let(:output_dir) { 'tmp_adopt_menu_output' }

  before do
    FileUtils.mkdir_p(source_dir)
    File.write("#{source_dir}/Gemfile", "gem 'rspec'\ngem 'selenium-webdriver'\ngem 'faker'\n")
    FileUtils.mkdir_p("#{source_dir}/pages")
    FileUtils.mkdir_p("#{source_dir}/spec")

    File.write("#{source_dir}/pages/login_page.rb", <<~RUBY)
      class LoginPage < BasePage
        def login(user, pass)
          driver.find_element(id: 'user').send_keys user
        end
      end
    RUBY

    File.write("#{source_dir}/spec/login_spec.rb", <<~RUBY)
      describe 'Login' do
        it 'can log in' do
          expect(result).to eq 'ok'
        end
      end
    RUBY
  end

  after do
    FileUtils.rm_rf(source_dir)
    FileUtils.rm_rf(output_dir)
  end

  describe '.adopt' do
    let(:params) do
      {
        source_path: source_dir,
        output_path: output_dir,
        target_automation: 'selenium',
        target_framework: 'rspec'
      }
    end

    it 'runs the full adoption pipeline' do
      result = described_class.adopt(params)

      expect(result[:plan]).to be_a(Adopter::MigrationPlan)
      expect(result[:results][:pages]).to eq(1)
      expect(result[:results][:tests]).to eq(1)
      expect(File).to exist("#{output_dir}/Gemfile")
      expect(File).to exist("#{output_dir}/page_objects/pages/login.rb")
    end

    it 'merges custom gems into the generated Gemfile' do
      described_class.adopt(params)

      gemfile = File.read("#{output_dir}/Gemfile")
      expect(gemfile).to include("gem 'faker'")
    end

    it 'converts page content with raider conventions' do
      described_class.adopt(params)

      page = File.read("#{output_dir}/page_objects/pages/login.rb")
      expect(page).to include('frozen_string_literal: true')
      expect(page).to include('class LoginPage < Page')
    end

    context 'with capybara target' do
      let(:params) do
        {
          source_path: source_dir,
          output_path: output_dir,
          target_automation: 'capybara',
          target_framework: 'rspec'
        }
      end

      it 'removes driver arguments from page instantiation' do
        File.write("#{source_dir}/spec/login_spec.rb", <<~RUBY)
          describe 'Login' do
            it 'can log in' do
              @page = LoginPage.new(driver)
            end
          end
        RUBY

        result = described_class.adopt(params)
        test_content = result[:plan].converted_tests.first.content
        expect(test_content).to include('LoginPage.new')
        expect(test_content).not_to include('LoginPage.new(driver)')
      end
    end

    context 'with ci_platform' do
      let(:params) do
        {
          source_path: source_dir,
          output_path: output_dir,
          target_automation: 'selenium',
          target_framework: 'rspec',
          ci_platform: 'github'
        }
      end

      it 'generates CI configuration' do
        described_class.adopt(params)

        expect(File).to exist("#{output_dir}/.github")
      end
    end
  end

  describe '.validate_params!' do
    it 'raises on missing source_path' do
      expect { described_class.validate_params!({}) }.to raise_error(ArgumentError, /source_path/)
    end

    it 'raises on missing output_path' do
      expect { described_class.validate_params!(source_path: 'x') }.to raise_error(ArgumentError, /output_path/)
    end

    it 'raises on missing target_automation' do
      expect do
        described_class.validate_params!(source_path: 'x', output_path: 'y')
      end.to raise_error(ArgumentError, /target_automation/)
    end

    it 'raises on missing target_framework' do
      expect do
        described_class.validate_params!(source_path: 'x', output_path: 'y', target_automation: 'selenium')
      end.to raise_error(ArgumentError, /target_framework/)
    end

    it 'raises on invalid target_automation' do
      expect do
        described_class.validate_params!(
          source_path: 'x', output_path: 'y',
          target_automation: 'appium', target_framework: 'rspec'
        )
      end.to raise_error(ArgumentError, /target_automation must be/)
    end

    it 'raises on invalid target_framework' do
      expect do
        described_class.validate_params!(
          source_path: 'x', output_path: 'y',
          target_automation: 'selenium', target_framework: 'junit'
        )
      end.to raise_error(ArgumentError, /target_framework must be/)
    end

    it 'accepts valid params without raising' do
      expect do
        described_class.validate_params!(
          source_path: 'x', output_path: 'y',
          target_automation: 'selenium', target_framework: 'rspec'
        )
      end.not_to raise_error
    end

    it 'accepts capybara as valid automation' do
      expect do
        described_class.validate_params!(
          source_path: 'x', output_path: 'y',
          target_automation: 'capybara', target_framework: 'minitest'
        )
      end.not_to raise_error
    end
  end
end
