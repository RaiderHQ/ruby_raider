# frozen_string_literal: true

module Raider
  # rspec-retry runs a retried example again in the same example group instance. The project's after
  # hook has quit the driver by then, and its driver_helper memoises it in @driver, so the retry would
  # reuse a dead session. Before each retry this clears @driver: the next `driver` call starts a fresh
  # one. Nothing is quit here.
  #
  # Installed from a before(:suite) hook, so it sees the final configuration whatever the require
  # order. Without rspec-retry it does nothing. A retry_callback the project set is kept as it is,
  # and then the project owns the reset.
  #
  # It relies on the after hook quitting the driver. A project whose after hook does not quit it leaves
  # one browser open per retry (the cleared @driver is never quit); such a project should set its own
  # retry_callback that quits and clears the driver.
  module RetryReset
    CALLBACK = proc { |_example| @driver = nil }

    module_function

    # True when the callback was set
    def install(config = ::RSpec.configuration)
      return false unless config.respond_to?(:retry_callback=)
      return false if config.retry_callback

      config.retry_callback = CALLBACK
      true
    end
  end
end

::RSpec.configure { |config| config.before(:suite) { Raider::RetryReset.install } } if defined?(::RSpec::Core)
