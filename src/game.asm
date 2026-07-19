; ---------------------------------------------------------------------------
; game.asm - gameplay state machine and logic
; All simulation in original world units (600x150) for fidelity.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; state_title
; ---------------------------------------------------------------------------
.proc state_title
        ; blink dino: 80-frame cycle, 10-frame lid (matches the web preview's
        ; 8-frame loop at 6fps: 1 blink frame in 8)
        lda blink_tmr
        bne @dec
        lda #80
        sta blink_tmr
        lda #1
        sta blink_state
@dec:   dec blink_tmr
        lda blink_state
        beq @eyes_done
        lda blink_tmr
        cmp #70
        bcs @eyes_done
        lda #0
        sta blink_state
@eyes_done:

        ; blink PRESS START every 30 frames
        lda frame16
        and #$1F
        bne @no_ps
        lda frame16
        and #$20
        bne @ps_show
        jsr hide_press_start
        jmp @no_ps
@ps_show:
        jsr show_press_start
@no_ps:

        jsr oam_title_dino

        lda joy_press
        and #BTN_START
        beq @done
        jsr sfx_start
        jsr start_intro
@done:
        rts
.endproc

.proc hide_press_start
        lda #$22
        ldx #$0E
        jsr vram_begin
        ldx #11
        lda #FONT_SP
@l:     sta vram_buf, y
        iny
        dex
        bne @l
        jsr vram_end
        rts
.endproc

.proc show_press_start
        lda #$22
        ldx #$0E
        jsr vram_begin
        ldx #0
@l:     lda text_press_start+1, x
        sta vram_buf, y
        iny
        inx
        cpx #11
        bne @l
        jsr vram_end
        rts
.endproc

; ---------------------------------------------------------------------------
; start_intro - transition title/over -> intro (build playfield, reset vars)
; ---------------------------------------------------------------------------
.proc start_intro
        ; stop music during rebuild
        jsr music_stop

        ; reset game vars (before building playfield so score shows 0)
        lda #SPEED_START_LO
        sta speed_88
        lda #SPEED_START_HI
        sta speed_88+1
        lda #0
        sta accel_div
        sta run_frames
        sta run_frames+1
        sta scroll_x
        sta scroll_nt
        sta scroll_frac
        sta scroll_frac+1
        sta col_stream
        sta col_stream+1
        sta dist_frac
        sta dist_px
        sta score_flash
        sta ob_count
        sta cloud_count
        sta night_mode
        sta night_timer
        sta night_timer+1
        sta dino_flags
        sta dino_anim_frm
        sta dino_anim_tmr
        sta over_timer
        sta score_changed
        ldx #4
        lda #0
@sc:    sta score, x
        dex
        bpl @sc
        lda #<700
        sta next_night
        lda #>700
        sta next_night+1
        lda #0
        sta next_night+2
        ; obstacle slots empty (OBTYPE = $FF for each slot)
        lda #$FF
        sta obstacles + OBTYPE + 0
        sta obstacles + OBTYPE + 8
        sta obstacles + OBTYPE + 16
        sta obstacles + OBTYPE + 24
        ; clouds empty
        sta clouds + CLY + 0
        sta clouds + CLY + 4
        sta clouds + CLY + 8
        sta clouds + CLY + 12
        ; dino at start
        lda #<(WORLD_GROUND_TOP << 8)
        sta dino_y88
        lda #>(WORLD_GROUND_TOP << 8)
        sta dino_y88+1
        lda #0
        sta dino_vy88
        sta dino_vy88+1

        ; rendering off, build nametables
        lda #0
        sta PPUMASK
        sta PPUCTRL
        jsr build_playfield

        ; day palette
        lda #1
        sta pal_update

        ; intro: dino runs in from left edge
        lda #0
        sta intro_x
        sta dino_draw_x

        lda #ST_INTRO
        sta game_state

        lda #%10100000
        sta ppuctrl_shadow
        sta PPUCTRL
        lda #%00011010          ; sprites clipped in left 8px (smooth exit)
        sta PPUMASK

        lda #SONG_GAME
        sta song_id
        jsr music_start
        rts
.endproc

