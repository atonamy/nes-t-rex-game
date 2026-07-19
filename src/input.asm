; ---------------------------------------------------------------------------
; input.asm - NES joypad reading with press/release edges
; joy_cur bits: A B Sel Start Up Down Left Right (bit7..bit0)
; ---------------------------------------------------------------------------

.proc read_joypad
        lda joy_cur
        sta joy_prev

        lda #1
        sta JOY1
        lda #0
        sta JOY1
        ldx #8
@loop:
        lda JOY1
        lsr a               ; button bit -> carry
        rol joy_cur         ; carry -> bit0; after 8x: A=bit7 ... Right=bit0
        dex
        bne @loop

        ; press = cur & ~prev ; release = ~cur & prev
        lda joy_prev
        eor #$FF
        and joy_cur
        sta joy_press
        lda joy_cur
        eor #$FF
        and joy_prev
        sta joy_release
        rts
.endproc
