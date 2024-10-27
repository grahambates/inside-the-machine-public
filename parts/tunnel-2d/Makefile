PART=tunnel-2d
deps= \
	data/tunnel.BPL \
			 $(shell $(SEQ) -f "data/runner/%02g.SPR" 01 15) \

include ../../part.mk

data/tunnel.BPL : assets/tunnel-reordered.png
	$(KINGCON) $< data/tunnel -F=5 -I

data/runner/%.SPR : assets/runner/%.png Makefile
	$(KINGCON) $< $(patsubst %.SPR,%,$@) -F=s16 -SX=286 -SY=122
# 157+129, 78+44
