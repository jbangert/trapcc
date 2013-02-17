require_relative 'compact_page_table'
#Label: X,Y, A,B
#X and Y are at the same vaddr (Y in context before fault, X on saving )
#A and B are TSS addrs (!= X) which will be the X addr of the next fault. We map A.y and B.y here
class Fixnum
  def page
    self * 4096
  end
end
class Program
  GDT_ENTRY_STEP = 0x1000 #Every TSS is page aligned
  GDT_FIRST_ENTRY = 0x0FF8 # Needs to be page-16
  GDT_LAST_ENTRY = 0xFFF8# End of GDT

  class Instruction
    attr_accessor :program,:label, :x,:y,:a_label,:b_label
    attr_accessor :tss_slot, :pt # Only valid during encode
    def to_s
      "#{label} : #{x} <- #{y} , #{a_label} , #{b_label}"
    end
    def x_page
      "var #{x}"
    end
    def y_page
      "var #{y}"
    end
    def page
      "ins #{label}"
    end
    def gdt_desc_page
      "gdt #{tss_slot/GDT_ENTRY_STEP}"
    end
    def self.gdt_tss_addr(slot)
      raise ArgumentError "Only have 8192 slots" unless (GDT_FIRST_ENTRY..GDT_LAST_ENTRY).include?(slot)
      raise ArgumentError "TSS needs to be aligned" unless (slot % GDT_ENTRY_STEP) == (GDT_FIRST_ENTRY % GDT_ENTRY_STEP)
      tss_idx = (slot - GDT_FIRST_ENTRY) / GDT_ENTRY_STEP
      1024 * 4096  + tss_idx *65536 + TSS_ALIGN     # See L200 in  init_gdt in the c file
            # we want all TSS addresses to be aligned -32 to  a page (so  that EIP/CR3 and ESP are on different pages)
            # Furthermore, the
    end
    def addr
      Instruction.gdt_tss_addr(tss_slot)
    end
  end
  def initialize
    @instructions  = {}
    @variables = {}
    @first_instruction = nil
    @outputs  = {}
  end
  DEFAULT_VARIABLE_VALUE = 4
  def instruction(label,x,y,a,b,tss_slot)
    i = Instruction.new
    i.program ,i.label, i.x , i.y, i.a_label ,i.b_label = self,label,x,y,a,b
    raise RuntimeError.new "Duplicate instruction #{label}" if @instructions.include? label
    @instructions[label] = i
    i.tss_slot = tss_slot  * GDT_ENTRY_STEP + GDT_FIRST_ENTRY
    @variables[i.x] ||= DEFAULT_VARIABLE_VALUE
    @variables[i.y] ||= DEFAULT_VARIABLE_VALUE
    @first_instruction ||= i
  end
  def variable(label, initial_value)
    @variables[label] = initial_value
  end
  def start(label)
    @first_instruction= @instructions[label]
  end
  IDT_DOUBLEFAULT = 8 * 8
  IDT_PAGEFAULT   = 14 * 8
  IDT_TASK_GATE_TYPE = 0b1110_0101 << 8
  TSS_ALIGN = -48
  IDT_ADDRESS = 0x0100_0000
  GDT_ADDRESS = 0x0180_0000
  GDT_CODE = 0x9A
  GDT_DATA = 0x92
  GDT_TSS = 0x89
  def map_gdt(pt,addr)
    (0..15).each do |idx|
      pt.map addr + (idx<<12), "gdt #{idx}"
    end
  end
  def gdt_entry(type,base,limit)
    return "#{(limit & 0xFFFF)} | ((#{base} & 0xFFFF) << 16) /* Base: #{base} */",
        "((#{base} &0x00FF0000) >> 16) | (#{type} << 8)" +
        "|(#{ (0xC0 | limit >> 16) & 0xFF}) << 16 |( #{base} & 0xFF000000) /* Type #{type} */"
  end
  def init_gdt(phys)
    def encode_gdt(phys, idx, type ,base, limit )
      raise ArgumentError "IDX not aligned" unless idx & 7 == 0
      label = "gdt #{(idx & 0xF000)>>12}"
      page_offset = idx & 0xFF8
      phys[label][page_offset] , phys[label][page_offset+4] = gdt_entry(type,base,limit)
    end
    encode_gdt(phys,0x8, GDT_CODE, 0,0xFFFF_FFFF)
    encode_gdt(phys,0x10, GDT_DATA,0, 0xFFFF_FFFF)
    encode_gdt(phys,0x18, GDT_TSS,"g_tss_ptr", 0xFF)
    (GDT_FIRST_ENTRY..GDT_LAST_ENTRY).step(GDT_ENTRY_STEP) do |idx|
      encode_gdt(phys,idx,GDT_TSS,Instruction.gdt_tss_addr(idx), 0xFF)
    end
  end
  def encode_idt(pt, idt_addr, df_tss, pf_tss)
    def task_gate(addr, tss, pt)
      pt[addr] = (tss << 16).to_s + "/* TSS 0x#{tss.to_s(16)} */"
      pt[addr + 4] = IDT_TASK_GATE_TYPE.to_s + "/* Task gate */"
    end
    task_gate(idt_addr + IDT_DOUBLEFAULT,df_tss, pt)
    #task_gate(idt_addr+ IDT_DOUBLEFAULT, 0x18,pt)
    task_gate(idt_addr + IDT_PAGEFAULT,pf_tss, pt)
  end
  def encode_tss(pt,  addr, eip,cs,eflags)
    pt[addr + 28] = "#{pt.cr3()} /*CR3: #{pt.cr3_tag} */"
    pt[addr + 32] = "0x#{eip.to_s(16)} /*EIP */"
    pt[addr + 36] = "reflags()"
    # pt[addr + 36] = "0x#{eflags.to_s(16)} /*EFLAGS*/"
    pt[addr + 40] , pt[addr +44] = gdt_entry(GDT_TSS, addr, 0xFFFFFFFF)
    encode_tss_high(pt,addr)
  end
  def output_binary(y,x, variable)
    @outputs[[x,y]] = [:variable, variable]
  end
  def output_fixed(y,x, character)
    @outputs[[x,y]] = [:character, character]
  end
  def encode_tss_high(pt,addr)
    pt[addr + 72] = "0x10"
    pt[addr + 76] = "0x8 /*CS*/"         #TODO: Check that we don't overwrite
    pt[addr + 80] = "0x10"
    pt[addr + 84] = "0x10"
    pt[addr + 88] = "0x10"
    pt[addr + 92] = "0x10"
    pt[addr + 96] = "0x0"
  end

  EIP_INVALID = 0xfffefff
  GLOBAL_CS = 0x8
  GLOBAL_DS = 0x10
  GLOBAL_EFLAGS = 0
  def encode(debug_nop = false)
    phys = PhysicalPageManager.new()
    #CompactPageTable.map_global(0xC00_000,3) #TODO: Get rid of global mapping
    CompactPageTable.globally_prohibit_mapping(EIP_INVALID)
    src = <<-eof
    void zero_memory();
    void interrupt_program(){
      zero_memory();
    eof
    @variables.each do |label,i|
      phys["var #{label}"][56 + TSS_ALIGN] = i
    end
    #init_gdt(phys,GDT_ADDRESS)
    init_gdt(phys)
    #CompactPageTable.map_global(GDT_ADDRESS, (GDT_ADDRESS >> 22) )
    #Map kernel code
    CompactPageTable.map_global(0x000C00000,   (0x000C00000>> 22))

    @instructions.each do |label, i|
      src <<" /* #{i} */ \n \n"

      pt = CompactPageTable.new(phys, label)
      pt.map(0,'stack_page')
      pt.map(i.addr,  i.page)
      pt.map(i.addr + 1.page, i.x_page)
      b_tss_slot = 0
      a_tss_slot = 0
      if(i.a_label != :exit)
        a = @instructions[i.a_label]
        raise RuntimeError.new "#{i.label} : #{i.a_label} not found" unless @instructions.has_key? i.a_label
        raise RuntimeError.new "#{label}: A and this need different slots" unless a.tss_slot != i.tss_slot
        pt.map(a.addr + 1.page, a.y_page)      # TODO: Only map B if A!=B
        pt.map(a.addr, a.page)
        encode_tss_high(pt,a.addr)
        a_tss_slot = a.tss_slot
      else
        a_tss_slot = 0x18
      end
      if(i.b_label != :exit)
        raise RuntimeError.new "#{i.b_label} not found" unless @instructions.has_key? i.b_label
        b = @instructions[i.b_label]
        raise RuntimeError.new "#{label}: B and this need different slots" unless b.tss_slot != i.tss_slot
        if(i.a_label != i.b_label)
          pt.map(b.addr, b.page)
          pt.map(b.addr + 1.page, b.y_page)       # We need to insure this is a valid page. X page is ok, but Y page not necessarily.
                                                  # Therefore, just encode them both again
          encode_tss_high(pt,b.addr)
        end
        b_tss_slot = b.tss_slot
      else
        b_tss_slot = 0x18
      end
      raise RuntimeError.new "A and B need different slots" if a_tss_slot == b_tss_slot && i.a_label !=i.b_label

      pt.map(IDT_ADDRESS, "IDT #{i.label}")
      if debug_nop
        pt.map(EIP_INVALID, "NOP page")
        pt[EIP_INVALID & ~3] = 0x90909090 # NOP
      end
      map_gdt(pt,GDT_ADDRESS)
      encode_tss(pt,i.addr, EIP_INVALID, GLOBAL_CS, GLOBAL_EFLAGS)
      pt.remap(i.addr, i.gdt_desc_page) # EAX:ECX will overwrite the GDT descriptor
      encode_idt(pt,IDT_ADDRESS,b_tss_slot,a_tss_slot)
      src << pt.mapping_source_code()
      i.pt = pt
    end

    @initial_pt = CompactPageTable.new(phys,'initial_pd')  #
    @initial_pt.map(0,'stack_page')
    @initial_pt.map(@first_instruction.addr, @first_instruction.page)      #Map CR3 correctly
    map_gdt(@initial_pt,GDT_ADDRESS)
    @initial_pt.map(@first_instruction.addr + 1.page,@first_instruction.y_page) # Load Y
    #@initial_pt.map(IDT_ADDRESS, "IDT #{@first_instruction.label}")
    src << @initial_pt.mapping_source_code()
    src << phys.initial_value_code()

    src <<  <<eof
    }
