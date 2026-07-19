; ---------------------------------------------------------------------------
; ppu.asm - vram buffer, palettes, nametable construction
;
; VRAM buffer entry format:
;   byte0: len (1-31) | bit6: vertical-stripe (inc32) flag
;   byte1: PPU addr hi
;   byte2: PPU addr lo
;   bytes3..len+2: data
; ---------------------------------------------------------------------------

VRAM_STRIP = %01000000
VRAM_LEN_MASK = %00011111

; vram_begin: A=addr hi, X=addr lo. Returns Y = index for first data byte.
.proc vram_begin
        ldy vram_wptr
        iny
        sta vram_buf, y
        iny
        txa
        sta vram_buf, y
        iny
        rts
.endproc

; vram_end: Y = index past last data byte. Writes len, advances wptr.
.proc vram_end
        tya
        sec
        sbc vram_wptr
        sbc #3
        ldx vram_wptr
        sta vram_buf, x
        sty vram_wptr
        rts
.endproc

; vram_end_vert: same but marks vertical-stripe
.proc vram_end_vert
        tya
        sec
        sbc vram_wptr
        sbc #3
        ldx vram_wptr
        ora #VRAM_STRIP
        sta vram_buf, x
        sty vram_wptr
        rts
.endproc

; ---------------------------------------------------------------------------
; vram_flush - called from NMI; drains the buffer
; ---------------------------------------------------------------------------
.proc vram_flush
        ldx vram_rptr
@next:
        cpx vram_wptr
        beq @done
        lda vram_buf, x
        and #VRAM_STRIP
        beq @horiz
        lda ppuctrl_shadow
        ora #%00000100
        sta PPUCTRL
        jmp @addr
@horiz:
        lda ppuctrl_shadow
        sta PPUCTRL
@addr:
        lda vram_buf+1, x
        sta PPUADDR
        lda vram_buf+2, x
        sta PPUADDR
        lda vram_buf, x
        and #VRAM_LEN_MASK
        tay
        inx                     ; skip the 2 address bytes
        inx
@data:
        inx
        lda vram_buf, x
        sta PPUDATA
        dey
        bne @data
        inx
        jmp @next
@done:
        lda ppuctrl_shadow
        sta PPUCTRL
        stx vram_rptr
        lda vram_rptr
        cmp vram_wptr
        bne @keep
        lda #0
        sta vram_rptr
        sta vram_wptr
@keep:
        lda PPUSTATUS
        rts
.endproc

; ---------------------------------------------------------------------------
; load_palettes - day/night (called in NMI when pal_update set)
; ---------------------------------------------------------------------------
.proc load_palettes
        lda PPUSTATUS
        lda #$3F
        sta PPUADDR
        lda #$00
        sta PPUADDR
        ldx night_mode
        lda pal_table_lo, x
        sta temp_ptr
        lda pal_table_hi, x
        sta temp_ptr+1
        ldy #0
@loop:
        lda (temp_ptr), y
        sta PPUDATA
        iny
        cpy #32
        bne @loop
        rts
.endproc

; ---------------------------------------------------------------------------
; clear_nametables (rendering OFF)
; ---------------------------------------------------------------------------
.proc clear_nametables
        lda PPUSTATUS
        lda #$20
        sta PPUADDR
        lda #$00
        sta PPUADDR
        ldx #$08
        ldy #0
        lda #0
@loop:
        sta PPUDATA
        iny
        bne @loop
        dex
        bne @loop
        rts
.endproc

; ---------------------------------------------------------------------------
; draw_text_direct - write len-prefixed tile string to PPU (rendering OFF)
; A = addr hi, X = addr lo, temp_ptr = string ptr
; ---------------------------------------------------------------------------
.proc draw_text_direct
        sta PPUADDR
        stx PPUADDR
        ldy #0
        lda (temp_ptr), y
        sta tmpF
        iny
@loop:
        lda (temp_ptr), y
        sta PPUDATA
        iny
        dec tmpF
        bne @loop
        rts
.endproc

