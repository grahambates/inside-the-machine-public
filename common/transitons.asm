LERPS_WORDS_LEN = 8

                rsreset
Lerp_Count      rs.w    1
Lerp_Shift      rs.w    1
Lerp_Inc        rs.l    1
Lerp_Tmp        rs.l    1
Lerp_Ptr        rs.l    1               ; Target address pointer
Lerp_SIZEOF     rs.w    0


********************************************************************************
; Start a new lerp (signed)
;-------------------------------------------------------------------------------
; d0.w - target value
; d1.w - duration (pow 2)
; a1 - ptr
;-------------------------------------------------------------------------------
LerpWord:
                lea     LerpWordsState,a2
                moveq   #LERPS_WORDS_LEN-1,d2
.l:             tst.w   Lerp_Count(a2)
                beq     .free
                lea     Lerp_SIZEOF(a2),a2
                dbf     d2,.l
                rts                     ; no free slots
.free:
                moveq   #1,d2
                lsl.w   d1,d2
                move.w  d2,(a2)+        ; count
                move.w  d1,(a2)+        ; shift
                move.w  (a1),d3         ; current value
                ext.l   d3
                ext.l   d0
                sub.l   d3,d0
                move.l  d0,(a2)+        ; inc
                lsl.l   d1,d3
                move.l  d3,(a2)+        ; tmp
                move.l  a1,(a2)+        ; ptr
                rts


********************************************************************************
; Start a new lerp (unsigned)
;-------------------------------------------------------------------------------
; d0.w - target value
; d1.w - duration (pow 2)
; a1 - ptr
;-------------------------------------------------------------------------------
LerpWordU:
                lea     LerpWordsState,a2
                moveq   #LERPS_WORDS_LEN-1,d2
.l:             tst.w   Lerp_Count(a2)
                beq     .free
                lea     Lerp_SIZEOF(a2),a2
                dbf     d2,.l
                rts                     ; no free slots
.free:
                moveq   #1,d2
                lsl.w   d1,d2
                move.w  d2,(a2)+        ; count
                move.w  d1,(a2)+        ; shift
                move.w  (a1),d3         ; current value
                sub.w   d3,d0
                ext.l   d0
                move.l  d0,(a2)+        ; inc
                lsl.l   d1,d3
                move.l  d3,(a2)+        ; tmp
                move.l  a1,(a2)+        ; ptr
                rts


********************************************************************************
; Continue any active lerps
;-------------------------------------------------------------------------------
LerpWordsStep:
                lea     LerpWordsState,a0
                moveq   #LERPS_WORDS_LEN-1,d0
.l:             move.w  Lerp_Count(a0),d1
                tst.w   d1              ; Skip if not enabled / finished
                beq     .next
                sub.w   #1,Lerp_Count(a0)
                movem.l Lerp_Inc(a0),d1-d2/a1
                add.l   d1,d2
                move.l  d2,Lerp_Tmp(a0)
                move.w  Lerp_Shift(a0),d1
                asr.l   d1,d2
                move.w  d2,(a1)
.next:          lea     Lerp_SIZEOF(a0),a0
                dbf     d0,.l
                rts


********************************************************************************
; Fade between two RGB palettes
;-------------------------------------------------------------------------------
; a0 - src1
; a1 - src2
; a2 - dest
; d0.w - step 0-$8000
; d1.w - colors-1
;-------------------------------------------------------------------------------
LerpPal:
                move.w  #$f0,d2
                cmp.w   #$8000,d0
                blo.s   .l
.cp:            move.w  (a1)+,(a2)+
                dbf     d1,.cp
                rts
.l:             move.w  (a0)+,d3
                move.w  (a1)+,d4
                bsr     DoLerpCol
                move.w  d7,(a2)+
                dbf     d1,.l
                rts


********************************************************************************
; Lerp single colour
;-------------------------------------------------------------------------------
; d0.w - step 0-$8000
; d3.w - src1
; d4.w - src2
; returns:
; d7 - dest
;-------------------------------------------------------------------------------
LerpCol:
                cmp.w   #$8000,d0
                blo.s   .l
                move.w  d4,d7
                rts
.l:
                move.w  #$f0,d2

DoLerpCol:
                move.w  d3,d5           ; R
                clr.b   d5
                move.w  d4,d7
                clr.b   d7
                sub.w   d5,d7
                add.w   d7,d7
                muls    d0,d7
                swap    d7
                add.w   d5,d7
                move.w  d3,d5           ; G
                and.w   d2,d5
                move.w  d4,d6
                and.w   d2,d6
                sub.w   d5,d6
                add.w   d6,d6
                muls    d0,d6
                swap    d6
                add.w   d5,d6
                and.w   d2,d6
                move.b  d6,d7
                moveq   #$f,d6
                and.w   d6,d3
                and.w   d6,d4
                sub.w   d3,d4           ; B
                add.w   d4,d4
                muls    d0,d4
                swap    d4
                add.w   d3,d4
                or.w    d4,d7
                rts


*******************************************************************************
; d0.w - colors
; d1.w - duration (pow 2)
; a0 - from
; a1 - to
; a2 - out ptr
StartPalLerp:
                lea     PalVars(pc),a3
                move.l  a0,(a3)+        ; from
                move.l  a1,(a3)+        ; to
                move.l  a2,(a3)+        ; out
                clr.w   (a3)+           ; step
                move.w  d0,(a3)+        ; size

                move.l  a0,(a2)         ; From pal out

                move.w  #$7fff,d0
                lea     PalStep(pc),a1
                bra     LerpWord


*******************************************************************************
LerpPalStep:
                move.w  PalStep(pc),d0
                move.l  PalOut(pc),a3
                cmp.w   #$7fff,d0
                bge     .done

                move.w  PalSize(pc),d1
                move.l  PalFrom(pc),a0
                move.l  PalTo(pc),a1
                lea     PalTmp(pc),a2

                move.l  a2,(a3)
                bra     LerpPal

.done:          move.l  PalTo(pc),(a3)  ; To pal out
                rts


*******************************************************************************
; Pre-lerp palette steps
;-------------------------------------------------------------------------------
; a0 - from
; a1 - to
; a2 - out data
; a3 - out ptrs
; d0 - steps (number of palettes-1)
; d1 - colors-1
;-------------------------------------------------------------------------------
PreLerpPal:
                move.l  a0,(a3)+        ; store ptr to src

                move.l  #$8000,d2
                divu    d0,d2           ; step increment

                move.w  d0,d7
                subq    #2,d7

                move.w  d2,d0           ; step value
.l:
                movem.l d0-a1,-(sp)
                move.l  a2,(a3)+
                bsr     LerpPal
                movem.l (sp)+,d0-a1
                add.w   d2,d0
                dbf     d7,.l

                move.l  a1,(a3)+        ; store ptr to dest
                rts


*******************************************************************************
; Vars:
*******************************************************************************

PalVars:
PalFrom:        dc.l    0
PalTo:          dc.l    0
PalOut:         dc.l    0
PalStep:        dc.w    $7fff
PalSize:        dc.w    32


*******************************************************************************
; Data:
*******************************************************************************

LerpWordsState: ds.b    Lerp_SIZEOF*LERPS_WORDS_LEN
PalTmp:         ds.w    32
