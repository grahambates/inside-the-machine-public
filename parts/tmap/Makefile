PART=tmap
deps= \
			../../common/c2p-4x4.asm \
			data/torus-8x4q.norm.i \
			data/objtex.rgbs \
			data/texshade.rgbs

include ../../part.mk

data/%.rgbs: assets/%.png ../../scripts/scramble-png.js
	node ../../scripts/scramble-png.js $< $@

data/%.norm.i: assets/%.obj ../../scripts/objconv.js
	node ../../scripts/objconv.js $< $@ --normals

data/%.i: assets/%.obj ../../scripts/objconv.js
	node ../../scripts/objconv.js $< $@
