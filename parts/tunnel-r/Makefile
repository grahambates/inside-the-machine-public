PART=tunnel-r
deps= \
	data/tex1.chk \
	data/tex2.chk \
	data/tex3.chk \
	data/tex1.pal \
	data/arms-160.ggb \
	../../common/c2p-2x2.asm \
	../../common/table-2x2.asm

include ../../part.mk

data/%.ggb: ../../scripts/uvtable-noshade-64.js assets/%.png
	node $^ $@

data/%.chk: assets/%.png
	$(AMIGECONV) -f chunky $< $@

data/%.pal: assets/%.png
	$(AMIGECONV) -f palette -p pal4 $< $@
