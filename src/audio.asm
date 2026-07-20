; ---------------------------------------------------------------------------
; audio.asm - APU music engine (4 channels) + sound effects
;
; Music streams: [note, len] pairs, note 0 = rest, $FF,$FF = loop/end.
; SFX owns channels temporarily (sq1 for jump/crash/start, sq2 for ding).
; ---------------------------------------------------------------------------

SFX_OWN_SQ1 = 1
SFX_OWN_SQ2 = 2

; ---------------------------------------------------------------------------
.proc apu_init
        lda #$0F
        sta APUSTATUS           ; enable sq1, sq2, tri, noise
        lda #$40
        sta $4017               ; 4-step frame counter, no IRQ
        lda #0
        sta song_id
        sta sfx_timer
        sta sfx_phase
        jsr silence_all
        rts
.endproc

.proc silence_all
        lda #$30
        sta SQ1_VOL
        sta SQ2_VOL
        sta NOISE_VOL
        lda #0
        sta TRI_LINEAR
        rts
.endproc

; ---------------------------------------------------------------------------
; music_start: A = song id
; ---------------------------------------------------------------------------
.proc music_start
        pha
        jsr silence_all
        pla
        cmp #SONG_NONE
        beq @done
        tax
        lda song_sq1_lo, x
        sta ch1_pos
        lda song_sq1_hi, x
        sta ch1_pos+1
        lda song_sq2_lo, x
        sta ch2_pos
        lda song_sq2_hi, x
        sta ch2_pos+1
        lda song_tri_lo, x
        sta tri_pos
        lda song_tri_hi, x
        sta tri_pos+1
        lda song_noi_lo, x
        sta noi_pos
        lda song_noi_hi, x
        sta noi_pos+1
        lda #1
        sta ch1_wait
        sta ch2_wait
        sta tri_wait
        sta noi_wait
        sta star_wait
        lda #0
        sta star_step
        sta star_drum_timer
        cpx #SONG_GAME
        bne @done
        ; STAR SWOOP drives pulse 2 directly with sweep disabled.
        sta SQ2_SWEEP
@done:
        rts
.endproc

.proc music_stop
        lda #SONG_NONE
        sta song_id
        jsr silence_all
        rts
.endproc

.proc music_pause
        jsr silence_all
        rts
.endproc

.proc music_resume
        ; force re-trigger of current notes
        lda #1
        sta ch1_wait
        sta ch2_wait
        sta tri_wait
        sta noi_wait
        sta star_wait
        rts
.endproc

; ---------------------------------------------------------------------------
; audio_tick - called every NMI
; ---------------------------------------------------------------------------
.proc audio_tick
        ; sfx has priority
        lda sfx_timer
        beq @music
        jsr sfx_tick
        ; Hold the game-over melody until the crash has fully finished so
        ; pulse 1, pulse 2, and triangle begin the lament together.
        lda song_id
        cmp #SONG_GAMEOVER
        beq @done
@music:
        lda song_id
        cmp #SONG_NONE
        beq @done
        lda pause_flag
        bne @done
        lda song_id
        cmp #SONG_GAME
        bne @stream_music
        jsr tick_star_game
        rts
@stream_music:
        jsr tick_sq1
        jsr tick_sq2
        jsr tick_tri
        ; Game over keeps its one-shot crash, but never inherits a repeating
        ; noise-drum stream beneath the sad melody.
        lda song_id
        cmp #SONG_GAMEOVER
        beq @done
        jsr tick_noise
@done:
        rts
.endproc

; ---------------------------------------------------------------------------
; Exact STAR SWOOP gameplay track
;
; Unlike the generic note-stream player, this writes the original raw APU
; timer, volume, duty, and noise values. SONG_TITLE and SONG_GAMEOVER remain
; on the generic stream player and never enter this routine.
; ---------------------------------------------------------------------------
.proc tick_star_game
        ; End the current drum hit after its original duration.
        lda star_drum_timer
        beq @step
        dec star_drum_timer
        bne @step
        lda #$30
        sta NOISE_VOL

@step:
        dec star_wait
        bne @done
        lda #8
        sta star_wait
        lda star_step
        and #$0F
        tax
        jsr play_star_drum

        ; Dino sound effects may temporarily own pulse 2. The song keeps time
        ; and resumes on the following step without touching gameplay logic.
        lda sfx_own
        and #SFX_OWN_SQ2
        bne @advance
        lda star_music_volume, x
        sta SQ2_VOL
        lda star_music_low, x
        sta SQ2_LO
        lda star_music_high, x
        sta SQ2_HI

@advance:
        inc star_step
@done:
        rts
.endproc

