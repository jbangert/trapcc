require_relative '../interrupt_program'
require_relative '../debug_program'
require_relative '../game_of_life'
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
  p.variable :evencounter, 8
  p.variable :oddcounter, 8
  p.instruction :dec_odd, :oddcounter, :evencounter, :dec_even , :exit, 0
  p.instruction :dec_even, :evencounter, :oddcounter, :dec_odd, :exit , 1
  p.start :dec_odd
  p.output_binary 1,0, :evencounter
  p.output_binary 1,1, :reset
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


#print counter_program.encode
X=4
glider = GameOfLifeProgram.new(Program,7,               [
                                                         [0,0,X,0,0,0,0,0,0,0],
                                                         [X,0,X,0,0,0,0,0,0,0],
                                                         [0,X,X,0,0,0,0,0,0,0],
                                                         [0,0,0,0,0,0,0,0,0,0],
                                                         [0,0,0,0,0,0,0,0,0,0],
                                                         [0,0,0,0,0,0,0,0,0,0],
                                                         [0,0,0,0,0,0,0,0,0,0],
                                                         [0,0,0,0,0,0,0,0,0,0],
                                                         [0,0,0,0,0,0,0,0,0,0],
                                                         [0,0,0,0,0,0,0,0,0,0],])
#debug_gol_program(glider)
print glider.source
#run_gol_program(glider)
#debug_gol_program(GameOfLifeProgram.new(DebugProgram,3,[[0,0,0],[0,1,0],[0,0,0]]))