; ---------------------------------------------------------------------------
; state_intro - dino runs in from left edge to start position
; ---------------------------------------------------------------------------
.proc state_intro
        ; ground scrolls at start speed, dino runs in
        jsr advance_world

        lda intro_x
        clc
        adc #2
        sta intro_x
        ; dino_draw_x = intro_x * 109 >> 8 (cap at DINO_SCREEN_X)
        tax
        lda mult109_hi, x
        sta dino_draw_x
        lda intro_x
        cmp #50
        bcc @still
        lda #DINO_SCREEN_X
        sta dino_draw_x
        lda #0
        sta run_frames
        sta run_frames+1
        lda #ST_PLAY
        sta game_state
@still:
        ; run animation
        jsr dino_run_anim
        jsr oam_compose
        rts
.endproc

; ---------------------------------------------------------------------------
; state_play
; ---------------------------------------------------------------------------
.proc state_play
        ; ---- pause ----
        lda joy_press
        and #BTN_START
        beq @no_pause
        lda #ST_PAUSE
        sta game_state
        jsr show_paused
        jsr music_pause
        rts
@no_pause:

        ; ---- input -> jump / duck / speeddrop ----
        jsr dino_input

        ; ---- physics ----
        jsr dino_physics

        ; ---- speed ramp: +1/256 every 4 frames (≈0.001/frame) ----
        lda frame16
        and #3
        bne @no_accel
        lda speed_88
        clc
        adc #1
        sta speed_88
        lda speed_88+1
        adc #0
        sta speed_88+1
        cmp #SPEED_MAX_HI
        bcc @no_accel
        bne @cap
        lda speed_88
        beq @no_accel          ; exactly 13.00: ok
@cap:
        lda #$00
        sta speed_88
        lda #SPEED_MAX_HI
        sta speed_88+1
@no_accel:

        ; ---- distance/score ----
        jsr update_distance

        ; ---- night mode ----
        jsr update_night

        ; ---- world scroll + terrain ----
        jsr advance_world

        ; ---- obstacles ----
        jsr update_obstacles

        ; ---- clouds ----
        jsr update_clouds

        ; ---- collision ----
        jsr check_collision
        bcs @crashed

        ; ---- animation + sprites ----
        jsr dino_run_anim
        jsr oam_compose

        ; ---- score display ----
        jsr update_score_display

        inc run_frames
        bne :+
        inc run_frames+1
:       rts

@crashed:
        jsr start_game_over
        rts
.endproc

; ---------------------------------------------------------------------------
; state_pause
; ---------------------------------------------------------------------------
.proc state_pause
        lda joy_press
        and #BTN_START
        beq @done
        jsr hide_paused
        jsr music_resume
        lda #ST_PLAY
        sta game_state
@done:
        rts
.endproc

; ---------------------------------------------------------------------------
; state_over
; ---------------------------------------------------------------------------
.proc state_over
        ; wait a bit, then allow restart
        lda over_timer
        beq @allow
        dec over_timer
        jmp @no_restart
@allow:
        lda joy_press
        and #BTN_START | BTN_A
        beq @no_restart
        jsr start_intro
        rts
@no_restart:
        rts
.endproc

; ---------------------------------------------------------------------------
; start_game_over
; ---------------------------------------------------------------------------
.proc start_game_over
        lda dino_flags
        ora #%00010000          ; dead bit
        sta dino_flags
        jsr sfx_crash

        ; save hiscore
        ldx #0
@cmp:
        lda score, x
        cmp hiscore, x
        bcc @no_hi
        bne @new_hi
        inx
        cpx #5
        bne @cmp
        jmp @no_hi
@new_hi:
        ldx #0
@cp:    lda score, x
        sta hiscore, x
        inx
        cpx #5
        bne @cp
        lda #1
        sta hiscore_dirty
@no_hi:

        ; game over panel + dead dino sprite
        jsr show_game_over
        jsr oam_compose_dead
        jsr update_score_display

        lda #45
        sta over_timer
        lda #ST_OVER
        sta game_state

        lda #SONG_GAMEOVER
        sta song_id
        jsr music_start
        rts
.endproc