eof
    src << phys.zero_memory_code()
    src << <<-eof
    void begin_computation(){
      load_cr3(#{@initial_pt.cr3()}); /* Begin the fun */
      __asm __volatile ("ljmp  $0x#{@first_instruction.tss_slot.to_s(16)}, $0x0");
eof
    @outputs.each do |coords, value|
      type, var = value
      outp_code = case type
                    when :variable
                      " *((unsigned int *)(#{phys.initialization_ptr("var #{var}")} + #{56+TSS_ALIGN})) < 4 ? ' ' : 'X'"
                    when :character
                      "'#{var}'"
                    else
                      raise RuntimeError.new
                  end
      src << "OUTPUT(#{coords[0]},#{coords[1]},#{outp_code});\n"
    end
    src << "}\n"

    src << "/* Instructions \n"
    @instructions.each do |label,i|
      src << "#{i.tss_slot.to_s(16)} #{label} #{phys.pfn_number(i.pt.cr3_tag).to_s(16)}\n"
    end
    src << "*/"
    src << phys.dump_mapping_info()
  end

  def sim_step
    inst = @first_instruction
    raise "Undefined references" unless @variables.include?(@first_instruction.x) and @variables.include?(@first_instruction.y)
    y=@variables[@first_instruction.y]
    if y<4
      @first_instruction = @instructions[@first_instruction.b_label]
    else
      @variables[@first_instruction.x] = y-4
      @first_instruction = @instructions[@first_instruction.a_label]
    end
  end
  def pretty_state
    @first_instruction.to_s + "\n" + pretty_print(@variables)
  end
end