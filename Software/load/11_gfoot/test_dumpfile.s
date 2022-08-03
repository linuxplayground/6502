    .zeropage
zp_sd_address:        .res 2
zp_sd_currentsector:  .res 4

  .code

fat32_workspace     = $2000       ; two pages
buffer              = $2400

  jmp reset

  .include "hwconfig.s"
  .include "libsd.s"
  .include "libfat32.s"
  .include "tty.inc"

subdirname:
  .asciiz "SUBFLDR    "
filename:
  .asciiz "LOREM10KTXT"

reset:

  ; Initialise
  jsr via_init
  jsr sd_init
  jsr fat32_init
  bcc @initsuccess
 
  ; Error during FAT32 initialization
  lda #'Z'
  jsr _tty_send_character
  lda fat32_errorstage
  jsr _tty_write_hex
  jmp loop

@initsuccess:

  ; Open root directory
  jsr fat32_openroot

;   ; Find subdirectory by name
;   ldx #<subdirname
;   ldy #>subdirname
;   jsr fat32_finddirent
;   bcc @foundsubdir

;   ; Subdirectory not found
;   lda #'X'
;   jsr _tty_send_character
;   jmp loop

; @foundsubdir:

;   ; Open subdirectory
;   jsr fat32_opendirent

;   ; First I want to list all the files in this directory.

;   clc
; @list_lp:
;   jsr fat32_readdirent
;   bcs @open_file      ; done listing carry on with demo.
;   jsr pfn
;   jmp @list_lp

;   jsr fat32_opendirent

@open_file:
  ; Find file by name
  ldx #<filename
  ldy #>filename
  jsr fat32_finddirent
  bcc @foundfile

  ; File not found
  lda #'Y'
  jsr _tty_send_character
  jmp loop

@foundfile:
 
  ; Open file
  jsr fat32_opendirent

  ; Read file contents into buffer
  lda #<buffer
  sta fat32_address
  lda #>buffer
  sta fat32_address+1

  jsr fat32_file_read

  jsr _tty_send_newline
  ldy #0
@printloop:
  lda buffer,y
  
  cmp #$0a    ; have we reached end of file.
  beq loop

  jsr _tty_send_character

  iny

  cpy #80
  bne @not16
  jsr _tty_send_newline
@not16:
  bne @printloop


  ; loop forever
loop:
  jsr _tty_send_newline
  rts

pfn:
  ldy #0
  jsr _tty_send_newline
@pfn_lp:
  lda (zp_sd_address), y
  jsr _tty_send_character
  iny
  cpy #$0b
  bne @pfn_lp
  rts