# Ruby Raider

This is a gem to make setup and start of UI automation projects easier
You can find more information and updates on releases in : https://ruby-raider.com/

Just do:

**gem install ruby_raider**

then do:

**raider new [name_of_project]**

and you will have a new project in the folder you are in

Currently we only support:

* Gerating a Selenium with both Cucumber and Rspec framework
* Gerating a Watir with both Cucumber and Rspec framework
* Generating an Appium project with Rspec and Cucumber on IOS

In order to run the appium tests, download the example [app](https://github.com/cloudgrey-io/the-app/releases/tag/v1.10.0)

This works in all the platforms (Tested on Mac OS, Linux and Windows)

**Ruby raider provides the following list of commands**
```
Commands:
  raider browser [BROWSER]         # Sets the default browser for a project
  
  raider feature [FEATURE_NAME]    # Creates a new feature
  
  raider help [COMMAND]            # Describe available commands or one specific command
  
  raider helper [HELPER_NAME]      # Creates a new helper
  
  raider new [PROJECT_NAME]        # Creates a new framework based on settings picked
  
  raider page [PAGE_NAME]          # Creates a new page object
  
  raider path [PATH]               # Sets the default path for scaffolding
  
  raider raid                      # It runs all the tests in a project
  
  raider scaffold [SCAFFOLD_NAME]  # It generates everything needed to start automating
  
  raider spec [SPEC_NAME]          # Creates a new spec
  
  raider url [URL]                 # Sets the default url for a project
```

It's possible to add the option --path or -p if you want to specify where to create your features, pages, helpers and
specs.

If you want to set the default path for the creation of your features, helpers and specs:

```
raider path [PATH_NAME] --feature or -f
raider path [PATH_NAME] --spec or -s
raider path [PATH_NAME] --helper or -h
```

If you don't specify an option path will assume you want to change the default path for pages
