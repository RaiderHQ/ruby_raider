# frozen_string_literal: true

require_relative '../schedules/store'
require_relative 'schedule'

module RubyRaider
  module Flows
    # .raider/flows/schedules.yml: the project's scheduled flows (Schedules::Store with Flows::Schedule)
    class ScheduleStore < Schedules::Store
      DIR = Schedule::KIND.dir

      def initialize(project)
        super(project, Schedule)
      end
    end
  end
end
