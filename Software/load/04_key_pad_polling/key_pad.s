;-------
; 1 = LEFT
; 2 = UP
; 4 = RIGHT
; 8 = DOWN
;-------


    .setcpu "65C02"
    .include "lcd.inc"
    .include "core.inc"
    .include "utils.inc"
    .include "blink.inc"
    .include "zeropage.inc"
    
    .import __VIA1_START__
    VIA1_PORTA = __VIA1_START__ + $01

    .bss
count:
    .res 2
quit_flag:
    .res 1
update_flag:
    .res 1

    .rodata
str_exit:
    .asciiz "Exiting ..."

    .code

    jsr _lcd_init                       ; update the LCD Screen / init

    stz count                           ; Zero out the counter and input flag
    stz count + 1
    stz quit_flag

loop:
    lda quit_flag
    bne quit
    jsr read_key                        ; if carry is set, a key was pressed.
    bcc end_loop                        ; carry not set, no key pressed.
update:
    lda count
    ldx count + 1
    jsr _lcd_clear
    jsr _lcd_write_dec
end_loop:
    jmp loop

quit:
    jsr _lcd_newline
    write_lcd #str_exit
    rts

read_key:
    lda keypad_buf
    cmp #$01
    beq @left
    cmp #$02
    beq @up
    cmp #$04
    beq @right
    cmp #$08
    beq @down
    jmp @end_read_key
@left:
    dec count
    bne @set
    dec count + 1
    jmp @set
@up:
    stz count
    stz count + 1
    jmp @set
@right:
    inc count
    bne @set
    inc count + 1
    jmp @set
@down:
    inc quit_flag        ; flag to quit.
    ; fall through
@set:
    sec
    jmp @end_read_key
@clear:
    clc
@end_read_key:
    ; reset keypad_buf after reading it.
    stz keypad_buf
    rts

