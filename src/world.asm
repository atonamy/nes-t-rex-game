; ---------------------------------------------------------------------------
; world.asm - obstacles, clouds, collision, night sky, RNG
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; RNG - 16-bit Galois LFSR. Returns pseudo-random A.
; ---------------------------------------------------------------------------
.proc rng_next
        lda rng16
        lsr a
        sta rng16
        lda rng16+1
        ror a
        sta rng16+1
        bcc @done
        lda rng16
        eor #$B4
        sta rng16
        lda rng16+1
        eor #$00
        sta rng16+1
@done:
        lda rng16
        eor rng16+1
        rts
.endproc

.proc rng_tick
        jmp rng_next
.endproc

; ---------------------------------------------------------------------------
; ob_width2: slot X -> A = width in world px (base * size)
; ---------------------------------------------------------------------------
.proc ob_width2
        lda obstacles + OBTYPE, x
        cmp #OB_CACT_SMALL
        beq @s
        cmp #OB_CACT_LARGE
        beq @l
        lda #46
        rts
@s:     lda #17
        jmp @m
@l:     lda #25
@m:
        sta tmpB
        lda #0
        ldy obstacles + OBSIZE, x
@acc:
        clc
        adc tmpB
        dey
        bne @acc
        rts
.endproc

; ---------------------------------------------------------------------------
; update_obstacles - move, animate, remove, spawn
; ---------------------------------------------------------------------------
.proc update_obstacles
        lda #0
        sta tmpE                ; slot offset
@loop:
        ldx tmpE
        cpx #OB_STRIDE * OB_SLOTS
        bcc @scan
        jmp @spawn_check
@scan:
        lda obstacles + OBTYPE, x
        cmp #$FF
        bne @has_ob
        jmp @next
@has_ob:
        ; movement delta
        cmp #OB_PTERO
        beq @ptero_move
        lda speed_88+1          ; floor(speed)
        jmp @delta
@ptero_move:
        lda obstacles + OBANIM, x
        bmi @slow
        lda speed_88
        clc
        adc #205
        sta tmpC
        lda speed_88+1
        adc #0
        jmp @delta
@slow:
        lda speed_88
        sec
        sbc #205
        sta tmpC
        lda speed_88+1
        sbc #0
@delta:
        sta tmpB
        lda obstacles + OBX_LO, x
        sec
        sbc tmpB
        sta obstacles + OBX_LO, x
        lda obstacles + OBX_HI, x
        sbc #0
        sta obstacles + OBX_HI, x
        ; ptero anim (bit6=frame, low5=timer)
        lda obstacles + OBTYPE, x
        cmp #OB_PTERO
        bne @no_anim
        lda obstacles + OBANIM, x
        and #$1F
        sec
        sbc #1
        bne @keep_t
        lda obstacles + OBANIM, x
        eor #$40
        and #$E0
        ora #10
        sta obstacles + OBANIM, x
        jmp @no_anim
@keep_t:
        sta tmpB
        lda obstacles + OBANIM, x
        and #$E0
        ora tmpB
        sta obstacles + OBANIM, x
@no_anim:
        ; remove if x + width < 0 (signed)
        lda obstacles + OBX_HI, x
        bmi @remove
        ; width check: x < -width?
        ; (x_hi=$FF and x_lo < 256-width) -> gone
        cmp #$FF
        bne @next
        jsr ob_width2
        eor #$FF                ; -width
        clc
        adc #1
        cmp obstacles + OBX_LO, x
        bcc @next
@remove:
        ldy tmpE
@shift:
        cpy #OB_STRIDE * (OB_SLOTS - 1)
        bcs @last
        lda obstacles + OB_STRIDE, y
        sta obstacles, y
        iny
        jmp @shift
@last:
        lda #$FF
        sta obstacles + OBTYPE, y
        lda #0
        sta obstacles + OBX_HI, y
        dec ob_count
        jmp @loop
@next:
        lda tmpE
        clc
        adc #OB_STRIDE
        sta tmpE
        jmp @loop

