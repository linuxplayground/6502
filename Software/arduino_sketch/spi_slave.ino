// Written by Nick Gammon
// April 2011

// what to do with incoming data
volatile byte command = 0;
char message[] = "Hello, World!";
//8800=f4 = LED OFF
//8800=f5 = LED ON
byte blinkon[6] =   {0xa9, 0xf5, 0x8d, 0x00, 0x88, 0x60};
byte blinkoff[6] =  {0xa9, 0xf4, 0x8d, 0x00, 0x88, 0x60};
byte hellolcd[19] = {0x20, 0xFA, 0xB1, 0xA9, 0xFF, 0xA2, 0xFF, 0x20, 0xA3, 0xB1, 0x60};

int ptr = 0;

char output[25];

void setup (void)
{

  // have to send on master in, *slave out*
  pinMode(MISO, OUTPUT);

  // turn on SPI in slave mode
  SPCR |= _BV(SPE);

  // turn on interrupts
  SPCR |= _BV(SPIE);

}  // end of setup

// SPI interrupt routine
ISR (SPI_STC_vect)
{
  byte c = SPDR;

  switch (command)
  {
  // no command? then this is the command
  case 0:
    command = c;
    SPDR = 0;
    break;
    
  // add to incoming byte, return result
  case 10:
    if (ptr <= sizeof(message)) {
      SPDR = message[ptr];
      ptr ++;
    } else {
      SPDR = 5; //EOF
      ptr = 0;
      command = 0;
    }
    break;
    
   case 11:
    if (ptr <= sizeof(hellolcd)) {
      SPDR = hellolcd[ptr];
      ptr ++;
    } else {
      SPDR = 5; //EOF
      ptr = 0;
      command = 0;
    }
    break;

   case 12:
    if (ptr <= sizeof(blinkon)) {
      SPDR = blinkon[ptr];
      ptr ++;
    } else {
      SPDR = 5; //EOF
      ptr = 0;
      command = 0;
    }
    break;

   case 13:
    if (ptr <= sizeof(blinkoff)) {
      SPDR = blinkoff[ptr];
      ptr ++;
    } else {
      SPDR = 5; //EOF
      ptr = 0;
      command = 0;
    }
    break;

  } // end of switch


}  // end of interrupt service routine (ISR) SPI_STC_vect

void loop (void)
{
  
  // if SPI not active, clear current command
  if (digitalRead (SS) == HIGH)
    command = 0;
}  // end of loop