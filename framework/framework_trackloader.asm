;------------------------------------------------------
; MFM trackloader based on Photon/Scoopex old snippets
; Changes by Michael "Axis" Hillebrandt.
; Completely reworked by Chris 'platon42' Hodges.
;------------------------------------------------------

MFMsync     = $4489
MFMBUFSIZE  = 12800

        IF      FW_MULTITASKING_SUPPORT
        IFEQ    FW_YIELD_FROM_MAIN_TOO
        fail    "Trackloader will be called from main task, too"
        ENDC
TRKLDRYIELD MACRO
        bsr     fw_Yield
        ENDM
        ELSE
TRKLDRYIELD MACRO
        ENDM
        ENDC

; Initializes the loader, turns motor on and steps to track 0
fw_InitTrackLoader:
        move.l  #MFMBUFSIZE,d0
        bsr     fw_AllocChip
        move.l  a0,fw_MfmTrackBuffer(a6)
        move.l  #11*512,d0
        bsr     fw_AllocFast
        move.l  a0,fw_TrackBuffer(a6)

        PUSHM   a4
        PUTMSG  10,<"MfmTrack buffer at %p, decoded Track buffer at %p">,fw_MfmTrackBuffer(a6),fw_TrackBuffer(a6)
        lea     $bfd100,a4
        clr.w   fw_CurrentHead(a6)
        ;clr.w  fw_CurrentDrive(a6)
        IF      FW_MULTITASKING_SUPPORT
        move.w  #1,fw_TrackloaderIdle(a6)
        ENDC
        moveq.l #-1,d0
        move.w  d0,fw_LastMfmTrack(a6)
        move.w  d0,fw_LastTrack(a6)
        clr.l   fw_TrackChecksum(a6)
        bsr     fw_FindRightFloppyDriveUnit
        POPM
        rts

; Turns on motor if not already on
fw_TrackloaderDiskMotorOn:
        tst.w   fw_DriveMotorOn(a6)
        bne.s   .skip
        PUSHM   a4
        lea     $bfd100,a4
        bsr     fw_MotorOn
        POPM
.skip
        rts

; Turns the motor off (after reading has completed)
fw_TrackloaderDiskMotorOff:
        PUSHM   a4
        lea     $bfd100,a4
        bsr     fw_MotorOff
        POPM
        rts

;--------------------------------------------------------------------
; Load data from disk
;
; In : a0: buffer to load the data into
;      d0: disk starting offset
;      d1: length in bytes
;
fw_TrackloaderLoad:
        PUSHM   d4-d7/a4
        lea     $bfd100,a4
        lea     .plaincopy(pc),a2
        bsr     fw_LoadMFM
        POPM
        rts

.plaincopy
        PUTMSG  10,<"Copying %d bytes (%ld left) from %p to %p">,d3,d7,a1,a3
        subq.w  #1,d3
        lsr.w   #1,d3
.copyloop
        move.w  (a1)+,(a3)+
        dbra    d3,.copyloop
        rts

;--------------------------------------------------------------------
; Load LZ4 compressed data from disk and decompress it while loading
;
; In : a0: buffer to load the data into
;      d0: disk starting offset
;      d1: compressed length in bytes
;
        IF      FW_TRACKMO_LZ4_SUPPORT
fw_TrackloaderLoadAndDecrunchLZ4:
        PUSHM   d4-d7/a4
        lea     $bfd100,a4
        lea     .lz4decode(pc),a2
        clr.w   fw_TrackLz4State(a6)
        bsr     fw_LoadMFM
        POPM
        rts

.lz4decode
        moveq.l #0,d5
        move.w  fw_TrackLz4State(a6),d5
        PUTMSG  50,<"LZ4 State %d %ld bytes, %ld left from %p to %p">,d5,d3,d7,a1,a3
        lea     .lz4states(pc),a0
        adda.w  (a0,d5.w),a0
        jmp     (a0)
.lz4states
        dc.w    .lzstart-.lz4states         ; 0
        dc.w    .lzlitsizeentry-.lz4states  ; 2
        dc.w    .lzlitcopy-.lz4states       ; 4
        dc.w    .lzreadoffsetlo-.lz4states  ; 6
        dc.w    .lzreadoffsethi-.lz4states  ; 8
        dc.w    .lzmatchlengthentry-.lz4states ; 10

.lzstart
        moveq.l #0,d0
        move.b  (a1)+,d0
        moveq.l #15,d1
        and.w   d0,d1
        lsr.b   #4,d0
        move.w  d0,fw_TrackLz4LiteralLength(a6)
        move.w  d1,fw_TrackLz4MatchLength(a6)

        moveq.l #2,d5   ; next state (lit size)

        cmp.w   #15,d0
        blt.s   .lzlitsizefinished