@spawn_check:
        lda run_frames+1
        bne @grace_ok
        lda run_frames
        cmp #180
        bcc @done
@grace_ok:
        lda ob_count
        beq @spawn
        ; last obstacle x + width + gap < 600?
        lda ob_count
        sec
        sbc #1
        asl a
        asl a
        asl a
        tax
        jsr ob_width2           ; A = width
        clc
        adc obstacles + OBX_LO, x
        sta temp16
        lda #0
        adc obstacles + OBX_HI, x
        sta temp16+1
        lda obstacles + OBGAP_LO, x
        clc
        adc temp16
        sta temp16
        lda obstacles + OBGAP_HI, x
        adc temp16+1
        sta temp16+1
        lda temp16+1
        cmp #>640
        bcc @spawn
        bne @done
        lda temp16
        cmp #<640
        bcc @spawn
@done:
        rts
@spawn:
        jsr spawn_obstacle
        rts
.endproc

; ---------------------------------------------------------------------------
; spawn_obstacle
; ---------------------------------------------------------------------------
.proc spawn_obstacle
        ldx #0
@retry:
        jsr rng_next
        and #3
        cmp #3
        beq @retry
        sta tmpA
        cmp #OB_PTERO
        bne @not_ptero
        ; min speed 8.5
        lda speed_88+1
        cmp #8
        bcc @bump
        bne @not_ptero
        lda speed_88
        cmp #$80
        bcc @bump
@not_ptero:
        lda tmpA
        cmp ob_last_type
        bne @type_ok
        cmp ob_last_type+1
        bne @type_ok
@bump:
        inx
        cpx #4
        bcc @retry
        lda #OB_CACT_SMALL
        sta tmpA
@type_ok:
        ldy ob_last_type
        sty ob_last_type+1
        lda tmpA
        sta ob_last_type

        lda ob_count
        cmp #OB_SLOTS
        bcc @slot_free
        jmp @full
@slot_free:
        asl a
        asl a
        asl a
        tax
        inc ob_count

        lda tmpA
        sta obstacles + OBTYPE, x

        ; size 1..3 (weighted like original: uniform)
        jsr rng_next
        and #3
        beq @one
        cmp #3
        beq @three
        lda #2
        jmp @sz
@one:   lda #1
        jmp @sz
@three: lda #3
@sz:
        sta tmpB
        ; multipleSpeed gate
        lda tmpA
        cmp #OB_CACT_SMALL
        beq @ms4
        cmp #OB_CACT_LARGE
        beq @ms7
        jmp @force1             ; ptero always 1
@ms4:   lda #4
        jmp @msc
@ms7:   lda #7
@msc:
        sta tmpC
        lda tmpB
        cmp #2
        bcc @sz_done
        lda speed_88+1
        cmp tmpC
        bcc @force1
        jmp @sz_done
@force1:
        lda #1
        sta tmpB
@sz_done:
        lda tmpB
        sta obstacles + OBSIZE, x

        ; x = 600 + base width
        lda tmpA
        cmp #OB_CACT_SMALL
        beq @bw17
        cmp #OB_CACT_LARGE
        beq @bw25
        lda #46
        jmp @bw
@bw17:  lda #17
        jmp @bw
@bw25:  lda #25
@bw:
        sta tmpC
        ; spawn at 640 (not 600): 600+w maps to screen x 256..287, already
        ; inside the column-stream window, so the first columns could stream
        ; before the obstacle exists. 640 keeps spawns 2+ columns ahead of
        ; the leading edge; the spawn threshold matches, so gaps are
        ; unchanged - the whole pipeline just sits 40 world px further right.
        lda #<640
        clc
        adc tmpC
        sta obstacles + OBX_LO, x
        lda #>640
        adc #0
        sta obstacles + OBX_HI, x

        ; ptero extras
        lda tmpA
        cmp #OB_PTERO
        bne @cactus
        jsr rng_next
        and #3
        beq @y100
        cmp #3
        beq @y50
        lda #75
        jmp @sety
