PART=circuit
deps= \
			 data/circuit-dots.BPL \
			 data/steffest.i \
			 data/steffest.BPL \
			 data/steffest.PAL \

include ../../part.mk

data/circuit-dots.BPL : assets/circuit-dots.png
	$(KINGCON) $< data/circuit-dots -F=1

data/%.i: ../../scripts/circuit.js assets/%.json
	node $^  $@

data/steffest.BPL data/steffest.PAL : assets/steffest.png
	$(KINGCON) $< data/steffest -F=3 -RP

