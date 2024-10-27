********************************************************************************
; a0 - bpl 0
;-------------------------------------------------------------------------------
DrawLines:
                lea     SCREEN_BPL(a0),a1 ; bpl 1
                lea     SCREEN_BPL(a1),a2 ; highlight bpl
		
                lea     Lines,a4
                move.w  (a4)+,d7        ; line count
.line:
                move.w  Line_DrawSpeed(a4),d6 ; speed is -1 if done
                blt     .highLight

                addq.w  #1,Line_DrawPos(a4)
                blt     .nextLine       ; delay if negative position
                bne     .draw
                move.w  Line_StartDot(a4),d2
                beq     .draw           ; no start dot
			
; Draw start dot
                move.w  Line_StartX(a4),d0
                move.w  Line_StartY(a4),d1
                move.w  Line_ColorIndex(a4),d3
                sub.w   d2,d0
                bsr     DrawDot

;-------------------------------------------------------------------------------
; Draw:
.draw:
                move.l  Line_HeadPtr(a4),a3
.drawPx:
; Get coords
                move.w  Line_HeadX(a4),d0
                move.w  Line_HeadY(a4),d1
                move.w  d0,d3
                not.w   d3
                lsr.w   #3,d0
                add.w   d0,d1

; Plot colour
                move.w  Line_ColorIndex(a4),d2
                btst    #0,d2
                beq     .n0
                bset    d3,(a0,d1.w)
.n0:
                btst    #1,d2
                beq     .n1
                bset    d3,(a1,d1.w)
.n1:

; Add delta
                move.w  Sect_Dx(a3),d0
                move.w  Sect_Dy(a3),d1
                add.w   d0,Line_HeadX(a4)
                add.w   d1,Line_HeadY(a4)

; More steps on section?
                subq.w  #1,Sect_HeadCount(a3)
                bge     .drawNextPx
; Next section
                move.w  Sect_Count(a3),Sect_HeadCount(a3) ; Reset count
                lea     Sect_SIZEOF(a3),a3
                move.l  a3,Line_HeadPtr(a4)

                tst.w   (a3)            ; Last section?
                bge     .drawNextPx
                move.w  #-1,Line_DrawSpeed(a4) ; Draw is done
                move.l  Line_Ptr(a4),Line_HeadPtr(a4) ; reset head for highlight
                move.w  Line_StartX(a4),Line_HeadX(a4)
                move.w  Line_StartY(a4),Line_HeadY(a4)

                move.w  Line_EndDot(a4),d2
                beq     .highLight      ; no end dot

; Draw end dot
                move.w  Line_EndX(a4),d0
                move.w  Line_EndY(a4),d1
                move.w  Line_ColorIndex(a4),d3
                add.w   d2,d0
                bsr     DrawDot

                bra     .highLight
.drawNextPx:
                dbf     d6,.drawPx
                bra     .nextLine       ; skip highlight as still drawing

;-------------------------------------------------------------------------------
.highLight:

; Head
                move.w  Line_HlSpeed(a4),d6 ; speed is -1 if done
                bge     .cont
                move.w  #2,d6           ; clear speed
                tst.w   DoClear
                bne     .doHighlight
                bsr     Random32
                cmp.w   #$8000-HL_PROB,d0 ; probability of starting highlight
                blt     .nextLine
                move.w  d0,d6
                and.w   #1,d6           ; random speed
.doHighlight:
                move.w  d6,Line_HlSpeed(a4)
                move.w  #-HL_DELAY,Line_HlPos(a4)
.cont:


                move.l  Line_HeadPtr(a4),a3
.headPx:
                tst.w   (a3)            ; Last section? Reset is done on tail
                bge     .notDone
		
                move.w  Line_EndDot(a4),d2
                beq     .tail           ; no end dot

; Draw end dot
                move.w  Line_EndX(a4),d0
                move.w  Line_EndY(a4),d1
                move.w  #4,d3
                add.w   d2,d0

                tst.w   DoClear
                beq     .noClear1
                bsr     ClearDot
                bra     .tail
.noClear1:
                bsr     DrawDot
                bra     .tail
.notDone:

; Get coords
                move.w  Line_HeadX(a4),d0
                move.w  Line_HeadY(a4),d1
                move.w  d0,d3
                not.w   d3
                lsr.w   #3,d0
                add.w   d0,d1

; Plot
                tst.w   DoClear
                beq     .noClear
                bclr    d3,(a0,d1.w)
                bclr    d3,(a1,d1.w)
                bra     .plotDone
