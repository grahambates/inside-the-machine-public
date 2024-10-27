PART=title
deps= \
			data/machine-32a.BPL \
			data/machine-32b.BPL

include ../../part.mk

data/machine-32a.BPL: assets/machine-32a.png
	$(KINGCON) $< data/machine-32a -F=5 -I -RP

data/machine-32b.BPL: assets/machine-32b.png
	$(KINGCON) $< data/machine-32b -F=5 -I
