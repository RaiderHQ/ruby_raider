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

    def build(role, name, exact, include_hidden)
      token = validated_role(role)
      raise ArgumentError, "name must be a String, got #{name.class}" unless name.nil? || name.is_a?(String)

      options = { name: name, exact: (true if exact), include_hidden: (true if include_hidden) }.compact
      { role: options.empty? ? [token] : [token, options] }
    end

    def validated_role(role)
      token = role.to_s
      return token if ROLES.include?(token)

      raise ArgumentError, "unknown role '#{token}'; roles are the ARIA role names such as button, link, textbox"
    end
  end

  def self.by_role(role, name: nil, exact: false, include_hidden: false)
    RoleLocator.build(role, name, exact, include_hidden)
  end

  # Locator helpers for page objects and wait helpers.
  module Helpers
    def by_role(role, **options)
      Raider.by_role(role, **options)
    end
  end
end
