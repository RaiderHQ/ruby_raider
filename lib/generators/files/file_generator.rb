# frozen_string_literal: true
require 'thor'

module RubyRaider
  class FileGenerator < Thor::Group
    include Thor::Actions

    argument :automation
    argument :framework
    argument :name

    def self.source_root
      File.dirname(__FILE__)
    end
  end
end