; ---------------------------------------------------------------------------
; build_title_screen (rendering OFF)
; ---------------------------------------------------------------------------
.proc build_title_screen
        jsr clear_nametables

        ; big "T-REX" logo: 5 letters x 2 tiles wide, rows 6-7, starting col 6
        ldx #0
@letters:
        txa
        pha
        asl a                   ; letter*2 = col offset
        sta tmpE
        txa
        asl a
        asl a                   ; letter*4 = tile quad offset
        tax
        lda logo_tiles, x
        sta tmpA
        lda logo_tiles+1, x
        sta tmpB
        lda logo_tiles+2, x
        sta tmpC
        lda logo_tiles+3, x
        sta tmpD
        ; top row $2146+off
        lda #$20
        sta PPUADDR
        lda #$A6
        clc
        adc tmpE
        sta PPUADDR
        lda tmpA
        sta PPUDATA
        lda tmpB
        sta PPUDATA
        ; bottom row $20C6+off
        lda #$20
        sta PPUADDR
        lda #$C6
        clc
        adc tmpE
        sta PPUADDR
        lda tmpC
        sta PPUDATA
        lda tmpD
        sta PPUDATA
        pla
        tax
        inx
        cpx #5
        bne @letters

        ; "RUNNER" row 9
        lda #<text_runner
        sta temp_ptr
        lda #>text_runner
        sta temp_ptr+1
        lda #$21
        ldx #$0D
        jsr draw_text_direct

        ; credit caption rows 10-13
        lda #<text_devby
        sta temp_ptr
        lda #>text_devby
        sta temp_ptr+1
        lda #$21
        ldx #$4A                ; row 10 col 10
        jsr draw_text_direct
        lda #<text_url1
        sta temp_ptr
        lda #>text_url1
        sta temp_ptr+1
        lda #$21
        ldx #$66                ; row 11 col 6
        jsr draw_text_direct
        lda #<text_url2
        sta temp_ptr
        lda #>text_url2
        sta temp_ptr+1
        lda #$21
        ldx #$85                ; row 12 col 5
        jsr draw_text_direct
        lda #<text_year
        sta temp_ptr
        lda #>text_year
        sta temp_ptr+1
        lda #$21
        ldx #$AE                ; row 13 col 14
        jsr draw_text_direct

        ; "PRESS START" row 16 (below the credit lines)
        lda #<text_press_start
        sta temp_ptr
        lda #>text_press_start
        sta temp_ptr+1
        lda #$22
        ldx #$0E
        jsr draw_text_direct

        ; subtitle row 18
        lda #<text_subtitle
        sta temp_ptr
        lda #>text_subtitle
        sta temp_ptr+1
        lda #$22
        ldx #$46
        jsr draw_text_direct

        ; ground rows 24-26
        lda PPUSTATUS
        lda #$23
        sta PPUADDR
        lda #$00
        sta PPUADDR
        ldx #32
@r24:
        lda #T_GROUND_A
        sta PPUDATA
        dex
        bne @r24
        ldx #32
@r25:
        txa
        and #1
        beq :+
        lda #T_DIRT_A
        jmp :++
:       lda #T_DIRT_B
:       sta PPUDATA
        dex
        bne @r25
        ldx #32
@r26:
        txa
        and #1
        beq :+
        lda #T_DIRT_B
        jmp :++
:       lda #T_DIRT_A
:       sta PPUDATA
        dex
        bne @r26

        ; sprite-0-hit bg marker at (col 31, row 2) - the NMI scroll split
        ; waits for the hit on every screen, so the title needs it too
        lda PPUSTATUS
        lda #$20
        sta PPUADDR
        lda #$5F
        sta PPUADDR
        lda #T_MARKER
        sta PPUDATA

        ; HI score row 2
        lda PPUSTATUS
        lda #$20
        sta PPUADDR
        lda #$4B
        sta PPUADDR
        lda #FONT_H
        sta PPUDATA
        lda #FONT_I
        sta PPUDATA
        lda #FONT_SP
        sta PPUDATA
        ldx #0
@d:
        lda hiscore, x
        tay
        lda digit_tiles, y
        sta PPUDATA
        inx
        cpx #5
        bne @d
        rts
.endproc
