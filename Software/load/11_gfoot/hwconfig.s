        .import __VIA2_START__

        .code
PORTB = __VIA2_START__ + $00
PORTA = __VIA2_START__ + $01
DDRB =  __VIA2_START__ + $02
DDRA =  __VIA2_START__ + $03

SD_CS   = %00010000
SD_SCK  = %00001000
SD_MOSI = %00000100
SD_MISO = %00000010

PORTA_OUTPUTPINS =  SD_CS | SD_SCK | SD_MOSI

via_init:
  lda #PORTA_OUTPUTPINS   ; Set various pins on port A to output
  sta DDRA
  rts
