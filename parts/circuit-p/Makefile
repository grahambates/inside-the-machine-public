PART=circuit
deps= \
			 data/circuit-dots.BPL \
			 data/pellicus.i \
			 data/pellicus.BPL \
			 data/pellicus.PAL \

include ../../part.mk

data/circuit-dots.BPL : assets/circuit-dots.png
	$(KINGCON) $< data/circuit-dots -F=1

data/%.i: ../../scripts/circuit.js assets/%.json
	node $^ $@

data/pellicus.BPL data/pellicus.PAL : assets/pellicus.png
	$(KINGCON) $< data/pellicus -F=3 -RP

