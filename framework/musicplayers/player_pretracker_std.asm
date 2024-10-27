        IFEQ    FW_VBL_MUSIC_IRQ
        fail    "FW_VBL_MUSIC_IRQ must be enabled"
        ENDC
        IFEQ    FW_DYNAMIC_MEMORY_SUPPORT
        fail    "FW_DYNAMIC_MEMORY_SUPPORT must be enabled"
        ENDC

fw_MusicAlloc:
        ; actually $1C6E for player (V1.0), $984 for song
        move.l  #$1C6E+$984,d0
        bsr     fw_AllocFast
        move.l  a0,fw_PretrackerMyPlayer(a6)
        lea     $1C6E(a0),a0
        move.l  a0,fw_PretrackerMySong(a6)
        rts

fw_MusicInit:
        PUTMSG  10,<"%d: Pretracker song init %p %p">,fw_FrameCounterLong(a6),a0,a1
        move.l  a0,a2
        PUSHM   d7/a1
        move.l  fw_PretrackerMyPlayer(a6),a0
        move.l  fw_PretrackerMySong(a6),a1
        PUTMSG  10,<"MyPlayer=%p MySong=%p Data=%p">,a0,a1,a2
        lea     fw_PretrackerReplayer(pc),a3
        adda.w  2(a3),a3
        jsr     (a3)        ; songInit
        POPM

        move.l  a1,d1
        bne.s   .noalloc
        PUTMSG  10,<"Allocating %ld bytes samples memory for Pretracker">,d0
        bsr     fw_AllocChip
        move.l  a0,fw_MusicSamples(a6)
        move.l  a0,a1
.noalloc

        PUTMSG  10,<"%d: Pretracker player init">,fw_FrameCounterLong(a6)
        move.l  fw_PretrackerMyPlayer(a6),a0
        move.l  fw_PretrackerMySong(a6),a2

        lea     fw_PretrackerReplayer(pc),a3
        adda.w  6(a3),a3
        jsr     (a3)        ; playerInit

        PUTMSG  10,<"%d: Pretracker init done">,fw_FrameCounterLong(a6)
        rts

fw_MusicPlay:
        move.l  fw_PretrackerMyPlayer(a6),a0
        lea     fw_PretrackerReplayer(pc),a3
        adda.w  10(a3),a3
        jsr     (a3)        ; playerTick
        rts

fw_MusicStop:
        move.w  #DMAF_AUDIO,dmacon(a5)
        ; unsupported right now
        rts

;--------------------------------------------------------------------

fw_PretrackerReplayer:
        ;include    "../framework/musicplayers/pretracker_replayer_resourced.asm"
        incbin  "../framework/musicplayers/pretracker_replayer_binary_blob.bin"
