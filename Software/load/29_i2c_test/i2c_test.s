    .include "utils.inc"
    .include "lcd.inc"
    .include "tty.inc"
    .include "i2c.inc"

    .import __VIA2_START__

VIA_REGISTER_PORTB = $00
VIA_REGISTER_DDRB  = $02

VIA2_PORTB = __VIA2_START__ + VIA_REGISTER_PORTB
VIA2_DDRB  = __VIA2_START__ + VIA_REGISTER_DDRB

I2C_DATABIT     = %00000010
I2C_CLOCKBIT    = %00000001
I2C_DDR         = VIA2_DDRB
I2C_PORT        = VIA2_PORTB

value 	= $2000		; 2 bytes

    .zeropage

    ZP_I2C_DATA:  .res 1
    ZP_X:         .res 1

    .code

init:

    jsr _lcd_init
    lda #%00001101  ; set output to LCD and SERIAL and input to SERIAL.
    jsr _tty_init

    jsr i2c_init    ; set up ports

    jsr i2c_start
    lda #$E2        ; address write
    jsr i2c_send_byte
    lda #$E1        ; system reset
    jsr i2c_send_byte
    jsr i2c_stop

    lda #$1         ; 1 second delay after reset. Could be as low as 260 ms.
    jsr _delay_sec

    jsr i2c_start
    lda #$E2        ; write
    jsr i2c_send_byte
    lda #$21        ; ask for temperature.
    jsr i2c_send_byte
    jsr i2c_start   ; repeat start

    lda #$E3        ; address read
    jsr i2c_send_byte
    jsr i2c_read_byte
    sta value       ; save data Before the decimal
    jsr i2c_send_ack
    jsr i2c_read_byte
    sta value + 1   ; save data After the decimal
    jsr i2c_send_nak
    jsr i2c_stop

    ; display on the lcd and terminal
    write_tty #STRTEMP

    lda value
    ldx #0
    jsr _tty_write_dec

    write_tty #STRPT

    lda value + 1
    ldx #0
    jsr _tty_write_dec

    write_tty #STRSFX

    jsr _tty_send_newline

    lda #%00000101  ; set output SERIAL and input to SERIAL.
    jsr _tty_init

    rts


    .rodata

STRTEMP: .asciiz "Temp: "
STRPT:   .asciiz "."
STRSFX:  .asciiz " C"
