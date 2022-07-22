        .setcpu "65c02"
        .include "i2c.inc"
        .include "utils.inc"

        .zeropage
chaser_byte: .res 1

        .code
init:

    jsr i2c_init    ; set up ports
    lda #$ff
    sta chaser_byte

loop_l:
    dec chaser_byte
    jsr send_byte
    jsr wait
    jmp loop_l


wait:
    lda #30
    jsr _delay_ms
    rts

send_byte:
    jsr i2c_start
    lda #$40        ; address write
    jsr i2c_send_byte
    lda chaser_byte
    jsr i2c_send_byte
    jsr i2c_stop  
    rts