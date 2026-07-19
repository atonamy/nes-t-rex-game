; ---------------------------------------------------------------------------
; data.asm - lookup tables, strings, palettes, collision boxes
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; mult109 tables: x * 109 (for world->screen x: *109>>8)
; ---------------------------------------------------------------------------
mult109_lo:
        .repeat 256, i
        .byte <(i*109)
        .endrepeat
mult109_hi:
        .repeat 256, i
        .byte >(i*109)
        .endrepeat

; mult174_hi: (x * 174) >> 8  (for world->screen y)
mult174_hi:
        .repeat 256, i
        .byte >((i*174) & $FFFF)
        .endrepeat

; ---------------------------------------------------------------------------
; jump initial velocity by speed: vy = -(10 + speed/10), 8.8 signed
; for speed 6..13: -10.6 .. -11.3
; ---------------------------------------------------------------------------
jump_vel_lo:
        .byte $9A, $80, $66, $4D, $33, $1A, $00, $E6
jump_vel_hi:
        .byte $F5, $F5, $F5, $F5, $F5, $F5, $F5, $F5
        ; -10.6 = $F59A, -10.7 = $F580, ... -11.3 = $F4E6

; ---------------------------------------------------------------------------
; digit tiles (font glyph indices)
; ---------------------------------------------------------------------------
digit_tiles:
        .byte FONT_0, FONT_1, FONT_2, FONT_3, FONT_4
        .byte FONT_5, FONT_6, FONT_7, FONT_8, FONT_9

; ---------------------------------------------------------------------------
; sprite tile lists (pair indices from chr_map.inc)
; ---------------------------------------------------------------------------
dino_stand_tiles:
        .byte S_DINO_STAND_0, S_DINO_STAND_1, S_DINO_STAND_2
        .byte S_DINO_STAND_3, S_DINO_STAND_4, S_DINO_STAND_5
dino_runa_tiles:
        .byte S_DINO_RUN_A_0, S_DINO_RUN_A_1, S_DINO_RUN_A_2
        .byte S_DINO_RUN_A_3, S_DINO_RUN_A_4, S_DINO_RUN_A_5
dino_runb_tiles:
        .byte S_DINO_RUN_B_0, S_DINO_RUN_B_1, S_DINO_RUN_B_2
        .byte S_DINO_RUN_B_3, S_DINO_RUN_B_4, S_DINO_RUN_B_5
dino_dead_tiles:
        .byte S_DINO_DEAD_0, S_DINO_DEAD_1, S_DINO_DEAD_2
        .byte S_DINO_DEAD_3, S_DINO_DEAD_4, S_DINO_DEAD_5
dino_blink_tiles:
        .byte S_DINO_BLINK_0, S_DINO_BLINK_1, S_DINO_BLINK_2
        .byte S_DINO_BLINK_3, S_DINO_BLINK_4, S_DINO_BLINK_5
dino_ducka_tiles:
        .byte S_DINO_DUCK_A_0, S_DINO_DUCK_A_1, S_DINO_DUCK_A_2, S_DINO_DUCK_A_3
dino_duckb_tiles:
        .byte S_DINO_DUCK_B_0, S_DINO_DUCK_B_1, S_DINO_DUCK_B_2, S_DINO_DUCK_B_3
ptero_a_tiles:
        .byte S_PTERO_A_0, S_PTERO_A_1, S_PTERO_A_2
ptero_b_tiles:
        .byte S_PTERO_B_0, S_PTERO_B_1, S_PTERO_B_2
cloud_tiles:
        .byte S_CLOUD_0, S_CLOUD_1, S_CLOUD_2

; ---------------------------------------------------------------------------
; text strings (length-prefixed tile sequences)
; ---------------------------------------------------------------------------
text_runner:
        .byte 6, FONT_R, FONT_U, FONT_N, FONT_N, FONT_E, FONT_R
text_press_start:
        .byte 11, FONT_P, FONT_R, FONT_E, FONT_S, FONT_S, FONT_SP
        .byte FONT_S, FONT_T, FONT_A, FONT_R, FONT_T
text_subtitle:
        .byte 21, FONT_C, FONT_H, FONT_R, FONT_O, FONT_M, FONT_E, FONT_SP
        .byte FONT_D, FONT_I, FONT_N, FONT_O, FONT_SP, FONT_SP
        .byte FONT_N, FONT_E, FONT_S, FONT_SP, FONT_P, FONT_O, FONT_R, FONT_T
