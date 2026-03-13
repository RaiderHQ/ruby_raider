# frozen_string_literal: true

module NameNormalizer
  SUFFIXES = %w[_page _spec _steps _helper _test _feature].freeze

  module_function

  # Normalize raw user input to a clean base name
  # 'LoginPage' -> 'login', 'login_page' -> 'login', 'admin/users' -> 'admin/users'
  def normalize(input)
    name = input.to_s.strip
    name = camel_to_snake(name) if name.match?(/[A-Z]/)
    strip_suffixes(name)
  end

  # Convert to class name: 'login' -> 'LoginPage', 'admin/users' -> 'Admin::UsersPage'
  def to_class_name(input, suffix = '')
    normalized = normalize(input)
    parts = normalized.split('/')
    parts.map { |part| part.split('_').map(&:capitalize).join }.join('::') + suffix
  end

  # Convert to page class: 'login' -> 'LoginPage'
  def to_page_class(input)
    to_class_name(input, 'Page')
  end

  # Convert to file name: 'LoginPage' -> 'login', 'admin/users' -> 'admin/users'
  def to_file_name(input)
    normalize(input)
  end

  # Check if the input contains a nested path
  def nested?(input)
    normalize(input).include?('/')
  end

  # Get the module path for nested names: 'admin/users' -> ['Admin']
  def module_parts(input)
    parts = normalize(input).split('/')
    parts[0..-2].map { |p| p.split('_').map(&:capitalize).join }
  end

  # Get the leaf name: 'admin/users' -> 'users'
  def leaf_name(input)
    normalize(input).split('/').last
  end

  def camel_to_snake(str)
    str.gsub(/::/, '/')
       .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
       .gsub(/([a-z\d])([A-Z])/, '\1_\2')
       .downcase
  end

  def strip_suffixes(name)
    result = name.dup
    SUFFIXES.each do |suffix|
      result = result.delete_suffix(suffix) if result.end_with?(suffix)
    end
    result
  end
end
