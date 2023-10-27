It is full-duplex synchronised interface usually used in embedded systems for data transfer. SPI has master or controller and slave or chip to which data is to be transfered. Refer the [master](https://github.com/Mhd-Shah/Verification-of-SPI-communication-protocol/blob/main/SPI_Master.png) and [slave](https://github.com/Mhd-Shah/Verification-of-SPI-communication-protocol/blob/main/SPI_Slave.png) images for better understanding.<br>

**__________SPI Master ______________**<br>
-> newd : When there is new data, it is turned to active high.<br>
-> cs ( _chip_select_ ) : Enable slave device on active low.<br>
-> MOSI ( _Master_output_slave_input_ ) : port to send data from master top slave serially.<br>
-> sclk ( _Synchronised_clock_ ) : serial clock to synchronise slave.<br>

**__________SPI Slave ______________**<br>
-> cs<br>
-> MOSI<br>
-> sclk<br>
-> done : Triggered on transfer completion.<br>
-> Dout : output port to collect data<br>

_Click here for_
**[design_code](https://github.com/Mhd-Shah/Verification-of-SPI-communication-protocol/blob/main/design.sv)**<br>
**[Testbench_code](https://github.com/Mhd-Shah/Verification-of-SPI-communication-protocol/blob/main/testbench.sv)**
