; PLaTOS 2.0 (22-May-23) by Chris 'platon42' Hodges (unless stated).

        ; link all parts together depending on the settings

        include "../framework/framework.i"

        IF      FW_STANDALONE_FILE_MODE
        include "../framework/os_startupcode.asm"
        ELSE
        include "../framework/trackmo_startupcode.asm"
        ENDC

        include "../framework/framework_misc.asm"

        IF      FW_MULTITASKING_SUPPORT
        include "../framework/framework_tasks.asm"
        ENDC

        IF      FW_BLITTERQUEUE_SUPPORT
        include "../framework/framework_blitterqueue.asm"
        ENDC

        IF      FW_DYNAMIC_MEMORY_SUPPORT
        include "../framework/framework_memory.asm"
        ENDC

        IF      FW_MUSIC_SUPPORT
        include "../framework/framework_music.asm"
        ENDC

        IF      FW_MULTIPART_SUPPORT
        include "../framework/framework_multipart.asm"
        ENDC

        IF      FW_SINETABLE_SUPPORT
        include "../framework/framework_sinetable.asm"
        ENDC

        IF      FW_SCRIPTING_SUPPORT
        include "../framework/framework_scripting.asm"
        ENDC

        IF      FW_PALETTE_LERP_SUPPORT
        include "../framework/framework_palettelerp.asm"
        ENDC

        IFEQ    FW_STANDALONE_FILE_MODE
        include "../framework/framework_trackloader.asm"
        include "../framework/framework_dos.asm"
        ELSE
        IF      FW_HD_TRACKMO_MODE
        include "../framework/framework_hdloader.asm"
        include "../framework/framework_dos.asm"
        ENDC
        ENDC

        IF      FW_MUSIC_SUPPORT
        IFNE    FW_MUSIC_PLAYER_CHOICE==0
        include "../framework/musicplayers/player_none.asm"
        ENDC
        IFNE    FW_MUSIC_PLAYER_CHOICE==1
        include "../framework/musicplayers/player_lsp_vbl.asm"
        ENDC
        IFNE    FW_MUSIC_PLAYER_CHOICE==2
        include "../framework/musicplayers/player_lsp_cia.asm"
        ENDC
        IFNE    FW_MUSIC_PLAYER_CHOICE==3
        fail    "Sorry, P61 not ported to this framework (yet). Use LSP instead."
        ENDC
        IFNE    (FW_MUSIC_PLAYER_CHOICE==4)|(FW_MUSIC_PLAYER_CHOICE==5)
        ;include "../framework/musicplayers/player_pretracker_std.asm"
        include "../framework/musicplayers/player_raspberry_casket.asm"
        ENDC
        ENDC

        IF      FW_LZ4_SUPPORT
fw_DecompressLZ4:
        include "../framework/unpackers/lz4_normal.asm"
        ENDC
        IF      FW_ZX0_SUPPORT
fw_DecompressZX0:
        ;include "../framework/unpackers/zx0.asm"
        include "../framework/unpackers/zx0_faster.asm"
        ENDC
        IF      FW_DOYNAX_SUPPORT
fw_DecompressDoynax:
        include "../framework/unpackers/doynax.asm"
        ENDC

        include "../framework/framework_chip_section.asm"

        IF      FW_STANDALONE_FILE_MODE
        ; framework structure is allocated from RAM and pointer is placed here
        ; for IRQ routines to access it.
fw_BasePtr:
        dc.l    0

        ELSE
        ; framework structure is stored here with a minimal LVO table.
        ; Pointer to base is stored here for IRQ routines to access it.
fw_BasePtr:
        dc.l    0

        bra.w   fw_InitPart     ; make init part reachable from base framework
        nop
fw_Base:
        ds.b    fw_SIZEOF
        ENDC
