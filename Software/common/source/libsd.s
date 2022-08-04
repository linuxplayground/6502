        .include "macros.inc"
        .include "utils.inc"
        .include "tty.inc"
        .include "via.inc"
        .include "via_const.inc"

        .export sd_init
        .export sd_readsector
        .export zp_sd_currentsector

        .bss
zp_sd_currentsector:    .res 4      ; 32 bit address of the current sector.

        .rodata
sd_cmd0_bytes:          .byte $40, $00, $00, $00, $00, $95
sd_cmd8_bytes:          .byte $48, $00, $00, $01, $aa, $87
sd_cmd55_bytes:         .byte $77, $00, $00, $00, $00, $01
sd_cmd41_bytes:         .byte $69, $40, $00, $00, $00, $01

.if DEBUG > 0           ; we don't want all this garbage in memory if not
                        ;debugging.
dbg_str_sd_init:        .asciiz "Initializing SD card in SPI mode"
dbg_str_sd_init_ok:     .asciiz "Initialize SD card - OK"
dbg_str_sd_init_fail:   .asciiz "Initialize SD card - FAIL"
dbg_str_sd_cmd0:        .asciiz "cmd0"
dbg_str_sd_cmd8:        .asciiz "cmd8"
dbg_str_sd_cmd55:       .asciiz "cmd55"
dbg_str_sd_cmd41:       .asciiz "cmd41"
dbg_str_read_sector:    .asciiz "Reading sector: 0x"
dbg_str_read_sec_ok:    .asciiz "Read sector - OK"
dbg_str_read_sec_fail:  .asciiz "Read sector - FAIL"
.endif

; macro to only print debug messages if debugging is turned on.
.macro debug message
.if DEBUG > 0
    jsr _tty_send_newline
    write_tty message
.endif
.endmacro

        .code
; -----------------------------------------------------------------------------
; Prepare the SD card for SPI mode.
; cycle the clock 80 times then send cmd0, cmd8, cmd55+cmd41 until response is
; 00
; Inputs: None
; Outputs: C=0=OK, C=1=FAIL
; clobbers: X, Y, A
; -----------------------------------------------------------------------------
sd_init:
    debug #dbg_str_sd_init
    lda #(SPI_CS|SPI_SCK|SPI_MOSI)
    sta VIA2_DDRA                   ; via port A set up for SPI master mode

@sd_init_pulse:
    lda #(SPI_CS|SPI_MOSI)          ; do not assert CS during this phase.
    sta VIA2_PORTA
    ldx #$A0                        ; we will pulse the clock 80 times
@sd_init_pulse_lp:
    eor #(SPI_SCK)
    sta VIA2_PORTA
    dex
    bne @sd_init_pulse_lp

; Send CMD0.  If this does not make the card ready, go back to pulsing the
; clock.
@sd_cmd0:
    debug #dbg_str_sd_cmd0
    lda #<sd_cmd0_bytes
    sta zp_send_cmd_bytes
    lda #>sd_cmd0_bytes
    sta zp_send_cmd_bytes + 1
    jsr sd_sendcommand
    cmp #$01
    beq @sd_cmd8
    lda #100
    jsr _delay_ms
    jmp @sd_init_pulse_lp

@sd_cmd8:
    debug #dbg_str_sd_cmd8
    lda #<sd_cmd8_bytes
    sta zp_send_cmd_bytes
    lda #>sd_cmd8_bytes
    sta zp_send_cmd_bytes + 1
    jsr sd_sendcommand
    cmp #$01
    bne @sd_init_failed

    ; Read 32-bit return value, but ignore it
    jsr sd_readbyte
    jsr sd_readbyte
    jsr sd_readbyte
    jsr sd_readbyte

@sd_cmd55:                          ; prepare for command
    debug #dbg_str_sd_cmd55
    lda #<sd_cmd55_bytes
    sta zp_send_cmd_bytes
    lda #>sd_cmd55_bytes
    sta zp_send_cmd_bytes + 1
    jsr sd_sendcommand
    cmp #$01
    bne @sd_init_failed

@sd_cmd41:
    debug #dbg_str_sd_cmd41
    lda #<sd_cmd41_bytes
    sta zp_send_cmd_bytes
    lda #>sd_cmd41_bytes
    sta zp_send_cmd_bytes + 1
    jsr sd_sendcommand
    cmp #$00
    beq @sd_initialized             ; $00 means we are initialized
    cmp #$01                        
    bne @sd_init_failed             ; $01 means not initialized, try again
    lda #100
    jsr _delay_ms
    jmp @sd_cmd55                   ; delay and try again

@sd_init_failed:
    debug #dbg_str_sd_init_fail
    sec
    rts

@sd_initialized:
    debug #dbg_str_sd_init_ok
    clc
    rts

; -----------------------------------------------------------------------------
; Reads the a sector (512 bytes) of the sd card into buffer
; Inputs: zp_sd_address points at 2 page buffer in memory
;         zp_current_sector is set up with the sector to read.
; Outputs: C=0=OK, C=1=FAIL
; clobbers: X, Y, A
; -----------------------------------------------------------------------------
sd_readsector:
    jsr sd_readbyte
    debug #dbg_str_read_sector
    lda #(SPI_MOSI)             ; assert CS
    sta VIA2_PORTA
    jsr sd_readbyte
    ; Command 17, arg is sector number, crc not checked
    lda #$51                    ; CMD17 - READ_SINGLE_BLOCK
    jsr sd_writebyte
    lda zp_sd_currentsector+3   ; sector 24:31
