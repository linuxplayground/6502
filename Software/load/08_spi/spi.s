; ------------------------------------------------------------------------------------------
; Use this in conjunction with an arduino to test SPI bitbanging.
; A slave sketch is included in this repo under `arduino_sketch` which includes a README
; that explains how this works.
; ------------------------------------------------------------------------------------------
    .include "utils.inc"
    .include "macros.inc"
    .include "lcd.inc"
    .include "tty.inc"

    .import __VIA2_START__

VIA2_PORTA  = __VIA2_START__ + $1	; check if some buttons have been pressed.
VIA2_DDRA   = __VIA2_START__ + $3   ; Port A data direction register

CS              = %00100000     ; CS
SCK             = %00001000     ; SCK
MOSI            = %00000100     ; DI
MISO            = %00000010     ; DO


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
        jsr spi_writebyte

read_loop:
        jsr spi_readbyte    ; send garbage data - we only want to read now (MOSI is HIGH on each bit.)
        jsr _tty_send_character
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

; -----------------------------------------------------------------------------
; Enable the card and tick the clock 8 times with MOSI high, 
; capturing bits from MISO and returning them.
; Inputs: None
; Outputs: byte received from SD card in A
; clobbers: X, Y
; -----------------------------------------------------------------------------
spi_readbyte:
    ldx #$fe    ; Preloaded with seven ones and a zero, so we stop after eight
                ; bits
@loop:
    lda #0                ; enable card (CS low), set MOSI (resting state), SCK low
    sta VIA2_PORTA
    lda #(SCK)          ; toggle the clock high
    sta VIA2_PORTA
    lda VIA2_PORTA             ; read next bit
    and #(MISO)
    clc                        ; default to clearing the bottom bit
    beq @bitnotset             ; unless MISO was set
    sec                        ; in which case get ready to set the bottom bit
@bitnotset: 
    txa                        ; transfer partial result from X
    rol                        ; rotate carry bit into read result, and loop bit into carry
    tax                        ; save partial result back to X
    bcs @loop                  ; loop if we need to read more bits
    rts

; -----------------------------------------------------------------------------
; Tick the clock 8 times with descending bits on MOSI
; SD communication is mostly half-duplex so we ignore anything it sends back
; here.
; Inputs: byte to send in A
; Outputs: None
; clobbers: X, Y and A
; -----------------------------------------------------------------------------
spi_writebyte:
    ldx #8                          ; send 8 bits
@loop:  
    asl                             ; shift next bit into carry
    tay                             ; save remaining bits for later
    lda #0  
    bcc @sendbit                    ; if carry clear, don't set MOSI for this bit
    ora #(MOSI) 
@sendbit:   
    sta VIA2_PORTA                  ; set MOSI (or not) first with SCK low
    eor #(SCK)  
    sta VIA2_PORTA                  ; raise SCK keeping MOSI the same, to send the bit
    tya                             ; restore remaining bits to send
    dex 
    bne @loop                       ; loop if there are more bits to send
    rts