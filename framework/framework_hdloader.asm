;--------------------------------------------------------------------
; Trackdisk loader replacement for harddisk/filedemo loading
;
; In : a0: buffer to load the data into
;      d0: disk starting offset
;      d1: length in bytes
;
fw_TrackloaderLoad:
        PUTMSG  10,<"TrackloaderLoad to %p (%ld bytes)">,a0,d0
        move.l  fw_TrackBuffer(a6),a1
        adda.l  d0,a1
        addq.l  #1,d1
        and.w   #-2,d1
        btst    #1,d1
        beq.s   .nooddword
        move.w  (a1)+,(a0)+
        subq.l  #2,d1
.nooddword
        subq.l  #1,d1
        lsr.l   #2,d1
.cpyloop
        move.l  (a1)+,(a0)+
        dbra    d1,.cpyloop
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
        PUTMSG  10,<"TrackloaderLoadAndDecrunchLZ4 to %p (%ld bytes)">,a0,d1
        move.l  fw_TrackBuffer(a6),a1
        adda.l  d0,a1
        exg     a0,a1
        move.l  d1,d0
        bra     lz4_depack
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
        PUTMSG  10,<"TrackloaderLoadAndDecrunchLZ4Delta8 to %p (%ld bytes)">,a0,d1
        move.l  fw_TrackBuffer(a6),a1
        adda.l  d0,a1
        move.l  d1,d0
        PUSHM   a0
        exg     a0,a1
        bsr     lz4_depack
        POPM
        move.l  a1,d0
        sub.l   a0,d0
        PUTMSG  10,<"Delta8 decoding %p %ld bytes">,a2,d0
        moveq.l #0,d1
        subq.l  #1,d0
        bmi.s   .d8done
.d8loop
        add.b   (a0),d1
        move.b  d1,(a0)+
        dbra    d0,.d8loop
        swap    d0
        subq.w  #1,d0
        bcs.s   .d8done
        swap    d0
        bra.s   .d8loop
.d8done
        rts
        ENDC