.lzlitsizeloop
        subq.w  #1,d3
        beq.s   .lzstateterm    ; buffer ends before literal size finalized
.lzlitsizeentry
        moveq.l #0,d0
        move.b  (a1)+,d0
        add.w   d0,fw_TrackLz4LiteralLength(a6)
        not.b   d0
        beq.s   .lzlitsizeloop

.lzlitsizefinished
        moveq.l #4,d5   ; next state (lit copy)

        subq.w  #1,d3
        beq.s   .lzstateterm    ; buffer ends right after literal size finished

.lzlitcopy
        move.w  fw_TrackLz4LiteralLength(a6),d0
        beq.s   .lznoliterals   ; literal size is 0, skip copying literals
        cmp.w   d3,d0
        ble.s   .lzfulllitcopy
        ; at least one byte is leftover
.lzlitcopyuntileob
        move.w  d3,d0
        sub.w   d3,fw_TrackLz4LiteralLength(a6) ; deduct from literal size
        subq.w  #1,d3
.lzlitcopyloopeob
        move.b  (a1)+,(a3)+
        dbra    d3,.lzlitcopyloopeob
        bra     .lzstateterm

.lzstateterm
        PUTMSG  40,<"Terminated at %p (output %p)">,a1,a3
        move.w  d5,fw_TrackLz4State(a6)
        rts

.lzfulllitcopy
        sub.w   d0,d3
        subq.w  #1,d0
.lzlitcopyloop
        move.b  (a1)+,(a3)+
        dbra    d0,.lzlitcopyloop

.lznoliterals
        moveq.l #6,d5   ; next state (match offset hi)
        tst.w   d3
        beq.s   .lzstateterm    ; buffer ended right after lit copy
.lzreadoffsetlo
        move.b  (a1)+,fw_TrackLz4Offset+3(a6)
        moveq.l #8,d5   ; next state (match offset lo)
        subq.w  #1,d3
        beq.s   .lzstateterm    ; buffer ended right after offset lo
.lzreadoffsethi
        move.b  (a1)+,fw_TrackLz4Offset+2(a6)
        moveq.l #10,d5   ; next state (additional match length)
        moveq.l #0,d0
        move.w  fw_TrackLz4MatchLength(a6),d1
        cmp.w   #15,d1
        blt.s   .lzskipmatchlength

.lzmatchlengthloop
        subq.w  #1,d3
        bne.s   .lzmatchlengthenterloop
        move.w  d1,fw_TrackLz4MatchLength(a6)
        bra.s   .lzstateterm    ; buffer ends before literal size finalized
.lzmatchlengthentry
        move.w  fw_TrackLz4MatchLength(a6),d1
        moveq.l #0,d0
.lzmatchlengthenterloop
        move.b  (a1)+,d0
        add.w   d0,d1
        not.b   d0
        beq.s   .lzmatchlengthloop

.lzskipmatchlength
        ; copy match
        addq.w  #3,d1
        move.l  a3,a0
        suba.l  fw_TrackLz4Offset(a6),a0
.lzmatchcopy
        move.b  (a0)+,(a3)+
        dbra    d1,.lzmatchcopy
.lzskipmatch
        moveq.l #0,d5           ; reset state machine
        subq.w  #1,d3
        beq     .lzstateterm    ; buffer ends before next sequence
        bra     .lzstart        ; start over
        ENDC

;--------------------------------------------------------------------
; Load LZ4 and delta compressed data from disk and decompress it while loading
;
; In : a0: buffer to load the data into
;      d0: disk starting offset
;      d1: compressed length in bytes
;
        IF      FW_TRACKMO_LZ4_DLT8_SUPPORT
fw_TrackloaderLoadAndDecrunchLZ4Delta8:
        PUSHM   d4-d7/a4
        lea     $bfd100,a4
        lea     .lz4decode(pc),a2
        clr.w   fw_TrackLz4State(a6)
        clr.b   fw_TrackLz4Delta8Value(a6)
        bsr     fw_LoadMFM
        POPM
        rts

.lz4decode
        moveq.l #0,d5
        move.w  fw_TrackLz4State(a6),d5
        PUTMSG  50,<"LZ4 State %d %ld bytes, %ld left from %p to %p">,d5,d3,d7,a1,a3
        lea     .lz4states(pc),a0
        adda.w  (a0,d5.w),a0
        jmp     (a0)
