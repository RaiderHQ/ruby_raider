# frozen_string_literal: true

require 'tmpdir'
require_relative '../../../lib/utilities/schedules/selection'

RSpec.describe RubyRaider::Schedules::Selection do # rubocop:disable RSpec/FilePath
  let(:tmp) { File.realpath(Dir.mktmpdir('schedules-selection')) }
  let(:root) { File.join(tmp, 'project') }
  let(:mac) { 'darwin24' }
  let(:windows) { 'mingw32' }

  before do
    FileUtils.mkdir_p(File.join(root, 'spec/login'))
    %w[spec/a_spec.rb spec/b_spec.rb spec/login/c_spec.rb].each { |file| File.write(File.join(root, file), '') }
  end

  after { FileUtils.rm_rf(tmp) }

  def parse(files: [], tag: nil, host_os: mac) = described_class.parse(files: files, tag: tag, root: root, host_os: host_os)

  def error_for(...)
    parse(...)
    nil
  rescue RubyRaider::Schedules::Error => e
    e.message
  end

  def load_error(hash, host_os: mac)
    described_class.from_h(hash, root: root, host_os: host_os)
    nil
  rescue RubyRaider::Schedules::Error => e
    e.message
  end

  describe '.parse' do
    it 'selects all tests with no files and no tag' do
      expect([parse.kind, parse.to_h]).to eq(['all', { 'kind' => 'all' }])
    end

    it 'selects one tag' do
      expect(parse(tag: 'smoke:fast-1_x').to_h).to eq({ 'kind' => 'tag', 'tag' => 'smoke:fast-1_x' })
    end

    it 'selects files, removing duplicates and keeping their order' do
      selection = parse(files: %w[spec/b_spec.rb spec/a_spec.rb spec/b_spec.rb spec/login/c_spec.rb])

      expect(selection.to_h).to eq({ 'kind' => 'files', 'files' => %w[spec/b_spec.rb spec/a_spec.rb spec/login/c_spec.rb] })
    end

    it 'refuses a tag together with files' do
      expect(error_for(files: %w[spec/a_spec.rb], tag: 'smoke')).to eq('Use --tag or spec files, not both')
    end

    it 'refuses a tag with a space, a semicolon, a newline or nothing in it' do
      errors = ['smoke test', 'smoke;rm', "smoke\n;x", '', 'smoke$(id)', 1, "\xFF".dup.force_encoding('UTF-8')].map { |tag| error_for(tag: tag) }

      expect(errors).to all(start_with('Invalid tag'))
    end

    it 'refuses paths that climb out, look like options or are absolute' do
      hostile = ['../x_spec.rb', 'spec/../../x_spec.rb', '-rf_spec.rb', '/abs_spec.rb', "#{root}/spec/a_spec.rb"]

      expect(hostile.map { |file| error_for(files: [file]) }).to all(start_with('Invalid spec file'))
    end

    it 'refuses a file that is not a _spec.rb, has a control character or is not text' do
      bad = ['spec/a.rb', 'spec/a_spec.rb.bak', "spec/a\n_spec.rb", "spec/a\0_spec.rb", '', nil, 1, "spec/\xFF_spec.rb".b.force_encoding('UTF-8')]

      expect(bad.map { |file| error_for(files: [file]) }).to all(start_with('Invalid spec file'))
    end

    it 'refuses a link that points outside the project' do
      outside = File.join(tmp, 'outside_spec.rb')
      File.write(outside, '')
      File.symlink(outside, File.join(root, 'spec/link_spec.rb'))

      expect(error_for(files: %w[spec/link_spec.rb])).to eq('spec/link_spec.rb points outside the project')
    end

    it 'refuses a folder link that points outside the project' do
      FileUtils.mkdir_p(File.join(tmp, 'elsewhere'))
      File.write(File.join(tmp, 'elsewhere/x_spec.rb'), '')
      File.symlink(File.join(tmp, 'elsewhere'), File.join(root, 'spec/away'))

      expect(error_for(files: %w[spec/away/x_spec.rb])).to eq('spec/away/x_spec.rb points outside the project')
    end

    it 'takes a link that stays inside the project' do
      File.symlink(File.join(root, 'spec/a_spec.rb'), File.join(root, 'spec/alias_spec.rb'))

      expect(parse(files: %w[spec/alias_spec.rb]).files).to eq(%w[spec/alias_spec.rb])
    end

    it 'refuses a file that is not there' do
      expect(error_for(files: %w[spec/a_spec.rb spec/gone_spec.rb])).to eq('spec/gone_spec.rb not found')
    end

    it 'takes 200 files and refuses 201' do
      files = Array.new(201) { |index| "spec/many/f#{index}_spec.rb" }
      FileUtils.mkdir_p(File.join(root, 'spec/many'))
      files.each { |file| File.write(File.join(root, file), '') }

      expect([parse(files: files.first(200)).files.size, error_for(files: files)])
        .to eq([200, 'Too many spec files (201): select at most 200, or use a tag'])
    end

    it 'counts files after removing duplicates' do
      expect(parse(files: %w[spec/a_spec.rb] * 300).files).to eq(%w[spec/a_spec.rb])
    end

    it 'refuses %NAME% and glob characters in a file on Windows only' do
      %w[a%PATH%_spec.rb a*_spec.rb a?_spec.rb a[1]_spec.rb a{b}_spec.rb].each { |file| File.write(File.join(root, 'spec', file), '') }
      files = %w[spec/a%PATH%_spec.rb spec/a*_spec.rb spec/a?_spec.rb spec/a[1]_spec.rb spec/a{b}_spec.rb]

      expect([files.map { |file| error_for(files: [file], host_os: windows) }, files.map { |file| error_for(files: [file]) }])
        .to match([all(start_with('Invalid spec file')), all(be_nil)])
    end

    it 'refuses backslash climbs and drive paths on Windows' do
      errors = ['spec\\..\\..\\x_spec.rb', 'C:/x_spec.rb', '\\\\host\\x_spec.rb'].map { |file| error_for(files: [file], host_os: windows) }

      expect(errors).to all(start_with('Invalid spec file'))
    end
  end

  describe '.from_h' do
    it 'reads back what to_h wrote' do
      [parse, parse(tag: 'smoke'), parse(files: %w[spec/a_spec.rb spec/login/c_spec.rb])].each do |selection|
        expect(described_class.from_h(selection.to_h, root: root, host_os: mac).to_h).to eq(selection.to_h)
      end
    end

    it 'loads a selection whose file is gone and names the missing file' do
      selection = described_class.from_h({ 'kind' => 'files', 'files' => %w[spec/a_spec.rb spec/gone_spec.rb] }, root: root, host_os: mac)

      expect([selection.missing_file(root), parse(files: %w[spec/a_spec.rb]).missing_file(root)]).to eq(['spec/gone_spec.rb', nil])
    end

    it 'refuses on load a file that exists but resolves outside the project' do
      File.write(File.join(tmp, 'outside_spec.rb'), '')
      File.symlink(File.join(tmp, 'outside_spec.rb'), File.join(root, 'spec/link_spec.rb'))

      expect(load_error({ 'kind' => 'files', 'files' => %w[spec/link_spec.rb] })).to eq('spec/link_spec.rb points outside the project')
    end

    it 'refuses broken shapes as errors, never anything else' do
      broken = [nil, 'all', [], {}, { 'kind' => 'some' }, { 'kind' => 'tag' }, { 'kind' => 'tag', 'tag' => 'a b' },
                { 'kind' => 'files' }, { 'kind' => 'files', 'files' => [] }, { 'kind' => 'files', 'files' => 'spec/a_spec.rb' },
                { 'kind' => 'files', 'files' => [1] }, { 'kind' => 'files', 'files' => ['../x_spec.rb'] },
                { 'kind' => 'all', 'tag' => 'smoke' }, { 'kind' => 'tag', 'tag' => 'smoke', 'files' => %w[spec/a_spec.rb] },
                { 'kind' => 'files', 'files' => Array.new(201) { |index| "spec/f#{index}_spec.rb" } }]

      expect(broken.map { |hash| load_error(hash) }).to all(be_a(String))
    end

    it 'applies the Windows rules on load' do
      expect(load_error({ 'kind' => 'files', 'files' => %w[spec/a%PATH%_spec.rb] }, host_os: windows)).to start_with('Invalid spec file')
    end
  end

  describe '#check!' do
    it 'raises for a missing file and returns itself otherwise' do
      gone = described_class.from_h({ 'kind' => 'files', 'files' => %w[spec/gone_spec.rb] }, root: root, host_os: mac)
      present = parse(files: %w[spec/a_spec.rb])

      expect(present.check!(root)).to be(present)
      expect { gone.check!(root) }.to raise_error(RubyRaider::Schedules::Error, 'spec/gone_spec.rb not found')
    end
  end

  it 'is frozen' do
    selection = parse(files: %w[spec/a_spec.rb])

    expect([selection, selection.files, selection.files.first]).to all(be_frozen)
  end
end
