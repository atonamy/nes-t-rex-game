; ---------------------------------------------------------------------------
; render.asm - OAM composition, score display, UI panels
;
; OAM layout (8x16 sprites):
;   0-5   dino (stand/run/jump/dead: 6; duck: 4 -> 2 hidden)
;   6-8   ptero slot A
;   9-11  ptero slot B
;   12-23 clouds (4 x 3)
;   rest  hidden
; ---------------------------------------------------------------------------

; sprite tile numbers are "pair index | 1" (bit0 selects pattern table 1)

; ---------------------------------------------------------------------------
; oam_compose - build full OAM for gameplay
; ---------------------------------------------------------------------------
.proc oam_compose
        jsr oam_clear_all
        jsr oam_split_marker
        jsr oam_dino
        jsr oam_pteros
        jsr oam_clouds
        jsr oam_night
        rts
.endproc

; ---------------------------------------------------------------------------
; oam_night - stationary moon + twinkling stars (OAM 26-29, palette 2).
; Drawn after the clouds so clouds pass in FRONT of the moon.
; ---------------------------------------------------------------------------
.proc oam_night
        lda night_mode
        bne :+
        rts
:
        ldx #26*4
        ; moon: two 8x16 sprites side by side
        lda moon_y
        sec
        sbc #1
        sta oam_shadow, x
        sta oam_shadow+4, x
        lda #S_MOON_0
        ora #1
        sta oam_shadow+1, x
        lda #S_MOON_1
        ora #1
        sta oam_shadow+5, x
        lda #%00000010
        sta oam_shadow+2, x
        sta oam_shadow+6, x
        lda moon_x
        sta oam_shadow+3, x
        clc
        adc #8
        sta oam_shadow+7, x
        ; stars: gentle twinkle, opposite phases (frame16 bit 5)
        lda star1_y
        sec
        sbc #1
        sta oam_shadow+8, x
        lda star2_y
        sec
        sbc #1
        sta oam_shadow+12, x
        lda frame16
        and #%00100000
        beq @phase_b
        lda #S_STAR_SPR_A
        sta tmpA
        lda #S_STAR_SPR_B
        sta tmpB
        jmp @tiles
@phase_b:
        lda #S_STAR_SPR_B
        sta tmpA
        lda #S_STAR_SPR_A
        sta tmpB
@tiles:
        lda tmpA
        ora #1
        sta oam_shadow+9, x
        lda tmpB
        ora #1
        sta oam_shadow+13, x
        lda #%00000010
        sta oam_shadow+10, x
        sta oam_shadow+14, x
        lda star1_x
        sta oam_shadow+11, x
        lda star2_x
        sta oam_shadow+15, x
        rts
.endproc

; sprite 0 = scroll-split marker at (248, 8), behind-bg priority, palette 3
.proc oam_split_marker
        lda #9                  ; top=10 -> OAM y = 9 (opaque px at scanline 16)
        sta oam_shadow
        lda #S_MARK
        ora #1
        sta oam_shadow+1
        lda #%00100011          ; behind bg, palette 3
        sta oam_shadow+2
        lda #248
        sta oam_shadow+3
        rts
.endproc

.proc oam_clear_all
        ldx #0
        lda #$FF
@l:     sta oam_shadow, x
        inx
        bne @l
        rts
.endproc

; ---------------------------------------------------------------------------
; dino_nes_y - compute dino top scanline -> A
; nes_top = 167 - ((93 - y_world) * 174 >> 8)
; ---------------------------------------------------------------------------
.proc dino_nes_y
        lda #<(WORLD_GROUND_TOP << 8)
        sec
        sbc dino_y88
        lda #>(WORLD_GROUND_TOP << 8)
        sbc dino_y88+1          ; A = 93 - y_world (world px above ground)
        bpl :+
        lda #0
:       tax
        lda mult174_hi, x       ; dy * 174 >> 8
        sta tmpA
        lda #DINO_RUN_TOP
        sec
        sbc tmpA
        rts
.endproc

; ---------------------------------------------------------------------------
; oam_dino - write dino sprites (OAM 0-5)
; ---------------------------------------------------------------------------
.proc oam_dino
        ; select pose tile list
        lda dino_flags
        and #%00010000
        bne @dead
        lda dino_flags
        and #2
        bne @duck
        lda dino_flags
        and #1
        bne @stand              ; jumping = stand pose
        lda dino_anim_frm
        beq @runa
        lda #<dino_runb_tiles
        sta temp_ptr
        lda #>dino_runb_tiles
        sta temp_ptr+1
        jmp @place_run