.lz4states
        dc.w    .lzstart-.lz4states         ; 0
        dc.w    .lzlitsizeentry-.lz4states  ; 2
        dc.w    .lzlitcopy-.lz4states       ; 4
        dc.w    .lzreadoffsetlo-.lz4states  ; 6
        dc.w    .lzreadoffsethi-.lz4states  ; 8
        dc.w    .lzmatchlengthentry-.lz4states ; 10

.lzstart
        moveq.l #0,d0
        move.b  (a1)+,d0
        moveq.l #15,d1
        and.w   d0,d1
        lsr.b   #4,d0
        move.w  d0,fw_TrackLz4LiteralLength(a6)
        move.w  d1,fw_TrackLz4MatchLength(a6)

        moveq.l #2,d5   ; next state (lit size)

        cmp.w   #15,d0
        blt.s   .lzlitsizefinished

.lzlitsizeloop
        subq.w  #1,d3
        beq.s   .lzstateterm    ; buffer ends before literal size finalized
.lzlitsizeentry
        moveq.l #0,d0
        move.b  (a1)+,d0
        add.w   d0,fw_TrackLz4LiteralLength(a6)
        not.b   d0
        beq.s   .lzlitsizeloop

.lzlitsizefinished
        moveq.l #4,d5   ; next state (lit copy)

        subq.w  #1,d3
        beq.s   .lzstateterm    ; buffer ends right after literal size finished

.lzlitcopy
        move.w  fw_TrackLz4LiteralLength(a6),d0
        beq.s   .lznoliterals   ; literal size is 0, skip copying literals
        cmp.w   d3,d0
        ble.s   .lzfulllitcopy
        ; at least one byte is leftover
.lzlitcopyuntileob
        move.w  d3,d0
        sub.w   d3,fw_TrackLz4LiteralLength(a6) ; deduct from literal size
        subq.w  #1,d3
        move.b  fw_TrackLz4Delta8Value(a6),d4
.lzlitcopyloopeob
        add.b   (a1)+,d4
        move.b  d4,(a3)+
        dbra    d3,.lzlitcopyloopeob
        move.b  d4,fw_TrackLz4Delta8Value(a6)
        bra     .lzstateterm

.lzstateterm
        PUTMSG  40,<"Terminated at %p (output %p)">,a1,a3
        move.w  d5,fw_TrackLz4State(a6)
        rts

.lzfulllitcopy
        sub.w   d0,d3
        subq.w  #1,d0
        move.b  fw_TrackLz4Delta8Value(a6),d4
.lzlitcopyloop
        add.b   (a1)+,d4
        move.b  d4,(a3)+
        dbra    d0,.lzlitcopyloop
        move.b  d4,fw_TrackLz4Delta8Value(a6)

.lznoliterals
        moveq.l #6,d5   ; next state (match offset hi)
        tst.w   d3
        beq.s   .lzstateterm    ; buffer ended right after lit copy
.lzreadoffsetlo
        move.b  (a1)+,fw_TrackLz4Offset+3(a6)
        moveq.l #8,d5   ; next state (match offset lo)
        subq.w  #1,d3
        beq.s   .lzstateterm    ; buffer ended right after offset lo
.lzreadoffsethi
        move.b  (a1)+,fw_TrackLz4Offset+2(a6)
        moveq.l #10,d5   ; next state (additional match length)
        moveq.l #0,d0
        move.w  fw_TrackLz4MatchLength(a6),d1
        cmp.w   #15,d1
        blt.s   .lzskipmatchlength

.lzmatchlengthloop
        subq.w  #1,d3
        bne.s   .lzmatchlengthenterloop
        move.w  d1,fw_TrackLz4MatchLength(a6)
        bra.s   .lzstateterm    ; buffer ends before literal size finalized
.lzmatchlengthentry
        move.w  fw_TrackLz4MatchLength(a6),d1
        moveq.l #0,d0
.lzmatchlengthenterloop
        move.b  (a1)+,d0
        add.w   d0,d1
        not.b   d0
        beq.s   .lzmatchlengthloop

.lzskipmatchlength
        ; copy match
        addq.w  #3,d1
        move.l  a3,a0
        suba.l  fw_TrackLz4Offset(a6),a0
        move.b  fw_TrackLz4Delta8Value(a6),d4
.lzmatchcopy
        move.b  (a0)+,d0
        sub.b   -2(a0),d0
        add.b   d0,d4
        move.b  d4,(a3)+
        dbra    d1,.lzmatchcopy
        move.b  d4,fw_TrackLz4Delta8Value(a6)
