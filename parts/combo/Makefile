PART=combo
deps= \
	data/torus-6x4q.i \
	data/ico.i \
	data/bgtex.rgb \
	data/texshade.rgbs \
	data/tek.SPR \
	../../common/table-4x4.asm \
	../../common/3d.asm

include ../../part.mk

bgtex = assets/bgtex.png
objtex = assets/objtex.png

data/bgtex-pal.png: $(bgtex) 
	$(MAGICK) $< -depth 4 $@
data/bgtex.png: $(bgtex) data/bgtex-pal.png
	$(MAGICK) $< -resize 64x64 -dither FloydSteinberg -remap data/bgtex-pal.png $@

data/objtex-pal.png: $(objtex) 
	$(MAGICK) $< -depth 4 $@
data/objtex.png: $(objtex) data/objtex-pal.png
	$(MAGICK) $< -resize 128x128 -dither FloydSteinberg -remap data/objtex-pal.png $@

data/%.rgbs: assets/%.png ../../scripts/scramble-png.js
	node ../../scripts/scramble-png.js $< $@

%.rgba: %.png
	$(MAGICK) $^ -depth 4 $@

%.rgb: %.rgba ../../scripts/rgba.js
	node ../../scripts/rgba.js $< $@

data/%.norm.i: assets/%.obj ../../scripts/objconv.js
	node ../../scripts/objconv.js $< $@ --normals

data/%.i: assets/%.obj ../../scripts/objconv.js
	node ../../scripts/objconv.js $< $@

data/tek.SPR : assets/tek.png Makefile
	$(KINGCON) $< data/tek -F=s16 -SX=126 -SY=66
