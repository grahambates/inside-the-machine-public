PART=roto
deps= \
	data/tex.rgbs \
	data/side-man.ASP data/side-man.PAL \

include ../../part.mk

tex=assets/tex.png

data/tex-pal.png: $(tex) 
	$(MAGICK) $< -depth 4 $@
data/tex.png: $(tex) data/tex-pal.png
	$(MAGICK) $< -resize 128x128 -dither FloydSteinberg -remap data/tex-pal.png $@

data/side-man.PAL data/side-man.ASP : assets/side-man.png Makefile
	$(KINGCON) $< data/side-man -F=a16 -SX=126 -SY=66 -RP

data/%.rgbs: data/%.png ../../scripts/scramble-png.js
	node ../../scripts/scramble-png.js $< $@
