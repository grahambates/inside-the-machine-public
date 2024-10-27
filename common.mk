# Emulator options
CONFIG=a500
# winuae / amiberry config
# FS-UAE cli options
MODEL=A500
FASTMEM=0
CHIPMEM=512
SLOWMEM=512
DRIVESOUNDS=off

# Detect platform
ifdef OS
	platform=win
	SHELL=powershell.exe
	RM=cmd //C del //Q //F
	CP=copy
	path_sep=;
	EMULATOR=winuae
	SEQ=$(platform_bin)/seq.exe
else
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Linux)
		platform=linux
	endif
	ifeq ($(UNAME_S),Darwin)
		platform=mac
	endif
	wine=wine
	CP=cp -f
	pathsep=:
	EMULATOR=fsuae
	SEQ=seq
endif

bin_dir=$(root_dir)/bin
platform_bin=$(bin_dir)/$(platform)

export PATH := $(platform_bin)$(pathsep)$(PATH)

hd0 = $(realpath $(root_dir))/emulator/hd0

# Toolchain binaries:
VASM=$(platform_bin)/vasmm68k_mot
VLINK=$(platform_bin)/vlink
PLATOSADF=$(platform_bin)/platosadf
AMIGECONV=$(platform_bin)/amigeconv
SALVADOR=$(platform_bin)/salvador
KINGCON = $(platform_bin)/kingcon
# Always use windows bin for LSP - other builds currently have some issues
LSP=$(wine) $(bin_dir)/win/LSPConvert.exe
MAGICK=magick

# Emulators:
WINUAE=$(wine) $(bin_dir)/win/winuae.exe
WINUAEARGS=-s use_gui=false -s debug_mem=true --log --config=$(root_dir)/emulator/configs/$(CONFIG).uae
AMIBERRY=/Applications/Amiberry.app/Contents/MacOS/Amiberry
AMIBERRYARGS=-s use_gui=false -s debug_mem=true -s amiberry.active_capture_automatically=false -s magic_mouse=true --log --config=$(root_dir)/emulator/configs/$(CONFIG).uae
FSUAE=/Applications/FS-UAE.app/Contents/MacOS/fs-uae
FSUAEARGS=--automatic_input_grab=0 --chip_memory=$(CHIPMEM) --fast_memory=$(FASTMEM) --slow_memory=$(SLOWMEM) --amiga_model=$(MODEL) --floppy_drive_0_sounds=$(DRIVESOUNDS) --console_debugger=1
VAMIGA=/Applications/vAmiga.app/Contents/MacOS/vAmiga

# Bartman toolchain:
CC = $(platform_bin)/bartman/opt/bin/m68k-amiga-elf-gcc
ELF2HUNK = $(platform_bin)/bartman/elf2hunk

# Build args:
VASMARGS=-m68000 -allmp -I../../includes
VLINKARGS=-bamigahunk -Bstatic -s
LSPARGS=-shrink
LDFLAGS = -Wl,--emit-relocs,-Ttext=0
CCFLAGS = -g -MP -MMD -m68000 -Ofast -nostdlib -Wextra -fomit-frame-pointer -fno-tree-loop-distribution -flto -fwhole-program

%.lsbank %.lsmusic: %.mod
	$(LSP) $(LSPARGS) $<

%.zx0: %
	$(SALVADOR) -c $< $@
