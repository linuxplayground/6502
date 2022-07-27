; Taken from : https://github.com/gfoot/sdcard6502/

        .include "lcd.inc"
        .include "utils.inc"
        .include "macros.inc"


        .import __VIA2_START__
fat32_workspace         = $2000      ; two pages
buffer                  = $2400


VIA2_PORTA  = __VIA2_START__ + $1	
VIA2_DDRA   = __VIA2_START__ + $3 


SD_CS   = %00010000     ; CS
SD_SCK  = %00001000     ; SCK
SD_MOSI = %00000100     ; DI
SD_MISO = %00000010     ; DO

        .zeropage
zp_sd_cmd_address:      .res 1
zp_sd_counter:          .res 1
zp_buff_ptr:            .res 2

        .rodata
cmd0_bytes:
  .byte $40, $00, $00, $00, $00, $95
cmd8_bytes:
  .byte $48, $00, $00, $01, $aa, $87
cmd55_bytes:
  .byte $77, $00, $00, $00, $00, $01
cmd41_bytes:
  .byte $69, $40, $00, $00, $00, $01

        .code

main:
  lda #(SD_CS|SD_SCK|SD_MOSI)   ; Set various pins on port A to output
  sta VIA2_DDRA

  lda #<$2000
  sta zp_buff_ptr
  lda #>$2000
  sta zp_buff_ptr + 1

  jsr _lcd_init

  jsr sd_init


  ; Read a sector
  jsr _lcd_clear
  lda #'r'
  jsr _lcd_print_char
  lda #'s'
  jsr _lcd_print_char
  lda #':'
  jsr _lcd_print_char

  lda #(SD_MOSI)
  sta VIA2_PORTA

  ; Command 17, arg is sector number, crc not checked
  lda #$51           ; CMD17 - READ_SINGLE_BLOCK
  jsr sd_writebyte
  lda #$00           ; sector 24:31
  jsr sd_writebyte
  lda #$00           ; sector 16:23
  jsr sd_writebyte
  lda #$00           ; sector 8:15
  jsr sd_writebyte
  lda #$00           ; sector 0:7
  jsr sd_writebyte
  lda #$01           ; crc (not checked)
  jsr sd_writebyte

  jsr sd_waitresult
  cmp #$00
  beq readsuccess

  lda #'f'
  jsr _lcd_print_char
  rts

readsuccess:
  lda #'s'
  jsr _lcd_print_char
  lda #':'
  jsr _lcd_print_char

  ; wait for data
  jsr sd_waitresult
  cmp #$fe
  beq @readgotdata

  lda #'f'
  jsr _lcd_print_char
  rts

@readgotdata:
  ; Need to read 512 bytes.  Read two at a time, 256 times.
  lda #0
  sta zp_sd_counter ; counter
@readloop:
  jsr sd_readbyte
  sta (zp_buff_ptr)
  inc_ptr zp_buff_ptr
  jsr sd_readbyte
  sta (zp_buff_ptr)
  inc_ptr zp_buff_ptr
  dec zp_sd_counter ; counter
  bne @readloop

  ; End command
  lda #(SD_CS | SD_MOSI)
  sta VIA2_PORTA

  dec_ptr zp_buff_ptr
  dec_ptr zp_buff_ptr

  ; Print the last two bytes read, in hex
  lda (zp_buff_ptr)
  jsr _lcd_print_hex
  inc_ptr zp_buff_ptr
  lda (zp_buff_ptr)
  jsr _lcd_print_hex

exit:
  rts



sd_init:
  ; Let the SD card boot up, by pumping the clock with SD CS disabled

  ; We need to apply around 80 clock pulses with CS and MOSI high.
  ; Normally MOSI doesn't matter when CS is high, but the card is
  ; not yet is SPI mode, and in this non-SPI state it does care.

  lda #(SD_CS | SD_MOSI)
  ldx #160               ; toggle the clock 160 times, so 80 low-high transitions
@preinitloop:
  eor #(SD_SCK)
  sta VIA2_PORTA
  dex
  bne @preinitloop
  

cmd0: ; GO_IDLE_STATE - resets card to idle state, and SPI mode
  lda #<cmd0_bytes
  sta zp_sd_cmd_address
  lda #>cmd0_bytes
  sta zp_sd_cmd_address+1

  jsr sd_sendcommand

  ; Expect status response $01 (not initialized)
  cmp #$01
  bne initfailed

cmd8: ; SEND_IF_COND - tell the card how we want it to operate (3.3V, etc)
  lda #<cmd8_bytes
  sta zp_sd_cmd_address
  lda #>cmd8_bytes
  sta zp_sd_cmd_address+1

  jsr sd_sendcommand

  ; Expect status response $01 (not initialized)
  cmp #$01
  bne initfailed

  ; Read 32-bit return value, but ignore it
  jsr sd_readbyte
  jsr sd_readbyte
  jsr sd_readbyte
  jsr sd_readbyte

