        IFEQ    FW_VBL_MUSIC_IRQ
        fail    "FW_VBL_MUSIC_IRQ must be enabled"
        ENDC
        IFEQ    FW_DYNAMIC_MEMORY_SUPPORT
        fail    "FW_DYNAMIC_MEMORY_SUPPORT must be enabled"
        ENDC

fw_MusicAlloc:
        move.l  #pv_SIZEOF+sv_SIZEOF,d0
        bsr     fw_AllocFast
        move.l  a0,fw_PretrackerMyPlayer(a6)
        lea     pv_SIZEOF(a0),a0
        move.l  a0,fw_PretrackerMySong(a6)
        rts

fw_MusicInit:
        PUTMSG  10,<"%d: Pretracker song init %p %p">,fw_FrameCounterLong(a6),a0,a1
        move.l  a0,a2
        PUSHM   d4-d7/a1/a4-a6
        ;move.l fw_PretrackerMyPlayer(a6),a0 ; unused
        move.l  fw_PretrackerMySong(a6),a1
        PUTMSG  10,<"MyPlayer=%p MySong=%p Data=%p">,a0,a1,a2
        bsr     pre_SongInit
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
        lea     fw_PretrackerProgress(a6),a3
        PUTMSG  10,<"Progress at %p">,a3
        clr.l   (a3)
        PUSHM   d4-d7/a4-a6
        bsr     pre_PlayerInit
        POPM

        PUTMSG  10,<"%d: Pretracker init done">,fw_FrameCounterLong(a6)
        rts

fw_MusicPlay:
        PUSHM   d4-d7/a4-a6
        move.l  fw_PretrackerMyPlayer(a6),a0
        move.l  fw_PretrackerCopperlist(a6),a1
        bsr.s   pre_PlayerTick
        POPM
        rts

fw_MusicStop:
        move.w  #DMAF_AUDIO,dmacon(a5)
        ; unsupported right now
        rts

;--------------------------------------------------------------------
; sets the position if supported
; d0.w = new position
fw_MusicSetPosition:
        move.w  d0,fw_PretrackerMySong+sv_curr_pat_pos_w(a6)
        rts

;--------------------------------------------------------------------
PRETRACKER_COPPER_OUTPUT = FW_MUSIC_PLAYER_CHOICE-4
PRETRACKER_DONT_TRASH_REGS = 0

        include "../framework/musicplayers/raspberry_casket.asm"