.lzskipmatch
        moveq.l #0,d5           ; reset state machine
        subq.w  #1,d3
        beq     .lzstateterm    ; buffer ends before next sequence
        bra     .lzstart        ; start over
        ENDC

;--------------------------------------------------------------------
; Waits for a diskchange (disk is removed and inserted again)
; 
fw_TrackloaderWaitForDiskChange:
        PUSHM   a4
        lea     $bfd100,a4
.ready  TRKLDRYIELD
        btst    #CIAB_DSKRDY,$bfe001-$bfd100(a4)
        bne.s   .ready
.notready
        TRKLDRYIELD
        btst    #CIAB_DSKRDY,$bfe001-$bfd100(a4)
        beq.s   .notready

        bsr     fw_MotorOff
        POPM
        rts

; Load sectors from disk
; a0 - buffer to load the data into (must be even)
; a2 - routine to be called for post processing buffer with a3 current buffer pos, a1, trackdisk buffer, d3 length
; d0.l - disk offset (must be even)
; d1.l - bytes to read (may be odd, but one extra byte will be written then)
; returns a1 end of buffer written
fw_LoadMFM:
        PUTMSG  10,<"%d: LoadMFM of %ld bytes at offset %ld to %p">,fw_FrameCounterLong(a6),d1,d0,a0
        IF      FW_MULTITASKING_SUPPORT
.retry
        subq.w  #1,fw_TrackloaderIdle(a6)
        beq.s   .notbusy
        addq.w  #1,fw_TrackloaderIdle(a6)
        PUTMSG  10,<"Trackloader busy! %p">,sp
.wait
        TRKLDRYIELD
        tst.w   fw_TrackloaderIdle(a6)
        ble.s   .wait
        bra.s   .retry
.notbusy
        ENDC

        PUSHM   d6-d7/a3
        divu    #11*512,d0
        move.l  d0,d6           ; starting track / offset
        move.l  d1,d7           ; length
        move.l  a0,a3

        cmp.w   fw_LastTrack(a6),d6
        beq     .righttrack
.wrongtrack
        cmp.w   fw_LastMfmTrack(a6),d6
        beq.s   .rightmfmtrackbutnotyetdecoded
        tst.w   fw_MfmReadingTriggered(a6)
        beq.s   .noreadinginprogress
        PUTMSG  10,<"Wrong track reading in progress... please wait">
        bsr     fw_WaitForTrackDmaDone
        PUTMSG  10,<"DMA done">
.noreadinginprogress
        tst.w   fw_DriveMotorOn(a6)
        bne.s   .noturnon
        bsr     fw_MotorOn
.noturnon
        bsr     fw_StepToRightCylinderAndSelectRightHead
        bsr     fw_TriggerReadTrack
.nexttrack

.rightmfmtrackbutnotyetdecoded
        bsr     fw_WaitForTrackDmaDone
        tst.w   fw_DriveMotorOn(a6)
        bne.s   .noturnon2
        bsr     fw_MotorOn
.noturnon2
        bsr     fw_PreparePrefetchOfNextTrack
        bsr     fw_DecodeMfmTrack

        tst.w   fw_MfmDoPrefetch(a6)
        beq.s   .noprefetch
        PUTMSG  30,<"Prefetching next track">
        bsr     fw_TriggerReadTrack
.noprefetch
.righttrack
        move.l  d6,d1
        swap    d1              ; start offset inside track
        move.l  fw_TrackBuffer(a6),a1 ; start in track buffer
        adda.w  d1,a1
        move.w  #11*512,d3
        sub.w   d1,d3
        ext.l   d3
        cmp.l   d7,d3
        ble.s   .notcompleteinbuffer
        move.w  d7,d3
.notcompleteinbuffer
        sub.l   d3,d7

        jsr     (a2)

        tst.l   d7
        beq.s   .finished

        swap    d6
        clr.w   d6              ; next track always starts at offset 0
        swap    d6
        bra     .nexttrack
.finished
        move.l  a3,a1
        POPM
        PUTMSG  10,<"%d: Data load finished">,fw_FrameCounterLong(a6)
        IF      FW_MULTITASKING_SUPPORT
        addq.w  #1,fw_TrackloaderIdle(a6)
        ENDC
        ;bsr.s  MotorOff
        rts

