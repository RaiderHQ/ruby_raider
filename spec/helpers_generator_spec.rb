# frozen_string_literal: true

require_relative '../lib/generators/helper_generator'
require_relative 'spec_helper'

describe HelpersGenerator do
  frameworks = @frameworks
  automation_types = @automation_types

  context 'with selenium' do
    describe 'with rspec' do
      name = "#{frameworks.last}_#{automation_types[2]}"

      it 'creates a raider file' do
        expect(File).to exist("#{name}/helpers/raider.rb")
      end

      it 'creates an allure helper file' do
        expect(File).to exist("#{name}/helpers/allure_helper.rb")
      end

      it 'creates a driver helper file', :watir do
        expect(File).to exist("#{name}/helpers/driver_helper.rb")
      end

      it 'creates a spec helper file' do
        expect(File).to exist("#{name}/helpers/spec_helper.rb")
      end
    end

    describe 'with cucumber' do
      name = "#{frameworks.first}_#{automation_types[2]}"

      it 'creates an allure helper file' do
        expect(File).to exist("#{name}/helpers/allure_helper.rb")
      end

      it 'creates a driver helper file', :watir do
        expect(File).to exist("#{name}/helpers/driver_helper.rb")
      end

      it 'does not create a spec helper' do
        expect(File).not_to exist("#{name}/helpers/spec_helper.rb")
      end
    end
  end

  context 'with watir' do
    describe 'with rspec' do
      name = "#{frameworks.last}_#{automation_types.last}"

      it 'creates a browser helper file', :watir do
        expect(File).to exist("#{name}/helpers/browser_helper.rb")
      end

      it 'creates a raider file' do
        expect(File).to exist("#{name}/helpers/raider.rb")
      end

      it 'creates an allure helper file' do
        expect(File).to exist("#{name}/helpers/allure_helper.rb")
      end
    end

    describe 'with cucumber' do
      name = "#{frameworks.first}_#{automation_types.last}"

      it 'creates a browser helper file' do
        expect(File).to exist("#{name}/helpers/browser_helper.rb")
      end

      it 'creates a raider file' do
        expect(File).to exist("#{name}/helpers/raider.rb")
      end

      it 'does not create a spec helper' do
        expect(File).not_to exist("#{name}/helpers/spec_helper.rb")
      end
    end
  end

  context 'with appium android' do
    describe 'with rspec' do
      name = "#{frameworks.last}_#{automation_types.first}"

      it 'creates a raider file' do
        expect(File).to exist("#{name}/helpers/raider.rb")
      end

      it 'creates an allure helper file' do
        expect(File).to exist("#{name}/helpers/allure_helper.rb")
      end

      it 'creates a driver helper file', :watir do
        expect(File).to exist("#{name}/helpers/driver_helper.rb")
      end
    end

    describe 'with cucumber' do
      name = "#{frameworks.first}_#{automation_types.first}"

      it 'creates a raider file' do
        expect(File).to exist("#{name}/helpers/raider.rb")
      end

      it 'creates an allure helper file' do
        expect(File).to exist("#{name}/helpers/allure_helper.rb")
      end

      it 'creates a driver helper file', :watir do
        expect(File).to exist("#{name}/helpers/driver_helper.rb")
      end
    end
  end

  context 'with appium ios' do
    describe 'with rspec' do
      name = "#{frameworks.last}_#{automation_types[1]}"

      it 'creates a raider file' do
        expect(File).to exist("#{name}/helpers/raider.rb")
      end

      it 'creates an allure helper file' do
        expect(File).to exist("#{name}/helpers/allure_helper.rb")
      end

      it 'creates a driver helper file', :watir do
        expect(File).to exist("#{name}/helpers/driver_helper.rb")
      end
    end

    describe 'with cucumber' do
      name = "#{frameworks.first}_#{automation_types[1]}"

      it 'creates a raider file' do
        expect(File).to exist("#{name}/helpers/raider.rb")
      end

      it 'creates an allure helper file' do
        expect(File).to exist("#{name}/helpers/allure_helper.rb")
      end

      it 'creates a driver helper file', :watir do
        expect(File).to exist("#{name}/helpers/driver_helper.rb")
      end
    end
  end
end