text_paused:
        .byte 6, FONT_P, FONT_A, FONT_U, FONT_S, FONT_E, FONT_D
text_devby:
        .byte 12, FONT_D, FONT_E, FONT_V, FONT_E, FONT_L, FONT_O, FONT_P
        .byte FONT_E, FONT_D, FONT_SP, FONT_B, FONT_Y
text_url1:
        .byte 19, FONT_H, FONT_T, FONT_T, FONT_P, FONT_S, FONT_COLON
        .byte FONT_SLASH, FONT_SLASH, FONT_G, FONT_I, FONT_T, FONT_H
        .byte FONT_U, FONT_B, FONT_DOT, FONT_C, FONT_O, FONT_M, FONT_SLASH
text_url2:
        .byte 22, FONT_A, FONT_T, FONT_O, FONT_N, FONT_A, FONT_M, FONT_Y
        .byte FONT_SLASH, FONT_N, FONT_E, FONT_S, FONT_DASH, FONT_T
        .byte FONT_DASH, FONT_R, FONT_E, FONT_X, FONT_DASH, FONT_G
        .byte FONT_A, FONT_M, FONT_E
text_year:
        .byte 4, FONT_2, FONT_0, FONT_2, FONT_6
text_gameover:
        .byte 16, FONT_G, FONT_SP, FONT_A, FONT_SP, FONT_M, FONT_SP, FONT_E
        .byte FONT_SP, FONT_SP, FONT_O, FONT_SP, FONT_V, FONT_SP, FONT_E
        .byte FONT_SP, FONT_R
text_restart_r0:
        .byte 5, T_RESTART_0, T_RESTART_1, T_RESTART_2, T_RESTART_3, T_RESTART_4
text_restart_r1:
        .byte 5, T_RESTART_5, T_RESTART_6, T_RESTART_7, T_RESTART_8, T_RESTART_9
text_restart_r2:
        .byte 5, T_RESTART_10, T_RESTART_11, T_RESTART_12, T_RESTART_13, T_RESTART_14
text_restart_r3:
        .byte 5, T_RESTART_15, T_RESTART_16, T_RESTART_17, T_RESTART_18, T_RESTART_19

; logo letter tile quads (T, -, R, E, X) - 4 tiles each (TL, TR, BL, BR)
logo_tiles:
        .byte LOGO_T_0, LOGO_T_1, LOGO_T_2, LOGO_T_3
        .byte LOGO_DASH_0, LOGO_DASH_1, LOGO_DASH_2, LOGO_DASH_3
        .byte LOGO_R_0, LOGO_R_1, LOGO_R_2, LOGO_R_3
        .byte LOGO_E_0, LOGO_E_1, LOGO_E_2, LOGO_E_3
        .byte LOGO_X_0, LOGO_X_1, LOGO_X_2, LOGO_X_3

; ---------------------------------------------------------------------------
; collision boxes (x, y, w, h) - original game values
; ---------------------------------------------------------------------------
trex_run_boxes:
        .byte 22, 0, 17, 16
        .byte 1, 18, 30, 9
        .byte 10, 35, 14, 8
        .byte 1, 24, 29, 5
        .byte 5, 30, 21, 4
        .byte 9, 34, 15, 4
trex_duck_box:
        .byte 1, 18, 55, 25
cact_s_boxes:
        .byte 0, 7, 5, 27
        .byte 4, 0, 6, 34
        .byte 10, 4, 7, 14
cact_l_boxes:
        .byte 0, 12, 7, 38
        .byte 8, 0, 7, 49
        .byte 13, 10, 10, 38
ptero_boxes:
        .byte 15, 15, 16, 5
        .byte 18, 21, 24, 6
        .byte 2, 14, 4, 3
        .byte 6, 10, 4, 7
        .byte 10, 8, 6, 9

; ---------------------------------------------------------------------------
; palettes
; day:   white bg, dark graphics
; night: inverted
; ---------------------------------------------------------------------------
pal_day:
        ; bg0: white bg, medium-gray main (matches original), idx2=marker (invisible)
        .byte $30, $00, $30, $10
        .byte $30, $00, $00, $10
        .byte $30, $00, $00, $10
        .byte $30, $00, $00, $10
        ; spr0 (dino/ptero): gray body, white eye
        .byte $30, $00, $30, $10
        ; spr1 (clouds): light gray
        .byte $30, $10, $00, $00
        .byte $30, $00, $30, $00
        ; spr3 (split marker): invisible
        .byte $30, $30, $30, $30