; Prefetch the next track to be loaded (but not decoded) into MFM buffer
fw_PreparePrefetchOfNextTrack:
        PUTMSG  20,<"%d: PreparePrefetchOfNextTrack %d+1 (%d:%d)">,fw_FrameCounterLong(a6),fw_LastMfmTrack-2(a6),fw_CurrentCylinder-2(a6),fw_CurrentHead-2(a6)
        PUSHM   d6
        clr.w   fw_MfmDoPrefetch(a6)
        tst.w   fw_MfmReadingTriggered(a6)
        bne.s   .noprefetch

        move.w  fw_CurrentCylinder(a6),d6
        add.w   d6,d6
        add.w   fw_CurrentHead(a6),d6
        cmp.w   fw_LastMfmTrack(a6),d6
        bne.s   .noprefetch
        addq.w  #1,d6
        cmp.w   #80*2,d6
        bge.s   .noprefetch

        lsr.w   #1,d6
        bcs.s   .head1pre
        bsr     fw_DriveStepHeadIn  ; 1 cyl forward
        bsr     fw_SelectUpperHead
        bra.s   .prefetch
.head1pre
        bsr     fw_SelectLowerHead
.prefetch
        st      fw_MfmDoPrefetch(a6)
        move.w  #235,d0             ; 15 ms=235 scan lines!
        bsr     fw_SetDriveSettleTime
.noprefetch
        POPM
        rts

; d6=track
fw_StepToRightCylinderAndSelectRightHead:
        PUTMSG  50,<"Select track %d">,d6
        PUSHM   a0/d0/d1/d6/d7
        move.w  d6,d7
        lsr.w   #1,d7

        sub.w   fw_CurrentCylinder(a6),d7   ;delta-step
        beq.s   .steppingdone
        bmi.s   .stepout
        bsr.s    fw_DriveStepHeadIn
        subq.w  #2,d7
        bmi.s   .steppingdone
.stepinloop
        bsr     fw_DriveStepHeadInFast
        dbra    d7,.stepinloop
        bra.s   .steppingdone
.stepout
        neg.w   d7              ; = neg+sub#1
        bsr.s    fw_DriveStepHeadOut
        subq.w  #2,d7
        bmi.b   .steppingdone
.stepoutloop
        bsr.s    fw_DriveStepHeadOutFast
        dbra    d7,.stepoutloop
.steppingdone
        lsr.w   #1,d6
        bcs.s   .head1
        bsr.s   fw_SelectUpperHead
        bra.s   .done
.head1
        bsr     fw_SelectLowerHead
.done
        move.w  #235,d0         ; 15 ms=235 scan lines!
        bsr     fw_SetDriveSettleTime
        POPM
        rts

; step head 1 track in and wait for timeout
fw_DriveStepHeadIn:
        bsr     fw_LoaderCiaWait
        bclr    #CIAB_DSKDIREC,(a4)
        addq.w  #1,fw_CurrentCylinder(a6)
        PUTMSG  30,<"Step in %d">,fw_CurrentCylinder-2(a6)
fw_DriveStepHead:
        bclr    #CIAB_DSKSTEP,(a4)
        bset    #CIAB_DSKSTEP,(a4)
        move.w  #282,d0         ;18 ms=282 scan lines!
        bra.s   fw_SetDriveSettleTime

; step head 1 track in fast and wait for timeout (this can be used if the direction of the head didnt change)
fw_DriveStepHeadInFast:
        addq.w  #1,fw_CurrentCylinder(a6)
        PUTMSG  30,<"Step in fast %d">,fw_CurrentCylinder-2(a6)
fw_DriveStepHeadFast:
        bsr.s   fw_LoaderCiaWait
        bclr    #CIAB_DSKSTEP,(a4)
        bset    #CIAB_DSKSTEP,(a4)
        moveq.l #47,d0          ;3 ms=47 scan lines!
        bra.s   fw_SetDriveSettleTime

; step head 1 track out and wait for timeout
fw_DriveStepHeadOut:
        bsr.s   fw_LoaderCiaWait
        bset    #CIAB_DSKDIREC,(a4)
        subq.w  #1,fw_CurrentCylinder(a6)
        PUTMSG  30,<"Step out %d">,fw_CurrentCylinder-2(a6)
        bra.s   fw_DriveStepHead

; step head 1 track out fast and wait for timeout (this can be used if the direction of the head didnt change)
fw_DriveStepHeadOutFast:
        subq.w  #1,fw_CurrentCylinder(a6)
        PUTMSG  30,<"Step out fast %d">,fw_CurrentCylinder-2(a6)
        bra.s   fw_DriveStepHeadFast

;switch to upper head and wait for timeout
fw_SelectUpperHead:
        bsr.s   fw_LoaderCiaWait
        PUTMSG  30,<"Head0">
        bset    #CIAB_DSKSIDE,(a4)  ; Head 0
        clr.w   fw_CurrentHead(a6)
        moveq.l #2,d0           ;0,1 ms=2 scan lines!
        bra.s   fw_SetDriveSettleTime