; ---------------------------------------------------------------------------
; dino_input - jump/duck/speeddrop from joypad
; ---------------------------------------------------------------------------
.proc dino_input
        ; --- jump: A or UP pressed ---
        lda joy_press
        and #BTN_A | BTN_UP
        beq @no_jump
        lda dino_flags
        and #%00000011          ; jumping or ducking?
        bne @no_jump
        ; start jump: vy = -(10 + speed/10)
        lda speed_88+1
        sec
        sbc #6                  ; index 0..7 for speed 6..13
        tax
        lda jump_vel_lo, x
        sta dino_vy88
        lda jump_vel_hi, x
        sta dino_vy88+1
        lda dino_flags
        ora #%00000001          ; jumping
        and #%11110111          ; clear reached_min
        sta dino_flags
        jsr sfx_jump
@no_jump:

        ; --- jump released -> endJump ---
        lda joy_release
        and #BTN_A | BTN_UP
        beq @no_release
        lda dino_flags
        and #1
        beq @no_release
        jsr dino_end_jump
@no_release:

        ; --- down pressed ---
        lda joy_cur
        and #BTN_DOWN
        beq @no_down
        lda dino_flags
        and #1                  ; jumping?
        beq @try_duck
        ; speeddrop: arm once, then leave it alone while DOWN stays held.
        ; (This used to branch to @no_down - the DOWN-released cleanup -
        ; which cleared the flag again every other frame, so vy kept being
        ; reset to its initial value and the dino floated instead of
        ; slamming down.)
        lda dino_flags
        and #4
        bne @done               ; already dropping: keep falling
        lda dino_flags
        ora #%00000100          ; speeddrop
        sta dino_flags
        lda #$00
        sta dino_vy88
        lda #$01
        sta dino_vy88+1         ; vy = +1.0 (8.8: hi=int, lo=fraction - the
        rts                     ; bytes were swapped, vy was 1/256 px/frame
                                ; and the dino hung mid-air on DOWN)
@try_duck:
        lda dino_flags
        ora #%00000010          ; ducking
        sta dino_flags
        rts
@no_down:
        ; down released / not held: clear duck + speeddrop
        lda dino_flags
        and #%11111001
        sta dino_flags
@done:
        rts
.endproc

; ---------------------------------------------------------------------------
; dino_end_jump - cap upward velocity at -5 once min height reached
; ---------------------------------------------------------------------------
.proc dino_end_jump
        lda dino_flags
        and #%00001000          ; reached_min?
        beq @done
        lda dino_vy88+1
        cmp #$FB                ; vy < -5.0? (more negative)
        bpl @done               ; vy_hi >= $FB means vy >= -5.0
        lda #$00
        sta dino_vy88
        lda #$FB
        sta dino_vy88+1         ; vy = -5.0
@done:
        rts
.endproc

; ---------------------------------------------------------------------------
; dino_physics - jump arc integration (8.8 fixed point, world units)
; ---------------------------------------------------------------------------
.proc dino_physics
        lda dino_flags
        and #1
        bne @jumping
        rts                     ; running on ground
@jumping:
        ; y += vy (x3 if speeddrop)
        lda dino_flags
        and #4
        bne @drop
        lda dino_y88
        clc
        adc dino_vy88
        sta dino_y88
        lda dino_y88+1
        adc dino_vy88+1
        sta dino_y88+1
        jmp @grav
@drop:
        ; y += vy*3
        lda dino_vy88
        sta temp16
        lda dino_vy88+1
        sta temp16+1
        lda dino_y88
        clc
        adc temp16
        sta dino_y88
        lda dino_y88+1
        adc temp16+1
        sta dino_y88+1
        lda dino_y88
        clc
        adc temp16
        sta dino_y88
        lda dino_y88+1
        adc temp16+1
        sta dino_y88+1
        lda dino_y88
        clc
        adc temp16
        sta dino_y88
        lda dino_y88+1
        adc temp16+1
        sta dino_y88+1
@grav:
        ; vy += 0.6
        lda dino_vy88
        clc
        adc #GRAVITY_LO
        sta dino_vy88
        lda dino_vy88+1
        adc #GRAVITY_HI
        sta dino_vy88+1

        ; reached_min if y < 63.0 ($3F00)
        lda dino_y88+1
        cmp #JUMP_MIN_Y
        bpl @no_min
        lda dino_flags
        ora #%00001000
        sta dino_flags
