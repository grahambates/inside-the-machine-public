        IFEQ    FW_VBL_MUSIC_IRQ
        fail    "FW_VBL_MUSIC_IRQ must be enabled"
        ENDC

fw_MusicInit:
        PUTMSG  10,<"Music-Init %p %p">,a0,a1
        bsr.s   LSP_MusicInit
        moveq.l #-1,d0
        move.w  d0,fw_MusicFrameCount(a6)
        PUTMSG  10,<"Music-Init done">
        rts

fw_MusicPlay:
        PUSHM   a4
        bsr.s   LSP_MusicPlayTick
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
        bra     LSP_MusicSetPos

        include "../framework/musicplayers/lightspeedplayer.asm"
