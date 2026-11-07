# frozen_string_literal: true

require 'rspec'
require_relative '../../../lib/ruby_raider/runtime'
require_relative '../support/browser'

RSpec.describe 'The in-page role engine', :browser do
  let(:driver) { Raider::Spec::Browser.driver }

  before(:all) { Raider::Spec::Browser.open('roles.html') } # rubocop:disable RSpec/BeforeAfterAll

  after(:all) { Raider::Spec::Browser.quit } # rubocop:disable RSpec/BeforeAfterAll

  def engine(body, *args)
    driver.execute_script("#{Raider::RoleFinder::ENGINE}\n#{body}", *args)
  end

  def element(id)
    driver.find_element(id: id)
  end

  def ids(elements)
    elements.map { |e| e.attribute('id') }
  end

  def query(scope, role, options = {})
    engine('return window.__raider.role(arguments[0] || document, arguments[1], arguments[2])',
           scope, role, { 'name' => nil, 'exact' => false, 'includeHidden' => false }.merge(options))
  end

  role_cases = {
    'r-h1' => 'heading', 'r-h2' => 'heading', 'r-h3' => 'heading', 'r-h4' => 'heading', 'r-h5' => 'heading',
    'r-h6' => 'heading', 'r-link' => 'link', 'r-anchor' => 'generic', 'r-area' => 'link',
    'r-article' => 'article', 'r-header-in-article' => 'generic', 'r-footer-in-article' => 'generic',
    'r-aside' => 'complementary', 'r-button' => 'button', 'r-datalist' => 'listbox', 'r-details' => 'group',
    'r-summary' => nil, 'r-dialog' => 'dialog', 'r-fieldset' => 'group', 'r-figure' => 'figure',
    'r-header' => 'banner', 'r-footer' => 'contentinfo', 'r-form' => 'form', 'r-hr' => 'separator',
    'r-img' => 'img', 'r-img-empty-alt' => 'presentation', 'r-img-presentation' => 'presentation',
    'r-in-button' => 'button', 'r-in-image' => 'button', 'r-in-reset' => 'button', 'r-in-submit' => 'button',
    'r-in-checkbox' => 'checkbox', 'r-in-radio' => 'radio', 'r-in-range' => 'slider',
    'r-in-number' => 'spinbutton', 'r-in-search' => 'searchbox', 'r-in-search-list' => 'combobox',
    'r-in-email' => 'textbox', 'r-in-tel' => 'textbox', 'r-in-text' => 'textbox', 'r-in-url' => 'textbox',
    'r-in-password' => 'textbox', 'r-in-default' => 'textbox', 'r-in-text-list' => 'combobox',
    'r-in-hidden' => nil, 'r-ul' => 'list', 'r-ol' => 'list', 'r-menu' => 'list', 'r-li' => 'listitem',
    'r-li-orphan' => 'generic', 'r-main' => 'main', 'r-math' => 'math', 'r-meter' => 'meter',
    'r-nav' => 'navigation', 'r-select' => 'combobox', 'r-option' => 'option', 'r-select-multiple' => 'listbox',
    'r-select-size' => 'listbox', 'r-output' => 'status', 'r-progress' => 'progressbar',
    'r-section' => 'generic', 'r-section-label' => 'region', 'r-section-labelledby' => 'region',
    'r-table' => 'table', 'r-thead' => 'rowgroup', 'r-tbody' => 'rowgroup', 'r-tfoot' => 'rowgroup',
    'r-tr' => 'row', 'r-th-col' => 'columnheader', 'r-th-colscope' => 'columnheader',
    'r-th-first' => 'rowheader', 'r-th-second' => 'columnheader', 'r-th-scoperow' => 'rowheader',
    'r-td' => 'cell', 'r-td-grid' => 'gridcell', 'r-td-grid-ancestor' => 'gridcell', 'r-textarea' => 'textbox',
    'r-div' => 'generic', 'r-span' => 'generic', 'r-div-button' => 'button', 'r-role-tokens' => 'button',
    'r-bad-role' => 'button', 'r-explicit-over-implicit' => 'button'
  }.freeze

  name_cases = {
    'n-labelledby' => 'First Second label', 'n-lb-hidden' => 'Hidden label', 'n-lb-nested' => 'Nest text',
    'n-lb-missing' => 'Falls back', 'n-arialabel' => 'Close dialog', 'n-labelfor' => 'Email address',
    'n-wrapped' => 'Wrapped label', 'n-img' => 'Company logo', 'n-input-image' => 'Go', 'n-area' => 'Area name',
    'n-submit' => 'Send', 'n-input-button' => 'Plain value', 'n-reset' => 'Clear',
    # Known gap: a valueless submit has a browser-supplied default label ("Submit") the engine does not know.
    'n-submit-empty' => '',
    'n-table' => 'Sales', 'n-fieldset' => 'Contact', 'n-figure' => 'Chart caption', 'n-title' => 'Tooltip only',
    'n-title-fallback' => 'Text wins', 'n-embedded' => 'Search for cats', 'n-slider' => 'Rate 7 stars',
    'n-select' => 'Pick Two', 'n-content' => 'Go icon now', 'n-blocks' => 'One Two', 'n-inline' => 'Abcd',
    'n-heading' => 'Spaced title', 'n-hidden-child' => 'Visible', 'n-div-button' => 'Div button',
    'n-generic' => '', 'n-li' => '', 'n-unreferenced-hidden' => '', 'n-unlabelled' => ''
  }.freeze

  hidden_cases = {
    'h-visible' => false, 'h-aria-hidden' => true, 'h-anc-aria' => true, 'h-anc-none' => true,
    'h-display-none' => true, 'h-attr' => true, 'h-visibility' => true, 'h-vis-parent-child' => false,
    'h-vis-inherit' => true, 'r-in-hidden' => true
  }.freeze

  describe 'getRole' do
    role_cases.each do |id, role|
      it "maps ##{id} to #{role.inspect}" do
        expect(engine('return window.__raider.getRole(arguments[0])', element(id))).to eq(role)
      end
    end
  end

  describe 'accessibleName' do
    name_cases.each do |id, name|
      it "names ##{id} #{name.inspect}" do
        expect(engine('return window.__raider.accessibleName(arguments[0])', element(id))).to eq(name)
      end
    end
  end

  describe 'isHidden' do
    hidden_cases.each do |id, hidden|
      it "reports ##{id} hidden=#{hidden}" do
        expect(engine('return window.__raider.isHidden(arguments[0])', element(id))).to eq(hidden)
      end
    end
  end

  describe 'role' do
    it 'matches the name case-insensitively as a substring' do
      expect(ids(query(element('saves'), 'button', 'name' => 'save'))).to eq(%w[save-1 save-2 save-3])
    end

    it 'matches a name exactly and case-sensitively' do
      expect(ids(query(element('saves'), 'button', 'name' => 'Save', 'exact' => true))).to eq(['save-1'])
    end

    it 'adds hidden elements under includeHidden' do
      found = ids(query(element('saves'), 'button', 'name' => 'save', 'includeHidden' => true))
      expect(found).to eq(%w[save-1 save-2 save-3 save-hidden])
    end

    it 'searches the whole document in document order' do
      expect(ids(query(nil, 'button', 'name' => 'Save', 'exact' => true))).to eq(%w[save-1 scope-save])
    end

    it 'limits the search to the scope and leaves the outside button out' do
      expect(ids(query(element('scope'), 'button'))).to eq(['scope-save'])
    end

    it 'never returns the scope element itself' do
      expect(ids(query(element('scope-button'), 'button'))).to eq(['scope-inner'])
    end

    it 'finds by an explicit role on a div' do
      expect(ids(query(element('scope-button'), 'button', 'name' => 'inner'))).to eq(['scope-inner'])
    end

    it 'writes nothing to the page but window.__raider' do
      added = driver.execute_script(
        "delete window.__raider; var before = Object.keys(window);\n#{Raider::RoleFinder::ENGINE}\n" \
        'return Object.keys(window).filter(function (k) { return before.indexOf(k) < 0 })'
      )
      expect(added).to eq(['__raider'])
      expect(engine('return Object.keys(window.__raider).sort()')).to eq(%w[accessibleName getRole isHidden role])
    end

    it 'merges into an existing window.__raider instead of replacing it' do
      result = driver.execute_script(
        "window.__raider = { keep: 1 }; #{Raider::RoleFinder::ENGINE}\nreturn [window.__raider.keep, typeof window.__raider.role]"
      )
      expect(result).to eq([1, 'function'])
    end
  end
end
