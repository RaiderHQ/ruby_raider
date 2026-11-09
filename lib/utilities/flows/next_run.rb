# frozen_string_literal: true

require 'date'
require_relative 'schedule'

module RubyRaider
  module Flows
    # When a schedule next runs, in local time, as launchd, schtasks, systemd and cron count it.
    # A day, weekday or week rule whose time falls in a spring-forward gap runs at the first minute
    # after the gap; one that falls in a fall-back hour runs at its first occurrence only.
    # An hour rule runs at every real instant whose local minute matches, so twice in a fall-back hour.
    module NextRun
      WDAYS = %w[sun mon tue wed thu fri sat].freeze
      # The longest stretch to search: a week rule, plus a day of slack
      SEARCH_DAYS = 8
      # The minutes to search for an hour rule: an hour, plus an hour of offset change
      SEARCH_MINUTES = 120

      module_function

      def after(schedule, now)
        local_now = now.getlocal
        schedule.every == 'hour' ? next_minute(schedule.minute, local_now) : next_day(schedule, local_now)
      end

      def next_minute(minute, now)
        time = Time.at(now.to_i - now.sec + 60).localtime
        SEARCH_MINUTES.times do
          return time if time.min == minute

          time += 60
        end
        raise Error, "No local time with minute #{minute} after #{now}"
      end

      def next_day(schedule, now)
        today = Date.new(now.year, now.month, now.day)
        (0..SEARCH_DAYS).each do |offset|
          date = today + offset
          next unless schedule.days.include?(WDAYS[date.wday])

          time = local(date, schedule.hour, schedule.minute)
          return time if time > now
        end
        raise Error, "No run for #{schedule.rule_text} after #{now}"
      end

      # The first instant whose local wall clock reaches date hour:minute
      def local(date, hour, minute)
        wanted = [date.year, date.month, date.day, hour, minute]
        time = Time.local(*wanted)
        time += 60 while (wall(time) <=> wanted).negative?
        time -= 60 until (wall(time - 60) <=> wanted).negative?
        earlier = time - 3600
        wall(earlier) == wanted ? earlier : time
      end

      def wall(time) = [time.year, time.month, time.day, time.hour, time.min]
    end
  end
end
