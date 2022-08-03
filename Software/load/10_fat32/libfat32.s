        .include "libsd.s"

        .export fat32_init
        .export fat32_list
        .export fat32_openfile
        .export fat32_readfile

.macro reset_sd_address
    lda #<fat32_readbuffer
    sta zp_sd_address
    lda #>fat32_readbuffer
    sta zp_sd_address+1
.endmacro

.macro print_sd_address
    lda zp_sd_address + 1
    jsr _tty_write_hex
    lda zp_sd_address
    jsr _tty_write_hex
    jsr _tty_send_newline
.endmacro

.macro print_current_sector
.if DEBUG > 0
    jsr _tty_send_newline
    write_tty #dbg_sd_current_sector

    lda zp_sd_currentsector + 3
    jsr _tty_write_hex
    lda zp_sd_currentsector + 2
    jsr _tty_write_hex
    lda zp_sd_currentsector + 1
    jsr _tty_write_hex
    lda zp_sd_currentsector + 0
    jsr _tty_write_hex
    jsr _tty_send_newline
.endif
.endmacro

        .rodata
str_error_header:           .asciiz "ERROR: 0x"
str_filename_sep:           .asciiz "  "
.if DEBUG > 0
dbg_sd_current_sector:      .asciiz "DBG: Current Sector is: 0x"
.endif

        .bss
fat32_errno:                .res 1
fat32_action:               .res 1
fat32_lba_begin:            .res 4
fat32_bytes_per_sec:        .res 2
fat32_sectors_per_cluster:  .res 1
fat32_reserved_sectors:     .res 2
fat32_number_of_fats:       .res 1
fat32_sectors_per_fat:      .res 4
fat32_data_begin:           .res 4
fat32_filesize:             .res 4

        .zeropage
fat32_filename_ptr:         .res 2

        .code
; -----------------------------------------------------------------------------
; Prepare fat32 environment, read MBR, find fat tables and start of data.
; SD Card must already be initialised.
; Inputs: None
; Outputs: C=0=OK, C=1=FAIL
; clobbers: X, Y, A
; -----------------------------------------------------------------------------
fat32_init:
    ; Read MBR
    lda #0
    sta zp_sd_currentsector
    sta zp_sd_currentsector+1
    sta zp_sd_currentsector+2
    sta zp_sd_currentsector+3

    reset_sd_address

    jsr sd_readsector

    ; some basic validation

    ; check mbr signature
    lda #$01
    sta fat32_errno

    lda fat32_readbuffer + $1fe
    cmp #$55
    bne @fail
    lda fat32_readbuffer + $1ff
    cmp #$aa
    bne @fail

    ; check partition type at offset 0x1c2
    lda #$02
    sta fat32_errno

    lda fat32_readbuffer + $1c2
    cmp #$0c
    bne @fail

    ; find root fat directory at offset 0x1c6
    lda fat32_readbuffer + $1c6
    sta zp_sd_currentsector
    lda fat32_readbuffer + $1c6 + 1
    sta zp_sd_currentsector     + 1
    lda fat32_readbuffer + $1c6 + 2
    sta zp_sd_currentsector     + 2
    lda fat32_readbuffer + $1c6 + 3
    sta zp_sd_currentsector     + 3
    jmp @load_volume_id

; I needed to put this fail step here so branches didn't cross page
; boundaries.
@fail:
    jmp fat32_error

@load_volume_id:
    ; load lba (volume id) replaces mbr in buffer
    reset_sd_address
    jsr sd_readsector

    ; check volumeid signature
    lda #$03
    sta fat32_errno

    lda fat32_readbuffer + $1fe
    cmp #$55
    bne @fail
    lda fat32_readbuffer + $1ff
    cmp #$aa
    bne @fail

    ; check bytes per sector
    lda #$04
    sta fat32_errno
    lda fat32_readbuffer + $0b
    bne @fail
    sta fat32_bytes_per_sec
    lda fat32_readbuffer + $0c
    cmp #$02
    bne @fail
    sta fat32_bytes_per_sec + 1

    ; save sectors per cluster
    lda fat32_readbuffer + $0d
    sta fat32_sectors_per_cluster

    ; save reserved sectors
    lda fat32_readbuffer + $0e
    sta fat32_reserved_sectors
    lda fat32_readbuffer + $0f
    sta fat32_reserved_sectors + 1

    ; check num fats - always 02 for fat32
    lda #$05
    sta fat32_errno
    lda fat32_readbuffer + $10
    cmp #$02
    bne @fail
    sta fat32_number_of_fats
    
    ; save sectors per fat.
    lda fat32_readbuffer + $24
    sta fat32_sectors_per_fat
    lda fat32_readbuffer + $24 + 1
    sta fat32_sectors_per_fat  + 1
    lda fat32_readbuffer + $24 + 2
    sta fat32_sectors_per_fat  + 2
    lda fat32_readbuffer + $24 + 3
    sta fat32_sectors_per_fat  + 3

