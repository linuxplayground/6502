DEBUG = 1

        .include "libfat32.inc"
        .include "libsd.inc"
        .include "tty.inc"
        .include "macros.inc"

        .rodata
file_to_open:       .asciiz "PRIME   BAS"
str_file_not_found: .asciiz "File not found."
str_file_found:     .asciiz "File found!"
str_printing_file:  .asciiz "Printing file contents."

        .code
        jmp main

main:
    jsr sd_init
    jsr fat32_init

    stz fat32_action                ; list not search
    jsr fat32_list                  ; Directory listing.

;     lda #<file_to_open
;     sta fat32_filename_ptr
;     lda #>file_to_open
;     sta fat32_filename_ptr + 1

;     lda #$01                        ; search, not list.
;     sta fat32_action

;     jsr fat32_list                  ; this will find a file and return C=0 if found
;     bcc open_file
;     write_tty #str_file_not_found

;     jsr _tty_send_newline
;     rts

; open_file:
;     write_tty #str_file_found
;     ; at this point zp_sd_address is pointing at the direntry of our file.
;     jsr fat32_openfile
;     jsr _tty_send_newline
;     writeln_tty #str_printing_file
;     ; now the buffer should have the file contents.
;     jsr fat32_readfile


    rts