;switch to lower head and wait for timeout
fw_SelectLowerHead:
        bsr.s   fw_LoaderCiaWait
        PUTMSG  30,<"Head1">
        bclr    #CIAB_DSKSIDE,(a4)  ; Head 1
        move.w  #1,fw_CurrentHead(a6)
        moveq.l #2,d0           ;0,1 ms=2 scan lines!
        bra.s   fw_SetDriveSettleTime

; move the head to track 0 (step out until track 0 is reached)
fw_DriveStepToCylinder0:
        bsr.s   fw_LoaderCiaWait
        btst    #CIAB_DSKTRACK0,$bfe001-$bfd100(a4)     ;Cyl 0 when low.
        beq.s   .zeroreached
        bsr     fw_DriveStepHeadOut
.stepto0loop
        btst    #CIAB_DSKTRACK0,$bfe001-$bfd100(a4)     ;Cyl 0 when low.
        beq.s   .zeroreached
        bsr     fw_DriveStepHeadOutFast
        bra.s   .stepto0loop
.zeroreached
        PUTMSG  30,<"Cylinder0">
        clr.w   fw_CurrentCylinder(a6)
        rts

fw_SetDriveSettleTime:
        moveq.l #0,d1
        move.b  $bfda00-$bfd100(a4),d1
        swap    d1
        move.b  $bfd900-$bfd100(a4),-(sp)
        move.w  (sp)+,d1
        move.b  $bfd800-$bfd100(a4),d1
        ext.l   d0
        add.l   d1,d0
        move.l  d0,fw_DriveSettleTime(a6)
        rts

;wait the specified amount of rasterlines
;d0 - amount of scanlines
fw_LoaderCiaWait:
        IF      FW_MULTITASKING_SUPPORT
        bra.s   .skipyield
.yieldloop
        cmp.w   #-50,d1
        bgt.s   .skipyield
        TRKLDRYIELD
.skipyield
        ELSE
.yieldloop
        ENDC
        moveq.l #0,d1
        move.b  $bfda00-$bfd100(a4),d1
        swap    d1
        move.b  $bfd900-$bfd100(a4),-(sp)
        move.w  (sp)+,d1
        move.b  $bfd800-$bfd100(a4),d1
        sub.l   fw_DriveSettleTime(a6),d1
        blt.s   .yieldloop
        PUTMSG  40,<"%ld: YD">,d1
        rts

fw_FindRightFloppyDriveUnit:
        move.l  4.w,a0
        cmp.w   #37,LIB_VERSION(a0)
        bhs.s   .checkdrives
        PUTMSG  10,<"LameOS, no drives check">
        ; kick 1.3 can only boot from DF0
        bsr     fw_MotorOn
        bsr     fw_DriveStepToCylinder0
        rts

.checkdrives
.retry
        move.w  fw_CurrentDrive(a6),d0
        PUTMSG  30,<"Checking disk in drive %d">,d0
        addq.w  #CIAB_DSKSEL0,d0
        or.b    #CIAF_DSKSEL0|CIAF_DSKSEL1|CIAF_DSKSEL2|CIAF_DSKSEL3,(a4)
        bclr    d0,(a4)
        bsr     fw_DriveStepToCylinder0
        bsr     fw_DriveStepHeadIn
        bsr     fw_DriveStepHeadOut
        btst    #CIAB_DSKCHANGE,$bfe001-$bfd100(a4)
        bne.s   .found
        move.w  fw_CurrentDrive(a6),d0
        addq.w  #1,d0
        cmp.w   #4,d0
        beq.s   .error
        move.w  d0,fw_CurrentDrive(a6)
        bra.s   .retry
.found  PUTMSG  10,<"Found valid floppy">
        bsr     fw_MotorOn
        rts
.error
        PUTMSG  10,<"No valid floppy found">
        move.w  #ERROR_DISK,d0
        bra     fw_Error

; turn the floppy motor on and wait until the motor is running
fw_MotorOn:
        PUTMSG  10,<"%d: Motor on">,fw_FrameCounterLong(a6)
        move.w  fw_CurrentDrive(a6),d0
        addq.w  #CIAB_DSKSEL0,d0
        or.b    #CIAF_DSKSEL0|CIAF_DSKSEL1|CIAF_DSKSEL2|CIAF_DSKSEL3,(a4)
        ;bset   d0,(a4)
        bclr    #CIAB_DSKMOTOR,(a4)         ; turns motor on
        bclr    d0,(a4)
        move.w  fw_FrameCounter(a6),d0
        add.w   #25,d0                      ; 500 ms delay max