.noClear:
                bset    d3,(a2,d1.w)
.plotDone:


; Add delta
                move.l  Line_HeadPtr(a4),a3
                move.w  Sect_Dx(a3),d0
                move.w  Sect_Dy(a3),d1
                add.w   d0,Line_HeadX(a4)
                add.w   d1,Line_HeadY(a4)

; More steps on section?
                subq.w  #1,Sect_HeadCount(a3)
                bge     .headNextPx	
; Next section
                move.w  Sect_Count(a3),Sect_HeadCount(a3) ; Reset count
                lea     Sect_SIZEOF(a3),a3
                move.l  a3,Line_HeadPtr(a4)

.headNextPx:
                dbf     d6,.headPx

; Tail
.tail:
                move.w  Line_HlSpeed(a4),d6 ; speed is -1 if done
                addq.w  #1,Line_HlPos(a4)
                blt     .nextLine       ; delay if negative position

.tailPx:
; Get coords
                move.w  Line_TailX(a4),d0
                move.w  Line_TailY(a4),d1
                move.w  d0,d3
                not.w   d3
                lsr.w   #3,d0
                add.w   d0,d1

; Clear
                bclr    d3,(a2,d1.w)

; Add delta
                move.l  Line_TailPtr(a4),a3
                move.w  Sect_Dx(a3),d0
                move.w  Sect_Dy(a3),d1
                add.w   d0,Line_TailX(a4)
                add.w   d1,Line_TailY(a4)

; More steps on section?
                subq.w  #1,Sect_TailCount(a3)
                bge     .tailNextPx	
; Next section
                move.w  Sect_Count(a3),Sect_TailCount(a3) ; Reset count
                lea     Sect_SIZEOF(a3),a3
                move.l  a3,Line_TailPtr(a4)

                tst.w   (a3)            ; Last section?
                bge     .tailNextPx
                move.w  #-1,Line_HlSpeed(a4)
                move.l  Line_Ptr(a4),Line_HeadPtr(a4) ; reset head
                move.w  Line_StartX(a4),Line_HeadX(a4)
                move.w  Line_StartY(a4),Line_HeadY(a4)
                move.l  Line_Ptr(a4),Line_TailPtr(a4) ; reset tail
                move.w  Line_StartX(a4),Line_TailX(a4)
                move.w  Line_StartY(a4),Line_TailY(a4)

                move.w  Line_EndDot(a4),d2
                beq     .nextLine       ; no end dot

; Draw end dot
                move.w  Line_EndX(a4),d0
                move.w  Line_EndY(a4),d1
                move.w  #4,d3
                add.w   d2,d0
                bsr     ClearDot

                bra     .nextLine
.tailNextPx:
                dbf     d6,.tailPx

.nextLine:
                lea     Line_SIZEOF(a4),a4
                dbf     d7,.line
                rts

DoClear:        dc.w    0


********************************************************************************
DrawDot:

                move.w  #$dfc,d5
BlitDot:
                move.l  a4,-(sp)
                sub.w   #3,d0
                sub.w   #SCREEN_BW*3,d1

                moveq   #$f,d4
                and.w   d0,d4
                lsr.w   #3,d0
                add.w   d0,d1
                ror.w   #4,d4
                or.w    d5,d4
                WAIT_BLIT
                move.w  d4,bltcon0(a5)
                clr.w   bltcon1(a5)
                move.l  #-1,bltafwm(a5)
                clr.w   bltamod(a5)
                move.w  #SCREEN_BW-4,bltbmod(a5)
                move.w  #SCREEN_BW-4,bltdmod(a5)

                lea     DotsImg,a3
                subq    #1,d2
                mulu    #7*4,d2
                lea     (a3,d2.w),a3

                move.w  #7*64+4/2,d5

                btst    #0,d3
                beq     .n0
                WAIT_BLIT
                lea     (a0,d1),a4
                move.l  a3,bltapt(a5)
                move.l  a4,bltbpt(a5)
                move.l  a4,bltdpt(a5)
                move.w  d5,bltsize(a5)
.n0:
                btst    #1,d3
                beq     .n1
                WAIT_BLIT
                lea     (a1,d1),a4
                move.l  a3,bltapt(a5)
                move.l  a4,bltbpt(a5)
                move.l  a4,bltdpt(a5)
                move.w  d5,bltsize(a5)
