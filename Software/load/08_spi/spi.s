; ------------------------------------------------------------------------------------------
; Use this in conjunction with an arduino to test SPI bitbanging.
; A slave sketch is included in this repo under `arduino_sketch` which includes a README
; that explains how this works.
; ------------------------------------------------------------------------------------------
    .include "utils.inc"
    .include "macros.inc"
    .include "lcd.inc"

    .import __VIA2_START__

VIA2_PORTA  = __VIA2_START__ + $1	; check if some buttons have been pressed.
VIA2_DDRA   = __VIA2_START__ + $3   ; Port A data direction register

SCK   = %00000001
CS    = %00000010
MOSI  = %00000100
MISO  = %10000000


        .zeropage
outb:   .res 1
inb:    .res 1
bufptr: .res 2

        .code

main:
        jsr _lcd_init       ; set up the LCD

        lda #(CS)
        sta VIA2_PORTA

        lda #<$2000         ; set up the read buffer.
        sta bufptr
        lda #>$2000
        sta bufptr + 1

        lda #(SCK|CS|MOSI)  ; Set up the SPI lines to low.
        sta VIA2_DDRA

        lda #$0a            ; command is 0x0a (arbitrarily chosen and defined in arduino sketch.)
                            ; change to 0x0b to have the slave send a differnt response.
                            ; use the monitor function on OS/1 to change the value at $1016 as follows
                            ;
                            ; put 1016=0b
                            ; go 1000
                            ;
        jsr spibyte
        jsr spibyte         ; read garbage first char.

read_loop:
        lda #$00            ; send garbage data - we only want to read now.
        jsr spibyte
        cmp #$05            ; was end of file received?
        beq @print_buffer   ; yes, jmp to print buffer
        sta (bufptr)        ; no, save the byte into the buffer
        inc_ptr bufptr      ; increment the buffer pointer.
        jmp read_loop       ; read again.
@print_buffer:
        lda #$00
        sta (bufptr)        ; zero terminate the buffer.
        lda #<$2000         ; print the buffer.
        ldx #>$2000
        jsr _lcd_print
@exit:
        lda #(CS)           ; set CS high.
        sta VIA2_PORTA
        rts

; Sends a byte and returns whatever came back on MISO in A.
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
