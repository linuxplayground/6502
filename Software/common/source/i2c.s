      .setcpu "65C02"

      .include "via.inc"
      .include "zeropage.inc"

      .export i2c_start
      .export i2c_stop
      .export i2c_init
      .export i2c_send_ack
      .export i2c_send_nak
      .export i2c_read_ack
      .export i2c_clear
      .export i2c_send_byte
      .export i2c_read_byte
      .export i2c_send_addr
    
I2C_DATABIT       = %00000010
I2C_CLOCKBIT      = %00000001
I2C_DDR           = VIA2_DDRB
I2C_PORT          = VIA2_PORTB


;------------------------------------------------------------------------------
      .macro i2c_data_up
;------------------------------------------------------------------------------
; Destroys A
;------------------------------------------------------------------------------
        lda   #I2C_DATABIT  ; Clear data bit of the DDR
        trb   I2C_DDR       ; to make bit an input and let it float up.
      .endmacro


;------------------------------------------------------------------------------
      .macro i2c_data_down
;------------------------------------------------------------------------------
; Destroys A
;------------------------------------------------------------------------------
        lda   #I2C_DATABIT  ; Set data bit of the DDR
        tsb   I2C_DDR       ; to make bit an output and pull it down.
      .endmacro


;------------------------------------------------------------------------------
      .macro i2c_clock_up
;------------------------------------------------------------------------------
; Destroys A
;------------------------------------------------------------------------------
        lda   #I2C_CLOCKBIT
        trb   I2C_DDR
      .endmacro


;------------------------------------------------------------------------------
      .macro i2c_clock_down
;------------------------------------------------------------------------------
; Destroys A
;------------------------------------------------------------------------------
        lda   #I2C_CLOCKBIT
        tsb   I2C_DDR
      .endmacro


;------------------------------------------------------------------------------
    .macro i2c_clock_pulse
;------------------------------------------------------------------------------
; Destroys A
;------------------------------------------------------------------------------
        lda   #I2C_CLOCKBIT
        trb   I2C_DDR           ; Clock up
        tsb   I2C_DDR           ; Clock down
    .endmacro


;------------------------------------------------------------------------------
i2c_start:
;------------------------------------------------------------------------------
; Destroys A
;------------------------------------------------------------------------------
    i2c_data_up
    i2c_clock_up
    i2c_data_down
    i2c_clock_down
    i2c_data_up
    rts


;------------------------------------------------------------------------------
i2c_stop:
;------------------------------------------------------------------------------
; Destroys A
;------------------------------------------------------------------------------
    i2c_data_down
    i2c_clock_up
    i2c_data_up
    i2c_clock_down
    i2c_data_up
    rts


;------------------------------------------------------------------------------
i2c_send_ack:
;------------------------------------------------------------------------------
; Destroys A
;------------------------------------------------------------------------------
    i2c_data_down       ; Acknowledge.  The ACK bit in I2C is the 9th bit of a "byte".
    i2c_clock_pulse     ; Trigger the clock
    i2c_data_up         ; End with data up
    rts


;------------------------------------------------------------------------------
i2c_send_nak:
;------------------------------------------------------------------------------
; Destroys A
;------------------------------------------------------------------------------
    i2c_data_up         ; Acknowledging consists of pulling it down.
    i2c_clock_pulse     ; Trigger the clock
    i2c_data_up
    rts


;------------------------------------------------------------------------------
i2c_read_ack:
;------------------------------------------------------------------------------
; Ack in carry flag (clear means ack, set means nak)
; Destroys A
;------------------------------------------------------------------------------
    i2c_data_up         ; Input
    i2c_clock_up        ; Clock up
    clc                 ; Clear the carry
    lda I2C_PORT        ; Load data from the port
    and #I2C_DATABIT    ; Test the data bit
    beq @skip           ; If zero skip
        sec             ; Set carry if not zero
@skip:
    i2c_clock_down      ; Bring the clock down
    rts


;------------------------------------------------------------------------------
i2c_init:
;------------------------------------------------------------------------------
; Destroys A
;------------------------------------------------------------------------------
    lda #(I2C_CLOCKBIT | I2C_DATABIT) 
    tsb I2C_DDR
    trb I2C_PORT
    rts


;------------------------------------------------------------------------------
i2c_clear:
;------------------------------------------------------------------------------
; This clears any unwanted transaction that might be in progress, by giving 
; enough clock pulses to finish a byte and not acknowledging it.
; Destroys  A 
;------------------------------------------------------------------------------
    phx                     ; Save X
    jsr i2c_start
    jsr i2c_stop
    i2c_data_up             ; Keep data line released so we don't ACK any byte sent by a device.
    ldx #9                  ; Loop 9x to send 9 clock pulses to finish any byte a device might send.
    lda #I2C_CLOCKBIT
@do:
        trb I2C_DDR         ; Clock up
        tsb I2C_DDR         ; Clock down
        dex
        bne @do
    plx                     ; Restore X
    jsr i2c_start
    jmp i2c_stop            ; (JSR, RTS)


;------------------------------------------------------------------------------
i2c_send_byte:
;------------------------------------------------------------------------------
; Sends the byte in A
; Destroys A
;------------------------------------------------------------------------------
    stx tmp1                ; Save X
    sta tmp2                ; Save to variable
    ldx #8                  ; We will do 8 bits.
@loop:
        lda #I2C_DATABIT    ; Init A for mask for TRB & TSB below.    
        trb I2C_DDR         ; Release data line.  This is like i2c_data_up but saves 1 instruction.
        asl tmp2            ; Get next bit to send and put it in the C flag.
        bcs @continue
            tsb I2C_DDR     ; If the bit was 0, pull data line down by making it an output.
@continue:
        
        i2c_clock_pulse     ; Pulse the clock
        dex
    bne @loop  
    ldx tmp1                ; Restore variables
    jmp i2c_read_ack         ; Put ack in Carry


;------------------------------------------------------------------------------
i2c_read_byte:
;------------------------------------------------------------------------------
; Start with clock low.  Ends with byte in A.  Do ACK separately.
;------------------------------------------------------------------------------
    stx tmp1                ; Save X
    sta tmp2                ; Define local zeropage variable

    i2c_data_up             ; Make sure we're not holding the data line down.  Be ready to input data.
    ldx #8                  ; We will do 8 bits.  
    lda #I2C_CLOCKBIT       ; Load the clock bit in for initial loop
    stz tmp2                ; Clear data
    clc                     ; Clear the carry flag
@loop:
        trb I2C_DDR         ; Clock up
        nop                 ; Delay for a few clock cycles
        nop
        nop
        nop
        lda I2C_PORT        ; Load PORTA
        
        and #I2C_DATABIT    ; Mask off the databit
        beq @skip           ; If zero, skip
            sec             ; Set carry flag
@skip:
        rol tmp2            ; Rotate the carry bit into value / carry cleared by rotated out bit
        lda #I2C_CLOCKBIT   ; Load the clock bit in
        tsb I2C_DDR         ; Clock down
        nop                 ; Delay for a few clock cycles
        nop
        nop
        nop
        dex
    bne @loop               ; Go back for next bit if there is one.

    lda tmp2                ; Load A from local
    ldx tmp1                ; Restore variables
    rts


;------------------------------------------------------------------------------
i2c_send_addr:
;------------------------------------------------------------------------------
; Address in A, carry flag contains read/write flag (read = 1, write 0)
; Return ack in Carry
;------------------------------------------------------------------------------
    rol A                   ; Rotates address 1 bit and puts read/write flag in A
    jmp i2c_send_byte        ; Sends address and returns