.if DEBUG > 0
    jsr _tty_write_hex
.endif
    jsr sd_writebyte
    lda zp_sd_currentsector+2   ; sector 16:23
.if DEBUG > 0
    jsr _tty_write_hex
.endif
    jsr sd_writebyte
    lda zp_sd_currentsector+1   ; sector 8:15
.if DEBUG > 0
    jsr _tty_write_hex
.endif
    jsr sd_writebyte
    lda zp_sd_currentsector     ; sector 0:7
.if DEBUG > 0
    jsr _tty_write_hex
.endif
    jsr sd_writebyte
    lda #$01                    ; crc (not checked)
    jsr sd_writebyte

    jsr sd_waitresult
    cmp #$00
    bne @fail

    ; wait for data start token
    jsr sd_waitresult
    cmp #$fe
    bne @fail

    ; Need to read 512 bytes - two pages of 256 bytes each
    jsr @readpage
    inc zp_sd_address+1
    jsr @readpage
    dec zp_sd_address+1

    ; End command
    jsr sd_readbyte
    lda #(SPI_CS | SPI_MOSI)
    sta VIA2_PORTA
    jsr sd_readbyte
    jsr sd_readbyte
    debug #dbg_str_read_sec_ok
    clc
    rts

@readpage:
    ; Read 256 bytes to the address at zp_sd_address
    ldy #0
@readloop:
    jsr sd_readbyte
    sta (zp_sd_address),y
    iny
    bne @readloop
    rts
    
@fail:
    debug #dbg_str_read_sec_fail
    sec
    rts

; -----------------------------------------------------------------------------
; Send a command to the SD Card and wait for a non-$ff result.
; Inputs: CMD to send in zp_send_cmd_bytes ptr
; Outputs: result when not FF.
; clobbers: X, Y, A
; -----------------------------------------------------------------------------
sd_sendcommand:
    jsr sd_readbyte
    lda #(SPI_MOSI)
    sta VIA2_PORTA                  ; assert CS
    jsr sd_readbyte
    ldy #$00
    lda (zp_send_cmd_bytes),y       ; command b0
    jsr sd_writebyte
    ldy #$01
    lda (zp_send_cmd_bytes),y       ; data 1
    jsr sd_writebyte
    ldy #$02
    lda (zp_send_cmd_bytes),y       ; data 2
    jsr sd_writebyte
    ldy #$03
    lda (zp_send_cmd_bytes),y       ; data 3
    jsr sd_writebyte
    ldy #$04
    lda (zp_send_cmd_bytes),y       ; data 4
    jsr sd_writebyte
    ldy #$05
    lda (zp_send_cmd_bytes),y       ; crc
    jsr sd_writebyte
    
    jsr sd_waitresult

    pha                             ; save result to stack
    jsr sd_readbyte
    lda #(SPI_MOSI|SPI_CS)          ; deassert CS
    sta VIA2_PORTA
    jsr sd_readbyte
    jsr sd_readbyte
    pla                             ; fetch result from stack
    rts

; -----------------------------------------------------------------------------
; Wait for the SD card to return something other than $ff
; XXX - Hangs if sd card never returns a result.
; Inputs: None
; Outputs: result when not FF.
; clobbers: X, Y
; -----------------------------------------------------------------------------
sd_waitresult:
    jsr sd_readbyte
.if DEBUG > 1
    jsr _tty_write_hex
.endif
    cmp #$ff
    beq sd_waitresult
    rts

; -----------------------------------------------------------------------------
; Enable the card and tick the clock 8 times with MOSI high, 
; capturing bits from MISO and returning them.
; Inputs: None
; Outputs: byte received from SD card in A
; clobbers: X, Y
; -----------------------------------------------------------------------------
sd_readbyte:
    ldx #$fe    ; Preloaded with seven ones and a zero, so we stop after eight
                ; bits
@loop:
    lda #(SPI_MOSI)            ; enable card (CS low), set MOSI (resting state), SCK low
    sta VIA2_PORTA
    lda #(SPI_MOSI | SPI_SCK)  ; toggle the clock high
    sta VIA2_PORTA
    lda VIA2_PORTA             ; read next bit
    and #(SPI_MISO)
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
sd_writebyte:
    ldx #8                          ; send 8 bits
@loop:  
    asl                             ; shift next bit into carry
    tay                             ; save remaining bits for later
    lda #0  
    bcc @sendbit                    ; if carry clear, don't set MOSI for this bit
    ora #(SPI_MOSI) 
@sendbit:   
    sta VIA2_PORTA                  ; set MOSI (or not) first with SCK low
    eor #(SPI_SCK)  
    sta VIA2_PORTA                  ; raise SCK keeping MOSI the same, to send the bit
    tya                             ; restore remaining bits to send
    dex 
    bne @loop                       ; loop if there are more bits to send
    rts
