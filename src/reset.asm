; ---------------------------------------------------------------------------
; reset.asm - startup, NMI handler, IRQ, main loop
; ---------------------------------------------------------------------------

.proc reset_handler
        sei
        cld
        ldx #$FF
        txs
        inx                     ; X = 0
        stx PPUCTRL
        stx PPUMASK
        stx $4010               ; DMC off
        stx APUSTATUS

        ; wait 2 vblanks for PPU warmup
@vbl1:  bit PPUSTATUS
        bpl @vbl1
@vbl2:  bit PPUSTATUS
        bpl @vbl2

        ; clear RAM
        txa
@clr:   sta $0000, x
        sta $0100, x
        sta $0200, x
        sta $0300, x
        sta $0400, x
        sta $0500, x
        sta $0600, x
        sta $0700, x
        inx
        bne @clr

        ; init OAM shadow to hidden
        ldx #0
        lda #$FF
@hide:  sta oam_shadow, x
        inx
        bne @hide

        ; init RNG
        lda #$5A
        sta rng16
        lda #$A5
        sta rng16+1

        ; default HI score
        lda #0
        ldx #4
@hi:    sta hiscore, x
        dex
        bpl @hi

        jsr apu_init

        ; default dino position
        lda #DINO_SCREEN_X
        sta dino_draw_x

        ; build title screen
        jsr build_title_screen

        ; day palette
        lda #1
        sta pal_update

        ; enable NMI + rendering
        lda #%10100000          ; NMI on, bg from PT0, sprites PT1 (8x16 uses both)
        sta ppuctrl_shadow
        sta PPUCTRL
        lda #%00011010          ; bg everywhere; sprites clipped in the
        sta PPUMASK             ; left 8px so they slide off, not pop

        lda #ST_TITLE
        sta game_state
        lda #SONG_TITLE
        sta song_id
        jsr music_start
.endproc

; ---------------------------------------------------------------------------
; Main loop: wait for NMI, then run game logic for the frame
; ---------------------------------------------------------------------------
.proc main_loop
@wait:
        lda nmi_done
        beq @wait
        lda #0
        sta nmi_done

        jsr read_joypad
        jsr rng_tick

        lda game_state
        cmp #ST_TITLE
        beq @title
        cmp #ST_INTRO
        beq @intro
        cmp #ST_PLAY
        beq @play
        cmp #ST_PAUSE
        beq @pause
        cmp #ST_OVER
        beq @over
        jmp main_loop

@title: jsr state_title
        jmp main_loop
@intro: jsr state_intro
        jmp main_loop
@play:  jsr state_play
        jmp main_loop
@pause: jsr state_pause
        jmp main_loop
@over:  jsr state_over
        jmp main_loop
.endproc

; ---------------------------------------------------------------------------
; NMI handler
; ---------------------------------------------------------------------------
.proc nmi_handler
        pha
        txa
        pha
        tya
        pha

        ; OAM DMA
        lda #0
        sta OAMADDR
        lda #>oam_shadow
        sta OAMDMA

        ; flush vram buffer (during vblank; clobbers PPU scroll register v)
        jsr vram_flush

        ; palette update
        lda pal_update
        beq @no_pal
        jsr load_palettes
        lda #0
        sta pal_update
@no_pal:

        ; --- scroll split: HUD band (y0-15) static, game scrolled below ---
        ; phase 1: HUD scroll (NT0, x=0) -- AFTER flush/palette restores v
        lda PPUSTATUS
        lda #%10100000
        sta PPUCTRL
        lda #0
        sta PPUSCROLL
        sta PPUSCROLL

        ; wait for sprite-0-hit flag to CLEAR first (stale from last frame),
        ; then wait for the real hit at scanline 16. Timeouts prevent hangs.
        ; PAL vblank is ~70 scanlines (~7500 CPU cycles) vs NTSC's ~20: with
        ; 8-bit timeouts both waits expired mid-vblank on PAL, the stale flag
        ; passed for a "hit", and the HUD band scrolled with the playfield.
        ; 16-bit timeouts cover PAL; real events still exit the loops early.
        ldy #8
        ldx #0
@wait_clear:
        bit PPUSTATUS
        bvc @cleared
        dex
        bne @wait_clear
        dey
        bne @wait_clear
@cleared:
        ldy #4
        ldx #0
@wait_hit:
        bit PPUSTATUS
        bvs @hit
        dex
        bne @wait_hit
        dey
        bne @wait_hit
@hit:
        ; phase 2: game scroll
        lda #%10100000
        ora scroll_nt
        sta ppuctrl_shadow
        sta PPUCTRL
        lda scroll_x
        sta PPUSCROLL
        lda #0
        sta PPUSCROLL

        ; audio
        jsr audio_tick

        ; frame counter + flag
        inc frame16
        bne :+
        inc frame16+1
:       lda #1
        sta nmi_done

        pla
        tay
        pla
        tax
        pla
        rti
.endproc

.proc irq_handler
        rti
.endproc
