require "test/unit"
require_relative "../compact_page_table"
class MyTest < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    @pt = CompactPageTable.new(PhysicalPageManager.new())

  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  # Fake test
  def test_pt1
    @pt.map(0,:test1,1)
    @pt.map(0xA000,:test2,2)
    source   = @pt.mapping_source_code
    #print source

    #Manually formatted, beware
    assert_equal(<<-eos.gsub(/ /,'') , source.gsub(/ /,''))
u_32 **pte_ptr = ALLOC_PTEPTR_ARRAY();
u_32 *pde_ptr = ALLOC_PAGE(); int i;
    for(i = 0; i< 1024; i++){
        pde_ptr[i] = PD_U | PD_A | PD_W;
    }
pte_ptr[0] = ALLOC_PAGE();
pde_ptr[0] |= PG_P| VIRT2PFN(pte_ptr[0]);
      for(i=0; i<1024; i++){
        pte_ptr[0][i] = PT_A| PT_U;
      }
pte_ptr[0][0] |= PT_P| PT_W | (base_pfn+0);
pte_ptr[0][10] |= PT_P| PT_W | (base_pfn+1);
    eos
  end
end