.diskreadyloop
        TRKLDRYIELD
        cmp.w   fw_FrameCounter(a6),d0
        beq.s   .diskreadybroken
        btst    #CIAB_DSKRDY,$bfe001-$bfd100(a4)        ; wait until motor running
        bne.s   .diskreadyloop
.diskreadybroken
        st      fw_DriveMotorOn(a6)
        rts

; turn the floppy motor off
fw_MotorOff:
.retry
        tst.w   fw_MfmReadingTriggered(a6)
        beq.s   .noreadinginprogress
        PUTMSG  10,<"%d: Waiting for read to finish before turning off motor">,fw_FrameCounterLong(a6)
        bsr     fw_WaitForTrackDmaDone
.noreadinginprogress
        IF      FW_MULTITASKING_SUPPORT
        tst.w   fw_TrackloaderIdle(a6)
        bgt.s   .nowait
        TRKLDRYIELD
        bra.s   .retry
        ENDC
.nowait
        PUTMSG  10,<"%d: Motor Off">,fw_FrameCounterLong(a6)
        move.w  fw_CurrentDrive(a6),d0
        addq.w  #CIAB_DSKSEL0,d0
        bset    d0,(a4)
        bset    #CIAB_DSKMOTOR,(a4)
        bclr    d0,(a4)
        clr.w   fw_DriveMotorOn(a6)
        rts

; trigger reading of one track
; trashes a1, d0
fw_TriggerReadTrack:
        tst.w   fw_MfmReadingTriggered(a6)
        bne     fw_Error
        move.w  fw_CurrentCylinder(a6),d0
        add.w   d0,d0
        add.w   fw_CurrentHead(a6),d0
        cmp.w   fw_LastMfmTrack(a6),d0
        bne.s   .cont
        PUTMSG  30,<"MfmTrack already read %d">,d0
        rts
.cont
        PUTMSG  20,<"%d: Triggered reading of track %d">,fw_FrameCounterLong(a6),d0
        clr.w   fw_MfmReadingDone(a6)
        move.w  d0,fw_LastMfmTrack(a6)

        bsr     fw_LoaderCiaWait                ; wait settle time

        move.l  fw_MfmTrackBuffer(a6),a1

        move.w  #INTF_DSKBLK,intreq(a5)
        move.w  #MFMsync,MFMBUFSIZE-2(a1)       ; make sure we get another sync match at the end of buffer
        clr.w   (a1)+
        move.l  a1,dskpt(a5)
        move.w  #DMAF_SETCLR|DMAF_MASTER|DMAF_DISK,dmacon(a5)
        move.w  #MFMsync,dsksync(a5)
        move.w  #ADKF_SETCLR|ADKF_MFMPREC|ADKF_WORDSYNC|ADKF_FAST,adkcon(a5)
        move.w  #$4000,dsklen(a5)
        move.w  #$8000+(MFMBUFSIZE/2)-2,dsklen(a5)  ; DskLen(12800)+DmaEn
        move.w  #$8000+(MFMBUFSIZE/2)-2,dsklen(a5)  ; start reading MFMdata
        st      fw_MfmReadingTriggered(a6)
        rts

fw_WaitForTrackDmaDone:
        tst.w   fw_MfmReadingTriggered(a6)
        bne.s   .waitdma
        rts
.waitdma
.rereadwaitdma
        PUTMSG  40,<"%d: MFM Wait">,fw_FrameCounterLong(a6)
        IF      FW_MULTITASKING_SUPPORT
        bra.s   .firstskipyield
        ENDC
.waitdmadone
        TRKLDRYIELD
.firstskipyield
        btst    #INTB_DSKBLK,intreqr+1(a5)  ; wait until data read
        beq.s   .waitdmadone
        PUTMSG  20,<"%d: MFM Done">,fw_FrameCounterLong(a6)
        st      fw_MfmReadingDone(a6)
        clr.w   fw_MfmReadingTriggered(a6)
        rts

; Decode the loaded MFM track
fw_DecodeMfmTrack:
        PUSHM   a2-a3/d7