@calculate_data_begin:
    ; calculate fat32 data begin
    ; start with the current sector (080000)
    ; add the number of reserved sectors
    ; then add number of sectors per fat once for 
    ; each of the number of fats.  (usually 2)
    print_current_sector
    clc
    lda zp_sd_currentsector
    adc fat32_reserved_sectors
    sta zp_sd_currentsector

    lda zp_sd_currentsector    + 1
    adc fat32_reserved_sectors + 1
    sta zp_sd_currentsector    + 1

    lda zp_sd_currentsector    + 2
    adc #0
    sta zp_sd_currentsector    + 2

    lda zp_sd_currentsector    + 3
    adc #0
    sta zp_sd_currentsector    + 3

    print_current_sector

    ldx fat32_number_of_fats
@fatsloop:
    clc
    lda zp_sd_currentsector
    adc fat32_sectors_per_fat
    sta zp_sd_currentsector
    sta fat32_data_begin

    lda zp_sd_currentsector   + 1
    adc fat32_sectors_per_fat + 1
    sta zp_sd_currentsector   + 1
    sta fat32_data_begin      + 1

    lda zp_sd_currentsector   + 2
    adc fat32_sectors_per_fat + 2
    sta zp_sd_currentsector   + 2
    sta fat32_data_begin      + 2

    lda zp_sd_currentsector   + 3
    adc fat32_sectors_per_fat + 3
    sta zp_sd_currentsector   + 3
    sta fat32_data_begin      + 3
    dex
    bne @fatsloop

    print_current_sector

    reset_sd_address
    jsr sd_readsector

    clc
    rts

; -----------------------------------------------------------------------------
; List all files found in an open directory depending on the fat32_action var
; it will either print the files or search for a file.
; Inputs:
; Outputs:
; clobbers: X, Y, A
; -----------------------------------------------------------------------------
fat32_list:
    jsr _tty_send_newline
    reset_sd_address

@list_next:
    clc
    lda zp_sd_address
    adc #$20
    sta zp_sd_address
    lda zp_sd_address + 1
    adc #$00
    sta zp_sd_address + 1
    
    cmp #>(fat32_readbuffer+$200)
    bcc @got_data
    jmp @list_done

@got_data:
    ldy #$00
    lda (zp_sd_address), y
    beq @list_done
    cmp #$e5
    beq @list_next
    cmp #$41
    beq @list_next
    lda fat32_action
    beq @do_pfn
; check if file is the one we are looking for
    jsr check_filename
    bcs @list_next                  ; The filename was not matched.
    rts
@do_pfn:
    jsr pfn
    jmp @list_next
    
@list_done:
    rts

; -----------------------------------------------------------------------------
; Prints the filename formatted with the extension.
; Inputs: zp_sd_address points at begining of direentry.
; Outputs:
; clobbers: X, A
; -----------------------------------------------------------------------------
pfn:
    phy
    ldy #$00
pfn_lp:
    lda (zp_sd_address), y
    jsr _tty_send_character
    iny
    cpy #$08
    beq @pfn_ext_gap
    cpy #$0b
    bne pfn_lp
    jmp @pfn_end
@pfn_ext_gap:
    write_tty #str_filename_sep
    jmp pfn_lp
@pfn_end:
    write_tty #str_filename_sep
    ldy #$1d
    lda (zp_sd_address),y
    tax
    ldy #$1c
    lda (zp_sd_address),y
    jsr _tty_write_dec
    ply
    jsr _tty_send_newline
    rts

; -----------------------------------------------------------------------------
; Check if current filaname matches the one we are looking for.
; Inputs: zp_sd_address points at begining of direentry.
; Outputs: C = 0 = Found, C = 1 = Not found.
; clobbers: X, A
; -----------------------------------------------------------------------------
check_filename:
    phy
    ldy #10
check_filename_lp:
    lda (fat32_filename_ptr), y
    cmp (zp_sd_address), y
    bne @not_found
    dey
    bpl check_filename_lp
    clc                             ; clear the carry to show that file was
    jmp @return                     ; found
@not_found:
    sec                             ; file not found
@return:
    ply
    rts

