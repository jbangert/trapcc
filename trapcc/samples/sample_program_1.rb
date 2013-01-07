require_relative '../interrupt_program'
def counter_program
  p = Program.new()
  p.variable :reset, 20
  p.variable :evencounter, 10
  p.variable :oddcounter, 18
  p.instruction :dec_odd, :oddcounter, :evencounter, :dec_even , :reset, 0
  p.instruction :dec_even, :evencounter, :oddcounter, :dec_odd, :reset , 1
  p.instruction :reset, :evencounter, :reset, :dec_odd, :dec_even, 2 #This always takes the a branch
  p.start :dec_odd
  p
end

def exit_program
  p = Program.new()
  p.variable :reset, 20
  p.variable :evencounter, 3
  p.variable :oddcounter, 3
  p.instruction :dec_odd, :oddcounter, :evencounter, :dec_even , :exit, 0
  p.instruction :dec_even, :evencounter, :oddcounter, :dec_odd, :exit , 1
  p.instruction :exit, :evencounter, :reset, :dec_odd, :dec_even, 2 #This always takes the a branch
  p.start :dec_odd
  p

end
def subtract_program
  p = Program.new()
  p.variable :a, 40
  p.variable :b, 20
  p.instruction :dec_b,:b, :b, :dec_a, :done_1 ,1
  p.instruction  :dec_a, :a,:a ,:dec_b, :done_1, 2

  p.instruction :done_1, :tmp_var, :a, :done_2 , :done_2,3
  p.instruction :done_2, :tmp_var, :a , :done_1, :done_1,4
  p
end

class GameOfLifeProgram
  def initialize(size,init)
    @size = size
    @p = Program.new()
    @p.variable :const_9, 9*4
    @p.variable :const_1, 4
    @p.variable :const_2, 2*4

    @p.variable :counter, 9*4
    @p.instruction :exit, :tmp_var,:counst_9 , 0x18, 0x18, 15
    next_inst = :exit
    (0..size-1).each do |x |
      (0..size-1).each do |y |
        @p.variable "CellX#{x}Y#{y}", init[x][y]
        c = Cell.new(x,y,size)
        next_inst = c.instructions(@p,next_inst)
      end
    end
    @p.start next_inst
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
    def dec_x_if_y(p, x,y,nxt)  # 1 2
      ins =  "dec #{x} if #{y} A"
      s1 = "check #{ins}"
      s2 = "dec #{ins}"
      s3 = "noop out #{ins}"
      p.instruction s1, :tmp_var, :y, s2, s3 , 1
      p.instruction s2, x, x, s3 , s3, 2
      p.instruction s3, :tmp_var, :const_9 , nxt,nxt , 3
      s1
    end
    def n(dx,dy)
      return (@x+dx)%@size, (@y+dy)%@size
    end
    def cellvar
      "Cell#{name}"
    end
    def instructions(p, next_inst)
      p.instruction "die#{name}", cellvar, :const_1 , next_inst , next_inst, 4
      p.instruction "live#{name}", cellvar, :const_2, next_inst,next_inst, 5
      p.instruction "maint#{name}", :tmp_var, cellvar, "live#{name}", "die#{name}", 6

      #Read this bottoms up
      tl,t,tr = n(-1,-1), n(-1,0), n(-1,1)
      l,r = n(-1,0), n(1,0)
      bl,b,br = n(1,-1), n(1,0), n(1,1)
      p.instruction "0-#{name}", :counter, :counter, "1-#{name}", "die#{name}",7   # 8 live cells
      p.instruction "1-#{name}", :counter, :counter, "2-#{name}", "die#{name}",8   # 7 live cells
      p.instruction "2-#{name}", :counter, :counter, "3-#{name}", "die#{name}",9   # 6 live cells
      p.instruction "3-#{name}", :counter, :counter, "4-#{name}", "die#{name}",10   # 5 live cells
      p.instruction "4-#{name}", :counter, :counter, "5-#{name}", "die#{name}",11   # 4 live cells
      # End of overcrowding
      p.instruction "5-#{name}", :counter, :counter, "6-#{name}", "live#{name}",12   # 3 live cells
      p.instruction "6-#{name}", :counter, :counter, "die#{name}", "maint#{name}",13   # 2 live cells
      #If less, you die
      # above here, :counter has the number of dead neighbours
      a= dec_x_if_y(p,:counter,tl,a)
      a=dec_x_if_y(p,:counter,t,a)
      a=dec_x_if_y(p,:counter,tr,a)
      a=dec_x_if_y(p,:counter,l,a)
      a=dec_x_if_y(p,:counter,r,a)
      a= dec_x_if_y(p,:counter,br,a)
      a=dec_x_if_y(p,:counter,bl,a)
      a=dec_x_if_y(p,:counter,b,a)
      p.instruction "#{name} init_ctr", :counter, :const_9, a,a, 0
      "#{name} init_ctr"
      #TODO: Add exit instruction
    end
  end
end
print counter_program.encode
#print GameOfLifeProgram.new(2, [[1,1 ], [1,1]]).source