@no_min:
        ; auto endJump if y < 30.0 or speeddrop
        lda dino_flags
        and #4
        bne @do_end
        lda dino_y88+1
        cmp #JUMP_MAX_Y
        bpl @no_end
@do_end:
        jsr dino_end_jump
@no_end:
        ; landed? y >= 93.0 ($5D00)
        lda dino_y88+1
        cmp #WORLD_GROUND_TOP
        bmi @air
        bne @landed
        lda dino_y88
        beq @air               ; exactly 93.00 -> treat as airborne edge
@landed:
        lda #<(WORLD_GROUND_TOP << 8)
        sta dino_y88
        lda #>(WORLD_GROUND_TOP << 8)
        sta dino_y88+1
        lda #0
        sta dino_vy88
        sta dino_vy88+1
        lda dino_flags
        and #%11111000          ; clear jumping/speeddrop/reached_min
        sta dino_flags
        ; if DOWN held, transition to duck
        lda joy_cur
        and #BTN_DOWN
        beq @air
        lda dino_flags
        ora #%00000010
        sta dino_flags
@air:
        rts
.endproc

; ---------------------------------------------------------------------------
; dino_run_anim - run cycle 12fps (5 frames), duck 8fps (7.5 -> 7/8 frames)
; ---------------------------------------------------------------------------
.proc dino_run_anim
        lda dino_flags
        and #1                  ; jumping: static pose
        bne @done
        lda dino_anim_tmr
        beq @tick
        dec dino_anim_tmr
        rts
@tick:
        lda dino_flags
        and #2
        bne @duck
        lda #5
        sta dino_anim_tmr
        jmp @flip
@duck:
        lda #7
        sta dino_anim_tmr
@flip:
        lda dino_anim_frm
        eor #1
        sta dino_anim_frm
@done:
        rts
.endproc

; ---------------------------------------------------------------------------
; update_distance - accumulate distance, score (decimal), ding at 100s
; dist accumulator: dist_frac(8) : dist_px(8) ; add speed_88 per frame
; score point every 40 world px (1/0.025)
; ---------------------------------------------------------------------------
.proc update_distance
        lda dist_frac
        clc
        adc speed_88
        sta dist_frac
        lda dist_px
        adc speed_88+1
        sta dist_px
        cmp #40
        bcc @done
        sec
        sbc #40
        sta dist_px
        ; score++
        ldx #4
@dig:
        lda score, x
        clc
        adc #1
        cmp #10
        bcc @set
        lda #0
        sta score, x
        dex
        bpl @dig
        jmp @rolled
@set:
        sta score, x
@rolled:
        lda #1
        sta score_changed
        ; ding every 100 (last two digits == 00)
        lda score+3
        bne @done
        lda score+4
        bne @done
        jsr sfx_ding
        lda #32
        sta score_flash
@done:
        rts
.endproc

; ---------------------------------------------------------------------------
; score_bin - returns 16-bit binary score in temp16 (for night trigger)
; ---------------------------------------------------------------------------
.proc score_to_bin
        lda #0
        sta temp16
        sta temp16+1
        ldx #0
@loop:
        ; temp16 = temp16*10 + score[x]
        lda temp16
        sta tmpA
        lda temp16+1
        sta tmpB
        ; *2
        asl temp16
        rol temp16+1
        ; *4 -> reuse: *8 then add *2
        asl temp16
        rol temp16+1
        asl temp16
        rol temp16+1
        ; add *2
        lda temp16
        clc
        adc tmpA
        adc tmpA               ; + 2*tmpA? careful: tmpA was lo of *1
        ; simpler: temp16 (*8) + tmpAB(*2)
        ; redo below
        jmp @add2
@add2:
        ; recompute: temp16 currently *8 of old; add old*2
        lda tmpA
        asl a
        sta tmpC
        lda tmpB
        rol a
        sta tmpD
        lda temp16
        clc
        adc tmpC
        sta temp16
        lda temp16+1
        adc tmpD
        sta temp16+1
        ; add digit
        lda temp16
        clc
        adc score, x
        sta temp16
        lda temp16+1
        adc #0
        sta temp16+1
        inx
        cpx #5
        bne @loop
        rts
.endproc

