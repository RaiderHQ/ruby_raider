module AppiumHelper
  def element(opts = {})
     return driver.find_element(strategy(opts) => selector(opts)) if opts[os]

     driver.find_element(opts)
  end

  def elements(opts = {})
     return driver.find_elements(strategy(opts) => selector(opts)) if opts[os]

     driver.find_elements(opts)
   end

 def os
   driver.appium_device
 end

 private

 def strategy(opts)
   opts[os].keys.first
 end

 def selector(opts)
   opts[os][strategy(opts)]
 end
end
