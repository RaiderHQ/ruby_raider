# frozen_string_literal: true

require 'erb'
require 'rspec/expectations'
# The real gem by its inner paths, not 'selenium-webdriver': spec/generators/video_helper_spec.rb puts a
# stub selenium-webdriver.rb first on $LOAD_PATH, and the stub's Support module would mask the autoload.
require 'selenium/webdriver'
require 'selenium/webdriver/support'
require 'tmpdir'
require 'yaml'

# Renders the WaitHelper templates and fakes the drivers and elements they talk to.
module WaitHelperSpec
  TEMPLATES = File.expand_path('../../../lib/generators/templates/helpers', __dir__)

  # Answers the template's ERB conditionals the way the generator does.
  class Render
    def initialize(mobile)
      @mobile = mobile
    end

    def mobile?
      @mobile
    end

    def context
      binding
    end
  end

  # Renders both templates into one temp dir, so wait_helper.rb's require_relative finds raider_element.rb.
  # The web render loads at the top level, as in a generated project. A mobile render loads inside
  # `into` instead (load's wrap module), so both renders live in one process without clashing.
  def self.load_templates(mobile: false, into: nil)
    Dir.mktmpdir('raider_tt') do |dir|
      paths = %w[raider_element wait_helper].to_h do |name|
        source = File.read(File.join(TEMPLATES, "#{name}.tt"))
        path = File.join(dir, "#{name}.rb")
        File.write(path, ERB.new(source, trim_mode: '-').result(Render.new(mobile).context))
        [name, path]
      end
      next load(paths['wait_helper']) unless into

      # require_relative never wraps, so raider_element.rb is loaded into the namespace first
      # and marked as required, which makes wait_helper.rb's require_relative a no-op.
      load(paths['raider_element'], into)
      $LOADED_FEATURES << File.realpath(paths['raider_element'])
      load(paths['wait_helper'], into)
    end
  end

  # Scripted lookups shared by the fake driver and fake elements. Each locator answers from its
  # queue, one answer per call, repeating the last: nil is "no such element", an error class is raised.
  module Finder
    def script(locator, *answers)
      @fake[:one][locator] = answers
      self
    end

    def script_many(locator, *answers)
      @fake[:many][locator] = answers
      self
    end

    def finds = @fake[:finds]

    def find_element(**locator)
      finds << locator
      answer = next_answer(:one, locator, nil)
      raise answer if answer.is_a?(Class)
      raise Selenium::WebDriver::Error::NoSuchElementError, 'no such element' unless answer

      answer
    end

    def find_elements(**locator)
      finds << locator
      next_answer(:many, locator, [])
    end

    private

    def next_answer(kind, locator, default)
      queue = @fake[kind].fetch(locator) { [default] }
      queue.size > 1 ? queue.shift : queue.first
    end
  end

  # Records driver.action chains into the driver's log.
  class FakeActions
    def initialize(log)
      @log = log
    end

    %i[move_to scroll_to drag_and_drop perform].each do |step|
      define_method(step) do |*elements|
        @log << [step, *elements]
        self
      end
    end
  end

  # Selenium's driver, plus the Appium calls the mobile render makes.
  class FakeDriver
    include Finder

    WINDOW = Selenium::WebDriver::Rectangle.new(0, 20, 390, 800)

    def initialize(device: :ios)
      @fake = { one: {}, many: {}, finds: [], actions: [], scripts: [], device: }
    end

    def appium_device = @fake[:device]
    def actions = @fake[:actions]
    def action = FakeActions.new(actions)
    def scripts = @fake[:scripts]
    def window_rect = WINDOW

    def execute_script(command, *args)
      scripts << [command, *args]
      nil
    end
  end

  class FakeElement
    include Finder

    STALE = Selenium::WebDriver::Error::StaleElementReferenceError

    def initialize(**state)
      @fake = { one: {}, many: {}, finds: [] }
      @state = { displayed: true, enabled: true, selected: false, rects: [[0, 0, 10, 10]], text: 'hi',
                 attributes: {}, tag_name: 'div', errors: [], log: [], stale: false, id: "el-#{object_id}" }.merge(state)
    end

    def log = @state[:log]
    def go_stale = @state[:stale] = true
    def go_hidden = @state[:displayed] = false
    def id = @state[:id]
    def displayed? = live(@state[:displayed])
    def enabled? = live(@state[:enabled])
    def selected? = live(@state[:selected])
    def text = live(@state[:text])
    def tag_name = live(@state[:tag_name])
    def attribute(name) = live(@state[:attributes][name])
    def dom_attribute(name) = live(@state[:attributes][name.to_s])
    def property(name) = live(@state[name.to_sym])

    def rect
      rects = @state[:rects]
      live(rects.size > 1 ? rects.shift : rects.first)
    end

    %i[click clear submit send_keys].each do |action|
      define_method(action) do |*keys|
        live(nil)
        error = @state[:errors].shift
        raise error if error

        log << [action, *keys]
      end
    end

    private

    def live(value)
      raise STALE, 'stale element reference' if @state[:stale]

      value
    end
  end
end