; ---------------------------------------------------------------------------
; update_night - invert at score multiples of 700; night covers the first
; 350 points of each cycle so day and night last about the same.
; ---------------------------------------------------------------------------
.proc update_night
        lda night_mode
        bne @counting
        ; check score >= next_night
        jsr score_to_bin
        lda temp16
        cmp next_night
        lda temp16+1
        sbc next_night+1
        bcc @done
        ; trigger night
        lda #1
        sta night_mode
        ; next trigger += 700
        lda next_night
        clc
        adc #<700
        sta next_night
        lda next_night+1
        adc #>700
        sta next_night+1
        ; palette + pick fixed sky positions for the sprite moon/stars
        lda #1
        sta pal_update
        jsr roll_night_sky
        rts
@counting:
        ; night covers half of each 700-point cycle: day returns at
        ; next_night - 350, so day and night get equal distance (and thus
        ; roughly equal time at any given speed).
        jsr score_to_bin
        lda next_night
        sec
        sbc #<350
        sta tmpA
        lda next_night+1
        sbc #>350
        sta tmpB
        lda temp16
        cmp tmpA
        lda temp16+1
        sbc tmpB
        bcc @done
        ; day returns (sprite moon/stars stop drawing with night_mode)
        lda #0
        sta night_mode
        lda #1
        sta pal_update
@done:
        rts
.endproc

; ---------------------------------------------------------------------------
; advance_world - scroll ground, advance column streamer
; scroll advance per frame = floor(speed) * 109 / 256 NES px
; ---------------------------------------------------------------------------
.proc advance_world
        ; px this frame = floor(speed) * 109 / 256, with an 8-bit fraction
        ; accumulator (scroll_frac holds the fraction, NOT a cumulative px)
        ldx speed_88+1          ; floor(speed)
        beq @done
        lda scroll_frac         ; 8-bit fraction
        clc
        adc mult109_lo, x
        sta scroll_frac         ; keep new fraction
        lda mult109_hi, x
        adc #0
        sta tmpB                ; px to advance this frame (0-4)
        beq @done
        ; advance fine scroll
        lda scroll_x
        clc
        adc tmpB
        sta scroll_x
        bcc @no_wrap
        lda scroll_nt
        eor #1
        sta scroll_nt
@no_wrap:
        ; advance global column streamer
        lda col_stream
        clc
        adc tmpB
        sta col_stream
        lda col_stream+1
        adc #0
        sta col_stream+1
        ; new column every 8 px
        lda col_stream
        and #7
        cmp tmpB
        bcs @done               ; wrapped past boundary? if rem < added -> new col
        jsr stream_column
@done:
        rts
.endproc

; ---------------------------------------------------------------------------
; stream_column - write one leading-edge nametable column (rows 20-26)
; column index = ((col_stream >> 3) + 32) & 63
; ---------------------------------------------------------------------------
.proc stream_column
        ; leading col = ((col_stream >> 3) + 32) & 63  (16-bit shift!)
        lda col_stream+1
        asl a
        asl a
        asl a
        asl a
        asl a
        sta tmpB
        lda col_stream
        lsr a
        lsr a
        lsr a
        ora tmpB
        and #63
        clc
        adc #32
        and #63
        sta tmpA                ; global column 0-63

        ; find covering cactus obstacle -> tmpC type ($FF none), tmpD col-in-cactus
        lda #$FF
        sta tmpC
        lda #0
        sta tmpD
        ldx #0
@ob_scan:
        cpx #OB_STRIDE * OB_SLOTS
        bcs @found
        lda obstacles + OBTYPE, x
        cmp #OB_PTERO
        beq @next_ob
        cmp #$FF
        beq @next_ob
        lda obstacles + OBX_HI, x
        bmi @next_ob            ; dying (x<0): its art already streamed past
        ; cactus columns were latched at spawn: OBY = start column (0-63),
        ; OBANIM = width in columns. Covered iff the circular distance from
        ; start col to the leading col is < width. The latched range is
        ; world-fixed, so no per-event math can race the 8px grid.
        ; NOTE: keep hands off tmpC/tmpD before a match - they carry the
        ; scan result ($FF = no covering cactus). Clobbering tmpC painted
        ; phantom cactus walls when garbage matched a cactus type.
        lda tmpA                ; leading col
        sec
        sbc obstacles + OBY, x  ; - start col
        and #63                 ; circular distance (cols straddling 63->0)
        cmp obstacles + OBANIM, x
        bcs @next_ob
        sta tmpD
        lda obstacles + OBTYPE, x
        sta tmpC
        jmp @found
