; ---------------------------------------------------------------------------
; T-REX RUNNER - NES port of the Chrome dino game
; ca65 / ld65, NROM-256 (mapper 0), vertical mirroring
; ---------------------------------------------------------------------------

.include "nes.inc"
.include "chr_map.inc"

; ---------------------------------------------------------------------------
; iNES header
; ---------------------------------------------------------------------------
.segment "HEADER"
        .byte "NES", $1A
        .byte 2                 ; 32 KB PRG-ROM
        .byte 1                 ; 8 KB CHR-ROM
        .byte %00000001         ; mapper 0, vertical mirroring
        .byte 0
        .res 8, 0

; ---------------------------------------------------------------------------
; PRG code
; ---------------------------------------------------------------------------
.segment "CODE"

.include "reset.asm"
.include "ppu.asm"
.include "input.asm"
.include "game.asm"
.include "world.asm"
.include "render.asm"
.include "audio.asm"
.include "data.asm"

; ---------------------------------------------------------------------------
; Vectors
; ---------------------------------------------------------------------------
.segment "VECTORS"
        .word nmi_handler
        .word reset_handler
        .word irq_handler

.segment "CHR"
        .incbin "../build/trex.chr"
