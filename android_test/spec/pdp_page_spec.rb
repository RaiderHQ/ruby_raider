require_relative '../page_objects/pages/home_page'
require_relative '../page_objects/pages/pdp_page'
require_relative 'base_spec'

class PdpPageSpec < BaseSpec
  describe 'Pdp Page' do

    let(:home_page) { HomePage.new(@driver) }
    let(:pdp_page) { PdpPage.new(@driver) }

    it 'can see the title on the pdp page' do
      home_page.go_to_backpack_pdp
      expect(pdp_page.add_to_cart_text).to eq 'Add To Cart'
    end
  end
end