.rereadwaitdma
        bsr     fw_WaitForTrackDmaDone
        PUTMSG  20,<"%d: Decoding Track %d">,fw_FrameCounterLong(a6),fw_LastMfmTrack-2(a6)
        move.w  #-1,fw_LastTrack(a6)        ; mark last track buffer as invalid in case of error
        move.l  #$55555555,d3   ; and-const

        move.l  fw_MfmTrackBuffer(a6),a1
        ; This routine is trickier than it appears. The trick is that we must NOT
        ; assume a $4489 at the beginning of our buffer. This phenomenon occurs when
        ; the DMA starts in the middle of the first sync word. The second sync word
        ; is thrown away by the hardware. It sounds exotic, but it actually happens
        ; quite often!
        cmp.w   #MFMsync,2(a1)
        beq.s   .nofixsyncbug
        PUTMSG  10,<"Fixing missing sync">
        move.w  #MFMsync,(a1)
.nofixsyncbug

        moveq.l #0,d7
        clr.l   fw_TrackChecksum(a6)
.decode
.findsyncword
        lea     MFMBUFSIZE(a1),a3
.syncloop
        PUTMSG  70,<"LW %lx">,(a1)
        cmp.w   #MFMsync,(a1)+  ; search for a sync word
        bne.s   .syncloop
        PUTMSG  60,<"Sync %lx at %p">,(a1),a1
        cmp.l   a1,a3           ; check for end of buffer
        beq     .diskerror      ; no more sync found
        cmp.b   (a1),d3         ; search for 0-nibble
        bne.s   .syncloop

        bsr     .decodemfmword

        PUTMSG  60,<"SectorInfo %lx">,d0
        move.b  d0,d1
        lsr.w   #8,d0           ; sector number
        cmp.w   #11,d0
        bge     .diskerror
        btst    d0,d7
        bne     .diskerror
        bset    d0,d7           ; mark as decoded
        add.w   d0,d0           ; x512
        lsl.w   #8,d0
        move.l  fw_TrackBuffer(a6),a0
        adda.w  d0,a0
        PUTMSG  60,<"Decoding %d to %p">,d0,a0

        move.w  d1,d4
        lea     40(a1),a1       ; found a sec, skip unnecessary data
        bsr     .decodemfmword
        move.l  d0,d2           ; checksum

        lea     512(a1),a2      ; first half of sector in a1 and second half in a2
        moveq.l #(512/4)-1,d5
.decodeloop
        move.l  (a1)+,d0        ; decode fmtbyte/trk#,sec#,eow#
        move.l  (a2)+,d1
        and.l   d3,d0
        and.l   d3,d1
        eor.l   d0,d2           ; EOR with checksum
        eor.l   d1,d2           ; EOR with checksum
        add.l   d0,d0
        or.l    d1,d0           ; MFM decoded first longword
        move.l  d0,(a0)+
        dbra    d5,.decodeloop  ; chksum should now be 0 if correct

        or.l    d2,fw_TrackChecksum(a6) ; or with track total chksum
        cmp.b   #1,d4
        bne.s   .nogapskip
        PUTMSG  60,<"Skipping much of gap after decoding">
        ; a gap of 300 words should be safe (340 is about normal),
        ; HOWEVER some drives (Greaseweazle?) may write with 2µs pulse length
        ; instead of the Amiga's 1.97356µs or faster rotational speeds,
        ; so the gap may become smaller!
        ; This broke some configurations apparently. Sorry.
        lea     200*2(a2),a2    ; skip 200 words
.nogapskip
        cmp.w   #(1<<11)-1,d7
        beq     .allsecsfound   ; decode until the bitmap is complete
        lea     6(a2),a1
        cmp.l   a1,a3           ; check for past end of buffer
        bhi     .findsyncword   ; continue seeking sync word
        bra     .diskerror      ; ooops, we're past the end of the buffer
.allsecsfound
        PUTMSG  50,<"Track Checksum %lx">,fw_TrackChecksum(a6)
        tst.l   fw_TrackChecksum(a6)    ; track total chksum OK?
        bne     .diskerror      ; no, then retry

        move.w  fw_LastMfmTrack(a6),fw_LastTrack(a6)
        move.w  fw_LastMfmTrack(a6),d0
        ext.l   d0
        PUTMSG  10,<"%d: Decoded Track %d">,fw_FrameCounterLong(a6),d0
        POPM
        rts

.decodemfmword
        move.l  (a1)+,d0        ; decode fmtbyte/trk#,sec#,eow#
        move.l  (a1)+,d1
        and.l   d3,d0
        and.l   d3,d1
        add.l   d0,d0
        or.l    d1,d0           ; MFM decoded first longword
        rts

.diskerror
        PUTMSG  10,<"Disk Error!">
        move.w  #$800,color(a5)
        move.w  #-1,fw_LastMfmTrack(a6)
        bsr     fw_TriggerReadTrack
        bra     .rereadwaitdma