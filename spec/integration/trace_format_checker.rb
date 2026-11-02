# frozen_string_literal: true

require 'json'
require 'zip'

# Checks a trace.zip against the raider-trace v1 format (trace viewer spec §1) and
# returns the problems it finds, so a spec can `expect(problems).to be_empty`.
# Stricter than readers need to be: an unknown locator strategy is a problem here.
module TraceFormatChecker
  ENTRY_NAME = %r{\Atrace\.json\z|\Asteps/\d{4}\.(jpg|png|html|xml)\z}
  TIMESTAMP = /\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z\z/
  KINDS = %w[navigate action group failure].freeze
  STRATEGIES = %w[id css xpath name link_text partial_link_text class_name tag_name].freeze
  # The required keys and the types each may have: the top level, then every step.
  FIELDS = {
    top: {
      'format' => [String], 'version' => [Integer], 'producer' => [Hash], 'test' => [Hash],
      'browser' => [Hash], 'viewport' => [Hash], 'device_pixel_ratio' => [Integer, Float],
      'started_at' => [String], 'finished_at' => [String], 'capabilities' => [Hash],
      'truncated' => [Hash], 'steps' => [Array], 'network' => [Array], 'console' => [Array]
    }.freeze,
    step: {
      'index' => [Integer], 'parent_index' => [Integer, NilClass], 'kind' => [String], 'action' => [String],
      'locator' => [Hash, NilClass], 'url' => [String, NilClass], 'page_title' => [String, NilClass],
      'started_at' => [String], 'duration_ms' => [Integer], 'waited_ms' => [Integer], 'retries' => [Integer],
      'status' => [String], 'error' => [Hash, NilClass], 'source' => [Hash, NilClass], 'rect' => [Hash, NilClass],
      'screenshot' => [String, NilClass], 'snapshot' => [String, NilClass]
    }.freeze
  }.freeze

  # The parsed trace.json and the zip's entry names.
  def self.read(path)
    Zip::File.open(path) do |zip|
      [JSON.parse(zip.read('trace.json')), zip.entries.map(&:name)]
    end
  end

  def self.problems(path)
    trace, names = read(path)
    problems = names.grep_v(ENTRY_NAME).map { |name| "entry #{name.inspect} is not an allowed name" }
    problems.concat(identity(trace)).concat(typed('trace', trace, FIELDS[:top]))
    problems.concat(error_rules('test', trace['test'])) if trace['test'].is_a?(Hash)
    return problems unless trace['steps'].is_a?(Array)

    problems.concat(steps(trace['steps'], names)).concat(events(trace)).concat(mocked_rules(trace['network']))
  rescue Zip::Error, JSON::ParserError, Errno::ENOENT => e
    ["not a readable trace.zip: #{e.class}: #{e.message}"]
  end

  def self.identity(trace)
    problems = []
    problems << "format is #{trace['format'].inspect}, not \"raider-trace\"" unless trace['format'] == 'raider-trace'
    problems << "version is #{trace['version'].inspect}, not 1" unless trace['version'] == 1
    problems
  end

  def self.typed(where, hash, fields)
    fields.flat_map do |key, types|
      next ["#{where} has no #{key.inspect}"] unless hash.key?(key)

      value = hash[key]
      next [] if types.any? { |type| value.is_a?(type) }

      ["#{where}.#{key} is #{value.inspect}, not #{types.join(' or ')}"]
    end
  end

  def self.steps(steps, names)
    steps.each_with_index.flat_map do |step, position|
      where = "steps[#{position}]"
      next ["#{where} is not an object"] unless step.is_a?(Hash)

      typed(where, step, FIELDS[:step]) + step_rules(where, step, position, names)
    end
  end

  def self.step_rules(where, step, position, names)
    problems = []
    problems << "#{where}.index is #{step['index'].inspect}, not #{position + 1}" unless step['index'] == position + 1
    problems << "#{where}.kind #{step['kind'].inspect} is not one of #{KINDS.join(', ')}" unless KINDS.include?(step['kind'])
    problems << "#{where}.started_at #{step['started_at'].inspect} is not UTC ISO-8601 with ms" unless TIMESTAMP.match?(step['started_at'].to_s)
    parent = step['parent_index']
    problems << "#{where}.parent_index #{parent} is not an earlier step" if parent && !parent.between?(1, position)
    problems.concat(error_rules(where, step))
    problems.concat(locator_rules(where, step['locator']))
    problems.concat(typed_rules(where, step))
    problems.concat(media_rules(where, step, names))
  end

  # error is null or { "class": String, "message": String }, on steps and on test.
  def self.error_rules(where, holder)
    return ["#{where} has no \"error\""] unless holder.key?('error')

    error = holder['error']
    return [] if error.nil?
    return ["#{where}.error is #{error.inspect}, not null or an object"] unless error.is_a?(Hash)

    %w[class message].filter_map { |key| "#{where}.error.#{key} is not a string" unless error[key].is_a?(String) }
  end

  # label is optional: ruby_raider never writes it, but another producer may.
  def self.locator_rules(where, locator)
    return [] unless locator.is_a?(Hash)

    label = locator.key?('label') && !locator['label'].is_a?(String) ? ["#{where}.locator.label is not a string"] : []
    label + [locator, *Array(locator['within'])].filter_map do |one|
      strategy = one['strategy']
      "#{where}.locator strategy #{strategy.inspect} is not canonical" unless STRATEGIES.include?(strategy)
    end
  end

  # value and secret exist only on send_keys and select_by; a secret value is null.
  # element, when present, is { tag, label?, role? } on an action step.
  def self.typed_rules(where, step)
    problems = []
    typed = %w[send_keys select_by].include?(step['action'])
    problems << "#{where} has value/secret but is not send_keys or select_by" if !typed && (step.key?('value') || step.key?('secret'))
    problems << "#{where} is #{step['action']} without value and secret" if typed && !(step.key?('value') && step.key?('secret'))
    problems << "#{where}.secret is true but value is not null" if step['secret'] == true && !step['value'].nil?
    element = step['element']
    problems << "#{where}.element is not an action step's { tag, label?, role? }" if step.key?('element') && !(element.is_a?(Hash) && element['tag'].is_a?(String) && step['kind'] == 'action')
    problems
  end

  def self.media_rules(where, step, names)
    %w[screenshot snapshot].filter_map do |key|
      entry = step[key]
      "#{where}.#{key} #{entry.inspect} is not an entry in the zip" if entry && !names.include?(entry)
    end
  end

  # mocked is optional on a network entry: "fulfilled" or "failed".
  def self.mocked_rules(network)
    Array(network).each_with_index.filter_map do |entry, position|
      next unless entry.is_a?(Hash) && entry.key?('mocked') && !%w[fulfilled failed].include?(entry['mocked'])

      "network[#{position}].mocked #{entry['mocked'].inspect} is not fulfilled or failed"
    end
  end

  def self.events(trace)
    count = [trace['steps'].size, 1].max
    %w[network console].flat_map do |list|
      Array(trace[list]).each_with_index.filter_map do |event, position|
        index = event.is_a?(Hash) ? event['step_index'] : nil
        "#{list}[#{position}].step_index #{index.inspect} is not between 1 and #{count}" unless index.is_a?(Integer) && index.between?(1, count)
      end
    end
  end
end
