PART=tunnel-p
deps= \
	data/tex1.chk \
	data/tex2.chk \
	data/tex3.chk \
	data/tex1.pal \
	$(shell $(SEQ) -f "data/sa_P_strutter/%04g.ASP" 0001 0026) \
	../../common/c2p-2x2.asm \
	../../common/table-2x2.asm

include ../../part.mk

data/%.chk: assets/%.png
	$(AMIGECONV) -f chunky $< $@

data/%.pal: assets/%.png
	$(AMIGECONV) -f palette -p pal4 $< $@

data/sa_P_strutter/%.ASP : assets/sa_P_strutter/%.png Makefile
	$(KINGCON) $< $(patsubst %.ASP,%,$@) -F=a16 -SX=260 -SY=121
# 129,72 DIW
# 136,65 POS
