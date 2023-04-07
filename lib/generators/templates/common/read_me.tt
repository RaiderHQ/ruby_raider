# Ruby Raider

<!-- PROJECT LOGO -->
<br />
<div align="center">
   <a href="https://github.com/RubyRaider/ruby_raider">
   <img src="https://rubyraiderdotcom.files.wordpress.com/2022/05/logo_transparent_background-1.png" alt="Logo">
   </a>
   <h1 align="center">Ruby Raider</h1>
   <p align="center">
      This is a gem to make setup and start of UI automation projects easier.
      <br />
      <a href="https://github.com/RubyRaider/ruby_raider#getting-started"><strong>Explore the docs »</strong></a>
      <br />
      <br />
      <a href="https://rubygems.org/gems/ruby_raider">Rubygems</a>
      ·
      <a href="https://github.com/RubyRaider/ruby_raider/issues">Report Bug</a>
      ·
      <a href="https://github.com/RubyRaider/ruby_raider/issues">Request Feature</a>
   </p>
   <p align="center"> For more information and updates on releases, see <a href="https://ruby-raider.com">https://ruby-raider.com</a></p>
</div>

## What is ruby raider?

Ruby Raider is a generator and scaffolding gem to make UI test automation easier

### At the moment Ruby raider supports

* Generating a framework with Cucumber and Selenium

* Generating a framework with Rspec and Selenium

* Generating a framework with Cucumber and Watir

* Generating a framework with Rspec and Watir

* Generating a framework with Rspec and Appium for IOS

* Generating a framework with Cucumber and Appium for IOS

* Generating a framework with Rspec and Appium for Android

* Generating a framework with Cucumber and Appium for Android

* Generating a framework with Rspec and Appium cross platform

* Generating a framework with Cucumber and Appium cross platform

* Generating a visual testing framework with Rspec, Applitools and Selenium

* Generating a visual testing framework with Rspec, Applitools and Watir

***In order to run the Appium tests, download the example [app](https://github.com/saucelabs/my-demo-app-rn).***

***In order to run the visual tests with applitools, you need to create an account and get your api key, you can read
more [here](https://applitools.com/docs/topics/overview/obtain-api-key.html#:~:text=If%20you%20already%20have%20an,Your%20key%20will%20be%20displayed.)
.***

***To use the open ai integration you need to set up the OPENAI_ACCESS_TOKEN environment variable and
you can also set the optional OPENAI_ORGANIZATION_ID if you have an organization***

This works in all the platforms (Tested on Mac OS, Linux and Windows).

## Getting started

To get the project up and running.

**Just do:**

```ruby
gem install ruby_raider
```

**Then do:**

```ruby
raider new [name_of_project]
```

Then a TUI/CLI will appear where the configuration of which frameworks you want to be generated/scaffolded can be
selected.

Select the ones you will like to work with.

### Ruby raider provides the following list of basic commands

###### Anything between square brackets([...]) is where your imput goes

```ruby
Commands :
  raider generate # Provides access to all the generators commands
raider help [COMMAND] # Describe available commands or one specific command
raider new [PROJECT_NAME] # Creates a new framework based on settings picked
raider open # It opens the desktop runner
raider open_ai # Provides access to all the open ai commands
raider utility # Provides access to all the utility commands
raider version # It shows the version of Ruby Raider you are currently using
```

All the basic commands have their corresponding shortcut:

* g for generate
* n for new
* o for open_ai
* u for utility
* v for version

Ruby raider also supports scaffolding:

* To create a new page object you do: ```raider g page [PAGE_NAME]```
* To create a new spec you do: ```raider g spec [SPEC_NAME]```
* To create a new feature you do: ```raider g feature [FEATURE_NAME]```

It's possible to add the option --path or -p if you want to specify where to create your features, pages, helpers and
specs.

If you want to set the default path for the creation of your features, helpers and specs:

```ruby
raider u path [PATH_NAME] - -feature or -f
raider u path [PATH_NAME] - -spec or -s
raider u path [PATH_NAME] - -helper or -h
```

If you don't specify an option, path will assume you want to change the default path for pages.

### Open AI Commands

```ruby
# Will print the result of the request on the terminal
raider o make [REQUEST]
# Will create a file with the result of your request as content
raider o make [REQUEST] - -path or -p [PATH]
# Will input the content of the chosen file into open ai and will edit it based on the result
raider o make [PATH_NAME] - -edit or -e [FILE_PATH]
# Creates a cucumber file and uses it to input into open ai and create a steps file
# The prompt is required
raider o cucumber [NAME] - -prompt or -p [PROMPT]
# Creates a cucumber step definitions file based on an scenario file
raider open_ai steps [NAME]
Options :
  -p, [--path = PATH] # The path where your steps will be created
  -pr, [--prompt = PROMPT] # This will create the selected steps based on your prompt using open ai
  -i, [--input = INPUT] # It uses a file as input to create the steps

```
