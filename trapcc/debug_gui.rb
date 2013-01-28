require 'tk'
require 'tkextlib/tile'
require 'debug_program'
class DebugProgram                                                                                  h
  def debug_gui()
    root= TkRoot.new
    root.title "TrapCC debugger"
    outer_frame = Tk::Tile::Paned.new(root) do
      orient "vertical"
    end
    source = TkListbox.new(outer_frame)    {
    }
    right_pane = Tk::Tile::Paned.new(outer_frame) do
      orient "horizontal"
    end
  end
end