pal_night:
        .byte $0F, $30, $0F, $00
        .byte $0F, $30, $20, $00
        .byte $0F, $30, $20, $00
        .byte $0F, $30, $20, $00
        .byte $0F, $30, $0F, $20
        .byte $0F, $00, $20, $30
        ; spr2 (moon/stars): white body, soft gray terminator
        .byte $0F, $30, $00, $10
        .byte $0F, $0F, $0F, $0F

pal_table_lo:
        .byte <pal_day, <pal_night
pal_table_hi:
        .byte >pal_day, >pal_night

; ---------------------------------------------------------------------------
; NOTE period table (NTSC): C1..B7 for pulse; triangle uses same
; stored as 16-bit periods, lo/hi interleaved by octave tables below
; ---------------------------------------------------------------------------
; note index 1 = C2 ... standard table (12*8 entries), index 0 = rest
period_lo:
        .byte 0
        .byte $AD, $4D, $F3, $9D, $4C, $00, $B8, $74, $34, $F8, $BF, $89
        .byte $56, $26, $F9, $CE, $A6, $80, $5C, $3A, $1A, $FB, $DF, $C4
        .byte $AB, $93, $7C, $67, $52, $3F, $2D, $1C, $0C, $FD, $EF, $E1
        .byte $D5, $C9, $BD, $B3, $A9, $9F, $96, $8E, $86, $7E, $77, $70
        .byte $6A, $64, $5E, $59, $54, $4F, $4B, $46, $42, $3F, $3B, $38
period_hi:
        .byte 0
        .byte $06, $06, $05, $05, $05, $05, $04, $04, $04, $03, $03, $03
        .byte $03, $03, $02, $02, $02, $02, $02, $02, $02, $01, $01, $01
        .byte $01, $01, $01, $01, $01, $01, $01, $01, $01, $00, $00, $00
        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

; note names for music data
NT_C2=1
NT_CS2=2
NT_D2=3
NT_DS2=4
NT_E2=5
NT_F2=6
NT_FS2=7
NT_G2=8
NT_GS2=9
NT_A2=10
NT_AS2=11
NT_B2=12
NT_C3=13
NT_CS3=14
NT_D3=15
NT_DS3=16
NT_E3=17
NT_F3=18
NT_FS3=19
NT_G3=20
NT_GS3=21
NT_A3=22
NT_AS3=23
NT_B3=24
NT_C4=25
NT_CS4=26
NT_D4=27
NT_DS4=28
NT_E4=29
NT_F4=30
NT_FS4=31
NT_G4=32
NT_GS4=33
NT_A4=34
NT_AS4=35
NT_B4=36
NT_C5=37
NT_CS5=38
NT_D5=39
NT_DS5=40
NT_E5=41
NT_F5=42
NT_FS5=43
NT_G5=44
NT_GS5=45
NT_A5=46
NT_AS5=47
NT_B5=48
NT_C6=49
NT_CS6=50
NT_D6=51
NT_DS6=52
NT_E6=53
NT_F6=54
NT_FS6=55
NT_G6=56
NT_GS6=57
NT_A6=58
NT_AS6=59
NT_B6=60
NT_C7=61
NT_D7=63
NT_E7=65
NT_G7=68
NT_R=0

SONG_TITLE = 0
SONG_GAME = 1
SONG_GAMEOVER = 2
SONG_NONE = $FF

; ---------------------------------------------------------------------------
; music data: streams of [note, len] pairs, $FF,$FF = end (loop)
; len in frames (6 = 16th at ~150bpm)
; ---------------------------------------------------------------------------

; --- title theme: gentle loop ---
mus_title_sq1:
        .byte NT_E5,12, NT_G5,12, NT_A5,24, NT_G5,12, NT_E5,12
        .byte NT_D5,12, NT_E5,12, NT_C5,24, NT_R,12
        .byte NT_E5,12, NT_G5,12, NT_A5,24, NT_G5,12, NT_E5,12
        .byte NT_D5,12, NT_C5,12, NT_D5,36
        .byte $FF, $FF
mus_title_sq2:
        .byte NT_C4,24, NT_E4,24, NT_G4,24, NT_E4,24
        .byte NT_F4,24, NT_A4,24, NT_G4,24, NT_E4,24
        .byte NT_C4,24, NT_E4,24, NT_G4,24, NT_C5,24
        .byte NT_A4,24, NT_G4,24, NT_E4,24, NT_D4,24
        .byte $FF, $FF
