PART=circuit
deps= \
			 data/circuit-dots.BPL \
			 data/gigabates.i \
			 data/gigabates.BPL \
			 data/gigabates.PAL \

include ../../part.mk

data/circuit-dots.BPL : assets/circuit-dots.png
	$(KINGCON) $< data/circuit-dots -F=1

data/%.i: ../../scripts/circuit.js assets/%.json
	node $^ $@

data/gigabates.BPL data/gigabates.PAL : assets/gigabates.png
	$(KINGCON) $< data/gigabates -F=3 -RP

