# frozen_string_literal: true

require_relative '../lib/generators/automation_generator'
require_relative 'spec_helper'

describe AutomationGenerator do
  context 'with selenium' do
    it 'creates a login page file' do
      expect(File).to exist("#{name}/page_objects/pages/login_page.rb")
    end

    it 'creates an abstract page file' do
      expect(File).to exist("#{name}/page_objects/abstract/abstract_page.rb")
    end

    it 'creates an abstract component file' do
      expect(File).to exist("#{name}/page_objects/abstract/abstract_component.rb")
    end

    it 'creates a component file' do
      expect(File).to exist("#{name}/page_objects/components/header_component.rb")
    end
  end

  context 'with watir' do
    it 'creates a login page file' do
      expect(File).to exist("#{name}/page_objects/pages/login_page.rb")
    end

    it 'creates an abstract page file' do
      expect(File).to exist("#{name}/page_objects/abstract/abstract_page.rb")
    end

    it 'creates an abstract component file' do
      expect(File).to exist("#{name}/page_objects/abstract/abstract_component.rb")
    end

    it 'creates a component file' do
      expect(File).to exist("#{name}/page_objects/components/header_component.rb")
    end
  end

  context 'with rspec and appium on ios' do
    it 'creates a home page file' do
      expect(File).to exist("#{name}/page_objects/pages/home_page.rb")
    end

    it 'creates an abstract page file' do
      expect(File).to exist("#{name}/page_objects/abstract/abstract_page.rb")
    end

    it 'creates a pdp page file' do
      expect(File).to exist("#{name}/page_objects/pages/pdp_page.rb")
    end

    it 'creates an appium config file' do
      expect(File).to exist("#{name}/appium.txt")
    end
  end

  context 'with android and rspec' do
    it 'creates a home page file' do
      expect(File).to exist("#{name}/page_objects/pages/home_page.rb")
    end

    it 'creates an abstract page file' do
      expect(File).to exist("#{name}/page_objects/abstract/abstract_page.rb")
    end

    it 'creates a pdp page file' do
      expect(File).to exist("#{name}/page_objects/pages/pdp_page.rb")
    end

    it 'creates an appium config file' do
      expect(File).to exist("#{name}/appium.txt")
    end
  end

  context 'with cucumber and selenium' do
    it 'creates a login page file' do
      expect(File).to exist("#{name}/page_objects/pages/login_page.rb")
    end

    it 'creates an abstract page file' do
      expect(File).to exist("#{name}/page_objects/abstract/abstract_page.rb")
    end

    it 'creates an abstract component file' do
      expect(File).to exist("#{name}/page_objects/abstract/abstract_component.rb")
    end

    it 'creates a component file' do
      expect(File).to exist("#{name}/page_objects/components/header_component.rb")
    end
  end

  context 'with cucumber and watir' do
    it 'creates a login page file' do
      expect(File).to exist("#{name}/page_objects/pages/login_page.rb")
    end

    it 'creates an abstract page file' do
      expect(File).to exist("#{name}/page_objects/abstract/abstract_page.rb")
    end

    it 'creates an abstract component file' do
      expect(File).to exist("#{name}/page_objects/abstract/abstract_component.rb")
    end

    it 'creates a component file' do
      expect(File).to exist("#{name}/page_objects/components/header_component.rb")
    end
  end

  context 'with cucumber and appium' do
    it 'creates a home page file' do
      expect(File).to exist("#{name}/page_objects/pages/home_page.rb")
    end

    it 'creates an abstract page file' do
      expect(File).to exist("#{name}/page_objects/abstract/abstract_page.rb")
    end

    it 'creates a pdp page file' do
      expect(File).to exist("#{name}/page_objects/pages/pdp_page.rb")
    end

    it 'creates an appium config file' do
      expect(File).to exist("#{name}/appium.txt")
    end
  end
end
