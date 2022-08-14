        .include "libfat32.inc"
        .include "libsd.inc"
        .include "tty.inc"
        .include "macros.inc"
        .include "menu.inc"
        .include "utils.inc"
        .include "string.inc"
        .include "parse.inc"

        .rodata
str_file_not_found: .asciiz "File not found."
str_file_found:     .asciiz "File found!"
str_printing_file:  .asciiz "Printing file contents ..."
str_executing_file: .asciiz "Loading and executing ..."
str_not_implimented:
                    .asciiz "Not implimented..."
prompt:             .asciiz "@ >"

menu:

        menuitem list_cmd, 1,  list_desc, process_list
        menuitem type_cmd, 2,  type_desc, process_type
        menuitem run_cmd,  2,  run_desc,  process_run
        endmenu 

list_cmd:           .asciiz "LIST"
list_desc:          .asciiz "LIST, displays list of files on sdcard"
type_cmd:           .asciiz "TYPE"
type_desc:          .asciiz "TYPE <filename>, reads file to stdout."
run_cmd:            .asciiz "RUN"
run_desc:           .asciiz "RUN, <filename>, opens file, copies it to 0x2000 and jmps there."

        .bss
tokens_pointer:     .res 2
param_pointer:      .res 2
parsed_token_pointer: .res 2

        .code
main:
    jsr sd_init
    jsr process_list
    run_menu #menu, #prompt
    rts

process_list:
    jsr fat32_init
    stz fat32_action                ; list not search
    jsr fat32_list                  ; Directory listing.
    rts

_open:

    sta tokens_pointer
    stx tokens_pointer+1

    strgettoken tokens_pointer, 1
    copy_ptr ptr1, param_pointer

    lda param_pointer
    ldx 1+(param_pointer)

    sta parsed_token_pointer
    stx parsed_token_pointer+1

    ; Convert whole token uppercase for comparison
    strtoupper parsed_token_pointer

    ; open the file.
    lda #$01                        ; search not list
    sta fat32_action
    ; filename to search for is now parsed_token_pointer
    copy_ptr parsed_token_pointer, fat32_filename_ptr
    writeln_tty fat32_filename_ptr
    clc
    jsr fat32_list
    bcc @open_file
    writeln_tty #str_file_not_found
    rts
@open_file:
    writeln_tty #str_file_found
    jsr fat32_openfile
    jsr _tty_send_newline
    rts

process_type:
    writeln_tty #str_printing_file
    jsr _open        ; open the file
    ; now the buffer should have the file contents.
    jsr fat32_readfile
    rts

; move a single block of data starting at the filename
; over to the memory location $2000.  Only works for small files
; less than a block in size.
process_run:
    writeln_tty #str_executing_file
    jsr _open
    lda #$00
    sta ptr1
    lda #$20
    sta ptr1 + 1

    lda #$00
    sta ptr2
    lda #$6a
    sta ptr2+1

    ldy #$00
process_run_lp:
    lda (ptr2),y
    sta (ptr1),y
    iny
    bne process_run_lp
    inc ptr2+1 
    inc ptr1+1
    lda ptr1+1
    cmp #>$2200
    bne process_run_lp

    ; now that we have copied the block - go ahead and run it.
    jsr $2000
    rts
