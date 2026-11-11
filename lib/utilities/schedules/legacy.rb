# frozen_string_literal: true

require 'yaml'
require_relative 'adapter'
require_relative 'os_enumerator'
require_relative 'rule'

module RubyRaider
  module Schedules
    # Removes the schedules Ruby Raider 4.1 made in a project (Kind::FLOW_LEGACY): they can't run in 4.2.
    # Every `raider schedule` command runs it first, and so does the hidden stub an old OS entry reaches.
    # It only ever acts on this project's os_ids, each recomputed from the project's real path and a name
    # (from the old schedules.yml or the OS scheduler); an os_id stored in the yml is never used. It deletes
    # the old schedules.yml once every entry is gone, and nothing else, and only when the file is a 4.1
    # schedules file all of whose entries are this project's: a file it can't read, or one with an entry
    # of another path (a moved project), stays, since its os_ids are what the user needs to remove by hand.
    # An adapter's error text is passed through as is on purpose: it names the os_id the README says to look for.
    # Never raises.
    # :reek:TooManyConstants { max_constants: 6 } -- the kind, file, size cap, open flags and the old rule
    # :reek:TooManyInstanceVariables { max_instance_variables: 5 } -- the project, its root, adapter, stream and whether the yml may go
    class Legacy
      KIND = Kind::FLOW_LEGACY
      FILE = 'schedules.yml'
      MAX_BYTES = 1_000_000
      NOFOLLOW = defined?(File::NOFOLLOW) ? File::NOFOLLOW : 0
      NONBLOCK = defined?(File::NONBLOCK) ? File::NONBLOCK : 0

      # The 4.1 rule, for its os_ids only (os_id_for, os_id_prefix_for)
      class OldRule < Rule
        def self.kind = KIND
      end

      # project: a Project (its real root); adapter: nil picks this machine's OS scheduler when first needed
      def initialize(project, adapter: nil, err: $stderr)
        @project = project
        @root = project.root
        @adapter = adapter
        @err = err
        @yml_clean = false
      end

      # True when the project has a real .raider/flows folder (4.1 always made one; this never deletes it):
      # without one there is nothing to clean, so `raider schedule` skips the cleanup for one lstat
      def self.folder?(project)
        File.lstat(File.join(project.root, KIND.dir)).directory?
      rescue SystemCallError
        false
      end

      # Removes every 4.1 schedule of the project, then its schedules.yml. Prints and returns the notice, nil
      # when there was nothing to remove. last: the name of the entry running this (the stub's own), removed
      # after the notice is written and the yml deleted, since removing it may end this process.
      def cleanup(last: nil)
        current = adapter
        return nil unless current

        names = (yml_names | OsEnumerator.new(current, schedule_class: OldRule, root: @root).names).sort
        own = names.delete(last) if last
        removed, failed = remove_all(current, names)
        removed << own if own
        delete_yml if failed.empty?
        notice = notice(removed, failed)
        say(notice) if notice
        remove_own(current, own) if own
        notice
      rescue StandardError => e
        say("Could not remove the schedules made with Ruby Raider 4.1: #{e.message}")
      end

      private

      def adapter
        @adapter ||= Schedules.adapter(kind: KIND)
      rescue Error
        nil
      end

      # [removed names, [name, message] of each that failed]; one already gone is neither
      def remove_all(current, names)
        removed = []
        failed = []
        names.each do |name|
          removed << name if current.remove(OldRule.os_id_for(@root, name))
        rescue Error, SystemCallError => e
          failed << [name, e.message]
        end
        [removed, failed]
      end

      # Its own entry last: the notice is out (and flushed) and the yml gone before this may end the process
      def remove_own(current, name)
        current.remove(OldRule.os_id_for(@root, name))
      rescue Error, SystemCallError => e
        say("Could not remove #{name}: #{e.message}")
      end

      def notice(removed, failed)
        lines = []
        lines << removed_text(removed) unless removed.empty?
        lines << failed_text(failed) unless failed.empty?
        lines.empty? ? nil : Schedules.printable(lines.join(' '))
      end

      def removed_text(names)
        one = names.size == 1
        "Removed #{counted(names.size)} made with Ruby Raider 4.1 (#{names.join(', ')}); #{one ? 'it' : 'they'} can't run in 4.2. " \
          "Add #{one ? 'it' : 'them'} again with raider schedule add."
      end

      def failed_text(failed)
        reasons = failed.map { |name, message| "#{name}: #{message}" }.join(', ')
        "Could not remove #{counted(failed.size)} made with Ruby Raider 4.1 (#{reasons}); " \
          "#{failed.size == 1 ? 'it is' : 'they are'} tried again next time."
      end

      def counted(count) = count == 1 ? '1 schedule' : "#{count} schedules"

      # One printable line on err, flushed; returns it
      def say(text)
        line = Schedules.printable(text)
        err = @err
        err.puts(line)
        err.flush if err.respond_to?(:flush)
        line
      rescue StandardError
        line
      end

      def dir = File.join(@root, KIND.dir)

      def yml = File.join(dir, FILE)

      # .raider and .raider/flows are real folders, not links (a missing one is one failed lstat)
      def real_dirs? = [File.join(@root, '.raider'), dir].all? { |path| File.lstat(path).directory? }

      # The names of the yml's entries that 4.1 would read as this project's: valid, with the os_id it
      # computes for this project; anything else in the file, or a file that is not a schedules file, gives
      # none. The yml may go only when it was a schedules file and every entry was one of these.
      def yml_names
        entries = read_entries
        return [] unless entries

        names = entries.map { |entry| entry_name(entry) }
        @yml_clean = names.all?
        names.compact.uniq
      end

      def entry_name(entry)
        return nil unless entry.is_a?(Hash)

        name = entry['name']
        name if name.is_a?(String) && KIND.valid_name?(name) && entry['os_id'] == OldRule.os_id_for(@root, name)
      end

      # The entries of a schedules file ([] for an empty document); nil when there is none or it is not one
      def read_entries
        text = read_text
        return nil unless text

        data = YAML.safe_load(text)
        return [] unless data

        entries = data.is_a?(Hash) ? data['schedules'] : nil
        entries.is_a?(Array) ? entries : nil
      rescue Psych::Exception
        nil
      end

      # The yml through one handle that is not a link, a regular file up to MAX_BYTES; nil otherwise.
      # The folders are lstat'ed and then the file opened (and later unlinked) by path, so a folder swapped
      # for a link in between is followed: that takes write access to the project, and Ruby has no
      # openat/unlinkat to close the window.
      def read_text
        return nil unless real_dirs?

        File.open(yml, File::RDONLY | NONBLOCK | NOFOLLOW) do |file|
          next nil unless file.stat.file?

          text = file.read(MAX_BYTES + 1) || +'' # an empty file reads nil
          text.bytesize > MAX_BYTES ? nil : text.force_encoding(Encoding::UTF_8)
        end
      rescue SystemCallError
        nil
      end

      # The yml only, when it was read as a clean schedules file and the folders and it still are real
      # (a link or folder stays)
      def delete_yml
        path = yml
        File.unlink(path) if @yml_clean && real_dirs? && File.lstat(path).file?
      rescue SystemCallError
        nil
      end
    end
  end
end