@runa:
        lda #<dino_runa_tiles
        sta temp_ptr
        lda #>dino_runa_tiles
        sta temp_ptr+1
        jmp @place_run
@stand:
        lda #<dino_stand_tiles
        sta temp_ptr
        lda #>dino_stand_tiles
        sta temp_ptr+1
        jmp @place_run
@dead:
        lda #<dino_dead_tiles
        sta temp_ptr
        lda #>dino_dead_tiles
        sta temp_ptr+1
@place_run:
        jsr dino_nes_y
        sta tmpA                ; top y
        ldx #4                  ; oam byte offset (after split marker)
        ldy #0                  ; tile index
@loop:
        tya
        cmp #3
        bcc @row0
        lda tmpA
        clc
        adc #16
        jmp @sety
@row0:
        lda tmpA
@sety:
        sec
        sbc #1
        sta oam_shadow, x
        lda (temp_ptr), y
        ora #1
        sta oam_shadow+1, x
        lda #0
        sta oam_shadow+2, x
        tya
        sec
@s3:    cmp #3
        bcc @x_ok
        sbc #3
        jmp @s3
@x_ok:
        asl a
        asl a
        asl a
        clc
        adc dino_draw_x
        sta oam_shadow+3, x
        inx
        inx
        inx
        inx
        iny
        cpy #6
        bne @loop
        rts

@duck:
        lda dino_anim_frm
        beq @da
        lda #<dino_duckb_tiles
        sta temp_ptr
        lda #>dino_duckb_tiles
        sta temp_ptr+1
        jmp @dplace
@da:
        lda #<dino_ducka_tiles
        sta temp_ptr
        lda #>dino_ducka_tiles
        sta temp_ptr+1
@dplace:
        ldx #4
        ldy #0
@dloop:
        lda #DINO_DUCK_TOP - 1
        sta oam_shadow, x
        lda (temp_ptr), y
        ora #1
        sta oam_shadow+1, x
        lda #0
        sta oam_shadow+2, x
        tya
        asl a
        asl a
        asl a
        clc
        adc dino_draw_x
        sta oam_shadow+3, x
        inx
        inx
        inx
        inx
        iny
        cpy #4
        bne @dloop
        rts
.endproc

; ---------------------------------------------------------------------------
; oam_pteros - pterodactyl sprites (OAM 6-11)
; ---------------------------------------------------------------------------
.proc oam_pteros
        lda #7
        sta tmpF                ; oam slot (7 or 10)
        lda #0
        sta ob_iter             ; obstacle slot offset
@loop:
        ldx ob_iter
        cpx #OB_STRIDE * OB_SLOTS
        bcc @scan
        jmp @done
@scan:
        lda obstacles + OBTYPE, x
        cmp #OB_PTERO
        beq @is_ptero
        jmp @next
@is_ptero:
        lda obstacles + OBX_HI, x
        bpl @alive              ; dying (x<0): removed this frame, don't draw
        jmp @next
@alive:
        ; screen x -> tmpD
        jsr ob_screen_x         ; -> tmpE (saturates at 255 off-screen right)
        lda tmpE
        cmp #253
        bcc @visible            ; still entering from the right: skip drawing
        jmp @next
@visible:
        sta tmpD
        ; y: anchor the 16px art on the collision boxes (rel y 8..27), not the
        ; bottom of the 40px world box - otherwise the hitbox floats ~7px above
        ; the drawn bird and deaths look like they happened in empty air.
        ; nes_top = screen(wy+8) - 2 = 197 - ((140 - (wy+8)) * 174 >> 8)
        ldx ob_iter
        lda obstacles + OBY, x
        clc
        adc #8
        sta tmpB
        lda #140
        sec
        sbc tmpB
        tax
        lda mult174_hi, x
        sta tmpB
        lda #197
        sec
        sbc tmpB
        sta tmpC                ; top y
        ; frame: OBANIM bit6
        ldx ob_iter
        lda obstacles + OBANIM, x
        and #$40
        beq @fa
        lda #<ptero_b_tiles
        sta temp_ptr
        lda #>ptero_b_tiles
        sta temp_ptr+1
        jmp @fr
@fa:
        lda #<ptero_a_tiles
        sta temp_ptr
        lda #>ptero_a_tiles
        sta temp_ptr+1
@fr:
        lda tmpF
        asl a
        asl a
        tax                     ; oam byte offset
        ldy #0
