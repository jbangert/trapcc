trapcc
======

Compute with 0 instructions on Intel! Discover the awesomeness of the Intel MMU!
Follow @julianbangert and @sergeybratus for updates. See a demo here:
http://www.youtube.com/watch?v=eSRcvrVs5ug

What is this?
=============
This is a proof by construction that the Intel MMU's fault handling mechanism is Turing complete.
We have constructed an assembler that translates 'Move, Branch if Zero, Decrement' instructions to C source that sets up various processor control tables. 
After this code has executed, the CPU computes by attempting to fault without ever executing a single instruction.
Optionally, the assembler can also generate X86 instructions that will display variables in the VGA frame buffer and will cause control to be transferred between the native (display) instructions and 'weird machine' trap instructions.

Why on earth?
=============

To read up on the awesome idea of weird machines and their uses, see  @sergeybratus's and @halvarflake's work. In short, we are trying to find hidden state and derive computation of it in unexpected places.  
One practical use of this technique is for code obfuscation - many (kernel) debuggers will break due to the frequent context switches (esp. cooperative debuggers like KGDB) and  analyzing the binary is going to be extraordinaly confusing, especially if normal X86 instructions and trap instructions are interleaved to do weird control transfer.
Furthermore, out of the many virtual machines only Bochs runs such trap based programs correctly (and there are other tricks to distinguish bochs from a real box).

TBD
===
As always, one of these days we will publish a detailed paper. Until then, please hack around with the code. Share any cool creations and ask any questions on twitter!

