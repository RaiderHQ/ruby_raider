require_relative 'generators/rs/generator'

class Scaffolding < Generator
  def generate_class
    template('automation/login_page.tt', "#{name}/page_objects/pages/login_page.rb")
  end
end
