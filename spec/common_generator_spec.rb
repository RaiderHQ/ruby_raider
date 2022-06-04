# frozen_string_literal: true

require_relative '../lib/generators/common_generator'
require_relative 'spec_helper'

describe CommonGenerator do
  context 'with selenium' do
    before(:all) do
      @name = 'rspec-selenium'
      CommonGenerator.new(['selenium', 'rspec', @name]).invoke_all
    end

    it 'creates a config file' do
      expect(File.exist?("#{@name}/config/config.yml")).to be_truthy
    end

    it 'creates a rake file' do
      expect(File.exist?("#{@name}/Rakefile")).to be_truthy
    end

    it 'creates a readMe file' do
      expect(File.exist?("#{@name}/Readme.md")).to be_truthy
    end

    it 'creates a gemfile file' do
      expect(File.exist?("#{@name}/Gemfile")).to be_truthy
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end
  end

  context 'with watir' do
    before(:all) do
      @name = 'rspec-watir'
      CommonGenerator.new(['watir', 'rspec', @name]).invoke_all
    end

    it 'creates a config file' do
      expect(File.exist?("#{@name}/config/config.yml")).to be_truthy
    end

    it 'creates a rake file' do
      expect(File.exist?("#{@name}/Rakefile")).to be_truthy
    end

    it 'creates a readMe file' do
      expect(File.exist?("#{@name}/Readme.md")).to be_truthy
    end

    it 'creates a gemfile file' do
      expect(File.exist?("#{@name}/Gemfile")).to be_truthy
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end
  end

  context 'with appium' do
    before(:all) do
      @name = 'rspec-appium'
      CommonGenerator.new(['appium_ios', 'rspec', @name]).invoke_all
    end

    it 'creates a config file' do
      expect(File.exist?("#{@name}/config/config.yml")).to be_truthy
    end

    it 'creates a rake file' do
      expect(File.exist?("#{@name}/Rakefile")).to be_truthy
    end

    it 'creates a readMe file' do
      expect(File.exist?("#{@name}/Readme.md")).to be_truthy
    end

    it 'creates a gemfile file' do
      expect(File.exist?("#{@name}/Gemfile")).to be_truthy
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end

    context 'with cucumber and selenium' do
      before(:all) do
        @name = 'cucumber-selenium'
        CommonGenerator.new(['selenium', 'cucumber', @name]).invoke_all
      end

      it 'creates a config file' do
        expect(File.exist?("#{@name}/config/config.yml")).to be_truthy
      end

      it 'creates a rake file' do
        expect(File.exist?("#{@name}/Rakefile")).to be_truthy
      end

      it 'creates a readMe file' do
        expect(File.exist?("#{@name}/Readme.md")).to be_truthy
      end

      it 'creates a gemfile file' do
        expect(File.exist?("#{@name}/Gemfile")).to be_truthy
      end

      after(:all) do
        FileUtils.rm_rf(@name)
      end
    end

    context 'with cucumber and watir' do
      before(:all) do
        @name = 'cucumber-watir'
        CommonGenerator.new(['watir', 'cucumber', @name]).invoke_all
      end

      it 'creates a config file' do
        expect(File.exist?("#{@name}/config/config.yml")).to be_truthy
      end

      it 'creates a rake file' do
        expect(File.exist?("#{@name}/Rakefile")).to be_truthy
      end

      it 'creates a readMe file' do
        expect(File.exist?("#{@name}/Readme.md")).to be_truthy
      end

      it 'creates a gemfile file' do
        expect(File.exist?("#{@name}/Gemfile")).to be_truthy
      end

      after(:all) do
        FileUtils.rm_rf(@name)
      end
    end
  end
end
