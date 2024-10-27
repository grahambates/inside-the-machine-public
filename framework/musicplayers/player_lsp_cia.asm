        IF      FW_VBL_MUSIC_IRQ
        fail    "FW_VBL_MUSIC_IRQ must be disabled"
        ENDC

fw_MusicInit:
        PUTMSG  10,<"Music-Init %p %p">,a0,a1
        PUSHM   d4-d7/a3-a4
        move.l  fw_VBR(a6),a2
        IF      FW_STANDALONE_FILE_MODE
        move.l  $78(a2),fw_OldCiaIRQ(a6)
        ENDC
        moveq.l #0,d0
        bsr.s   LSP_MusicDriver_CIA_Start
        moveq.l #-1,d0
        move.w  d0,fw_MusicFrameCount(a6)
        POPM
        PUTMSG  10,<"Music-Init done">
        rts

fw_MusicStop:
        bsr.s   LSP_MusicDriver_CIA_Stop
        IF      FW_STANDALONE_FILE_MODE
        move.l  fw_VBR(a6),a2
        move.l  fw_OldCiaIRQ(a6),$78(a2)
        ENDC
        rts

;--------------------------------------------------------------------
; sets the position if supported
; d0.w = new position
fw_MusicSetPosition:
        bra     LSP_MusicSetPos


        include "../framework/musicplayers/lightspeedplayer_cia.asm"
        include "../framework/musicplayers/lightspeedplayer.asm"