@sloop:
        ; part x first: a bird entering at the right edge must CLIP the
        ; parts that would wrap past 255 - they used to reappear at the
        ; left edge as a brief ghost in front of the dino
        tya
        asl a
        asl a
        asl a
        clc
        adc tmpD
        bcs @part_clip          ; wrapped: leave this sprite hidden
        sta oam_shadow+3, x
        lda tmpC
        sec
        sbc #1
        sta oam_shadow, x
        lda (temp_ptr), y
        ora #1
        sta oam_shadow+1, x
        lda #0
        sta oam_shadow+2, x
@part_clip:
        inx
        inx
        inx
        inx
        iny
        cpy #3
        bne @sloop
        lda tmpF
        clc
        adc #3
        sta tmpF
        cmp #13
        bcs @done               ; max 2 pteros drawn
@next:
        lda ob_iter
        clc
        adc #OB_STRIDE
        sta ob_iter
        jmp @loop
@done:
        rts
.endproc

; ---------------------------------------------------------------------------
; oam_clouds - OAM 12-23 (4 clouds x 3 sprites)
; ---------------------------------------------------------------------------
.proc oam_clouds
        lda #0
        sta tmpE                ; cloud slot offset
        lda #13
        sta tmpF                ; oam slot
@loop:
        ldx tmpE
        cpx #CL_STRIDE * CLOUD_MAX
        bcs @done
        lda clouds + CLY, x
        cmp #$FF
        beq @next
        ; CLY bit7 = "leaving" marker (x has gone negative); low 7 bits = y
        lda #0
        sta tmpC
        lda clouds + CLY, x
        bpl :+
        inc tmpC                ; tmpC=1: x decodes as negative
:       lda clouds + CLY, x
        and #$7F
        sec
        sbc #1
        sta tmpA
        ; x = integer byte of the 8.8 position
        lda clouds + CLX_HI, x
        sta tmpB
        ; write 3 sprites; part visible iff add-carry matches the base sign
        ; (positive base: carry means wrapped past 255 -> hide;
        ;  negative base: carry means crossed into >=0 -> show)
        lda tmpF
        asl a
        asl a
        tax
        ldy #0
@sloop:
        tya
        asl a
        asl a
        asl a
        clc
        adc tmpB
        sta tmpD                ; part x
        lda #0
        rol a                   ; A = carry
        eor tmpC
        bne @clip
        lda tmpD
        sta oam_shadow+3, x
        lda tmpA
        sta oam_shadow, x
        lda cloud_tiles, y
        ora #1
        sta oam_shadow+1, x
        lda #1                  ; palette 1
        sta oam_shadow+2, x
@clip:
        inx
        inx
        inx
        inx
        iny
        cpy #3
        bne @sloop
@next:
        lda tmpE
        clc
        adc #CL_STRIDE
        sta tmpE
        lda tmpF
        clc
        adc #3
        sta tmpF
        jmp @loop
@done:
        rts
.endproc

; ---------------------------------------------------------------------------
; oam_title_dino - static standing dino on title screen
; ---------------------------------------------------------------------------
.proc oam_title_dino
        jsr oam_clear_all
        jsr oam_split_marker
        ; blink: use blink tiles when blink_state active
        lda blink_state
        beq @open
        lda #<dino_blink_tiles
        sta temp_ptr
        lda #>dino_blink_tiles
        sta temp_ptr+1
        jmp @go
@open:
        lda #<dino_stand_tiles
        sta temp_ptr
        lda #>dino_stand_tiles
        sta temp_ptr+1
@go:
        lda #DINO_RUN_TOP
        sta tmpA
        ldx #4
        ldy #0
@loop:
        tya
        cmp #3
        bcc @r0
        lda tmpA
        clc
        adc #16
        jmp @sy
@r0:    lda tmpA
@sy:
        sec
        sbc #1
        sta oam_shadow, x
        lda (temp_ptr), y
        ora #1
        sta oam_shadow+1, x
        lda #0
        sta oam_shadow+2, x
        tya
@s3:    cmp #3
        bcc @xok
        sbc #3
        jmp @s3
@xok:
        asl a
        asl a
        asl a
        clc
        adc dino_draw_x
        sta oam_shadow+3, x
        inx
        inx
        inx
        inx
        iny
        cpy #6
        bne @loop
        rts
.endproc

