    .setcpu "65C02"
    .include "lcd.inc"

    .code

    jsr _lcd_init
    write_lcd #msg

    lda #$FE
    ldx #$FE
    jsr _lcd_write_dec
    rts 

    .rodata
msg: .asciiz "Hello: "