# Arduino Sketch for SPI example

The sketch in this folder can be loaded onto an Arduino and wired up as follows:

|Arduino (NANO)|VIA2 PORTA
|--------------|----------
| D13 (SCK)    | P0
| D10 (CS)     | P1
| D11 (MOSI)   | P2
| D12 (MISO)   | P7 * Note this is P7

The SPI Spec on the nano is as follows:

The Assembly code in `Software/load/08_spi/spi.s` includes an `spibyte` routine which will pull the CS pin low and then send whatever is in the A register.  As it sends the byte out on MOSI, it will clock in 8 bits on the MISO line and store that byte in the A register.  The rest of the code deals with storing all the bytes received in a buffer.

This example expects the slave to stop sending data with an EOF (0x05) character.  There are two instructions the arduino can receive, a `0x0A` and a `0x0B`.  Each of these will cause the slave to start responding with the bytes of a different message.

The assembly code, will enter a loop and send a 0x00 to the slave in order to receve the next byte. It will keep doing so until a 0x05 (EOF) is received.
