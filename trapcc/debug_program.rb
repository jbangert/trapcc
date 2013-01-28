require 'set'
class DebugProgram
  # To change this template use File | Settings | File Templates.
  def initialize(trace=true)
    @variables ={}
    @instructions = {}
    @pc = :exit
    @breakpoints = Set.new
    @trace = trace
  end
  def instruction(label,x,y,a,b,tss_slot)
    raise RuntimeError.new "#{label} instruction redefined" if @instructions.include? label
    @instructions[label] = {x: x, y: y, a: a, b: b, slot: tss_slot }
  end
  def variable(label,initial_value)
    @variables[label]=initial_value
  end
  def dbg_inspect(variable)
    @variables[variable]
  end
  def dbg_set_variables(vars)
    @variables = vars
  end
  def start(label)
    @pc = label
  end
  def breakpoint(label)
    @breakpoints.add(label)
  end
  def step()
    return if @pc == :exit
    #TODO: Catch bad slots
    raise RuntimeError.new "Invalid Instruction #{@pc}" unless @instructions.include? @pc
    raise RuntimeError.new "Instruction #{@instructions[@pc]} has invalid Y-variable" unless
        @variables.include? @instructions[@pc][:y]
    if(@variables[@instructions[@pc][:y]] < 4)
      @pc = @instructions[@pc][:b]
    else
      @variables[@instructions[@pc][:x]] =  @variables[@instructions[@pc][:y]] -4
      @pc = @instructions[@pc][:a]
    end

  end
  def encode() # This actually runs the debugger
    while @pc != :exit
      if @trace
        print "#{@pc} : #{@instructions[@pc][:x]} <- #{@instructions[@pc][:y]} (#{@variables[@instructions[@pc][:y]]/4}) -1 \n"
      end
      step
      if @breakpoints.include? @pc
        print "Breakpoint hit\n"
      end
    end
    @variables
  end
end

def debug_gol_program(p)# Debugs graphical programs
  (1..2).each do |iteration|
    print "Game of Life iteration #{iteration}\n"
    (0..p.size-1).each do |y|
      (0..(p.size-1)).each do |x|
        putc '|'
        var = p.program.dbg_inspect("X#{x}Y#{y}Cell")
        if(var > 0)
          putc (var / 4 ).to_s
        else
          putc ' '
        end
      end
      putc '|'
      putc "\n"
    end
    p.program.encode() # Run in debugger
  end
end