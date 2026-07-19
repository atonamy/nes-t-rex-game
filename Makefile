# T-REX RUNNER - NES port of the Chrome dino game
# Requires: cc65 (ca65, ld65)
#
# build/trex.chr is a pre-built CHR asset (tile/sprite data compiled from
# pixel art) checked into the repo, so building the ROM needs no extra
# tooling beyond cc65.

CA65    = ca65
LD65    = ld65

ROM     = build/trex.nes
OBJ     = build/main.o
CHR     = build/trex.chr

all: $(ROM)

$(OBJ): src/main.asm src/*.asm src/*.inc $(CHR) nes.cfg
	$(CA65) -g -I src -o $(OBJ) src/main.asm

$(ROM): $(OBJ)
	$(LD65) -C nes.cfg -o $(ROM) $(OBJ) -m build/map.txt -Ln build/labels.txt
	@echo "Built $(ROM)"

run: $(ROM)
	open -a Mesen $(ROM)

clean:
	rm -f build/*.o build/*.nes build/map.txt build/labels.txt

.PHONY: all run clean
