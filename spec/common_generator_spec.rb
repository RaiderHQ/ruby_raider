# frozen_string_literal: true

require_relative '../lib/generators/common_generator'
require_relative 'spec_helper'

describe CommonGenerator do
  context 'with selenium' do
    it 'creates a config file' do
      expect(File).to exist("#{name}/config/config.yml")
    end

    it 'creates a rake file' do
      expect(File).to exist("#{name}/Rakefile")
    end

    it 'creates a readMe file' do
      expect(File).to exist("#{name}/Readme.md")
    end

    it 'creates a gemfile file' do
      expect(File).to exist("#{name}/Gemfile")
    end
  end

  context 'with watir' do
    it 'creates a config file' do
      expect(File).to exist("#{name}/config/config.yml")
    end

    it 'creates a rake file' do
      expect(File).to exist("#{name}/Rakefile")
    end

    it 'creates a readMe file' do
      expect(File).to exist("#{name}/Readme.md")
    end

    it 'creates a gemfile file' do
      expect(File).to exist("#{name}/Gemfile")
    end
  end

  context 'with appium' do
    it 'creates a config file' do
      expect(File).to exist("#{name}/config/config.yml")
    end

    it 'creates a rake file' do
      expect(File).to exist("#{name}/Rakefile")
    end

    it 'creates a readMe file' do
      expect(File).to exist("#{name}/Readme.md")
    end

    it 'creates a gemfile file' do
      expect(File).to exist("#{name}/Gemfile")
    end

    context 'with cucumber and selenium' do
      name = 'cucumber-selenium'
      it 'creates a config file' do
        expect(File).to exist("#{name}/config/config.yml")
      end

      it 'creates a rake file' do
        expect(File).to exist("#{name}/Rakefile")
      end

      it 'creates a readMe file' do
        expect(File).to exist("#{name}/Readme.md")
      end

      it 'creates a gemfile file' do
        expect(File).to exist("#{name}/Gemfile")
      end
    end

    context 'with cucumber and watir' do
      it 'creates a config file' do
        expect(File).to exist("#{name}/config/config.yml")
      end

      it 'creates a rake file' do
        expect(File).to exist("#{name}/Rakefile")
      end

      it 'creates a readMe file' do
        expect(File).to exist("#{name}/Readme.md")
      end

      it 'creates a gemfile file' do
        expect(File).to exist("#{name}/Gemfile")
      end
    end
  end
end
