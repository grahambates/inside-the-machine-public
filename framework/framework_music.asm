;--------------------------------------------------------------------
; Starts the music playback with the given module
;
; Data and samples should be provided in fw_MusicData(a6) and
; fw_MusicSamples(a6) respectively.
;
fw_StartMusic:
        move.l  fw_MusicData(a6),a0
        move.l  fw_MusicSamples(a6),a1
        bsr     fw_MusicInit
        move.w  #1,fw_MusicEnabled(a6)
        rts

;--------------------------------------------------------------------
; Stops the music playback if music is active
;
fw_StopMusic:
        tst.w   fw_MusicEnabled(a6)
        bne.s   .cont
        rts
.cont   clr.w   fw_MusicEnabled(a6)
        bra     fw_MusicStop

