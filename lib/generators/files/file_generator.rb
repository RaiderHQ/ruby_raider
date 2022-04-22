# frozen_string_literal: true
require 'thor'

module RubyRaider
  class FileGenerator < Thor::Group
    include Thor::Actions

    def self.source_root
      File.dirname(__FILE__) + '/../templates'
    end
  end
end
