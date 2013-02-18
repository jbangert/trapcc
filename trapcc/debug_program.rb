require 'set'
class DebugProgram
  # To change this template use File | Settings | File Templates.
  def initialize(trace=false)
    @variables ={}
    @instructions = {}
    @start = :exit
    @breakpoints = Set.new
    @trace = trace
  end
  def instruction(label,x,y,a,b,tss_slot)
    raise RuntimeError.new "#{label} instruction redefined" if @instructions.include? label
    @instructions[label] = {x: x, y: y, a: a, b: b, slot: tss_slot }
  end
  def output_binary(x,y,var)

  end
  def output_fixed(y,x,char)

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
    @start = label
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
    y=   @variables[@instructions[@pc][:y]]
    print "R #{@instructions[@pc][:y]} #{y.to_s(16)}\n"
    if(y < 4)
      @variables[@instructions[@pc][:x]] = y
      printf "W #{@instructions[@pc][:x]} #{y.to_s(16).upcase}\n"

      @pc = @instructions[@pc][:b]
      raise RuntimeError.new "TRIPLEFAULT! #{@pc}" if @variables[@instructions[@pc][:y]] < 4
    else
      @variables[@instructions[@pc][:x]] =  y -4
      print "W #{@instructions[@pc][:x]} #{(y-4).to_s(16).upcase}\n"
      @pc = @instructions[@pc][:a]
    end

  end
  def encode() # This actually runs the debugger
    @pc = @start
    while @pc != :exit
      if @trace
        print "#{@pc} : #{@instructions[@pc][:x]} <- #{@instructions[@pc][:y]} (#{@variables[@instructions[@pc][:y]]/4}) -1 \n"
      end
      step
      if @breakpoints.include? @pc
        print "Breakpoint hit\n"
      end
    end
    # @variables
  end
  def validate_bochs() #TBD: Validate steps in bochs!

  end
end

def run_gol_program(p)
  while true
    p.program.encode()
  end
end
def debug_gol_program(p)# Debugs graphical programs
  (1..50).each do |iteration|
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