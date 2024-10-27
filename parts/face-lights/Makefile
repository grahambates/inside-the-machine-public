PART=face-lights
deps= \
	data/face-160.bin \
	data/phong-x4.chk \
	data/phong-x4.pal \
	data/light-32.SPR \
	../../common/table-2x2.asm

include ../../part.mk

data/face-160.bin: ../../scripts/uvtable-noshade.js assets/face-160.png
	node $^ $@

data/phong-x4.chk: assets/phong-x4.png
	$(AMIGECONV) -f chunky $< $@
data/phong-x4.pal: assets/phong-x4.png
	$(AMIGECONV) -f palette -p pal4 $< $@

data/light-32.SPR : assets/light-32.png
	$(KINGCON) $< data/light-32 -F=s16

