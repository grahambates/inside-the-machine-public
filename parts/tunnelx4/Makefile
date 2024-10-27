PART=tunnelx4
deps= \
	data/tex1.chk \
	data/tex2.chk \
	data/tex3.chk \
	data/tex1.pal \
	$(combined_sprites) \
	../../common/table-2x2.asm

orig_sprites = \
	$(shell $(SEQ) -f "data/sa_M4x_jogger/%04g.ASP" 0001 0025) \
	$(shell $(SEQ) -f "data/sa_P4x_strutter/%04g.ASP" 0001 0025) \
	$(shell $(SEQ) -f "data/sa_G4x_walker/%04g.ASP" 0001 0025) \
	$(shell $(SEQ) -f "data/sa_S4x_flyer/%04g.ASP" 0001 0025) \

combined_sprites = \
	$(shell $(SEQ) -f "data/Sprites-%04g.ASP" 0001 0025) \

include ../../part.mk

data/%.chk: assets/%.png
	$(AMIGECONV) -f chunky $< $@

data/%.pal: assets/%.png
	$(AMIGECONV) -f palette -p pal4 $< $@

data/sa_M4x_jogger/%.ASP : assets/sa_M4x_jogger/%.png Makefile
	$(KINGCON) $< $(patsubst %.ASP,%,$@) -F=a16 -SX=190 -SY=82
data/sa_S4x_flyer/%.ASP : assets/sa_S4x_flyer/%.png Makefile
	$(KINGCON) $< $(patsubst %.ASP,%,$@) -F=a16 -SX=354 -SY=137
data/sa_G4x_walker/%.ASP : assets/sa_G4x_walker/%.png Makefile
	$(KINGCON) $< $(patsubst %.ASP,%,$@) -F=a16 -SX=345 -SY=181
data/sa_P4x_strutter/%.ASP : assets/sa_P4x_strutter/%.png Makefile
	$(KINGCON) $< $(patsubst %.ASP,%,$@) -F=a16 -SX=185 -SY=230

$(combined_sprites): $(orig_sprites) scripts/sprites.js
	node scripts/sprites.js
