PART=tunnel-g
deps= \
	data/tex1.chk \
	data/tex2.chk \
	data/tex3.chk \
	data/tex1.pal \
	$(shell $(SEQ) -f "data/sa_G_walker/%04g.ASP" 0001 0026) \
	../../common/c2p-2x2.asm \
	../../common/table-2x2.asm

include ../../part.mk

data/%.chk: assets/%.png
	$(AMIGECONV) -f chunky $< $@

data/%.pal: assets/%.png
	$(AMIGECONV) -f palette -p pal4 $< $@

data/sa_G_walker/%.ASP : assets/sa_G_walker/%.png Makefile
	$(KINGCON) $< $(patsubst %.ASP,%,$@) -F=a16 -SX=227 -SY=162
# DIW:129,82
