# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require_relative '../../../lib/utilities/schedules/project'

RSpec.describe RubyRaider::Schedules::Project do # rubocop:disable RSpec/FilePath
  let(:dir) { File.realpath(Dir.mktmpdir('raider-project')) }
  let(:outside) { File.realpath(Dir.mktmpdir('raider-outside')) }
  let(:project) { described_class.new(dir) }
  let(:helper) { File.join(dir, 'helpers', 'driver_helper.rb') }
  let(:runtime_helper) { "# frozen_string_literal: true\n\nrequire 'yaml'\nrequire 'ruby_raider/runtime'\n" }

  before { FileUtils.mkdir_p(File.dirname(helper)) }

  after { FileUtils.rm_rf([dir, outside]) }

  describe '#runtime_driver?' do
    it 'is true when helpers/driver_helper.rb requires the runtime' do
      File.write(helper, runtime_helper)
      expect(project.runtime_driver?).to be(true)
    end

    it 'is true for a helper with bytes that are not UTF-8' do
      File.binwrite(helper, "# \xFF\xFE\n#{runtime_helper}")
      expect(project.runtime_driver?).to be(true)
    end

    it 'is true when the helper links to a file inside the project' do
      File.write(File.join(dir, 'real_helper.rb'), runtime_helper)
      File.symlink(File.join(dir, 'real_helper.rb'), helper)
      expect(project.runtime_driver?).to be(true)
    end

    it 'is false when the helper is missing, made before 4.0, or only mentions the runtime in a comment' do
      results = [project.runtime_driver?]
      File.write(helper, "require 'selenium-webdriver'\nrequire 'yaml'\n")
      results << project.runtime_driver?
      File.write(helper, "# require 'ruby_raider/runtime'\n")
      results << project.runtime_driver?
      expect(results).to eq([false, false, false])
    end

    it 'is false when the helper links out of the project' do
      File.write(File.join(outside, 'driver_helper.rb'), runtime_helper)
      File.symlink(File.join(outside, 'driver_helper.rb'), helper)
      expect(project.runtime_driver?).to be(false)
    end

    it 'is false when helpers/ links out of the project' do
      FileUtils.mkdir_p(File.join(outside, 'helpers'))
      File.write(File.join(outside, 'helpers', 'driver_helper.rb'), runtime_helper)
      FileUtils.rm_rf(File.dirname(helper))
      File.symlink(File.join(outside, 'helpers'), File.dirname(helper))
      expect(project.runtime_driver?).to be(false)
    end

    it 'is false when the helper is not a regular file' do
      File.mkfifo(helper)
      expect(project.runtime_driver?).to be(false)
    end
  end

  describe '#check_show_browser!' do
    it 'refuses a project made before Ruby Raider 4.0' do
      File.write(helper, "require 'selenium-webdriver'\n")
      expect { project.check_show_browser! }
        .to raise_error(RubyRaider::Schedules::Error, 'Show the browser needs a project made with Ruby Raider 4.0 or later')
    end

    it 'accepts a project whose driver_helper requires the runtime' do
      File.write(helper, runtime_helper)
      expect { project.check_show_browser! }.not_to raise_error
    end
  end
end
