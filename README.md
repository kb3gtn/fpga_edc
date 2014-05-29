fpga_edc
========

FPGA Embedded Device Controller (fpga_edc)

This is a simple design to allow a computer to control a address/data bus
though a uart interface.  This data bus can be connected to custom built 
I/O interfaces to control external devices.

Current Design was built using a mojo_board fpga spartan6.
But could be adapted to other fpga platforms.

Still a work in progress..

Components Built:

* Simple rs232 uart tx/rx
* uart <-> databus glue state machine
* databus master
* spi_master databus slave
* led register databus slave


Some silly examples:
* run_leds.py
  A simple program that performs databus writes to the LED register and
  can do different LED patterns.  (uart databus write testing apps)



