        .include "libfat32.inc"
        .include "libsd.inc"
        .include "tty.inc"
        .include "macros.inc"
        .include "menu.inc"
        .include "utils.inc"
        .include "string.inc"
        .include "parse.inc"

        .rodata
file_to_open:       .asciiz "PRIME   BAS"
str_file_not_found: .asciiz "File not found."
str_file_found:     .asciiz "File found!"
str_printing_file:  .asciiz "Printing file contents."
str_not_implimented:
                    .asciiz "Not implimented..."
prompt:             .asciiz "@ >"

menu:

        menuitem list_cmd, 0,  list_desc, process_list
        menuitem open_cmd, 11, open_desc, process_open
        menuitem read_cmd, 11, read_desc, process_read
        menuitem exec_cmd, 0,  exec_desc, process_exec
        endmenu 

list_cmd:           .asciiz "LIST"
list_desc:          .asciiz "LIST, displays list of files on sdcard"
open_cmd:           .asciiz "OPEN"
open_desc:          .asciiz "OPEN <filename>, opens file."
read_cmd:           .asciiz "READ"
read_desc:          .asciiz "READ <filename>, reads file to stdout."
exec_cmd:           .asciiz "EXEC"
exec_desc:          .asciiz "EXEC, runs whatever is in buffer after open."

        .bss
tokens_pointer:     .res 2
param_pointer:      .res 2

        .code
main:
    jsr sd_init
    jsr fat32_init
    jsr process_list
    ; run_menu #menu, #prompt
    rts

process_list:
    stz fat32_action                ; list not search
    jsr fat32_list                  ; Directory listing.
    rts

process_open:
    lda #<file_to_open
    sta fat32_filename_ptr
    lda #>file_to_open
    sta fat32_filename_ptr + 1

    lda #$01                        ; search, not list.
    sta fat32_action

    jsr fat32_list                  ; this will find a file and return C=0 if found
    bcc process_open
    write_tty #str_file_not_found

    jsr _tty_send_newline
    rts

    write_tty #str_file_found
    ; at this point zp_sd_address is pointing at the direntry of our file.
    jsr fat32_openfile
    jsr _tty_send_newline
    rts

process_read:
    writeln_tty #str_printing_file
    ; now the buffer should have the file contents.
    jsr fat32_readfile
    rts

process_exec:
    writeln_tty #str_not_implimented
    rts