.proc play_star_drum
        lda star_drum_pattern, x
        beq @done
        cmp #1
        beq @kick
        cmp #2
        beq @snare

        ; Hi-hat: $36 volume, period $02, two frames.
        lda #$36
        sta NOISE_VOL
        lda #$02
        sta NOISE_LO
        lda #$00
        sta NOISE_HI
        lda #2
        sta star_drum_timer
        rts

@kick:
        ; Kick: $3F volume, period $0E, four frames.
        lda #$3F
        sta NOISE_VOL
        lda #$0E
        sta NOISE_LO
        lda #$00
        sta NOISE_HI
        lda #4
        sta star_drum_timer
        rts

@snare:
        ; Snare: $3C volume, period $05, five frames.
        lda #$3C
        sta NOISE_VOL
        lda #$05
        sta NOISE_LO
        lda #$00
        sta NOISE_HI
        lda #5
        sta star_drum_timer
@done:
        rts
.endproc

; ---------------------------------------------------------------------------
; channel ticks
; ---------------------------------------------------------------------------
.proc tick_sq1
        lda sfx_own
        and #SFX_OWN_SQ1
        bne @skip               ; sfx owns channel
        lda ch1_wait
        sec
        sbc #1
        sta ch1_wait
        bne @skip
        ; read next pair
        ldy #0
        lda (ch1_pos), y
        cmp #$FF
        bne @note
        ; loop: reset pointer to song start
        ldx song_id
        lda song_sq1_lo, x
        sta ch1_pos
        lda song_sq1_hi, x
        sta ch1_pos+1
        ldy #0
        lda (ch1_pos), y
@note:
        sta tmpA                ; note
        iny
        lda (ch1_pos), y
        sta ch1_wait
        ; advance
        lda ch1_pos
        clc
        adc #2
        sta ch1_pos
        lda ch1_pos+1
        adc #0
        sta ch1_pos+1
        ; rest?
        lda tmpA
        beq @rest
        tax
        lda #%10011100          ; duty 50%, const vol 12
        sta SQ1_VOL
        lda period_lo, x
        sta SQ1_LO
        lda period_hi, x
        sta SQ1_HI
        lda #%11111000          ; no sweep
        sta SQ1_SWEEP
        rts
@rest:
        lda #$30
        sta SQ1_VOL
@skip:
        rts
.endproc

.proc tick_sq2
        lda sfx_own
        and #SFX_OWN_SQ2
        bne @skip
        lda ch2_wait
        sec
        sbc #1
        sta ch2_wait
        bne @skip
        ldy #0
        lda (ch2_pos), y
        cmp #$FF
        bne @note
        ldx song_id
        lda song_sq2_lo, x
        sta ch2_pos
        lda song_sq2_hi, x
        sta ch2_pos+1
        ldy #0
        lda (ch2_pos), y
@note:
        sta tmpA
        iny
        lda (ch2_pos), y
        sta ch2_wait
        lda ch2_pos
        clc
        adc #2
        sta ch2_pos
        lda ch2_pos+1
        adc #0
        sta ch2_pos+1
        lda tmpA
        beq @rest
        tax
        lda #%01011001          ; duty 25%, const vol 9
        sta SQ2_VOL
        lda period_lo, x
        sta SQ2_LO
        lda period_hi, x
        sta SQ2_HI
        lda #%11111000
        sta SQ2_SWEEP
        rts
@rest:
        lda #$30
        sta SQ2_VOL
@skip:
        rts
.endproc

.proc tick_tri
        lda tri_wait
        sec
        sbc #1
        sta tri_wait
        bne @skip
        ldy #0
        lda (tri_pos), y
        cmp #$FF
        bne @note
        ldx song_id
        lda song_tri_lo, x
        sta tri_pos
        lda song_tri_hi, x
        sta tri_pos+1
        ldy #0
        lda (tri_pos), y
@note:
        sta tmpA
        iny
        lda (tri_pos), y
        sta tri_wait
        lda tri_pos
        clc
        adc #2
        sta tri_pos
        lda tri_pos+1
        adc #0
        sta tri_pos+1
        lda tmpA
        beq @rest
        tax
        lda #$81                ; linear counter on
        sta TRI_LINEAR
        lda period_lo, x
        sta TRI_LO
        lda period_hi, x
        sta TRI_HI
        rts
@rest:
        lda #0
        sta TRI_LINEAR
@skip:
        rts
.endproc

.proc tick_noise
        ; decay current hit
        lda noi_vol
        beq @next
        dec noi_vol
        lda noi_vol
        ora #$30
        sta NOISE_VOL
@next:
        lda noi_wait
        sec
        sbc #1
        sta noi_wait
        bne @skip
        ldy #0
        lda (noi_pos), y
        cmp #$FF
        bne @note
        ldx song_id
        lda song_noi_lo, x
        sta noi_pos
        lda song_noi_hi, x
        sta noi_pos+1
        ldy #0
        lda (noi_pos), y
