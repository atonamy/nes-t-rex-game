; ---------------------------------------------------------------------------
; nes.inc - NES hardware registers, constants, zeropage map
; ---------------------------------------------------------------------------

PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
OAMDATA   = $2004
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAMDMA    = $4014
APUSTATUS = $4015
JOY1      = $4016
JOY2      = $4017

; APU
SQ1_VOL   = $4000
SQ1_SWEEP = $4001
SQ1_LO    = $4002
SQ1_HI    = $4003
SQ2_VOL   = $4004
SQ2_SWEEP = $4005
SQ2_LO    = $4006
SQ2_HI    = $4007
TRI_LINEAR= $4008
TRI_LO    = $400A
TRI_HI    = $400B
NOISE_VOL = $400C
NOISE_LO  = $400E
NOISE_HI  = $400F
DMC_FREQ  = $4010

; Buttons
BTN_A      = %10000000
BTN_B      = %01000000
BTN_SELECT = %00100000
BTN_START  = %00010000
BTN_UP     = %00001000
BTN_DOWN   = %00000100
BTN_LEFT   = %00000010
BTN_RIGHT  = %00000001

; Game states
ST_TITLE = 0
ST_INTRO = 1
ST_PLAY  = 2
ST_OVER  = 3
ST_PAUSE = 4

; World constants (original game units)
WORLD_GROUND_TOP = 93        ; dino yPos (top of dino) on ground
WORLD_GROUND_BOT = 140       ; feet
WORLD_WIDTH      = 600

; NES screen constants
SCREEN_GROUND_FEET = 199     ; dino feet scanline
DINO_SCREEN_X      = 21      ; world 50 * 109/256 = 21
DINO_RUN_TOP       = 164     ; 199 - 32 - 3: feet just below the ground line
DINO_DUCK_TOP      = 180     ; 199 - 16 - 3   so they stay visible against it

; Speed: world px/frame in 8.8 fixed point. 6.0 = $0600, 13.0 = $0D00
SPEED_START_LO = $00
SPEED_START_HI = $06
SPEED_MAX_HI   = $0D

; Jump physics (8.8)
GRAVITY_LO     = $9A         ; 0.6 * 256 = 153.6 -> 154 = $9A
GRAVITY_HI     = $00
JUMP_MIN_Y     = 63          ; groundYPos - minJumpHeight = 93-30
JUMP_MAX_Y     = 30          ; endJump() auto-trigger level
DROP_VEL_HI    = $FB         ; -5 in 8.8 signed = $FB00
SPEEDDROP_MUL  = 3

; Obstacle types
OB_CACT_SMALL = 0
OB_CACT_LARGE = 1
OB_PTERO      = 2
OB_SLOTS      = 4

; obstacle record layout (8 bytes each)
OBX_LO   = 0
OBX_HI   = 1
OBTYPE   = 2
OBSIZE   = 3
OBGAP_LO = 4
OBGAP_HI = 5
OBY      = 6               ; ptero world y / cactus drawn-column count
OBANIM   = 7               ; anim timer / frame / speed-offset sign
OB_STRIDE = 8

; Clouds (4 slots x 4 bytes)
CLX_LO   = 0               ; screen x, 8.8: LO = fraction
CLX_HI   = 1               ;                HI = integer pixel (0-248)
CLY      = 2               ; screen y (top)
CLGAP    = 3               ; gap before next cloud
CL_STRIDE = 4
CLOUD_MAX = 4

; ---------------------------------------------------------------------------
; Zeropage map
; ---------------------------------------------------------------------------
.zeropage

temp_ptr:     .res 2        ; general pointer
temp16:       .res 2
tmpA:         .res 1
tmpB:         .res 1
tmpC:         .res 1
tmpD:         .res 1
tmpE:         .res 1
tmpF:         .res 1

joy_cur:      .res 1
joy_prev:     .res 1
joy_press:    .res 1
joy_release:  .res 1

game_state:   .res 1
nmi_done:     .res 1
frame16:      .res 2

scroll_x:     .res 1        ; fine X scroll (0-255)
scroll_nt:    .res 1        ; bit0 = nametable select
scroll_frac:  .res 2        ; 8.8 accumulator (px scrolled)

speed_88:     .res 2        ; world speed 8.8
accel_div:    .res 1        ; accel tick divider
run_frames:   .res 2        ; frames since game start (obstacle grace)