; -----------------------------------------------------------------------------
; Open a file.  Set currentsector to the sector contianing the data as defined
; by the direntry.
; Inputs: zp_sd_address is pointing at the direntry of the file to open
; Outputs: None
; clobbers: A, Y
; -----------------------------------------------------------------------------
fat32_openfile:
    ; get the 32bit cluster number
    jsr _tty_send_newline

    ; get filesize
    ldy #$1c
    lda (zp_sd_address),y
    sta fat32_filesize
    ldy #$1d
    lda (zp_sd_address),y
    sta fat32_filesize + 1
    ldy #$1e
    lda (zp_sd_address),y
    sta fat32_filesize + 2
    ldy #$1f
    lda (zp_sd_address),y
    sta fat32_filesize + 3
    
    ; get first sector of file
    ldy #$1a
    lda (zp_sd_address),y
    sta zp_sd_currentsector + 0
    ldy #$1b
    lda (zp_sd_address),y
    sta zp_sd_currentsector + 1
    ldy #$14
    lda (zp_sd_address),y
    sta zp_sd_currentsector + 2
    ldy #$15
    lda (zp_sd_address),y
    sta zp_sd_currentsector + 3
    
    print_current_sector

    ; reduce it by 2
    sec
    lda zp_sd_currentsector
    sbc #2
    sta zp_sd_currentsector
    lda zp_sd_currentsector + 1
    sbc #0
    sta zp_sd_currentsector + 1
    lda zp_sd_currentsector + 2
    sbc #0
    sta zp_sd_currentsector + 2
    lda zp_sd_currentsector + 3
    sbc #0
    sta zp_sd_currentsector + 3

    print_current_sector

    ; Multiply by sectors-per-cluster which is a power of two between 1 and 128
    ; I have just copied this code from gfoot.  I don't understand multiplication.
    lda fat32_sectors_per_cluster
@spcshiftloop:
    lsr
    bcs @spcshiftloopdone
    asl zp_sd_currentsector
    rol zp_sd_currentsector+1
    rol zp_sd_currentsector+2
    rol zp_sd_currentsector+3
    jmp @spcshiftloop
@spcshiftloopdone:

    print_current_sector

    ; Add start of data
    clc
    lda zp_sd_currentsector
    adc fat32_data_begin
    sta zp_sd_currentsector
    lda zp_sd_currentsector + 1
    adc fat32_data_begin    + 1
    sta zp_sd_currentsector + 1
    lda zp_sd_currentsector + 2
    adc fat32_data_begin    + 2
    sta zp_sd_currentsector + 2
    lda zp_sd_currentsector + 3
    adc fat32_data_begin    + 3
    sta zp_sd_currentsector + 3

    print_current_sector
    
    reset_sd_address
    jsr sd_readsector
    rts

; -----------------------------------------------------------------------------
; Read contents of open file.
; Inputs: fat32_readbuffer is already populated with first block of the file.
;         fat32_filesize is the total number of bytes to read.
;         This routine needs to read a block, then load the next block and read
;         that until fat32_filesyze is reduced to 0.
; Outputs: None
; clobbers: A, Y
; -----------------------------------------------------------------------------
fat32_readfile:

    reset_sd_address

    jsr @readpage
    inc zp_sd_address + 1
    jsr @readpage
    dec zp_sd_address

    ; reduce fat32_filesize by 0x200
    ; if less than 0, return
    ; else read next block
    sec
    lda fat32_filesize
    sbc #$00
    sta fat32_filesize
    lda fat32_filesize + 1
    sbc #$02
    sta fat32_filesize + 1
    lda fat32_filesize + 2
    sbc #$00
    sta fat32_filesize + 2
    lda fat32_filesize + 3
    sbc #$00
    sta fat32_filesize + 3

    bcs @load_next_block

    rts

@load_next_block:
    ; add 1 to the current sector
    ; read in the next block.

    print_current_sector

    clc
    lda zp_sd_currentsector
    adc #$01
    sta zp_sd_currentsector
    lda zp_sd_currentsector + 1
    adc #$00
    sta zp_sd_currentsector + 1
    lda zp_sd_currentsector + 2
    adc #$00
    sta zp_sd_currentsector + 2
    lda zp_sd_currentsector + 3
    adc #$00
    sta zp_sd_currentsector + 3

    reset_sd_address
    jsr sd_readsector

    jmp fat32_readfile

@readpage:
    ldy #$00
    ldx #$00
@readpage_lp:
    lda (zp_sd_address),y
    beq @done

    cmp #$0a
    beq @newline

    inx
    cpx #80
    beq @wrap

    jsr _tty_send_character
    iny
    bne @readpage_lp
@done:
    rts

@newline:
    jsr _tty_send_newline
    iny
    ldx #$00
    jmp @readpage_lp
@wrap:
    jsr _tty_send_newline
    iny
    ldx #$00
    jmp @readpage_lp


; -----------------------------------------------------------------------------
; Display current error
; set carry to indicate error.
; -----------------------------------------------------------------------------
fat32_error:
    jsr _tty_send_newline
    write_tty #str_error_header
    lda fat32_errno
    jsr _tty_write_hex
    jsr _tty_send_newline
    sec
    rts