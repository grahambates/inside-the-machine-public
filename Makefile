PROG=DESiRE-InsideTheMachine
MOD=inside_the_machine
EMULATOR=amiberry

adf=dist/$(PROG).adf
exe=dist/$(PROG)-hd.exe

root_dir = .
include common.mk

music = \
	music/$(MOD).lsmusic \
	music/$(MOD).lsbank \
	music/$(MOD).lsmusic.zx0 \
	music/$(MOD).lsbank.zx0 \

outputs = \
	demo/bootblock.bin \
	demo/trackmo_launcher.bin \
	$(adf) \
	$(exe)

$(adf): $(music) parts demo/bootblock.bin demo/trackmo_launcher.bin demo/layout.txt
ifdef OS
	powershell -Command '$$env:PATH = ".\\bin\\win"; $(PLATOSADF) -ndb 4 --label INTHMACH -f $@ demo/bootblock.bin demo/layout.txt'
else
	$(PLATOSADF) -ndb 4 --label INTHMACH -f $@ demo/bootblock.bin demo/layout.txt
endif


demo/hddemo.adf: $(music) parts demo/bootblock.bin demo/hdlayout.txt
ifdef OS
	powershell -Command '$$env:PATH = ".\\bin\\win"; $(PLATOSADF) -ndb 4 --label INTHMACH -f -t $@ demo/bootblock.bin demo/hdlayout.txt'
else
	$(PLATOSADF) -ndb 4 --label INTHMACH -f -t $@ demo/bootblock.bin demo/hdlayout.txt
endif

demo/bootblock.bin: framework/bootblock.asm
	$(VASM) -m68010 -Fbin -phxass -o $@ -I../includes $<

demo/trackmo_launcher.bin: demo/trackmo_launcher.asm demo/trackmo_script.asm demo/trackmo_settings.i $(wildcard framework/*)
	$(VASM) -m68000 -Fbin -phxass -o $@ -I../includes $<

$(exe): demo/hd_launcher.asm demo/hddemo.adf demo/trackmo_script.asm demo/hdtrackmo_settings.i $(wildcard framework/*)
	$(VASM) -m68000 -Fhunkexe -kick1hunks -phxass -o $@ -I../includes $<

#-------------------------------------------------------------------------------
.PHONY: run
run: run-$(EMULATOR)

.PHONY: run-amiberry
run-amiberry: $(adf)
	$(AMIBERRY) $(AMIBERRYARGS) -s floppy0=$<

.PHONY: run-winuae
run-winuae: $(adf)
	$(WINUAE) $(WINUAEARGS) -s floppy0=$(CURDIR)/$<

.PHONY: run-fsuae
run-fsuae: $(adf)
	$(FSUAE) $(FSUAEARGS) $<

.PHONY: run-vamiga
run-vamiga: $(adf)
	$(VAMIGA) $<

#-------------------------------------------------------------------------------
.PHONY: runhd
runhd: runhd-$(EMULATOR)

.PHONY: runhd-amiberry
runhd-amiberry: $(exe)
	$(CP) "$<" "$(hd0)/a.exe"
	$(AMIBERRY) $(AMIBERRYARGS) -s warp=true -s cycle_exact=false -s filesystem2=rw,RDH0:out:$(hd0),0

.PHONY: runhd-winuae
runhd-winuae: $(exe)
	$(CP) "$<" "$(hd0)/a.exe"
	$(WINUAE) $(WINUAEARGS) -s warp=true -s cycle_exact=false -s filesystem2=rw,RDH0:out:$(hd0),0

.PHONY: runhd-fsuae
runhd-fsuae: $(exe)
	$(CP) "$<" "$(hd0)/a.exe"
	$(FSUAE) $(FSUAEARGS) --hard_drive_0=$(hd0)

.PHONY: runhd-vamiga
runhd-vamiga: $(exe)
	$(CP) "$<" "$(hd0)/a.exe"
	$(VAMIGA) $(hd0)/a.exe

#-------------------------------------------------------------------------------
part_dirs = $(wildcard parts/*)

.PHONY: parts $(part_dirs)
parts: $(part_dirs)

$(part_dirs):
	@$(MAKE) -C $@

.PHONY: clean
clean:
	$(RM) $(music) $(outputs)
	@for part in $(part_dirs); do \
		$(MAKE) -C $$part clean; \
	done

music: $(music)
