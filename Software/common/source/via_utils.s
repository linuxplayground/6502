        .include "via_const.inc"
        .include "macros.inc"
        .include "zeropage.inc"

        .import __VIA2_START__
        .export via2_get_register
        .export _via2_get_register
        .export via2_set_register
        .export _via2_set_register

        .code

; NEGATIVE C COMPLIANT
via2_get_register:
        lda __VIA2_START__,X
        rts

; C version of the set register routine
_via2_get_register:
        tax
        lda __VIA2_START__,X
        rts

; NEGATIVE C COMPLIANT
via2_set_register:
        sta __VIA2_START__,X
        rts

; C version of the set register routine
_via2_set_register:
        pha
        lda (sp)
        tax
        pla
        sta __VIA2_START__,X
        inc_ptr sp
        rts