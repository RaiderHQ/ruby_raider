require_relative '../lib/generators/menu_generator'

describe 'A menu is generated' do
  it 'generates a menu' do
    menu = RubyRaider::MenuGenerator.new
    menu.generate_choice_menu
  end
end
