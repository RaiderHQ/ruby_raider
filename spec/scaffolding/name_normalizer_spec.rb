# frozen_string_literal: true

require_relative '../../lib/scaffolding/name_normalizer'

RSpec.describe NameNormalizer do
  describe '.normalize' do
    it 'strips _page suffix' do
      expect(described_class.normalize('login_page')).to eq('login')
    end

    it 'strips _spec suffix' do
      expect(described_class.normalize('login_spec')).to eq('login')
    end

    it 'strips _steps suffix' do
      expect(described_class.normalize('login_steps')).to eq('login')
    end

    it 'strips _helper suffix' do
      expect(described_class.normalize('login_helper')).to eq('login')
    end

    it 'converts CamelCase to snake_case' do
      expect(described_class.normalize('LoginPage')).to eq('login')
    end

    it 'handles CamelCase without suffix' do
      expect(described_class.normalize('Dashboard')).to eq('dashboard')
    end

    it 'preserves nested paths' do
      expect(described_class.normalize('admin/users')).to eq('admin/users')
    end

    it 'handles CamelCase nested paths' do
      expect(described_class.normalize('Admin::UsersPage')).to eq('admin/users')
    end

    it 'leaves clean names unchanged' do
      expect(described_class.normalize('login')).to eq('login')
    end
  end

  describe '.to_class_name' do
    it 'converts snake_case to CamelCase' do
      expect(described_class.to_class_name('login')).to eq('Login')
    end

    it 'handles underscored names' do
      expect(described_class.to_class_name('user_profile')).to eq('UserProfile')
    end

    it 'strips suffixes before converting' do
      expect(described_class.to_class_name('login_page')).to eq('Login')
    end

    it 'handles nested names with modules' do
      expect(described_class.to_class_name('admin/users')).to eq('Admin::Users')
    end

    it 'appends optional suffix' do
      expect(described_class.to_class_name('login', 'Page')).to eq('LoginPage')
    end
  end

  describe '.to_page_class' do
    it 'converts to page class name' do
      expect(described_class.to_page_class('login')).to eq('LoginPage')
    end

    it 'does not double the Page suffix' do
      expect(described_class.to_page_class('login_page')).to eq('LoginPage')
    end

    it 'handles CamelCase input' do
      expect(described_class.to_page_class('LoginPage')).to eq('LoginPage')
    end
  end

  describe '.nested?' do
    it 'returns true for nested paths' do
      expect(described_class.nested?('admin/users')).to be true
    end

    it 'returns false for simple names' do
      expect(described_class.nested?('login')).to be false
    end
  end

  describe '.module_parts' do
    it 'returns module path for nested names' do
      expect(described_class.module_parts('admin/users')).to eq(['Admin'])
    end

    it 'returns empty for simple names' do
      expect(described_class.module_parts('login')).to eq([])
    end

    it 'handles deep nesting' do
      expect(described_class.module_parts('admin/settings/users')).to eq(%w[Admin Settings])
    end
  end

  describe '.leaf_name' do
    it 'returns last segment of nested path' do
      expect(described_class.leaf_name('admin/users')).to eq('users')
    end

    it 'returns name itself for simple names' do
      expect(described_class.leaf_name('login')).to eq('login')
    end
  end
end
