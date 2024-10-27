root_dir = ../..
include ../../common.mk

BUILD=hunkexe
sources = $(PART).asm $(PART).i $(deps) $(root_dir)/demo/timings.i

#-------------------------------------------------------------------------------
.PHONY: bin
bin: out/a.bin out/a.hd.bin

#-------------------------------------------------------------------------------
.PHONY: hunkexe
hunkexe: out/a.hunk.exe out/a.debug.exe
	$(CP) "$<" "$(hd0)/a.exe"

#-------------------------------------------------------------------------------
.PHONY: elfexe
elfexe: out/a.exe
	$(CP) "$<" "$(hd0)/a.exe"

#-------------------------------------------------------------------------------
.PHONY: run
run: run-$(EMULATOR)

.PHONY: run-amiberry
run-amiberry: $(BUILD)
	$(AMIBERRY) $(AMIBERRYARGS) -s warp=true -s cycle_exact=false -s filesystem2=rw,RDH0:out:$(hd0),0

.PHONY: run-winuae
run-winuae: $(BUILD)
	$(WINUAE) $(WINUAEARGS) -s warp=true -s cycle_exact=false -s filesystem2=rw,RDH0:out:$(hd0),0

.PHONY: run-fsuae
run-fsuae: $(BUILD)
	$(FSUAE) $(FSUAEARGS) --hard_drive_0=$(hd0)

.PHONY: run-vamiga
run-vamiga: $(BUILD)
	$(VAMIGA) $(hd0)/a.exe

#-------------------------------------------------------------------------------
.PHONY: clean
clean:
	$(RM) $(wildcard out/*.*) $(wildcard data/*.*)

-include $(wildcard out/*.d)

#-------------------------------------------------------------------------------
# Trackmo build

out/$(PART).o: $(sources)
	$(VASM) $(VASMARGS) -depend=make -depfile $@.d -Fhunk -DFW_DEMO_PART -o $@ $<

out/a.bin: out/$(PART).o
	$(VLINK) $(VLINKARGS) -o $@ $<

#-------------------------------------------------------------------------------
# HD build

out/$(PART).hd.o: $(sources)
	$(VASM) $(VASMARGS) -depend=make -depfile $@.d -Fhunk -DFW_DEMO_PART -DFW_HD_DEMO_PART -o $@ $<

out/a.hd.bin: out/$(PART).hd.o
	$(VLINK) $(VLINKARGS) -o $@ $<

#-------------------------------------------------------------------------------
# Hunk exe build

out/a.hunk.exe: $(sources)
	$(VASM) $(VASMARGS) -depend=make -depfile $@.d -Fhunkexe -kick1hunks -o $@ $<

out/a.debug.exe: $(sources)
	$(VASM) $(VASMARGS) -depend=make -depfile $@.d -Fhunkexe -kick1hunks -linedebug -o $@ $<

#-------------------------------------------------------------------------------
# Elf2Hunk exe build (Bartman debugger)

out/$(PART).elf: $(sources)
	$(VASM) $(VASMARGS) -depend=make -depfile $@.d -Felf -dwarf=3 -o $@ $<

out/a.elf: out/$(PART).elf
	$(CC) $(CCFLAGS) $(LDFLAGS) $< -o $@

out/a.exe: out/a.elf
	$(ELF2HUNK) $< $@ -s