@y100:  lda #100
        jmp @sety
@y50:   lda #50
@sety:
        sta obstacles + OBY, x
        jsr rng_next
        and #$80
        ora #10
        sta obstacles + OBANIM, x
        jmp @gap
@cactus:
        ; Latch the nametable column range NOW, while the cactus is still
        ; 2+ columns right of the streaming edge. The streamer compares the
        ; leading column against this fixed range - deriving the column from
        ; the moving x every event raced the 8px grid and randomly skipped
        ; the only paint event a 1-column cactus gets (invisible cactus).
        ; OBY = start column (0-63), OBANIM = width in columns.
        lda obstacles + OBX_LO, x
        sta temp16
        lda obstacles + OBX_HI, x
        sta temp16+1
        txa
        pha
        ldx temp16+1
        lda mult109_lo, x       ; hi*109 (fits: <=327 uses hi=0..2 -> <=218)
        ldx temp16
        clc
        adc mult109_hi, x       ; + (lo*109)>>8
        sta tmpD                ; screen x lo
        lda #0
        adc #0
        sta tmpE                ; screen x hi
        lda col_stream
        clc
        adc tmpD
        sta tmpD
        lda col_stream+1
        adc tmpE
        asl a
        asl a
        asl a
        asl a
        asl a
        sta tmpE
        lda tmpD
        lsr a
        lsr a
        lsr a
        ora tmpE
        and #63
        sta tmpD                ; absolute start column
        pla
        tax
        lda tmpD
        sta obstacles + OBY, x
        ; width in columns: small = size, large = size*2
        lda tmpA
        cmp #OB_CACT_LARGE
        bne @wc_small
        lda tmpB
        asl a
        jmp @wc
@wc_small:
        lda tmpB
@wc:
        sta obstacles + OBANIM, x
@gap:
        ; minGap = round(width*speed) + round(minGapType*0.6)
        ; width*speed (16-bit) = width*speed_hi + (width*speed_lo)>>8
        jsr ob_width2           ; A = width
        sta tmpB
        ; part1 = width * speed_88_hi (16-bit)
        lda #0
        sta temp16
        sta temp16+1
        ldy tmpB
@acc1:
        tya
        beq @acc1d
        lda temp16
        clc
        adc speed_88+1
        sta temp16
        lda temp16+1
        adc #0
        sta temp16+1
        dey
        jmp @acc1
@acc1d:
        ; part2 = (width * speed_88_lo) >> 8
        lda #0
        sta tmpC                ; 16-bit accum in tmpC:tmpD
        sta tmpD
        ldy tmpB
@acc2:
        tya
        beq @acc2d
        lda tmpC
        clc
        adc speed_88
        sta tmpC
        lda tmpD
        adc #0
        sta tmpD
        dey
        jmp @acc2
@acc2d:
        ; total = temp16 + tmpD (tmpC is the fraction)
        lda temp16
        clc
        adc tmpD
        sta temp16
        lda temp16+1
        adc #0
        sta temp16+1            ; temp16 = round(width*speed)
        ; + type min gap
        lda tmpA
        cmp #OB_PTERO
        beq @gp
        lda #73
        jmp @ga
@gp:    lda #90
@ga:
        clc
        adc temp16
        sta temp16
        lda temp16+1
        adc #0
        sta temp16+1            ; temp16 = minGap
        ; maxGap = minGap * 1.5 (16-bit)
        lda temp16+1
        lsr a
        sta tmpD
        lda temp16
        ror a
        sta tmpC                ; tmpCD = minGap/2
        lda temp16
        clc
        adc tmpC
        sta tmpC
        lda temp16+1
        adc tmpD
        sta tmpD                ; tmpCD = maxGap
        ; range = max-min+1
        lda tmpC
        sec
        sbc temp16
        sta tmpC
        lda tmpD
        sbc temp16+1
        sta tmpD
        lda tmpC
        clc
        adc #1
        sta tmpC
        lda tmpD
        adc #0
        sta tmpD                ; tmpCD = range (1..~800)
        ; rand16 % range: use 16-bit rand
        jsr rng_next
        sta tmpB                ; rand lo
        jsr rng_next
        and #3                  ; rand hi (0-3) => rand16 < 1024
        sta tmpE
        ; mod: while (tmpE:tmpB >= range) subtract
