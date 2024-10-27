PART=circuit
deps= \
			 data/circuit-dots.BPL \
			 data/ma2e.i \
			 data/ma2e.BPL \
			 data/ma2e.PAL \

include ../../part.mk

data/circuit-dots.BPL : assets/circuit-dots.png
	$(KINGCON) $< data/circuit-dots -F=1

data/%.i: ../../scripts/circuit.js assets/%.json
	node $^ $@

data/ma2e.BPL data/ma2e.PAL : assets/ma2e.png
	$(KINGCON) $< data/ma2e -F=3 -RP