; ---------------------------------------------------------------------------
; oam_compose_dead - game over screen: dino in dead pose (dino_flags bit4
; selects the tiles) PLUS the frozen pteros/clouds. Dropping the ptero here
; would erase the obstacle that killed the player from the crash screen.
; ---------------------------------------------------------------------------
.proc oam_compose_dead
        jsr oam_clear_all
        jsr oam_split_marker
        jsr oam_dino
        jsr oam_pteros
        jsr oam_clouds
        jsr oam_night
        rts
.endproc

; ---------------------------------------------------------------------------
; update_score_display - buffer changed score digits (row 1)
; layout: col 18:H 19:I 21-25:HI 27-31:score
; ---------------------------------------------------------------------------
.proc update_score_display
        ; achievement flash: blink score
        lda score_flash
        beq @normal
        dec score_flash
        lda score_flash
        and #7
        cmp #4
        bcc @show
        ; hide score
        lda #$20
        ldx #$3B
        jsr vram_begin
        ldx #5
        lda #FONT_SP
@h:     sta vram_buf, y
        iny
        dex
        bne @h
        jsr vram_end
        rts
@show:
        jsr @write_score
        rts
@normal:
        ; only write when changed
        lda score_changed
        beq @maybe_hi
        jsr @write_score
        lda #0
        sta score_changed
@maybe_hi:
        lda hiscore_dirty
        beq @done
        jsr @write_hi
        lda #0
        sta hiscore_dirty
@done:
        rts
@write_score:
        lda #$20
        ldx #$37                ; row 1 col 23
        jsr vram_begin
        ldx #0
@d:     lda score, x
        sty tmpF
        tay
        lda digit_tiles, y
        ldy tmpF
        sta vram_buf, y
        iny
        inx
        cpx #5
        bne @d
        jsr vram_end
        rts
@write_hi:
        lda #$20
        ldx #$31                ; row 1 col 17
        jsr vram_begin
        ldx #0
@dh:    lda hiscore, x
        sty tmpF
        tay
        lda digit_tiles, y
        ldy tmpF
        sta vram_buf, y
        iny
        inx
        cpx #5
        bne @dh
        jsr vram_end
        rts
.endproc

; ---------------------------------------------------------------------------
; UI panels
; ---------------------------------------------------------------------------
; The playfield is scrolled, so a panel's nametable columns depend on the
; current scroll. PPU address increments never hop nametables: a horizontal
; run that reaches column 31 wraps to the next row of the SAME nametable.
; panel_write therefore splits a run at the 32-column seam and continues at
; column 0 of the other nametable.
;
; panel_text: A=row, X=screen col, temp_ptr -> len-prefixed tile string
; panel_fill: A=row, X=screen col, Y=len; writes FONT_SP (erase)
.proc panel_text
        ldy #1
        sty p_mode
        jmp panel_write
.endproc

.proc panel_fill
        sty p_len
        ldy #0
        sty p_mode
        jmp panel_write
.endproc

.proc panel_write
        sta p_row
        stx p_col
        lda p_mode
        beq @have_len
        ldy #0
        lda (temp_ptr), y
        sta p_len
@have_len:
        lda #1
        sta p_idx
        ; absolute column = (scroll_x>>3) + nt*32 + screen col, mod 64
        lda scroll_x
        lsr a
        lsr a
        lsr a
        sta p_abs
        lda scroll_nt
        and #1
        beq @nt0
        lda p_abs
        clc
        adc #32
        sta p_abs
@nt0:
        lda p_abs
        clc
        adc p_col
        and #63
        sta p_abs
        jsr @set_addr
@chunk:
        lda p_hi
        ldx p_lo
        jsr vram_begin
@emit:
        lda p_mode
        beq @fill
        sty p_vy
        ldy p_idx
        lda (temp_ptr), y
        inc p_idx
        ldy p_vy
        jmp @put
@fill:
        lda #FONT_SP
@put:
        sta vram_buf, y
        iny
        dec p_len
        beq @done
        dec p_seam
        bne @emit
        ; reached the seam: flush this run, continue at col 0 of the other NT
        jsr vram_end
        lda p_abs
        eor #32
        and #32
        sta p_abs
        jsr @set_addr
        jmp @chunk
@done:
        jsr vram_end
        rts

; @set_addr: p_abs/p_row -> p_hi/p_lo, p_seam = cols until seam
@set_addr:
        lda p_abs
        and #31
        sta p_lo                ; col within nametable
        lda #32
        sec
        sbc p_lo
        sta p_seam
        lda p_row
        asl a
        asl a
        asl a
        asl a
        asl a
        ora p_lo                ; col fits in low 5 bits - no carry
        sta p_lo
        lda p_row
        lsr a
        lsr a
        lsr a
        clc
        adc #$20
        ldx p_abs
        cpx #32
        bcc :+
        clc
        adc #$04                ; NT1 base is +$400