@mod:
        lda tmpE
        cmp tmpD
        bcc @mod_done
        bne @mod_sub
        lda tmpB
        cmp tmpC
        bcc @mod_done
@mod_sub:
        lda tmpB
        sec
        sbc tmpC
        sta tmpB
        lda tmpE
        sbc tmpD
        sta tmpE
        jmp @mod
@mod_done:
        ; gap = minGap + rand%range
        lda temp16
        clc
        adc tmpB
        sta obstacles + OBGAP_LO, x
        lda temp16+1
        adc tmpE
        sta obstacles + OBGAP_HI, x
@full:
        rts
.endproc

; ---------------------------------------------------------------------------
; update_clouds - slow parallax drift in 8.8 fixed point
; CLX_HI = integer screen x, CLX_LO = fraction. Spawn at the right edge
; (x=248, parts clipped in by oam_clouds), drift left at speed/32 px/frame,
; recycle the slot once past the left edge. High sky band y 40..87 keeps
; clouds off the ptero/dino scanlines (no 8-sprites-per-line dropout).
; ---------------------------------------------------------------------------
.proc update_clouds
        ; drift this frame = speed/32, in 1/256 px units
        lda speed_88
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        sta tmpB
        lda speed_88+1
        asl a
        asl a
        asl a
        ora tmpB
        sta tmpB
        ldx #0
@loop:
        cpx #CL_STRIDE * CLOUD_MAX
        bcs @spawn
        lda clouds + CLY, x
        cmp #$FF
        beq @next
        lda clouds + CLX_LO, x
        sec
        sbc tmpB
        sta clouds + CLX_LO, x
        lda clouds + CLX_HI, x
        sbc #0
        sta clouds + CLX_HI, x
        bcs @chk_gone
        ; borrow: crossed below x=0. Mark the cloud as "leaving" in CLY
        ; bit7 - x values alone are ambiguous ($F8 = spawn 248 OR -8), so
        ; the sign must be tracked explicitly.
        lda clouds + CLY, x
        ora #$80
        sta clouds + CLY, x
@chk_gone:
        lda clouds + CLY, x
        bpl @next               ; not leaving: alive on screen
        lda clouds + CLX_HI, x
        cmp #$F0
        bcc @kill               ; below -16: every part is off/masked, recycle
        jmp @next
@kill:
        stx tmpF                ; compact slots from this one up
@ksh:
        cpx #CL_STRIDE * (CLOUD_MAX - 1)
        bcs @klast
        lda clouds + CL_STRIDE, x
        sta clouds, x
        inx
        jmp @ksh
@klast:
        lda #$FF
        sta clouds + CLY, x
        dec cloud_count
        ldx tmpF
        jmp @loop               ; re-examine: shifted-in cloud, unmoved
@next:
        txa
        clc
        adc #CL_STRIDE
        tax
        jmp @loop
@spawn:
        lda cloud_count
        cmp #CLOUD_MAX
        bcs @done
        jsr rng_next
        bmi @maybe
        rts
@maybe:
        lda cloud_count
        beq @go
        ; spacing: last cloud must have drifted its gap from the right edge
        sec
        sbc #1
        asl a
        asl a
        tax
        lda clouds + CLGAP, x
        eor #$FF
        sec
        adc #0                  ; 256 - gap
        cmp clouds + CLX_HI, x
        bcc @done               ; last_x > 256-gap: too close to the edge
