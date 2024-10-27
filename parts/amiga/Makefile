PART=amiga
deps= \
	data/amiga-original.BPL \
	data/amiga-chrome.BPL \
	data/amiga-mask-line.BPL \
	data/amiga-mask-top.BPL \
	data/amiga-mask-kb.BPL \
	data/amiga-mask-side.BPL \
	data/amiga-mask-mouse.BPL \
	data/amiga-mask-hand.BPL

include ../../part.mk

data/amiga-original.BPL : assets/amiga-original.png
	$(KINGCON) $< data/amiga-original -F=5 -I -RP
data/amiga-chrome.BPL : assets/amiga-chrome.png
	$(KINGCON) $< data/amiga-chrome -F=5 -I -RP
data/amiga-mask-line.BPL : assets/amiga-mask-line.png
	$(KINGCON) $< data/amiga-mask-line -F=1
data/amiga-mask-top.BPL : assets/amiga-mask-top.png
	$(KINGCON) $< data/amiga-mask-top -F=1
data/amiga-mask-kb.BPL : assets/amiga-mask-kb.png
	$(KINGCON) $< data/amiga-mask-kb -F=1
data/amiga-mask-side.BPL : assets/amiga-mask-side.png
	$(KINGCON) $< data/amiga-mask-side -F=1
data/amiga-mask-hand.BPL : assets/amiga-mask-hand.png
	$(KINGCON) $< data/amiga-mask-hand -F=1
data/amiga-mask-mouse.BPL : assets/amiga-mask-mouse.png
	$(KINGCON) $< data/amiga-mask-mouse -F=1
