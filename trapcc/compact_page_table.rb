require 'set'
#PhysicalPageManager provides a set of labelled physical addresses.

#
class PhysicalPageManager
  def initialize
    @page_offsets = {}
    @pages = {}
    @page_labels ={}
  end
  def <<(tag)  # Add a new tag
    @page_offsets[tag] ||= @page_offsets.size # unless @page_offsets.has_key?  tag
    @pages[@page_offsets[tag]]  ||= {}
    @page_labels[@page_offsets[tag]] = tag
  end
  def [](tag)
    self << tag
    @pages[@page_offsets[tag]]
  end
  def zero_memory_code()
    <<-eof
    void zero_memory()
    {
        int i;
        for(i=0;i<#{@page_labels.size};i++)
         memset((char *)(PFN2VIRT(base_pfn+i) ), 0,4096);
    }
    eof
  end
  def initial_value_code()
    src = ""
    @pages.sort.each do |page_number,page|
      page.sort.each do |addr,value|
        raise ArgumentError "Tried to map offset #{addr} > 4095 in page #{page_number}" if addr > 4096-4
        src << "*((u_int *)((char *)(PFN2VIRT(base_pfn+#{page_number}) + #{addr})))"
        src << "/* #{@page_labels[page_number]} + #{addr} */ = #{value.to_s} ;\n"
      end
    end
    src
  end
  def dump_mapping_info()
    src = "\n/* Pages\n"
    @page_labels.sort.each do |pfn,label|
      src << "#{(pfn << 12).to_s(16)} #{label}\n"
    end
    src << "*/"
    src
  end
  def pfn_number(tag)
    @page_offsets[tag] || 0 # RuntimeError.new ("Unknown page #{tag}")
  end
  def pfn_code(tag)
    "(base_pfn+#{pfn_number(tag)})"
  end
  def initialization_ptr(tag)
    "PFN2VIRT(#{pfn_code(tag)}) /* #{tag} */"
  end
end
#CompactPageTable allows the creation of an address space from physical page labels
class CompactPageTable
  class VirtualPage
    attr_accessor :phys_label, :pte
  end
  @@global_hugepages = {}
  @@global_prohibited = {}
  def initialize(physical_tag_manager,label_tag = nil)
    @address_space = {}
    @physical_tag_manager = physical_tag_manager
    @label_tag = label_tag || object_id
    physical_tag_manager << cr3_tag
  end
  PAGE_MASK =  0x3ff
  def self.globally_prohibit_mapping(virtual)
    hugepage , page =addr_to_index (virtual)
    @@global_prohibited[hugepage] ||= {}
    @@global_prohibited[hugepage][virtual] = true
  end
  def self.map_global(virtual,physical)      #TODO: RE-Add page frames here
    hugepage,virtual = addr_to_index(virtual)
    raise ArgumentError "Duplicate global mapping " if @@global_hugepages.has_key? hugepage
    @@global_hugepages[hugepage] = VirtualPage.new
    @@global_hugepages[hugepage].phys_label = physical
    @@global_hugepages[hugepage].pte = "PG_P | PG_PS | PG_U | PG_W | PG_A | PG_PS"
  end
  def unmap(virtual)
    hugepage,page = CompactPageTable.addr_to_index(virtual)
    if @address_space.include? hugepage
      @address_space[hugepage].delete page
    end
  end
  def map(virtual,physical,  write=1)
    hugepage,page = CompactPageTable.addr_to_index(virtual)
    @address_space[hugepage] ||= {}
    if @address_space[hugepage].has_key? page
      raise RuntimeError.new "Page #{hugepage } mapped twice"
    end
    @address_space[hugepage][page] = VirtualPage.new()
    @address_space[hugepage][page].pte = "PG_P"
    @address_space[hugepage][page].pte << "| PG_W" if write
    @address_space[hugepage][page].phys_label = physical
    @physical_tag_manager << physical
  end
  def remap(virtual,physical)
    unmap(virtual)
    map(virtual,physical)
  end


  # @param virtual [Integer] Virtual Address
  # @return (Integer, Integer) PDE and PTE index
  def CompactPageTable.addr_to_index(virtual)
    return (virtual >> 22) & PAGE_MASK , (virtual >> 12) & PAGE_MASK
  end

  def [](virtual)
    hugepage, page = CompactPageTable.addr_to_index(virtual)
    return @physical_tag_manager[@address_space[hugepage][page].phys_label]
  end
  def []=(virtual,val)
    hugepage, page = CompactPageTable.addr_to_index(virtual)
    offset = virtual & 0xFFF
    self[virtual][offset] = val
  end
  #Mapping source requires these macros:
  # ALLOC_PTEPTR_ARRAY()  -> Allocates an array of 1024 pointers
  # ALLOC_PAGE()) -> Allocates a single page locked to phys memory and returns its starting VA
  # VIRT2PFN(X)-> Returns the page frame number of the virtual page starting at X. X was returned from ALLOC_PAGE
  def cr3_tag()
    "pd #{@label_tag}"
  end
  def mapping_source_code      #TODO: Use physical page
    phys = @physical_tag_manager
    src = "{ \n "
    src << "u_int **pte_ptr = ALLOC_PTEPTR_ARRAY(); \n"
    src<< "u_int *pde_ptr = #{phys.initialization_ptr(cr3_tag)}; int i; \n"

    src << <<-eos
    for(i = 0; i< 1024; i++){
        pde_ptr[i] = PG_U | PG_A | PG_W;
    }
    eos
    @address_space.sort.each do |hugepage, pt|
      raise ArgumentError "Mapping tries to overwrite global mapping" if @@global_hugepages.has_key? hugepage
      pt_phys_label = "pt #{@label_tag} #{hugepage}"
      phys << pt_phys_label
      src << "pte_ptr[#{hugepage}] = #{phys.initialization_ptr(pt_phys_label)};\n"    #New page
      src << "pde_ptr[#{hugepage}] |= PG_P| (#{phys.pfn_code(pt_phys_label)} << 12);\n" #and enter it into the PDE
      src << <<-eos
      for(i=0; i<1024; i++){
        pte_ptr[#{hugepage}][i] = PG_A| PG_U;
      }
      eos
      pt.sort.each do |idx,pte|
        src << "pte_ptr[#{hugepage}][#{idx}] |= #{pte.pte} | (#{@physical_tag_manager.pfn_code(pte.phys_label)} << 12);"
        src << "/* #{ ((hugepage << 22) + (idx<< 12)).to_s(16)} -> '#{pte.phys_label}' */ \n"
      end
    end
    @@global_hugepages.each do |hugepage,pd|
      raise ArgumentError "Hugepage #{pd.phys_label }too large" unless pd.phys_label < 1024
      src << "pde_ptr[#{hugepage}] = #{pd.pte} | (#{pd.phys_label} << 22); \n"
    end
    src << "}\n"
    src
  end
  def cr3
    "#{@physical_tag_manager.pfn_code(cr3_tag)} << 12"
  end
end