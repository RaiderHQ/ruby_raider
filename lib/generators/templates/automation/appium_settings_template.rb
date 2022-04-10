require_relative '../template'

class AppiumSettingsTemplate < Template
  def body
    <<~EOF
      [caps]
      platformName = "iOS"
      platformVersion = "15.4"
      deviceName = "iPhone SE (3rd generation)"
      app = "TheApp.app"

      [appium_lib]
      server_url = "http://127.0.0.1:4723/wd/hub"
    EOF
  end
end