cmd55: ; APP_CMD - required prefix for ACMD commands
  lda #<cmd55_bytes
  sta zp_sd_cmd_address
  lda #>cmd55_bytes
  sta zp_sd_cmd_address+1

  jsr sd_sendcommand

  ; Expect status response $01 (not initialized)
  cmp #$01
  bne initfailed

cmd41: ; APP_SEND_OP_COND - send operating conditions, initialize card
  lda #<cmd41_bytes
  sta zp_sd_cmd_address
  lda #>cmd41_bytes
  sta zp_sd_cmd_address+1

  jsr sd_sendcommand

  ; Status response $00 means initialised
  cmp #$00
  beq initialized

  ; Otherwise expect status response $01 (not initialized)
  cmp #$01
  bne initfailed

  ; Not initialized yet, so wait a while then try again.
  ; This retry is important, to give the card time to initialize.
  jsr delay
  jmp cmd55


initialized:
  lda #'Y'
  jsr _lcd_print_char
  rts

initfailed:
  lda #'X'
  jsr _lcd_print_char
  rts


sd_readbyte:
  ; Enable the card and tick the clock 8 times with MOSI high, 
  ; capturing bits from MISO and returning them

  ldx #8                      ; we'll read 8 bits
@loop:

  lda #(SD_MOSI)                ; enable card (CS low), set MOSI (resting state), SCK low
  sta VIA2_PORTA

  lda #(SD_MOSI | SD_SCK)       ; toggle the clock high
  sta VIA2_PORTA

  lda VIA2_PORTA                   ; read next bit
  and #(SD_MISO)

  clc                         ; default to clearing the bottom bit
  beq @bitnotset              ; unless MISO was set
  sec                         ; in which case get ready to set the bottom bit
@bitnotset:

  tya                         ; transfer partial result from Y
  rol                         ; rotate carry bit into read result
  tay                         ; save partial result back to Y

  dex                         ; decrement counter
  bne @loop                   ; loop if we need to read more bits

  rts


sd_writebyte:
  ; Tick the clock 8 times with descending bits on MOSI
  ; SD communication is mostly half-duplex so we ignore anything it sends back here

  ldx #8                      ; send 8 bits

@loop:
  asl                         ; shift next bit into carry
  tay                         ; save remaining bits for later

  lda #0
  bcc @sendbit                ; if carry clear, don't set MOSI for this bit
  ora #(SD_MOSI)

@sendbit:
  sta VIA2_PORTA                   ; set MOSI (or not) first with SCK low
  eor #(SD_SCK)
  sta VIA2_PORTA                   ; raise SCK keeping MOSI the same, to send the bit

  tya                         ; restore remaining bits to send

  dex
  bne @loop                   ; loop if there are more bits to send

  rts


sd_waitresult:
  ; Wait for the SD card to return something other than $ff
  jsr sd_readbyte
  cmp #$ff
  beq sd_waitresult
  rts


sd_sendcommand:
  ; Debug print which command is being executed
  jsr _lcd_clear

  lda #'c'
  jsr _lcd_print_char
  ldx #0
  lda (zp_sd_cmd_address,x)
  jsr _lcd_print_hex

  lda #(SD_MOSI)           ; pull CS low to begin command
  sta VIA2_PORTA

  ldy #0
  lda (zp_sd_cmd_address),y    ; command byte
  jsr sd_writebyte
  ldy #1
  lda (zp_sd_cmd_address),y    ; data 1
  jsr sd_writebyte
  ldy #2
  lda (zp_sd_cmd_address),y    ; data 2
  jsr sd_writebyte
  ldy #3
  lda (zp_sd_cmd_address),y    ; data 3
  jsr sd_writebyte
  ldy #4
  lda (zp_sd_cmd_address),y    ; data 4
  jsr sd_writebyte
  ldy #5
  lda (zp_sd_cmd_address),y    ; crc
  jsr sd_writebyte

  jsr sd_waitresult
  pha

  ; Debug print the result code
  jsr _lcd_print_hex

  ; End command
  lda #(SD_CS | SD_MOSI)   ; set CS high again
  sta VIA2_PORTA

  pla   ; restore result code
  rts



_lcd_print_hex:
  pha
  ror
  ror
  ror
  ror
  jsr print_nybble
  pla
print_nybble:
  and #15
  cmp #10
  bmi @skipletter
  adc #6
@skipletter:
  adc #48
  jsr _lcd_print_char
  rts


delay:
  ldx #0
  ldy #0
@loop:
  dey
  bne @loop
  dex
  bne @loop
  rts

