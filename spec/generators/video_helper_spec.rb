# frozen_string_literal: true

require 'base64'
require 'erb'
require 'fileutils'
require 'stringio'
require 'tmpdir'
require 'yaml'
require_relative '../../lib/generators/helper_generator'

$LOAD_PATH.unshift(File.expand_path('fixtures/video_helper_stubs', __dir__))
require 'selenium-webdriver'

# Renders the real video_helper.tt for a project type, loads it, and drives it
# with doubles. ffmpeg is a fake shell script given through RAIDER_FFMPEG_PATH.
# rubocop:disable RSpec/MultipleMemoizedHelpers, RSpec/VerifiedDoubles, RSpec/ExpectOutput, RSpec/MultipleExpectations
describe 'Generated VideoHelper' do
  let(:template) { File.expand_path('../../lib/generators/templates/helpers/video_helper.tt', __dir__) }
  let(:png) { Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==') }
  let(:project_dir) { Dir.mktmpdir('video-helper-project') }
  let(:video_config) { { 'enabled' => true, 'fps' => 5, 'max_width' => 1280 } }
  let(:config_yml) { { 'browser' => 'chrome', 'video' => video_config } }
  let(:automation) { 'selenium' }
  let(:ffmpeg_mode) { :ok }
  let(:ffmpeg_body) do
    {
      ok: %(printf 'webm-bytes' > "$last"),
      fail: 'echo "boom" >&2; exit 1',
      empty: %(: > "$last"),
      hang: 'exec sleep 30'
    }.fetch(ffmpeg_mode)
  end
  let(:fake_ffmpeg) do
    path = File.join(project_dir, 'fake-ffmpeg')
    File.write(path, <<~SH)
      #!/bin/sh
      log_dir='#{project_dir}'
      printf '%s\\n' "$@" > "$log_dir/argv.txt"
      prev=''
      for arg in "$@"; do
        if [ "$prev" = "-i" ]; then cp "$arg" "$log_dir/list.txt"; fi
        prev="$arg"
        last="$arg"
      done
      #{ffmpeg_body}
    SH
    File.chmod(0o755, path)
    path
  end
  let(:env) { { 'RAIDER_FFMPEG_PATH' => fake_ffmpeg } }
  let(:tmp) { File.join(project_dir, 'tmp').tap { |dir| FileUtils.mkdir_p(dir) } }
  let(:argv) { File.exist?(argv_path) ? File.read(argv_path).lines(chomp: true) : nil }
  let(:argv_path) { File.join(project_dir, 'argv.txt') }
  let(:alerts) { double('target_locator') }
  let(:driver) { double('driver', switch_to: alerts) }
  let(:shots) { [] }
  let(:stderr) { StringIO.new }
  let(:warnings) { stderr.string.lines.grep(/\[video\]/) }

  def render_and_load
    generator = HelpersGenerator.new([automation, 'rspec', 'proj'])
    source = ERB.new(File.read(template), trim_mode: '-').result(generator.instance_eval { binding })
    path = File.join(project_dir, 'video_helper.rb')
    File.write(path, source)
    load path
  end

  def frame_files(recorder)
    Dir.glob(File.join(recorder.dir, 'frame-*.png'))
  end

  around do |example|
    original_stderr = $stderr
    $stderr = stderr
    FileUtils.mkdir_p(File.join(project_dir, 'config'))
    File.write(File.join(project_dir, 'config', 'config.yml'), config_yml.to_yaml)
    Dir.chdir(project_dir) { example.run }
  ensure
    $stderr = original_stderr
    Object.send(:remove_const, :VideoHelper) if defined?(VideoHelper)
    FileUtils.rm_rf(project_dir)
  end

  before do
    # Recorder tmpdirs land inside the project, which the around hook removes.
    stub_const('ENV', ENV.to_h.merge(env).merge('TMPDIR' => tmp).compact)
    allow(alerts).to receive(:alert).and_raise(Selenium::WebDriver::Error::NoSuchAlertError)
    allow(driver).to receive(:save_screenshot) do |path|
      shots << path
      File.binwrite(path, png)
    end
    render_and_load
  end

  context 'with a selenium project' do
    it 'stop(keep: false) never invokes ffmpeg and returns nil' do
      recorder = VideoHelper.recorder_for(driver)
      recorder.start
      VideoHelper.listener.after_click(:element, driver)

      expect(recorder.stop(keep: false)).to be_nil
      expect(argv).to be_nil
      expect(shots.size).to eq(1)
      expect(warnings).to be_empty
    end

    it 'stop(keep: true) invokes ffmpeg with libvpx and returns <tmpdir>/video.webm' do
      recorder = VideoHelper.recorder_for(driver)
      recorder.start
      VideoHelper.listener.after_navigate_to('https://example.test', driver)

      path = recorder.stop(keep: true)

      expect(path).to eq(File.join(recorder.dir, 'video.webm'))
      expect(File.size(path)).to be_positive
      expect(argv.each_cons(2).to_a).to include(%w[-c:v libvpx], %w[-deadline realtime], %w[-b:v 1M],
                                                %w[-f concat], %w[-safe 0], %w[-r 5], %w[-pix_fmt yuv420p])
      expect(argv.last).to eq(path)
      expect(shots.size).to eq(2) # navigate + final frame
      expect(warnings).to be_empty
    end

    it "scales frames to max_width via ffmpeg -vf scale='min(1280,iw)':-2" do
      recorder = VideoHelper.recorder_for(driver)
      recorder.start
      recorder.stop(keep: true)

      expect(argv.each_cons(2).to_a).to include(['-vf', "scale='min(1280,iw)':-2"])
    end

    context 'when the config sets other fps and max_width' do
      let(:video_config) { { 'enabled' => true, 'fps' => 10, 'max_width' => 640 } }

      it 'uses them for the output rate and the scale filter' do
        recorder = VideoHelper.recorder_for(driver)
        recorder.start
        recorder.stop(keep: true)

        expect(argv.each_cons(2).to_a).to include(['-vf', "scale='min(640,iw)':-2"], %w[-r 10])
      end
    end

    it 'writes a concat list timed by real gaps, clamped to [1/fps, 2.0], with the last file repeated' do
      allow(VideoHelper).to receive(:monotonic_now).and_return(10.0, 10.05, 13.05, 13.55)
      recorder = VideoHelper.recorder_for(driver)
      recorder.start
      listener = VideoHelper.listener
      listener.after_navigate_to('https://example.test', driver)
      listener.after_click(:element, driver)
      listener.after_change_value_of(:element, driver)
      recorder.stop(keep: true)

      expect(File.read(File.join(project_dir, 'list.txt'))).to eq(<<~LIST)
        file 'frame-000001.png'
        duration 0.200
        file 'frame-000002.png'
        duration 2.000
        file 'frame-000003.png'
        duration 0.500
        file 'frame-000004.png'
        duration 0.200
        file 'frame-000004.png'
      LIST
    end

    it 'saves frames as frame-%06d.png in the recorder tmpdir' do
      recorder = VideoHelper.recorder_for(driver)
      recorder.start
      VideoHelper.listener.after_click(:element, driver)

      expect(frame_files(recorder).map { |f| File.basename(f) }).to eq(['frame-000001.png'])
    end

    it 'does not capture after execute_script or find' do
      recorder = VideoHelper.recorder_for(driver)
      recorder.start
      VideoHelper.listener.after_execute_script('return 1', driver)
      VideoHelper.listener.after_find(:css, 'a', driver)

      expect(shots).to be_empty
    end

    it 'skips a frame without disabling when an alert is open, so the screenshot cannot dismiss it' do
      allow(alerts).to receive(:alert).and_return(double('alert'))
      recorder = VideoHelper.recorder_for(driver)
      recorder.start
      VideoHelper.listener.after_click(:element, driver)

      expect(shots).to be_empty
      expect(VideoHelper.enabled?).to be(true)
      expect(warnings).to be_empty
    end

    context 'when ffmpeg exits non-zero' do
      let(:ffmpeg_mode) { :fail }

      it 'returns nil and warns once' do
        recorder = VideoHelper.recorder_for(driver)
        recorder.start
        expect(recorder.stop(keep: true)).to be_nil
        second = VideoHelper.recorder_for(driver)
        second.start

        expect(second.stop(keep: true)).to be_nil
        expect(warnings.size).to eq(1)
        expect(warnings.first).to match(/\A\[video\] .+; recording disabled for this run\n\z/)
        expect(VideoHelper.enabled?).to be(false)
      end
    end

    context 'when ffmpeg writes 0 bytes' do
      let(:ffmpeg_mode) { :empty }

      it 'returns nil, warns once and removes the tmpdir' do
        recorder = VideoHelper.recorder_for(driver)
        recorder.start

        expect(recorder.stop(keep: true)).to be_nil
        expect(warnings.size).to eq(1)
        expect(File).not_to exist(recorder.dir)
      end
    end

    context 'when ffmpeg hangs' do
      let(:ffmpeg_mode) { :hang }

      it 'kills it after the encode timeout, returns nil and warns once' do
        stub_const('VideoHelper::ENCODE_TIMEOUT', 0.5)
        recorder = VideoHelper.recorder_for(driver)
        recorder.start
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        expect(recorder.stop(keep: true)).to be_nil
        expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 5
        expect(stderr.string).to eq("[video] ffmpeg could not encode the video: ffmpeg timed out after 0.5 seconds; recording disabled for this run\n")
      end
    end

    context 'when ffmpeg exits between the join timeout and the kill' do
      let(:ffmpeg_mode) { :hang }

      it 'ignores the missing process and still reports the timeout once' do
        stub_const('VideoHelper::ENCODE_TIMEOUT', 0.5)
        # Kill for real so the hung process ends, then report it as already gone.
        allow(Process).to receive(:kill).and_wrap_original do |original, *args|
          original.call(*args)
          raise Errno::ESRCH
        end
        recorder = VideoHelper.recorder_for(driver)
        recorder.start

        expect { expect(recorder.stop(keep: true)).to be_nil }.not_to raise_error
        expect(stderr.string).to include('ffmpeg timed out after 0.5 seconds')
        expect(warnings.size).to eq(1)
      end
    end

    it 'still encodes the saved frames, quietly, when only the final frame fails' do
      recorder = VideoHelper.recorder_for(driver)
      recorder.start
      VideoHelper.listener.after_click(:element, driver)
      allow(driver).to receive(:save_screenshot).and_raise(Selenium::WebDriver::Error::WebDriverError, 'browser crashed')

      expect(recorder.stop(keep: true)).to eq(File.join(recorder.dir, 'video.webm'))
      expect(File.read(File.join(project_dir, 'list.txt')).scan('frame-000001.png').size).to eq(2)
      expect(VideoHelper.enabled?).to be(true)
      expect(warnings).to be_empty
    end

    it 'returns nil quietly when the final frame fails and no frames were saved' do
      allow(driver).to receive(:save_screenshot).and_raise(Selenium::WebDriver::Error::WebDriverError, 'browser crashed')
      recorder = VideoHelper.recorder_for(driver)
      recorder.start

      expect(recorder.stop(keep: true)).to be_nil
      expect(File).not_to exist(recorder.dir)
      expect(argv).to be_nil
      expect(warnings).to be_empty
    end

    it 'returns nil, warns once, and does not raise when save_screenshot raises (driver quit)' do
      allow(driver).to receive(:save_screenshot).and_raise(Selenium::WebDriver::Error::WebDriverError, 'invalid session id')
      recorder = VideoHelper.recorder_for(driver)
      recorder.start

      expect { VideoHelper.listener.after_click(:element, driver) }.not_to raise_error
      expect(recorder.stop(keep: true)).to be_nil
      expect(warnings.size).to eq(1)
      expect(warnings.first).to include('invalid session id')
      expect(VideoHelper.recorder_for(driver)).to be_a(VideoHelper::NullRecorder)
    end

    it 'two recorders started at once use different tmpdirs' do
      first = VideoHelper.recorder_for(driver)
      second = VideoHelper.recorder_for(driver)
      first.start
      second.start

      expect(first.dir).not_to eq(second.dir)
      expect(first.dir).to start_with(tmp)
      expect([first.dir, second.dir]).to all(satisfy { |dir| File.directory?(dir) })
    end

    it 'adds no frames from hooks after stop' do
      recorder = VideoHelper.recorder_for(driver)
      recorder.start
      recorder.stop(keep: false)
      VideoHelper.listener.after_click(:element, driver)

      expect(shots).to be_empty
      expect(VideoHelper.active_recorder).to be_nil
    end

    it 'listener does nothing and does not raise with no active recorder' do
      expect { VideoHelper.listener.after_click(:element, driver) }.not_to raise_error
      expect(shots).to be_empty
      expect(warnings).to be_empty
    end

    it 'returns one process-wide listener' do
      expect(VideoHelper.listener).to be_a(VideoHelper::FrameListener)
      expect(VideoHelper.listener).to equal(VideoHelper.listener)
    end

    it 'cleanup removes the tmpdir and is safe to call twice' do
      recorder = VideoHelper.recorder_for(driver)
      recorder.start
      recorder.stop(keep: true)
      recorder.cleanup

      expect(File).not_to exist(recorder.dir)
      expect { recorder.cleanup }.not_to raise_error
      expect(recorder.stop(keep: true)).to be_nil
    end

    it 'disable! warns once in the [video] format' do
      VideoHelper.disable!('first reason')
      VideoHelper.disable!('second reason')

      expect(warnings).to eq(["[video] first reason; recording disabled for this run\n"])
    end

    it 'records frames of a Watir browser through its Selenium driver' do
      browser = double('browser', wd: driver)
      recorder = VideoHelper.recorder_for(browser)
      recorder.start

      expect(recorder.stop(keep: true)).to end_with('video.webm')
      expect(shots.size).to eq(1)
    end

    context 'when the ruby_raider gem has no ffmpeg support' do
      it 'disables video with an update hint' do
        allow(VideoHelper).to receive(:require).with('ruby_raider/ffmpeg').and_raise(LoadError)
        recorder = VideoHelper.recorder_for(driver)
        recorder.start

        expect(recorder.stop(keep: true)).to be_nil
        expect(warnings).to eq(["[video] ruby_raider gem too old for video; update it; recording disabled for this run\n"])
      end
    end

    context 'when no ffmpeg can be obtained (no override, placeholder manifest)' do
      let(:env) { { 'RAIDER_FFMPEG_PATH' => nil } }

      it 'decides once, at the first call: listener nil, NullRecorder, exactly one [video] line' do
        require 'ruby_raider/ffmpeg'
        allow(RubyRaider::Ffmpeg).to receive(:ensure!)

        expect(VideoHelper.listener).to be_nil
        expect(warnings.size).to eq(1)
        expect(VideoHelper.recorder_for(driver)).to be_a(VideoHelper::NullRecorder)
        expect(VideoHelper.listener).to be_nil
        expect(warnings).to eq(['[video] no ffmpeg available for this platform yet (set RAIDER_FFMPEG_PATH, or run ' \
                                '`raider u video install` once the ffmpeg release is published); ' \
                                "recording disabled for this run\n"])
        expect(RubyRaider::Ffmpeg).not_to have_received(:ensure!)
        expect(shots).to be_empty
      end
    end

    it 'checks Ffmpeg.obtainable? only once per process' do
      require 'ruby_raider/ffmpeg'
      allow(RubyRaider::Ffmpeg).to receive(:obtainable?).and_call_original
      3.times { VideoHelper.recorder_for(driver) }
      VideoHelper.listener

      expect(RubyRaider::Ffmpeg).to have_received(:obtainable?).once
      expect(VideoHelper.enabled?).to be(true)
    end

    context 'when VIDEO=off and no ffmpeg can be obtained' do
      let(:env) { { 'RAIDER_FFMPEG_PATH' => nil, 'VIDEO' => 'off' } }

      it 'prints nothing' do
        VideoHelper.listener
        VideoHelper.recorder_for(driver)

        expect(warnings).to be_empty
      end
    end

    context 'when Ffmpeg.ensure! returns nil' do
      it 'disables video without a second warning' do
        require 'ruby_raider/ffmpeg'
        allow(RubyRaider::Ffmpeg).to receive(:ensure!) do
          $stderr.write("[video] ffmpeg build not published yet\n")
          nil
        end
        recorder = VideoHelper.recorder_for(driver)
        recorder.start

        expect(recorder.stop(keep: true)).to be_nil
        expect(warnings).to eq(["[video] ffmpeg build not published yet\n"])
        expect(VideoHelper.enabled?).to be(false)
      end
    end

    it 'never calls Ffmpeg.ensure! for a passing test' do
      require 'ruby_raider/ffmpeg'
      allow(RubyRaider::Ffmpeg).to receive(:ensure!)
      recorder = VideoHelper.recorder_for(driver)
      recorder.start
      recorder.stop(keep: false)

      expect(RubyRaider::Ffmpeg).not_to have_received(:ensure!)
    end

    context 'when VIDEO=off' do
      let(:env) { { 'RAIDER_FFMPEG_PATH' => fake_ffmpeg, 'VIDEO' => 'off' } }

      it 'makes recorder_for return a NullRecorder and listener nil' do
        expect(VideoHelper.recorder_for(driver)).to be_a(VideoHelper::NullRecorder)
        expect(VideoHelper.listener).to be_nil
      end
    end

    context 'when video is disabled in config' do
      let(:video_config) { { 'enabled' => false } }

      it 'makes recorder_for return a NullRecorder' do
        expect(VideoHelper.enabled?).to be(false)
        expect(VideoHelper.recorder_for(driver)).to be_a(VideoHelper::NullRecorder)
      end
    end

    context 'when config.yml has no video key (older project)' do
      let(:config_yml) { { 'browser' => 'chrome' } }

      it 'records with the defaults' do
        recorder = VideoHelper.recorder_for(driver)
        recorder.start
        recorder.stop(keep: true)

        expect(VideoHelper.enabled?).to be(true)
        expect(argv.each_cons(2).to_a).to include(['-vf', "scale='min(1280,iw)':-2"], %w[-r 5])
      end
    end

    it 'NullRecorder answers the recorder interface with nil' do
      recorder = VideoHelper::NullRecorder.new

      expect([recorder.start, recorder.stop(keep: true), recorder.cleanup]).to all(be_nil)
    end
  end

  describe '.final_attempt?' do
    let(:automation) { 'selenium' }

    def example_with(exception: StandardError.new('boom'), **metadata)
      double('example', exception:, metadata:)
    end

    it 'is true when the example passed' do
      expect(VideoHelper.final_attempt?(example_with(exception: nil, retry: 3, retry_attempts: 0))).to be(true)
    end

    it 'is false on attempt 1 of 3' do
      expect(VideoHelper.final_attempt?(example_with(retry: 3, retry_attempts: 0))).to be(false)
    end

    it 'is false on attempt 2 of 3' do
      expect(VideoHelper.final_attempt?(example_with(retry: 3, retry_attempts: 1))).to be(false)
    end

    it 'is true on attempt 3 of 3' do
      expect(VideoHelper.final_attempt?(example_with(retry: 3, retry_attempts: 2))).to be(true)
    end

    it 'is true when the retry count is 0 or unset' do
      expect(VideoHelper.final_attempt?(example_with(retry: 0, retry_attempts: 0))).to be(true)
      expect(VideoHelper.final_attempt?(example_with)).to be(true)
    end

    it 'reads the default retry count of rspec-retry when the example has no retry metadata' do
      RSpec.configuration.define_singleton_method(:default_retry_count) { 2 }

      expect(VideoHelper.final_attempt?(example_with(retry_attempts: 0))).to be(false)
      expect(VideoHelper.final_attempt?(example_with(retry_attempts: 1))).to be(true)
    ensure
      RSpec.configuration.singleton_class.send(:remove_method, :default_retry_count)
    end

    it 'lets RSPEC_RETRY_RETRY_COUNT win, as rspec-retry does' do
      stub_const('ENV', ENV.to_h.merge('RSPEC_RETRY_RETRY_COUNT' => '2'))

      expect(VideoHelper.final_attempt?(example_with(retry: 5, retry_attempts: 0))).to be(false)
      expect(VideoHelper.final_attempt?(example_with(retry: 5, retry_attempts: 1))).to be(true)
    end
  end

  context 'with an appium project' do
    let(:automation) { 'ios' }
    let(:mp4) { "\x00\x00\x00\x18ftypmp42".b }
    let(:appium) { double('appium_driver', start_recording_screen: nil, stop_recording_screen: Base64.strict_encode64(mp4)) }

    it 'uses an AppiumRecorder that writes the mp4 as-is when kept' do
      recorder = VideoHelper.recorder_for(appium)
      expect(recorder).to be_a(VideoHelper::AppiumRecorder)
      recorder.start
      path = recorder.stop(keep: true)

      expect(path).to eq(File.join(recorder.dir, 'video.mp4'))
      expect(File.binread(path)).to eq(mp4)
      expect(argv).to be_nil
    end

    it 'stops the device recording but keeps nothing when not kept' do
      recorder = VideoHelper.recorder_for(appium)
      recorder.start

      expect(recorder.stop(keep: false)).to be_nil
      expect(appium).to have_received(:stop_recording_screen)
      expect(File).not_to exist(recorder.dir)
    end

    it 'records through the core driver of an appium_lib Appium::Driver' do
      wrapper = double('appium_lib_driver', driver: appium)
      recorder = VideoHelper.recorder_for(wrapper)
      recorder.start

      expect(recorder.stop(keep: true)).to end_with('video.mp4')
      expect(appium).to have_received(:start_recording_screen).with(time_limit: 1800)
    end

    it 'warns once and does not raise when start_recording_screen fails' do
      allow(appium).to receive(:start_recording_screen).and_raise(StandardError, 'not supported')
      recorder = VideoHelper.recorder_for(appium)

      expect { recorder.start }.not_to raise_error
      expect(recorder.stop(keep: true)).to be_nil
      expect(warnings.size).to eq(1)
      expect(File).not_to exist(recorder.dir)
    end

    it 'has no listener' do
      expect(VideoHelper).not_to respond_to(:listener)
    end

    it 'asks iOS for a 1800 s recording' do
      VideoHelper.recorder_for(appium).start

      expect(appium).to have_received(:start_recording_screen).with(time_limit: 1800)
    end

    context 'when the project is android' do
      let(:automation) { 'android' }

      it "keeps Appium's 180 s limit, which needs no ffmpeg on the Appium host" do
        VideoHelper.recorder_for(appium).start

        expect(appium).to have_received(:start_recording_screen).with(time_limit: 180)
      end
    end

    context 'when an android project sets video.time_limit in config.yml' do
      let(:automation) { 'android' }
      let(:video_config) { { 'enabled' => true, 'time_limit' => 600 } }

      it 'uses it' do
        VideoHelper.recorder_for(appium).start

        expect(appium).to have_received(:start_recording_screen).with(time_limit: 600)
      end
    end

    context 'when the project is cross-platform' do
      let(:automation) { 'cross_platform' }

      it 'picks the limit from the platform in config.yml' do
        File.write('config/config.yml', { 'platform' => :android }.to_yaml)
        VideoHelper.recorder_for(appium).start
        File.write('config/config.yml', "platform: :ios\n")
        VideoHelper.recorder_for(appium).start

        expect(appium).to have_received(:start_recording_screen).with(time_limit: 180).ordered
        expect(appium).to have_received(:start_recording_screen).with(time_limit: 1800).ordered
      end
    end

    it 'defines final_attempt? too' do
      example = double('example', exception: StandardError.new('boom'), metadata: { retry: 3, retry_attempts: 2 })

      expect(VideoHelper.final_attempt?(example)).to be(true)
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers, RSpec/VerifiedDoubles, RSpec/ExpectOutput, RSpec/MultipleExpectations
