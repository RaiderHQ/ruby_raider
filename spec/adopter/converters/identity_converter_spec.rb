# frozen_string_literal: true

require 'rspec'
require_relative '../../../lib/adopter/converters/identity_converter'

RSpec.describe Adopter::Converters::IdentityConverter do
  describe '#convert_page' do
    context 'targeting selenium' do
      let(:converter) { described_class.new('selenium') }

      it 'adds frozen_string_literal if missing' do
        input = "class LoginPage < BasePage\nend\n"
        result = converter.convert_page(input, {})
        expect(result).to start_with('# frozen_string_literal: true')
      end

      it 'does not duplicate frozen_string_literal' do
        input = "# frozen_string_literal: true\n\nclass LoginPage < Page\nend\n"
        result = converter.convert_page(input, {})
        expect(result.scan('frozen_string_literal').length).to eq(1)
      end

      it 'updates base class to Page' do
        input = "class LoginPage < BasePage\nend\n"
        result = converter.convert_page(input, {})
        expect(result).to include('class LoginPage < Page')
      end

      it 'preserves non-page base classes' do
        input = "class UserFactory < ModelFactory\nend\n"
        result = converter.convert_page(input, {})
        expect(result).to include('class UserFactory < ModelFactory')
      end

      it 'adds require_relative for abstract page' do
        input = "class LoginPage < BasePage\nend\n"
        result = converter.convert_page(input, {})
        expect(result).to include("require_relative '../abstract/page'")
      end

      it 'does not duplicate page require' do
        input = "require_relative '../abstract/page'\n\nclass LoginPage < Page\nend\n"
        result = converter.convert_page(input, {})
        expect(result.scan("require_relative '../abstract/page'").length).to eq(1)
      end

      it 'swaps browser to driver in page instantiation' do
        input = "class Test\n  @page = LoginPage.new(browser)\nend\n"
        result = converter.convert_page(input, {})
        expect(result).to include('LoginPage.new(driver)')
      end
    end

    context 'targeting capybara' do
      let(:converter) { described_class.new('capybara') }

      it 'removes driver argument from page instantiation' do
        input = "class Test\n  @page = LoginPage.new(driver)\nend\n"
        result = converter.convert_page(input, {})
        expect(result).to include('LoginPage.new')
        expect(result).not_to include('LoginPage.new(driver)')
      end

      it 'removes browser argument from page instantiation' do
        input = "  @page = LoginPage.new(browser)\n"
        result = converter.convert_page(input, {})
        expect(result).to include('LoginPage.new')
        expect(result).not_to include('LoginPage.new(browser)')
      end
    end

    context 'targeting watir' do
      let(:converter) { described_class.new('watir') }

      it 'swaps driver to browser in page instantiation' do
        input = "class Test\n  @page = LoginPage.new(driver)\nend\n"
        result = converter.convert_page(input, {})
        expect(result).to include('LoginPage.new(browser)')
      end
    end
  end

  describe '#convert_test' do
    let(:converter) { described_class.new('selenium') }

    it 'adds frozen_string_literal if missing' do
      input = "describe 'Login' do\nend\n"
      result = converter.convert_test(input, {})
      expect(result).to start_with('# frozen_string_literal: true')
    end

    it 'updates helper require paths for selenium' do
      input = "require_relative '../support/browser_setup'\n\ndescribe 'x' do; end\n"
      result = converter.convert_test(input, {})
      expect(result).to include("require_relative '../helpers/driver_helper'")
    end

    context 'targeting capybara' do
      let(:converter) { described_class.new('capybara') }

      it 'updates helper require paths for capybara' do
        input = "require_relative '../support/driver_helper'\n\ndescribe 'x' do; end\n"
        result = converter.convert_test(input, {})
        expect(result).to include("require_relative '../helpers/capybara_helper'")
      end
    end

    context 'targeting watir' do
      let(:converter) { described_class.new('watir') }

      it 'updates helper require paths for watir' do
        input = "require_relative '../support/driver_setup'\n\ndescribe 'x' do; end\n"
        result = converter.convert_test(input, {})
        expect(result).to include("require_relative '../helpers/browser_helper'")
      end
    end
  end

  describe '#convert_step' do
    context 'targeting capybara' do
      let(:converter) { described_class.new('capybara') }

      it 'removes driver argument from page instantiation in steps' do
        input = <<~RUBY
          Given('I am on the login page') do
            @page = LoginPage.new(driver)
          end
        RUBY
        result = converter.convert_step(input)
        expect(result).to include('LoginPage.new')
        expect(result).not_to include('LoginPage.new(driver)')
      end
    end

    context 'targeting selenium' do
      let(:converter) { described_class.new('selenium') }

      it 'swaps browser to driver in step page instantiation' do
        input = "  @page = LoginPage.new(browser)\n"
        result = converter.convert_step(input)
        expect(result).to include('LoginPage.new(driver)')
      end
    end
  end
end