.n1:
                btst    #2,d3
                beq     .n2
                WAIT_BLIT
                lea     (a2,d1),a4
                move.l  a3,bltapt(a5)
                move.l  a4,bltbpt(a5)
                move.l  a4,bltdpt(a5)
                move.w  d5,bltsize(a5)
.n2:
                move.l  (sp)+,a4

                rts


********************************************************************************
ClearDot:
                move.w  #$d30,d5        ; blitter mask
                bra     BlitDot

********************************************************************************
SetPal:
                ; BG light (x2)
                lea     pd_PalLerpBg(a6),a0
                lea     Bg1,a2
                move.w  cl_Color(a0),d0
                move.w  d0,(a2)
                move.w  d0,Bg1a-Bg1(a2)
                addq    #4,a2
                lea     cl_SIZEOF(a0),a0

                lea     pd_PalLerpLight(a6),a1
                moveq.l #6-1,d7
.l:
                move.w  cl_Color(a1),d0
                move.w  d0,(a2)
                move.w  d0,Bg1a-Bg1(a2)
                lea     cl_SIZEOF(a1),a1
                addq    #4,a2
                dbra    d7,.l

                ; Bg dark
                lea     Bg2,a2
                move.w  cl_Color(a0),(a2)
                addq    #4,a2

                lea     pd_PalLerpDark(a6),a1
                moveq.l #6-1,d7
.l1:
                move.w  cl_Color(a1),d0
                move.w  d0,(a2)
                lea     cl_SIZEOF(a1),a1
                addq    #4,a2
                dbra    d7,.l1

                lea     color01(a5),a0

                lea     Gradient1,a1
                move.w  fw_FrameCounter(a6),d0
                lsr.w   #3,d0
                and.w   #31,d0
                add.w   d0,d0
                move.w  (a1,d0),d4

                move.w  pd_LineColFade(a6),d0
                moveq   #0,d3
                bsr     LerpCol
                move.w  d7,(a0)+

                lea     Gradient2,a1
                move.w  fw_FrameCounter(a6),d0
                divu    #10,d0
                and.w   #31,d0
                add.w   d0,d0
                move.w  (a1,d0),d4

                move.w  pd_LineColFade(a6),d0
                moveq   #0,d3
                bsr     LerpCol
                move.w  d7,(a0)+

                lea     Gradient3,a1
                move.w  fw_FrameCounter(a6),d0
                divu    #10,d0
                and.w   #31,d0
                add.w   d0,d0
                move.w  d7,(a0)+

                move.w  pd_LineColFade(a6),d0
                moveq   #0,d3
                move.w  #HIGHLIGHT_COLOR,d4 ; highlight colour
                bsr     LerpCol

                move.w  d4,(a0)+
                move.w  d4,(a0)+
                move.w  d4,(a0)+
                move.w  d4,(a0)+
		
                rts


********************************************************************************
PokeBpls:
                move.l  pd_Screen(a6),a1

; Set bpl pointers in copper:
                lea     CopBplPt+2,a0
                moveq   #3-1,d7
.bpl:           move.l  a1,d0
                swap    d0
                move.w  d0,(a0)         ; hi
                move.w  a1,4(a0)        ; lo
                lea     8(a0),a0
                lea     SCREEN_BPL(a1),a1
                dbf     d7,.bpl

                move.l  pd_Image(a6),a1
                subq    #4,a1

                movem.w pd_ImageScroll(a6),d0
                move.w  d0,d2
                neg.w   d2
                and.w   #$f,d2
                lsl.w   #4,d2
                move.w  d2,CopScroll
                add.w   #15,d0          ; round up
                lsr.w   #4,d0
                add.w   d0,d0
                adda.w  d0,a1

                moveq   #3-1,d7
.bpl1:          move.l  a1,d0
                swap    d0
                move.w  d0,(a0)         ; hi
                move.w  a1,4(a0)        ; lo
                lea     8(a0),a0
                lea     SCREEN_BPL(a1),a1
                dbf     d7,.bpl1

                rts


********************************************************************************
; Random number generator
;-------------------------------------------------------------------------------
; Returns:
; d0 - random 32 bit value
;-------------------------------------------------------------------------------
Random32:
                move.l  RandomSeed(pc),d0
                add.l   d0,d0
                bcc.s   .done
                eori.b  #$af,d0
.done:          move.l  d0,RandomSeed
                rts
RandomSeed:     dc.l    RANDOM_SEED


