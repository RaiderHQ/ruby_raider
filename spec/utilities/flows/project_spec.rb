# frozen_string_literal: true

require 'stringio'
require 'tmpdir'
require_relative '../../../lib/utilities/flows/project'

# Flow specs live under spec/utilities/flows, next to the code in lib/utilities/flows
RSpec.describe RubyRaider::Flows::Project do # rubocop:disable RSpec/FilePath
  let(:dir) { Dir.mktmpdir('flows-project') }
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  let(:project) { described_class.new(dir) }

  def write(relative, content)
    file = File.join(dir, relative)
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, content)
  end

  def read(relative) = File.read(File.join(dir, relative))

  def selenium_project(pin: "'~> 4.0'")
    write('Gemfile', "gem 'raider_reporter', '~> 1.0'\ngem 'ruby_raider', #{pin}\ngem 'selenium-webdriver'\n")
    write('helpers/driver_helper.rb', "require 'selenium-webdriver'\nrequire 'ruby_raider/runtime'\n")
    write('.gitignore', "raider-results\nspec/examples.txt\n.raider/auth/\n")
  end

  after { FileUtils.rm_rf(dir) }

  describe '#init' do
    it 'creates the flow helper, the run recorder and the gitignore lines' do
      selenium_project

      expect(project.init(out:, err:)).to eq(0)
      expect(File).to exist(File.join(dir, 'flows/flow_helper.rb'))
      expect(File).to exist(File.join(dir, 'flows/support/run.rb'))
      expect(read('.gitignore').lines.map(&:strip)).to include('flow-results/', '.raider/flows/', '.raider/auth/')
    end

    it 'raises a ~> 4.0 ruby_raider pin to ~> 4.1 and says to bundle' do
      selenium_project

      project.init(out:, err:)

      expect(read('Gemfile')).to include("gem 'ruby_raider', '~> 4.1'")
      expect(out.string).to include('Run bundle install')
    end

    it 'keeps a pin that already allows flows' do
      selenium_project(pin: "'~> 4.2'")

      project.init(out:, err:)

      expect(read('Gemfile')).to include("gem 'ruby_raider', '~> 4.2'")
      expect(out.string).not_to include('Run bundle install')
    end

    it 'is idempotent' do
      selenium_project
      project.init(out:, err:)
      helper = read('flows/flow_helper.rb')
      second = StringIO.new

      expect(project.init(out: second, err:)).to eq(0)
      expect(second.string).to eq("Flows already set up\n")
      expect(read('flows/flow_helper.rb')).to eq(helper)
      expect(read('.gitignore').scan('flow-results/').size).to eq(1)
    end

    it 'never overwrites a flow helper the user changed' do
      selenium_project
      write('flows/flow_helper.rb', "# mine\n")

      project.init(out:, err:)

      expect(read('flows/flow_helper.rb')).to eq("# mine\n")
    end

    it 'adds a newline before the gitignore lines when the file does not end with one' do
      selenium_project
      write('.gitignore', 'raider-results')

      project.init(out:, err:)

      expect(read('.gitignore')).to eq("raider-results\nflow-results/\n.raider/flows/\n")
    end

    shared_examples 'a refused project' do
      it 'refuses with exit 2 and writes nothing' do
        expect(project.init(out:, err:)).to eq(2)
        expect(err.string).to eq("Flows need a Selenium web project made with Ruby Raider 4.0 or later\n")
        expect(File).not_to exist(File.join(dir, 'flows'))
      end
    end

    context 'with a mobile project' do
      before do
        selenium_project
        write('Gemfile', "gem 'appium_lib'\ngem 'ruby_raider', '~> 4.0'\n")
      end

      it_behaves_like 'a refused project'
    end

    context 'with a 3.x project' do
      before do
        selenium_project(pin: "'~> 3.15'")
        write('helpers/driver_helper.rb', "require 'selenium-webdriver'\n")
      end

      it_behaves_like 'a refused project'
    end

    context 'with a 3.x pin on 4.0 helpers' do
      before { selenium_project(pin: "'~> 3.15'") }

      it_behaves_like 'a refused project'
    end

    context 'without a Gemfile' do
      it_behaves_like 'a refused project'
    end
  end

  describe '#flow_file' do
    before { selenium_project }

    it 'returns the real path of flows/<name>_flow.rb' do
      write('flows/report_flow.rb', '')

      expect(project.flow_file('report')).to eq(File.realpath(File.join(dir, 'flows/report_flow.rb')))
    end

    it 'rejects a name outside the allowed characters' do
      expect { project.flow_file('../x') }.to raise_error(RubyRaider::Flows::Error, /Invalid flow name/)
    end

    it 'rejects a name longer than 60 characters' do
      expect { project.flow_file('a' * 61) }.to raise_error(RubyRaider::Flows::Error, /Invalid flow name/)
    end

    it 'reports a missing flow' do
      expect { project.flow_file('nope') }.to raise_error(RubyRaider::Flows::Error, 'No flow nope: flows/nope_flow.rb not found')
    end

    it 'rejects a flow file that links outside the project' do
      outside = Dir.mktmpdir('outside')
      File.write(File.join(outside, 'evil_flow.rb'), '')
      FileUtils.mkdir_p(File.join(dir, 'flows'))
      File.symlink(File.join(outside, 'evil_flow.rb'), File.join(dir, 'flows/evil_flow.rb'))

      expect { project.flow_file('evil') }.to raise_error(RubyRaider::Flows::Error, /outside the project/)
    ensure
      FileUtils.rm_rf(outside)
    end
  end

  describe '#flow_names' do
    it 'lists flow files by name, sorted' do
      write('flows/b_flow.rb', '')
      write('flows/a_flow.rb', '')
      write('flows/flow_helper.rb', '')

      expect(project.flow_names).to eq(%w[a b])
    end
  end

  it 'raises a Flows::Error for a missing project folder' do
    expect { described_class.new(File.join(dir, 'missing')) }.to raise_error(RubyRaider::Flows::Error, /Project folder not found/)
  end
end