@note:
        sta tmpA
        iny
        lda (noi_pos), y
        sta noi_wait
        lda noi_pos
        clc
        adc #2
        sta noi_pos
        lda noi_pos+1
        adc #0
        sta noi_pos+1
        lda tmpA
        beq @rest
        cmp #1
        beq @hat
        ; kick: period 8
        lda #$08
        sta NOISE_LO
        lda #10
        sta noi_vol
        jmp @fire
@hat:
        lda #$04
        sta NOISE_LO
        lda #6
        sta noi_vol
@fire:
        lda noi_vol
        ora #$30
        sta NOISE_VOL
        rts
@rest:
        lda #0
        sta noi_vol
@skip:
        rts
.endproc

; ---------------------------------------------------------------------------
; SFX
; ---------------------------------------------------------------------------
.proc sfx_jump
        lda #1
        sta sfx_id
        lda #12
        sta sfx_timer
        lda #0
        sta sfx_phase
        lda sfx_own
        ora #SFX_OWN_SQ1
        sta sfx_own
        rts
.endproc

.proc sfx_ding
        lda #2
        sta sfx_id
        lda #10
        sta sfx_timer
        lda #0
        sta sfx_phase
        lda sfx_own
        ora #SFX_OWN_SQ2
        sta sfx_own
        rts
.endproc

.proc sfx_crash
        lda #3
        sta sfx_id
        lda #24
        sta sfx_timer
        lda #0
        sta sfx_phase
        lda sfx_own
        ora #SFX_OWN_SQ1
        sta sfx_own
        rts
.endproc

.proc sfx_start
        lda #4
        sta sfx_id
        lda #8
        sta sfx_timer
        lda #0
        sta sfx_phase
        lda sfx_own
        ora #SFX_OWN_SQ1
        sta sfx_own
        rts
.endproc

; sfx engine: simple per-frame sweeps
.proc sfx_tick
        dec sfx_timer
        bne @go
        jmp @end
@go:
        lda sfx_id
        cmp #1
        beq @jump
        cmp #2
        beq @ding
        cmp #3
        beq @crash
        jmp @start
@jump:
        ; rising sweep: period from high to low over 12 frames
        lda #%10011110          ; duty 50% vol 14
        sta SQ1_VOL
        lda sfx_timer
        asl a
        asl a
        asl a
        asl a
        clc
        adc #$40
        sta SQ1_LO             ; period falls as timer decreases -> pitch rises
        lda #0
        sta SQ1_HI
        rts
@ding:
        ; two-tone beep on sq2
        lda #%10011110
        sta SQ2_VOL
        lda sfx_timer
        cmp #5
        bcs :+
        lda #NT_C6
        jmp :++
:       lda #NT_G6
:       tax
        lda period_lo, x
        sta SQ2_LO
        lda period_hi, x
        sta SQ2_HI
        rts
@crash:
        ; noise burst + low thud
        lda sfx_timer
        cmp #12
        bcc @thud
        lda #$0A
        sta NOISE_LO
        lda sfx_timer
        ora #$30
        sta NOISE_VOL
        rts
@thud:
        lda #$30
        sta NOISE_VOL
        lda #%10001100
        sta SQ1_VOL
        lda sfx_timer
        asl a
        asl a
        asl a
        clc
        adc #$20
        sta SQ1_LO
        lda #$04
        sta SQ1_HI
        rts
@start:
        lda #%10011110
        sta SQ1_VOL
        lda #NT_E6
        tax
        lda period_lo, x
        sta SQ1_LO
        lda period_hi, x
        sta SQ1_HI
        rts
@end:
        ; Preserve Dino's original all-channel cleanup for title/game-over.
        ; Gameplay alone needs ownership-aware cleanup so pulse-1 jump/start
        ; effects cannot punch holes in STAR SWOOP's pulse-2 melody.
        lda song_id
        cmp #SONG_GAME
        beq @owned_cleanup
        lda #0
        sta sfx_own
        lda #$30
        sta SQ1_VOL
        sta SQ2_VOL
        sta NOISE_VOL
        jmp @retrigger

@owned_cleanup:
        ; Release and silence only channels owned by this effect.  The old
        ; all-channel mute cut a hole in pulse 2 after Start/Jump effects,
        ; even though those effects own pulse 1 only.
        lda sfx_own
        sta tmpA
        lda #0
        sta sfx_own
        lda tmpA
        and #SFX_OWN_SQ1
        beq :+
        lda #$30
        sta SQ1_VOL
:
        lda tmpA
        and #SFX_OWN_SQ2
        beq :+
        lda #$30
        sta SQ2_VOL
:
        lda sfx_id
        cmp #3
        bne :+
        lda #$30
        sta NOISE_VOL
:
        ; force music re-trigger
@retrigger:
        lda #1
        sta ch1_wait
        sta ch2_wait
        rts
.endproc