@go:
        lda cloud_count
        asl a
        asl a
        tax
        inc cloud_count
        lda #0
        sta clouds + CLX_LO, x
        lda #248
        sta clouds + CLX_HI, x
        ; y: high sky band 40..87
        jsr rng_next
        and #63
        cmp #48
        bcc :+
        sbc #48
:       clc
        adc #40
        sta clouds + CLY, x
        jsr rng_next
        and #127
        clc
        adc #43
        sta clouds + CLGAP, x
@done:
        rts
.endproc

; ---------------------------------------------------------------------------
; check_collision - carry set = crash
; ---------------------------------------------------------------------------
.proc check_collision
        lda dino_y88+1
        sta dinoy
        lda #0
        sta tmpE
@ob_loop:
        ldx tmpE
        cpx #OB_STRIDE * OB_SLOTS
        bcs @no_crash
        lda obstacles + OBTYPE, x
        cmp #$FF
        beq @next
        ; quick reject on x: hit window is ob.x in [50-w, 109]
        lda obstacles + OBX_HI, x
        bmi @next
        beq @lo
        cmp #1
        bne @next
        lda obstacles + OBX_LO, x
        cmp #109
        bcs @next
        jmp @test
@lo:
        ; ob.x+width >= 50 ?
        jsr ob_width2
        clc
        adc obstacles + OBX_LO, x
        cmp #50
        bcc @next
@test:
        jsr collide_obstacle
        bcs @crash
@next:
        lda tmpE
        clc
        adc #OB_STRIDE
        sta tmpE
        jmp @ob_loop
@no_crash:
        clc
        rts
@crash:
        sec
        rts
.endproc

; ---------------------------------------------------------------------------
; collide_obstacle - slot X vs dino. Carry set = hit.
; Iterates trex boxes x obstacle boxes with a clean AABB.
; ---------------------------------------------------------------------------
.proc collide_obstacle
        lda dino_flags
        and #2
        bne @duck
        lda #6
        sta trex_box_count
        lda #<trex_run_boxes
        sta temp_ptr
        lda #>trex_run_boxes
        sta temp_ptr+1
        jmp @go
@duck:
        lda #1
        sta trex_box_count
        lda #<trex_duck_box
        sta temp_ptr
        lda #>trex_duck_box
        sta temp_ptr+1
@go:
@tbox_loop:
        ldy #0
        lda (temp_ptr), y
        clc
        adc #50
        sta a_bx
        iny
        lda (temp_ptr), y
        clc
        adc dinoy
        sta a_by
        iny
        lda (temp_ptr), y
        sta a_bw
        iny
        lda (temp_ptr), y
        sta a_bh
        ; choose obstacle box table
        lda obstacles + OBTYPE, x
        cmp #OB_CACT_SMALL
        beq @cs
        cmp #OB_CACT_LARGE
        beq @cl
        lda #<ptero_boxes
        sta temp16
        lda #>ptero_boxes
        sta temp16+1
        lda #5
        sta ob_box_count
        lda #0                  ; obstacle world y comes from OBY
        jmp @set
@cs:
        lda #<cact_s_boxes
        sta temp16
        lda #>cact_s_boxes
        sta temp16+1
        lda #3
        sta ob_box_count
        jmp @set
@cl:
        lda #<cact_l_boxes
        sta temp16
        lda #>cact_l_boxes
        sta temp16+1
        lda #3
        sta ob_box_count
@set:
        lda #0
        sta ob_box_idx
@obox_loop:
        lda ob_box_idx
        asl a
        asl a
        tay
        lda (temp16), y
        sta b_bxr               ; rel x
        iny
        lda (temp16), y
        sta b_by                ; rel y
        iny
        lda (temp16), y
        sta b_bw
        iny
        lda (temp16), y
        sta b_bh
        ; cactus size>1 box adjustments
        lda obstacles + OBTYPE, x
        cmp #OB_PTERO
        beq @no_adj
        lda obstacles + OBSIZE, x
        cmp #1
        beq @no_adj
        jsr ob_width2           ; A = total width
        sta ob_totw
        lda ob_box_idx
        cmp #1
        bne @adj2
        ; box1.w = totalW - box0.w - box2.w
        ldy #2
        lda (temp16), y         ; box0.w
        sta tmpB
        ldy #10
        lda (temp16), y         ; box2.w
        clc
        adc tmpB
        sta tmpB
        lda ob_totw
        sec
        sbc tmpB
        sta b_bw
        jmp @no_adj
