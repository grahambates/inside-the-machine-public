PART=tunnel
deps= \
	data/tex.rgb \
	data/tcmm_M_tunnel_UVL_150x110_t64_Delta.bin \
	$(shell $(SEQ) -f "data/sa_M_jogger/%04g.ASP" 0001 0031) \

include ../../part.mk

data/sa_M_jogger/%.ASP : assets/sa_M_jogger/%.png
	$(KINGCON) $< $(patsubst %.ASP,%,$@) -F=a16

tex=assets/tex.png

data/tex-pal.png: $(tex) 
	$(MAGICK) $< -depth 4 $@
data/tex.png: $(tex) data/tex-pal.png
	$(MAGICK) $< -resize 64x64 -dither FloydSteinberg -remap data/tex-pal.png $@

%.rgba: %.png
	$(MAGICK) $^ -depth 4 $@
%.rgb: %.rgba ../../scripts/rgba.js
	node ../../scripts/rgba.js $< $@

data/%.bin: assets/%.ggb ../../scripts/table2code-4x4.js
	node ../../scripts/table2code-4x4.js $< $@
