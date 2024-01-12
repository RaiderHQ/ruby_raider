# frozen_string_literal: true

require_relative '../helpers/spec_helper'
require_relative '../models/model_factory'
require_relative '../page_objects/pages/account'
require_relative '../page_objects/pages/login'

describe 'Login' do
  subject(:header) { account_page.header.customer_name }

  let(:user) { ModelFactory.for('users')['registered user'] }
  let(:login_page) { Login.new(driver) }
  let(:account_page) { Account.new(driver) }

  before do
    login_page.visit
    login_page.login(user['username'], password)
  end

  context 'with right credentials' do
    let(:password) { user['password'] }

    it 'can successfully log in' do
      check_page account_page
    end
  end

  context 'with wrong credentials' do
    let(:password) { 'wrongPassword' }

    it 'cannot log in' do
      check_page login_page
    end
  end
end
