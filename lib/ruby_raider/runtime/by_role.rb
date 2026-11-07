# frozen_string_literal: true

module Raider
  # The WAI-ARIA 1.2 concrete roles, plus generic.
  ROLES = %w[
    alert alertdialog application article banner blockquote button caption cell checkbox code columnheader
    combobox complementary contentinfo definition deletion dialog directory document emphasis feed figure form
    generic grid gridcell group heading img insertion link list listbox listitem log main marquee math menu
    menubar menuitem menuitemcheckbox menuitemradio meter navigation none note option paragraph presentation
    progressbar radio radiogroup region row rowgroup rowheader scrollbar search searchbox separator slider
    spinbutton status strong subscript superscript switch tab table tablist tabpanel term textbox time timer
    toolbar tooltip tree treegrid treeitem
  ].freeze

  # Builds the role locator: a Hash the finders turn into a raider role query.
  module RoleLocator
    module_function

    def build(role, name, exact, include_hidden, level = nil)
      token = validated_role(role)
      raise ArgumentError, "name must be a String, got #{name.class}" unless name.nil? || name.is_a?(String)

      validated_level(token, level)
      options = { name: name, exact: (true if exact), include_hidden: (true if include_hidden), level: level }.compact
      { role: options.empty? ? [token] : [token, options] }
    end

    # level: filters headings by h1-h6 or aria-level; nil means any level.
    def validated_level(token, level)
      return if level.nil?
      raise ArgumentError, "level: only applies to the heading role, not '#{token}'" unless token == 'heading'
      return if level.is_a?(Integer) && level.between?(1, 6)

      raise ArgumentError, "level: must be an Integer from 1 to 6, got #{level.inspect}"
    end

    def validated_role(role)
      token = role.to_s
      return token if ROLES.include?(token)

      raise ArgumentError, "unknown role '#{token}'; roles are the ARIA role names such as button, link, textbox"
    end
  end

  def self.by_role(role, name: nil, exact: false, include_hidden: false, level: nil)
    RoleLocator.build(role, name, exact, include_hidden, level)
  end

  # Locator helpers for page objects and wait helpers.
  module Helpers
    def by_role(role, **options)
      Raider.by_role(role, **options)
    end
  end
end