@next_ob:
        txa
        clc
        adc #OB_STRIDE
        tax
        jmp @ob_scan
@found:

        ; vram addr = nt_base + 20*32 + (col & 31)
        lda tmpA
        and #31
        clc
        adc #<(20*32)
        tax                     ; lo
        lda #$22
        ldy tmpA
        cpy #32
        bcc :+
        lda #$26
:       jsr vram_begin          ; A=hi, X=lo -> Y data index

        ; row 20: always blank
        lda #0
        sta vram_buf, y
        iny
        ; rows 21-23: cactus upper / blank
        lda tmpC
        cmp #OB_CACT_LARGE
        beq @large_rows
        cmp #OB_CACT_SMALL
        beq @small_rows
        ; no cactus: 3 blanks
        lda #0
        sta vram_buf, y
        iny
        sta vram_buf, y
        iny
        sta vram_buf, y
        iny
        jmp @row24
@large_rows:
        ; tiles T_CACT_L_0..7: art is 2 cols x 4 rows, tile = row*2 + col.
        ; tmpD is the column within the GROUP (0..2*size-1); each cactus of
        ; the group repeats the same 2-col art, so reduce to col & 1 first -
        ; indexing with the raw group column walked past the art into the
        ; font tiles (the "01" that showed up under multi-cactus groups).
        lda tmpD
        and #1
        sta tmpD
        clc
        adc #T_CACT_L_0
        sta vram_buf, y
        iny
        lda tmpD
        clc
        adc #T_CACT_L_2
        sta vram_buf, y
        iny
        lda tmpD
        clc
        adc #T_CACT_L_4
        sta vram_buf, y
        iny
        jmp @row24
@small_rows:
        ; small: row21 blank, row22 = T_CACT_S_0, row23 = T_CACT_S_1
        lda #0
        sta vram_buf, y
        iny
        lda #T_CACT_S_0
        sta vram_buf, y
        iny
        lda #T_CACT_S_1
        sta vram_buf, y
        iny
@row24:
        lda tmpC
        cmp #OB_CACT_LARGE
        beq @l24
        cmp #OB_CACT_SMALL
        beq @s24
        lda #T_GROUND_A
        jmp @e24
@l24:
        lda tmpD
        clc
        adc #T_CACT_L_6
        jmp @e24
@s24:
        lda #T_CACT_S_2
@e24:
        sta vram_buf, y
        iny
        ; rows 25-26 dirt (vary by column parity)
        lda tmpA
        and #1
        beq :+
        lda #T_DIRT_A
        jmp :++
:       lda #T_DIRT_B
:       sta vram_buf, y
        iny
        lda tmpA
        and #1
        beq :+
        lda #T_DIRT_B
        jmp :++
:       lda #T_DIRT_A
:       sta vram_buf, y
        iny
        jsr vram_end_vert
        rts
.endproc
; ---------------------------------------------------------------------------
; ob_screen_x - screen x of obstacle slot X (ob.x * 109 >> 8) -> tmpE
; ---------------------------------------------------------------------------
.proc ob_screen_x
        lda obstacles + OBX_LO, x
        sta temp16
        lda obstacles + OBX_HI, x
        sta temp16+1
        jmp mul109_to_tmpE
.endproc

; mul109: temp16 (0..700) * 109 >> 8 -> result in tmpE and A
; (hi*256+lo)*109>>8 = hi*109 + (lo*109)>>8
; preserves X (used as obstacle loop counter by callers)
; Screen x saturates at 255: world x > 601 maps past the right edge, and an
; 8-bit wrap would teleport it to the left edge (ghost sprites / bad columns).
.proc mul109_to_tmpE
        txa
        pha                     ; preserve X (obstacle loop counter)
        ldx temp16+1        ; hi (0-2)
        lda mult109_lo, x   ; hi*109 (fits: <=218)
        ldx temp16          ; lo
        clc
        adc mult109_hi, x   ; (lo*109)>>8
        bcc :+
        lda #255            ; off-screen right stays off-screen right
:       sta tmpE
        pla
        tax
        rts
.endproc
