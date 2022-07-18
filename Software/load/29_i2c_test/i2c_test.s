    .include "utils.inc"
    .include "lcd.inc"
    .include "tty.inc"
    .include "i2c.inc"

    .code

init:

    jsr _lcd_init
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
    sta temp       ; save integral
    jsr i2c_send_ack
    jsr i2c_read_byte
    sta temp + 1   ; save decimal
    jsr i2c_send_nak
    jsr i2c_stop

    lda #$1         ; 1 second delay after reset. Could be as low as 260 ms.
    jsr _delay_sec

    jsr i2c_start
    lda #$E2        ; write
    jsr i2c_send_byte
    lda #$23        ; ask for humidity.
    jsr i2c_send_byte
    jsr i2c_start   ; repeat start

    lda #$E3        ; address read
    jsr i2c_send_byte
    jsr i2c_read_byte
    sta humi       ; save integral
    jsr i2c_send_nak
    jsr i2c_stop

    ; display temp on the lcd and terminal
    write_tty #STRTEMP
    lda temp
    ldx #0
    jsr _tty_write_dec
    write_tty #STRPT
    lda temp + 1
    ldx #0
    jsr _tty_write_dec
    write_tty #STRTMPSFX
    jsr _tty_send_newline

    ; display humidity on the lcd and terminal
    write_tty #STRHUMI
    lda humi
    ldx #0
    jsr _tty_write_dec
    write_tty #STRHUMSFX

    jsr _tty_send_newline

    lda #%00000101  ; set output SERIAL and input to SERIAL.
    jsr _tty_init

    rts

    .bss
temp: .res 2
humi: .res 2

    .rodata

STRTEMP:    .asciiz "Temp: "
STRHUMI:    .asciiz "Humi: "
STRPT:      .asciiz "."
STRTMPSFX:  .asciiz " C"
STRHUMSFX:  .asciiz " %"
