;--------------------------------------------------------------------
; Initializes the built-in sine-table
;
; Code by a/b (EAB forum)
;
; Sine and cosine tables with 1024 entries and -16384 to +16384 range are
; accessible through the fw_SinTable(a6) and fw_CosTable(a6) base pointers.
;
fw_InitSineTable:
        PUTMSG  10,<"%d: Script at %p installed">,fw_FrameCounterLong(a6),a0
        IF      FW_DYNAMIC_MEMORY_SUPPORT
        move.l  #(1024+256)*2,d0
        bsr     fw_AllocFast
        move.l  a0,fw_SinTable(a6)
        lea     256*2(a0),a1
        move.l  a1,fw_CosTable(a6)
        ELSE
        move.l  fw_FastMemStack(a6),a0
        move.l  a0,fw_SinTable(a6)
        lea     256*2(a0),a1
        move.l  a1,fw_CosTable(a6)
        lea     1024*2(a1),a1
        move.l  a1,fw_FastMemStack(a6)
        ENDC

        PUTMSG  10,<"%d: Init Sine table %p">,fw_FrameCounterLong(a6),a0
        moveq.l #0,d0           ; amp=16384, length=1024
        move.w  #511+2,a1
.loop   subq.l  #2,a1
        move.l  d0,d1

        IF      1
; extra accuracy begin
        move.w  d1,d2
        not.w   d2
        mulu.w  d1,d2
        divu.w  #75781/2,d2     ; 16384/0.2162
        lsr.w   #3,d2           ; can't do a 32-bit divu
        sub.w   d2,d1
; extra accuracy end
        ENDC

        asr.l   #2,d1
        move.w  d1,(a0)+
        neg.w   d1
        move.w  d1,1024-2(a0)
        add.l   a1,d0
        bne.s   .loop

        move.l  fw_SinTable(a6),a0  ; fill back of cos table
        lea     1024*2(a0),a1
        moveq.l #(256/2)-1,d0
.cloop  move.l  (a0)+,(a1)+
        dbra    d0,.cloop

        PUTMSG  10,<"%d: Sine table done">,fw_FrameCounterLong(a6)
        rts
