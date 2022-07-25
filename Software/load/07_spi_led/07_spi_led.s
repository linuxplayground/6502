    .include "utils.inc"

    .import __VIA2_START__

VIA2_PORTA  = __VIA2_START__ + $1	; check if some buttons have been pressed.
VIA2_DDRA   = __VIA2_START__ + $3   ; Port A data direction register

SCK   = %00000001
CS    = %00001000
MOSI  = %00000100

DECODE_MODE     = $09                       
INTENSITY       = $0a                        
SCAN_LIMIT      = $0b                        
SHUTDOWN        = $0c                        
DISPLAY_TEST    = $0f


        .zeropage
outb:   .res 1
inb:    .res 1
row:    .res 1
col:    .res 1

        .code

 main:
        jsr led_init
        lda #SHUTDOWN
        ldx #1
        jsr spisend

        lda #INTENSITY
        ldx #0
        jsr spisend

        ; paint a heart.
        ; it's rotated CCW 90deg on the breadboard such that:
        ; A=1, x(MSB) is at bottom left corner.
        ; A=8, x(LSB) is at top right corner.

        lda #1
        ldx #%00001100
        jsr spisend

        lda #2
        ldx #%00010010
        jsr spisend

        lda #3
        ldx #%00100010
        jsr spisend

        lda #4
        ldx #%01000100
        jsr spisend

        lda #5
        ldx #%00100010
        jsr spisend

        lda #6
        ldx #%00010010
        jsr spisend

        lda #7
        ldx #%00001100
        jsr spisend

        lda #8
        ldx #%00000000
        jsr spisend

exit:
        rts

led_init:
        lda #(SCK|CS|MOSI)
        sta VIA2_DDRA

        lda #CS
        sta VIA2_PORTA

        lda #DISPLAY_TEST
        ldx #0
        jsr spisend

        lda #SCAN_LIMIT
        ldx #7
        jsr spisend

        lda #DECODE_MODE
        ldx #0
        jsr spisend

        jsr led_clear

        lda #SHUTDOWN
        ldx #0
        jsr spisend

        rts

; this ends up sending a nop on the last loop which is fine.
led_clear:
        ldx #9
@loop:
        dex
        beq @exit
        phx
        txa
        ldx #%00000000  ; each column has 8 dots.  turn them all off
        jsr spisend
        plx
        jmp @loop
@exit:
       rts

; A = command, X = value
; borks both A and X
spisend:
        phx
        pha
        lda #0
        sta VIA2_PORTA
        pla
        jsr spibyte
        plx
        txa
        jsr spibyte
        lda #CS
        sta VIA2_PORTA
        rts

spibyte:
        sta outb
        ldy #0
        sty inb
        ldx #8
spibytelp:
        tya		        ; (2) set A to 0
        asl outb	    ; (5) shift MSB in to carry
        bcc spibyte1	; (2)
        ora #MOSI	    ; (2) set MOSI if MSB set
spibyte1:
        sta VIA2_PORTA	; (4) output (MOSI, SCS low, SCLK low)
        tya		        ; (2) set A to 0 (Do it here for delay reasons)
        inc VIA2_PORTA	; (6) toggle clock high (SCLK is bit 0)
        clc		        ; (2) clear C (Not affected by bit)
        bit VIA2_PORTA  ; (4) copy MISO (bit 7) in to N (and MOSI in to V)
        bpl spibyte2	; (2)
        sec		        ; (2) set C is MISO bit is set (i.e. N)
spibyte2:
        rol inb		    ; (5) copy C (i.e. MISO bit) in to bit 0 of result
        dec VIA2_PORTA  ; (6) toggle clock low (SCLK is bit 0)
        dex		        ; (2) next bit
        bne spibytelp	; (2) loop
        lda inb		    ; get result
        rts
        