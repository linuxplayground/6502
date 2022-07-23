        .include "via.inc"
        .include "via_const.inc"
        .include "sys_const.inc"
        .include "zeropage.inc"
        
        .export keypad_init
        .export keypad_scan

        .code

keypad_init:
        ; Set up Interrupt on CA1 positive edge
        lda #(VIA_IER_SET_FLAGS|VIA_IER_CA1_FLAG)
        sta VIA1_IER
        lda #(VIA_PCR_CA1_INTERRUPT_POSITIVE)
        sta VIA1_PCR

        ; set up VIA1_DDRA / PORTA bottom 4 pins as input.
        ; top 4 pins are unused - leave them as input too.
        ; 0  1  2  3  4  5  6  7
        ; LT UP RT DN -  -  -  -
        ; 0  0  0  0  0  0  0  0
        lda #$00
        sta VIA1_DDRA


; nonblocking scan for key press
; pressed key in A
; bit 0 = left, 1 = up, 2 = right, 3 = down, 4-7 = zero / reserved
; carry: 0 = no key, 1 = key
keypad_scan:
        lda VIA1_PORTA      ; load in port a
        and #$0f            ; mask out bottom 4 bits
        beq @no_key
        sec                 ; set carry bit
        jmp @return_key     ; exit
@no_key:
        clc                 ; clear carry bit / fall through to exit.
@return_key:
        rts