:       sta p_hi
        rts
.endproc

; write "PAUSED" centered (row 12, screen col 13)
.proc show_paused
        lda #<text_paused
        sta temp_ptr
        lda #>text_paused
        sta temp_ptr+1
        lda #12
        ldx #13
        jmp panel_text
.endproc

.proc hide_paused
        ldy #6
        lda #12
        ldx #13
        jmp panel_fill
.endproc

.proc show_game_over
        ; "G A M E   O V E R" spaced (16 tiles), centered (row 11, col 7)
        lda #<text_gameover
        sta temp_ptr
        lda #>text_gameover
        sta temp_ptr+1
        lda #11
        ldx #7
        jsr panel_text
        ; restart icon 5x4 (rows 13-16, col 13: centered under the text)
        lda #<text_restart_r0
        sta temp_ptr
        lda #>text_restart_r0
        sta temp_ptr+1
        lda #13
        ldx #13
        jsr panel_text
        lda #<text_restart_r1
        sta temp_ptr
        lda #>text_restart_r1
        sta temp_ptr+1
        lda #14
        ldx #13
        jsr panel_text
        lda #<text_restart_r2
        sta temp_ptr
        lda #>text_restart_r2
        sta temp_ptr+1
        lda #15
        ldx #13
        jsr panel_text
        lda #<text_restart_r3
        sta temp_ptr
        lda #>text_restart_r3
        sta temp_ptr+1
        lda #16
        ldx #13
        jmp panel_text
.endproc

.proc hide_game_over
        ldy #16
        lda #11
        ldx #7
        jsr panel_fill
        ldy #5
        lda #13
        ldx #13
        jsr panel_fill
        ldy #5
        lda #14
        ldx #13
        jsr panel_fill
        ldy #5
        lda #15
        ldx #13
        jsr panel_fill
        ldy #5
        lda #16
        ldx #13
        jmp panel_fill
.endproc

; ---------------------------------------------------------------------------
; build_playfield - nametables for gameplay (rendering OFF)
; ---------------------------------------------------------------------------
.proc build_playfield
        jsr clear_nametables

        ; score row (row 1): HI label at cols 14-15
        lda PPUSTATUS
        lda #$20
        sta PPUADDR
        lda #$2E
        sta PPUADDR
        lda #FONT_H
        sta PPUDATA
        lda #FONT_I
        sta PPUDATA
        ; hiscore digits col 17-21
        lda #$20
        sta PPUADDR
        lda #$31
        sta PPUADDR
        ldx #0
@h:     lda hiscore, x
        tay
        lda digit_tiles, y
        sta PPUDATA
        inx
        cpx #5
        bne @h
        ; current score col 23-27
        lda #$20
        sta PPUADDR
        lda #$37
        sta PPUADDR
        ldx #0
@s:     lda score, x
        tay
        lda digit_tiles, y
        sta PPUDATA
        inx
        cpx #5
        bne @s

        ; sprite-0-hit bg marker pixel at (col 31, row 2) = screen (248,16)
        lda #$20
        sta PPUADDR
        lda #$5F
        sta PPUADDR
        lda #T_MARKER
        sta PPUDATA

        ; ground: rows 24-26 across both nametables
        lda PPUSTATUS
        lda #$23
        sta PPUADDR
        lda #$00
        sta PPUADDR
        ldx #32
@g0:    lda #T_GROUND_A
        sta PPUDATA
        dex
        bne @g0
        ; rows 25-26 (64 tiles, alternate dirt)
        ldx #64
        lda #0
@g1:    txa
        and #1
        beq :+
        lda #T_DIRT_A
        jmp :++
:       lda #T_DIRT_B
:       sta PPUDATA
        dex
        bne @g1
        ; second nametable rows 24-26
        lda #$27
        sta PPUADDR
        lda #$00
        sta PPUADDR
        ldx #32
@g2:    lda #T_GROUND_A
        sta PPUDATA
        dex
        bne @g2
        ldx #64
@g3:    txa
        and #1
        beq :+
        lda #T_DIRT_B
        jmp :++
:       lda #T_DIRT_A
:       sta PPUDATA
        dex
        bne @g3
        rts
.endproc
