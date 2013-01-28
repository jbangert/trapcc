require_relative 'interrupt_program'
require_relative 'debug_program'
class GameOfLifeProgram
  attr_accessor :size
  def initialize(programClass,size,init)
    @size = size
    @p = programClass.new()
    @p.variable :const_9, 9*4
    @p.variable :const_1, 4
    @p.variable :const_2, 2*4
    @p.variable :const_3, 3*4

    @p.variable :counter, 1000 * 4
    @p.instruction :exit, :tmp_var,:const_9 , :exit, :exit, 15
    next_inst = :exit
    cells = []
    (0..size-1).each do |x |
      (0..size-1).each do |y |
        val = init[y][x] > 0 ? 4 : 0
        @p.variable "X#{x}Y#{y}NewCell",val # 4096
        @p.variable "X#{x}Y#{y}Cell",      val
        @p.output_binary 10+y, x, "X#{x}Y#{y}Cell"
        c = Cell.new(x,y,size)
        cells << c
        next_inst = c.copy_instructions(@p,next_inst)
      end
    end
    cells.each do |c|
      next_inst = c.step_instructions(@p,next_inst)
    end
    @p.start next_inst
  end

  def program
    @p
  end
  def source
    @p.encode
  end
  class Cell
    def name
      "X#{@x}Y#{@y}"
    end
    def initialize(x,y,size)
      @x,@y,@size = x,y,size
    end
    def dec_x_ifnot_y(label,p, x,y,nxt)  # 1 2
      s1 = "#{label}-test"
      s2 = "#{label}-dec"
      s3 = "#{label}-nop"
      p.instruction s1, :tmp_var, y, s3, s2 , 1  # Decrement if this was an underflow
      p.instruction s2, x, x, s3 , s3, 2
      p.instruction s3, :tmp_var, :const_9 , nxt,nxt , 3
      s1
    end
    def n(dx,dy)
      return "X#{(@x+dx)%@size}Y#{(@y+dy)%@size}Cell"
    end
    def cellvar
      "#{name}Cell"
    end
    def cellnewvar
      "#{name}NewCell"
    end
    def copy_instructions(p,next_inst)
      p.instruction "#{name}-copynop", :tmp_var, :const_9, next_inst, next_inst, 12
      p.instruction "#{name}-copy", cellvar, cellnewvar, "#{name}-copynop", "#{name}-copynop", 11
      "#{name}-copy"
    end
    def step_instructions(p, next_inst)
      if(@neighbour_count_only)             #Debugging
           p.instruction "#{name}-0", cellnewvar, :counter, next_inst, next_inst, 4
      else
        p.instruction "#{name}-die", cellnewvar, :const_2 , next_inst , next_inst, 4
        p.instruction "#{name}-live", cellnewvar, :const_3, next_inst,next_inst, 5
        p.instruction "#{name}-maint", :tmp_var, cellvar, "#{name}-live", "#{name}-die", 6
        p.instruction "#{name}-mainttrampoline", :tmp_var, :const_3, "#{name}-maint", "#{name}-maint", 12
        p.instruction "#{name}-0", :counter, :counter, "#{name}-1", "#{name}-die",7   # 0 live cells
        p.instruction "#{name}-1", :counter, :counter, "#{name}-2", "#{name}-die",8   # 1 live cell
        p.instruction "#{name}-2", :counter, :counter, "#{name}-3", "#{name}-mainttrampoline",9   # 2 live
        p.instruction "#{name}-3", :counter, :counter, "#{name}-die", "#{name}-live",10   # 3 live cells
      end
      ##Read this bottoms up
      tl,t,tr = n(-1,1), n(0,1), n(1,1)
      l,r = n(-1,0), n(1,0)
      bl,b,br = n(-1,-1), n(0,-1), n(1,-1)

      # above here, :counter has the number of  live neighbours
      a= dec_x_ifnot_y("#{name} cdec TL ",p,:counter,tl,"#{name}-0")
      a=dec_x_ifnot_y("#{name} cdec T",p,:counter,t,a)
      a=dec_x_ifnot_y("#{name} cdec TR",p,:counter,tr,a)
      a=dec_x_ifnot_y("#{name} cdec L",p,:counter,l,a)
      a=dec_x_ifnot_y("#{name} cdec R",p,:counter,r,a)
      a= dec_x_ifnot_y("#{name} cdec BR",p,:counter,br,a)
      a=dec_x_ifnot_y("#{name} cdec B",p,:counter,b,a)
      a=dec_x_ifnot_y("#{name} cdec BL",p,:counter,bl,a)
      p.instruction "#{name} init_ctr", :counter, :const_9, a,a, 0
      "#{name} init_ctr"
      #TODO: Add exit instruction
    end
  end
end
def GOLSample1(p)
 GameOfLifeProgram(p,3,[[0,0,0],[0,1,0],[0,0,0]])
end