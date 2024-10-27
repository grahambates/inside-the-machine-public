PART=motherboard
deps= \
	data/board.BPL \
	data/board.PAL \
	data/board-hot.PAL \
	data/accelerator.BPL \
	data/accelerator-mask.BPL \
	data/burn-mask.BPL \
	data/sparkle1.ASP \
	data/sparkle2.ASP \
	data/sparkle3.ASP \
	data/acc-sparkle1.BPL \
	data/acc-sparkle2.BPL \
	data/acc-sparkle3.BPL \
	$(shell $(SEQ) -f "data/burn/%02g.BPL" 01 14) \

include ../../part.mk

data/%.BPL : assets/%.png
	$(KINGCON) $< $(patsubst %.BPL,%,$@) -F=5 -I

data/%.PAL : assets/%.png
	$(KINGCON) $< $(patsubst %.PAL,%,$@) -F=5 -I -RP

data/%.ASP : assets/%.png
	$(KINGCON) $< $(patsubst %.ASP,%,$@) -F=a16
