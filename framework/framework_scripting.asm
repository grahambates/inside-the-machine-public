;--------------------------------------------------------------------
; Install a script
;
; Routines of the script will be executed via CheckScript once the
; given relative frame numbers (from the point in time this routine
; is called) have been reached (or passed).
;
; A script is built in this way:
;       dc.w    <framenumber>,<routinetocall>-*
;       dc.w    <framenumber>,<routinetocall>-*
;
; The script is terminated with a zero word.
;
; In : a0 = script pointer
;
fw_InstallScript:
        PUTMSG  10,<"%d: Script at %p installed">,fw_FrameCounterLong(a6),a0
        move.l  a0,fw_ScriptPointer(a6)
        move.w  fw_FrameCounter(a6),fw_ScriptFrameOffset(a6)
        rts

;--------------------------------------------------------------------
; Checks the script for execution
;
; Checkes if a script is installed and another cue is due to the
; current frame counter, executes it and advances the script pointer.
;
fw_CheckScript:
        move.l  fw_ScriptPointer(a6),d0
        bne.s   .cont
        rts
.cont   move.l  d0,a0
        move.w  (a0)+,d0
        add.w   fw_ScriptFrameOffset(a6),d0
        cmp.w   fw_FrameCounter(a6),d0
        bgt     .exit
        move.w  (a0)+,d0
        move.l  a0,fw_ScriptPointer(a6)
        pea     -2(a0,d0.w)
        PUTMSG  10,<"%d: Script hit %p">,fw_FrameCounterLong(a6),(sp)
        tst.w   (a0)
        bne     .exit
        PUTMSG  10,<"Script terminated.">
        clr.l   fw_ScriptPointer(a6)
.exit   rts

        IF      FW_MUSIC_SUPPORT
;--------------------------------------------------------------------
; Install a music-frame based script
;
; Routines of the script will be executed via CheckMusicScript once 
; the given absolute music frame numbers have been reached (or passed).
;
; A script is built in this way:
;       dc.w    <musicframenumber>,<routinetocall>-*
;       dc.w    <musicframenumber>,<routinetocall>-*
;
; The script is terminated with a zero word.
;
; In : a0 = script pointer
;
fw_InstallMusicScript:
        PUTMSG  10,<"%d: MusicScript at %p installed">,fw_FrameCounterLong(a6),a0
        move.l  a0,fw_MusicScriptPointer(a6)
        rts

;--------------------------------------------------------------------
; Checks the music script for execution
;
; Checkes if a music script is installed and another cue is due to the
; current frame counter, executes it and advances the script pointer.
;
fw_CheckMusicScript:
        move.l  fw_MusicScriptPointer(a6),d0
        bne.s   .cont
        rts
.cont   move.l  d0,a0
        move.w  (a0)+,d0
        cmp.w   fw_MusicFrameCount(a6),d0
        bgt     .exit
        move.w  (a0)+,d0
        move.l  a0,fw_MusicScriptPointer(a6)
        pea     -2(a0,d0.w)
        PUTMSG  10,<"%d: MusicScript (%d) hit %p">,fw_FrameCounterLong(a6),fw_MusicFrameCount-2(a6),(sp)
        tst.w   (a0)
        bne.s   .exit
        PUTMSG  10,<"MusicScript terminated.">
        clr.l   fw_MusicScriptPointer(a6)
.exit   rts
        ENDC
