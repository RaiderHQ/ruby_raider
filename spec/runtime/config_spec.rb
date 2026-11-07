# frozen_string_literal: true

require 'rspec'
require 'tmpdir'
require 'fileutils'
require_relative '../../lib/ruby_raider/runtime/config'

RSpec.describe 'Raider configuration' do
  let(:env_keys) { %w[RAIDER_STRICT RAIDER_ACTIONABILITY RAIDER_TIMEOUT RAIDER_TEST_ID_ATTRIBUTE] }

  around do |example|
    saved = env_keys.to_h { |key| [key, ENV.fetch(key, nil)] }
    env_keys.each { |key| ENV.delete(key) }
    Raider.reset
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) { example.run }
    end
  ensure
    saved.each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
    Raider.reset
  end

  def write_config(content)
    FileUtils.mkdir_p('config')
    File.write(Raider::CONFIG_FILE, content)
    Raider.reset
  end

  it 'uses defaults without a file or env' do
    expect([Raider.strict, Raider.actionability, Raider.timeout, Raider.test_id_attribute])
      .to eq([true, true, 10, 'data-testid'])
  end

  it 'prefers file values over defaults' do
    write_config("strict: false\nactionability: 'off'\ntimeout: 3.5\ntest_id_attribute: data-qa\n")
    expect([Raider.strict, Raider.actionability, Raider.timeout, Raider.test_id_attribute])
      .to eq([false, false, 3.5, 'data-qa'])
  end

  it 'prefers env over the file' do
    write_config("strict: true\n")
    ENV['RAIDER_STRICT'] = 'off'
    expect(Raider.strict).to be(false)
  end

  it 'reads env timeout and test id attribute' do
    ENV['RAIDER_TIMEOUT'] = '2.5'
    ENV['RAIDER_TEST_ID_ATTRIBUTE'] = 'data-cy'
    expect([Raider.timeout, Raider.test_id_attribute]).to eq([2.5, 'data-cy'])
  end

  it 'prefers the setter over env' do
    ENV['RAIDER_STRICT'] = 'off'
    Raider.strict = true
    expect(Raider.strict).to be(true)
  end

  it 'ignores a non-Hash YAML file' do
    write_config("- one\n- two\n")
    expect(Raider.timeout).to eq(10)
  end

  it 're-reads the file after reset' do
    write_config("timeout: 4\n")
    expect(Raider.timeout).to eq(4)
    write_config("timeout: 6\n")
    expect(Raider.timeout).to eq(6)
  end
end