@adj2:
        cmp #2
        bne @no_adj
        ; box2.x = totalW - box2.w
        ldy #10
        lda (temp16), y
        sta tmpB
        lda ob_totw
        sec
        sbc tmpB
        sta b_bxr
@no_adj:
        ; obstacle world y
        lda obstacles + OBTYPE, x
        cmp #OB_PTERO
        beq @py
        cmp #OB_CACT_SMALL
        beq @sy
        lda #90
        jmp @yy
@sy:    lda #105
        jmp @yy
@py:    lda obstacles + OBY, x
@yy:
        clc
        adc b_by
        sta b_by
        ; abs x (16-bit)
        lda b_bxr
        clc
        adc obstacles + OBX_LO, x
        sta b_bx
        lda #0
        adc obstacles + OBX_HI, x
        sta b_bx_hi
        ; ---- AABB ----
        ; overlap iff b.x < a.x+a.w && a.x < b.x+b.w && b.y < a.y+a.h && a.y < b.y+b.h
        ; 1) b.x < a.x + a.w  (b.x is 16-bit, a.x+a.w <= 255)
        lda a_bx
        clc
        adc a_bw
        sta tmpB                ; a.x+a.w (lo)
        lda #0
        sta tmpC                ; hi
        lda b_bx_hi
        cmp tmpC
        bcc @c1ok               ; b.hi < a.hi -> true
        bne @next_box           ; b.hi > 0 -> false
        lda b_bx
        cmp tmpB
        bcs @next_box
@c1ok:
        ; 2) a.x < b.x + b.w
        lda b_bx
        clc
        adc b_bw
        sta tmpB
        lda b_bx_hi
        adc #0
        sta tmpC
        lda tmpC
        bne @c2ok               ; b.x+b.w >= 256 > a.x -> true
        lda a_bx
        cmp tmpB
        bcs @next_box
@c2ok:
        ; 3) b.y < a.y + a.h
        lda a_by
        clc
        adc a_bh
        cmp b_by
        bcc @next_box
        beq @next_box
        ; 4) a.y < b.y + b.h
        lda b_by
        clc
        adc b_bh
        cmp a_by
        bcc @next_box
        beq @next_box
        sec
        rts
@next_box:
        inc ob_box_idx
        lda ob_box_idx
        cmp ob_box_count
        bcs @tbox_next
        jmp @obox_loop
@tbox_next:
        lda temp_ptr
        clc
        adc #4
        sta temp_ptr
        lda temp_ptr+1
        adc #0
        sta temp_ptr+1
        dec trex_box_count
        beq @miss
        jmp @tbox_loop
@miss:
        clc
        rts
.endproc

; ---------------------------------------------------------------------------
; roll_night_sky - pick fixed screen positions for the sprite moon + stars.
; They stay put for the whole night (drawn by oam_night); the world scrolls
; underneath and clouds drift past in front of the moon.
; ---------------------------------------------------------------------------
.proc roll_night_sky
        jsr rng_next
        and #31
        clc
        adc #168
        sta moon_x              ; 168-199 (right side of the sky)
        jsr rng_next
        and #15
        clc
        adc #24
        sta moon_y              ; 24-39
        jsr rng_next
        and #63
        clc
        adc #24
        sta star1_x             ; 24-87
        jsr rng_next
        and #7
        clc
        adc #20
        sta star1_y             ; 20-27
        jsr rng_next
        and #31
        clc
        adc #104
        sta star2_x             ; 104-135
        jsr rng_next
        and #7
        clc
        adc #22
        sta star2_y             ; 22-29
        rts
.endproc