dino_y88:     .res 2        ; signed 8.8 world y (top of dino)
dino_vy88:    .res 2        ; signed 8.8
dino_flags:   .res 1        ; bit0 jumping bit1 ducking bit2 speeddrop
                            ; bit3 reached_min bit4 dead
dino_anim_tmr: .res 1
dino_anim_frm: .res 1
blink_tmr:    .res 1
blink_state:  .res 1

dist_frac:    .res 1        ; distance accumulator (frac)
dist_px:      .res 1        ; px toward next point (0-39)
score:        .res 5        ; decimal digits, MSD first
hiscore:      .res 5
score_flash:  .res 1        ; achievement flash timer
hiscore_dirty: .res 1

night_mode:   .res 1        ; 0=day 1=night
night_timer:  .res 2        ; frames left of night
next_night:   .res 3        ; score value (24-bit) of next invert trigger
pal_update:   .res 1        ; nonzero -> load palettes in NMI

obstacles:    .res OB_STRIDE * OB_SLOTS
ob_count:     .res 1
ob_last_type: .res 2        ; history of last 2 types (dup check)
spawn_grace:  .res 1        ; countdown before obstacles allowed

clouds:       .res CL_STRIDE * CLOUD_MAX
cloud_count:  .res 1

moon_x:       .res 1        ; night sky sprites: fixed screen positions
moon_y:       .res 1
star1_x:      .res 1
star1_y:      .res 1
star2_x:      .res 1
star2_y:      .res 1
rng16:        .res 2

vram_wptr:    .res 1        ; vram buffer write index
vram_rptr:    .res 1        ; vram buffer read index
col_stream:   .res 2        ; global column counter (for star scheduling)

over_timer:   .res 1
sfx_id:       .res 1        ; pending sfx request
music_ptr_id: .res 1
intro_x:      .res 1        ; intro run-in world x

; collision temporaries
dinoy:        .res 1
trex_box_count: .res 1
ob_box_count: .res 1
ob_box_idx:   .res 1
ob_totw:      .res 1
a_bx:         .res 1
a_by:         .res 1
a_bw:         .res 1
a_bh:         .res 1
b_bx:         .res 1
b_bx_hi:      .res 1
b_bxr:        .res 1
b_by:         .res 1
b_bw:         .res 1
b_bh:         .res 1

; APU channel state
ch1_pos:      .res 2
ch1_wait:     .res 1
ch1_vol:      .res 1
ch2_pos:      .res 2
ch2_wait:     .res 1
ch2_vol:      .res 1
tri_pos:      .res 2
tri_wait:     .res 1
noi_pos:      .res 2
noi_wait:     .res 1
noi_vol:      .res 1
sfx_timer:    .res 1
sfx_phase:    .res 1
song_id:      .res 1

pause_flag:   .res 1
sfx_own:      .res 1        ; sfx channel ownership mask
score_changed: .res 1
ob_iter:      .res 1        ; obstacle loop offset for render
dino_draw_x:  .res 1        ; dino screen x (intro run-in / play)
ppuctrl_shadow: .res 1      ; PPUCTRL is write-only; keep last written value

; panel writer (seam-aware UI text)
p_row:        .res 1        ; target nametable row
p_col:        .res 1        ; screen column
p_len:        .res 1        ; tiles remaining
p_idx:        .res 1        ; string data index
p_abs:        .res 1        ; absolute column (0-63 across both nametables)
p_seam:       .res 1        ; columns left before the nametable seam
p_lo:         .res 1        ; current vram addr
p_hi:         .res 1
p_vy:         .res 1        ; saved vram buffer index
p_mode:       .res 1        ; 1 = string via temp_ptr, 0 = fill with FONT_SP

; Exact STAR SWOOP gameplay-music state. Appended so existing gameplay ZP
; addresses remain unchanged.
star_step:       .res 1
star_wait:       .res 1
star_drum_timer: .res 1

; ---------------------------------------------------------------------------
; RAM
; ---------------------------------------------------------------------------
.segment "BSS"

oam_shadow:   .res 256      ; $0200-ish shadow OAM
vram_buf:     .res 160      ; vram write queue

; ---------------------------------------------------------------------------
; Macros
; ---------------------------------------------------------------------------

.macro LDA16 addr
        lda addr
        ldx addr+1
.endmacro

.macro STA16 addr
        sta addr
        stx addr+1
.endmacro

; add A (unsigned) to 16-bit zp var
.macro ADD_A_TO16 addr
        clc
        adc addr
        sta addr
        bcc :+
        inc addr+1
:
.endmacro
