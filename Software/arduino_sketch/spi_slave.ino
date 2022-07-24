// Written by Nick Gammon (Well - based on actually)
// April 2011
// http://www.gammon.com.au/spi

// what to do with incoming data
volatile byte command = 0;
char message[] = "Hello, World!";
char welcome[] = "Welcome to SPI Slave!";
int ptr = 0;

void setup (void)
{

    // have to send on master in, *slave out*
    pinMode(MISO, OUTPUT);

    // turn on SPI in slave mode
    SPCR |= _BV(SPE);

    // turn on interrupts
    SPCR |= _BV(SPIE);

    Serial.begin(9600);

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

        // Send message
        // A pointer into the buffer is used to track which byte to send.
        case 10:
            if (ptr <= sizeof(message)) {
                SPDR = message[ptr];
                Serial.print(message[ptr]);
                ptr ++;
            } else {
                SPDR = 5; //EOF
                ptr = 0;
                command = 0;
                Serial.println();
            }
            break;

        // Send welcome
        // A pointer into the buffer is used to track which byte to send.
        case 11:
            if (ptr <= sizeof(welcome)) {
                SPDR = welcome[ptr];
                Serial.print(welcome[ptr]);
                ptr ++;
            } else {
                SPDR = 5; //EOF
                ptr = 0;
                command = 0;
                Serial.println();
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