mus_title_tri:
        .byte NT_C3,48, NT_A2,48, NT_F2,48, NT_G2,48
        .byte NT_C3,48, NT_A2,48, NT_F2,48, NT_G2,48
        .byte $FF, $FF
mus_title_noi:
        .byte 1,12, 1,12, 1,12, 1,12, 1,24, 1,12, 1,24
        .byte 1,12, 1,12, 1,12, 1,12, 1,24, 1,12, 1,24
        .byte $FF, $FF

; --- game theme: bouncy loop (48-frame phrases) ---
mus_game_sq1:
        .byte NT_C5,6, NT_E5,6, NT_G5,6, NT_E5,6, NT_A5,6, NT_G5,6, NT_E5,6, NT_C5,6
        .byte NT_D5,6, NT_E5,6, NT_F5,6, NT_E5,6, NT_D5,6, NT_C5,6, NT_D5,6, NT_G4,6
        .byte NT_C5,6, NT_E5,6, NT_G5,6, NT_E5,6, NT_A5,6, NT_G5,6, NT_A5,6, NT_C6,6
        .byte NT_G5,6, NT_E5,6, NT_D5,6, NT_E5,6, NT_C5,12, NT_R,12
        .byte $FF, $FF
mus_game_sq2:
        .byte NT_E4,6, NT_G4,6, NT_C5,6, NT_G4,6, NT_E4,6, NT_G4,6, NT_C5,6, NT_G4,6
        .byte NT_F4,6, NT_A4,6, NT_C5,6, NT_A4,6, NT_F4,6, NT_A4,6, NT_C5,6, NT_A4,6
        .byte NT_E4,6, NT_G4,6, NT_C5,6, NT_G4,6, NT_E4,6, NT_G4,6, NT_C5,6, NT_G4,6
        .byte NT_G4,6, NT_B4,6, NT_D5,6, NT_B4,6, NT_G4,6, NT_B4,6, NT_D5,6, NT_B4,6
        .byte $FF, $FF
mus_game_tri:
        .byte NT_C3,12, NT_G3,12, NT_C3,12, NT_G3,12
        .byte NT_F3,12, NT_C4,12, NT_F3,12, NT_C4,12
        .byte NT_C3,12, NT_G3,12, NT_C3,12, NT_G3,12
        .byte NT_G2,12, NT_D3,12, NT_G2,12, NT_D3,12
        .byte $FF, $FF
mus_game_noi:
        .byte 1,6, 2,6, 1,6, 2,6, 1,6, 2,6, 1,6, 2,6
        .byte 1,6, 2,6, 1,6, 2,6, 1,6, 2,6, 1,6, 2,6
        .byte 1,6, 2,6, 1,6, 2,6, 1,6, 2,6, 1,6, 2,6
        .byte 1,6, 2,6, 1,6, 2,6, 1,6, 2,6, 2,3, 2,3, 2,3, 2,3
        .byte $FF, $FF

; --- game over sting ---
mus_over_sq1:
        .byte NT_C5,10, NT_G4,10, NT_E4,10, NT_C4,30, NT_R,20
        .byte $FF, $FF
mus_over_sq2:
        .byte NT_E4,10, NT_C4,10, NT_G3,10, NT_E3,30, NT_R,20
        .byte $FF, $FF
mus_over_tri:
        .byte NT_C3,10, NT_C3,10, NT_G2,10, NT_C3,30, NT_R,20
        .byte $FF, $FF
mus_over_noi:
        .byte 2,10, 1,10, 1,10, 2,30, 1,20
        .byte $FF, $FF

; song pointer tables
song_sq1_lo: .byte <mus_title_sq1, <mus_game_sq1, <mus_over_sq1
song_sq1_hi: .byte >mus_title_sq1, >mus_game_sq1, >mus_over_sq1
song_sq2_lo: .byte <mus_title_sq2, <mus_game_sq2, <mus_over_sq2
song_sq2_hi: .byte >mus_title_sq2, >mus_game_sq2, >mus_over_sq2
song_tri_lo: .byte <mus_title_tri, <mus_game_tri, <mus_over_tri
song_tri_hi: .byte >mus_title_tri, >mus_game_tri, >mus_over_tri
song_noi_lo: .byte <mus_title_noi, <mus_game_noi, <mus_over_noi
song_noi_hi: .byte >mus_title_noi, >mus_game_noi, >mus_over_noi
