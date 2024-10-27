PART=credits
deps= \
	../../common/cop-4x2-looped.asm \
	data/code.bin \
	data/flip.bin \
	data/ramps.bin \
	data/phong-32x32.rgbs \
	data/credit-text1.SPR \
	data/credit-text2.SPR \
	data/credit-text3.SPR \
	data/credit-text4.SPR

include ../../part.mk

data/face-steffest-pal.rgbs data/face-steffest.bin: ../../scripts/uvcols-data.js assets/face-steffest-col-16.png assets/face-steffest-uv.png
	node ../../scripts/uvcols-data.js assets/face-steffest-col-16.png assets/face-steffest-uv.png data/face-steffest-pal.rgbs data/face-steffest.bin

data/ramps.bin data/flip.bin data/code.bin: ../../scripts/uvcols-data.js assets/group-col-16.png assets/group-uv.png
	node ../../scripts/uvcols-data.js assets/group-col-16.png assets/group-uv.png data/code.bin data/ramps.bin data/flip.bin

data/%.rgbs: assets/%.png ../../scripts/scramble-png.js
	node ../../scripts/scramble-png.js $< $@

data/%.SPR : assets/%.png
	$(KINGCON) $< $(patsubst %.SPR,%,$@) -F=s16 -SX=190 -SY=80
