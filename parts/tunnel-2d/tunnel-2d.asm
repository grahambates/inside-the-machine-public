                include tunnel-2d.i

                ifnd    FW_DEMO_PART
                xdef    _start
_start:
                include "../framework/framework.asm"
                endc

********************************************************************************
entrypoint:
********************************************************************************
                ifd     FW_DEMO_PART
                move.l  #pd_SIZEOF,d0
                CALLFW  InitPart
                endc

                bsr     InitVars

                ifd     FW_DEMO_PART
                move.w  #TUNNEL_2D_START,d0
                CALLFW  WaitForFrame
                PUTMSG  10,<10,"%d TIMING: start part Tunnel2D">,fw_FrameCounter(a6)
                endc

                lea     .script,a0
                CALLFW  InstallScript

                bsr     UpdatePal
                bsr     SetBplPtrs
                lea     Cop,a0
                CALLFW  SetCopper

;-------------------------------------------------------------------------------
.loop:
                CALLFW  VSyncWithTask
                CALLFW  CheckScript

                bsr     UpdatePal
                bsr     SetSprites
                bsr     Update
                bsr     DoBars

                cmp.w   #TUNNEL_2D_END,fw_FrameCounter(a6)
                blt     .loop
                CALLFW  SetBaseCopper
                move.w  #0,color00(a5)
                rts


;-------------------------------------------------------------------------------
.script:
                dc.w    T_PATTERN,.speedup-*
                dc.w    T_PATTERN+T_BAR*2,.speedup2-*
                dc.w    T_PATTERN+T_BAR*3,.speedup3-*
                dc.w    0

.speedup:
                move.w  #32,pd_Speed(a6)
                rts
.speedup2:
                move.w  #64,pd_Speed(a6)
                rts
.speedup3:
                move.w  #128,pd_Speed(a6)
                rts

********************************************************************************
* Routines
********************************************************************************

********************************************************************************
InitVars:
                move.w  #16,pd_Speed(a6)
                rts

********************************************************************************
Update:
                move.w  pd_Speed(a6),d0
                add.w   d0,pd_Pos(a6)
                rts

********************************************************************************
UpdatePal:
                lea     BasePal(pc),a0
                lea     color00(a5),a1
                move.l  fw_SinTable(a6),a2
                move.w  #8-1,d7
.l:             move.w  (a0)+,(a1)+
                dbf     d7,.l

                move.w  pd_Pos(a6),d0
                asr.w   #6,d0
                and.w   #$f,d0
                add.w   d0,d0
                ext.l   d0

                move.w  fw_FrameCounter(a6),d5
                lsl.w   #3,d5
                and.w   #$7fe,d5
                move.w  (a2,d5.w),d5
                add.w   #$4000,d5
                asr.w   #2,d5

                ; Don't cycle color00 - borders look weird

                ; lea     Col0Pal(pc),a0
                ; move.w  d0,d6
                ; divu    #COL0_COUNT,d6
                ; swap    d6
                ; add.w   d6,d6
                ; adda.w  d6,a0
                ; move.w  (a0),color00(a5)

                lea     Col1Pal(pc),a0
                move.l  d0,d6
                divu    #COL1_COUNT,d6
                swap    d6
                add.w   d6,d6
                move.w  (a0,d6),d1
                bsr     Fade2
                move.w  d1,color01(a5)

                lea     Col2Pal(pc),a0
                move.l  d0,d6
                divu    #COL2_COUNT,d6
                swap    d6
                add.w   d6,d6
                move.w  (a0,d6),d1
                bsr     Fade2
                move.w  d1,color02(a5)

                lea     Col3Pal(pc),a0
                move.l  d0,d6
                divu    #COL3_COUNT,d6
                swap    d6
                add.w   d6,d6
                move.w  (a0,d6),d1
                bsr     Fade2
                move.w  d1,color03(a5)

                lea     Col4Pal(pc),a0
                move.l  d0,d6
                divu    #COL4_COUNT,d6
                swap    d6
                add.w   d6,d6
                move.w  (a0,d6),d1
                bsr     Fade2
                move.w  d1,color04(a5)

                lea     Col5Pal(pc),a0
                move.l  d0,d6
                divu    #COL5_COUNT,d6
                swap    d6
                add.w   d6,d6
                move.w  (a0,d6),d1
                bsr     Fade2
                move.w  d1,color05(a5)

                lea     Col6Pal(pc),a0
                move.l  d0,d6
                divu    #COL6_COUNT,d6
                swap    d6
                add.w   d6,d6
                move.w  (a0,d6),d1
                bsr     Fade2
                move.w  d1,color06(a5)

                lea     Col7Pal(pc),a0
                move.l  d0,d6
                divu    #COL7_COUNT,d6
                swap    d6
                add.w   d6,d6
                move.w  (a0,d6),d1
                bsr     Fade2
                move.w  d1,color07(a5)

                lea     ArchLowColors,a0
                adda.w  d0,a0
                move.w  (a0)+,color08(a5)
                move.w  (a0)+,color18(a5) ; shared with sprite
                move.w  (a0)+,color22(a5) ;
                move.w  (a0)+,color09(a5)
                move.w  (a0)+,color10(a5)
                move.w  (a0)+,color11(a5)

                lea     ArchHighColors,a0
                adda.w  d0,a0
                move.w  (a0)+,color12(a5)
                move.w  (a0)+,color19(a5) ; shared with sprite
                move.w  (a0)+,color23(a5) ;
                move.w  (a0)+,color13(a5)
                move.w  (a0)+,color14(a5)
                move.w  (a0)+,color15(a5)

                lea     color24(a5),a1

                lea     SegmentColorsDark,a0
                adda.w  d0,a0
                move.w  (a0)+,(a1)+
                move.w  (a0)+,(a1)+
                move.w  (a0)+,(a1)+
                move.w  (a0)+,(a1)+

                lea     SegmentColorsMedium,a0
                adda.w  d0,a0
                move.w  (a0)+,(a1)+
                move.w  (a0)+,(a1)+

                lea     SegmentColorsLight,a0
                adda.w  d0,a0
                move.w  (a0)+,(a1)+
                move.w  (a0)+,(a1)+

                clr.w   color17(a5)
                clr.w   color21(a5)

                rts


********************************************************************************
SetBplPtrs:
                lea     ImgOrig,a1

; Set bpl pointers in copper:
                lea     CopBplPt+2,a0
                moveq   #BPLS-1,d7
.bpl:           move.l  a1,d0
                swap    d0
                move.w  d0,(a0)         ; hi
                move.w  a1,4(a0)        ; lo
                lea     8(a0),a0
                lea     SCREEN_BPL(a1),a1
                dbf     d7,.bpl

                rts

********************************************************************************
SetSprites:
                lea     CopSprPt+2,a2
                lea     SpritePts,a0
                move.w  fw_FrameCounter(a6),d0
                asr.w   d0
                and.w   #$f,d0
                lsl.w   #2,d0
                move.l  (a0,d0),a0
                move.l  a0,a1

                moveq   #3-1,d7
.l:
                move.w  (a1)+,d3
                lea     (a0,d3),a3

                move.l  a3,d3
                move.w  d3,4(a2)
                swap    d3
                move.w  d3,(a2)
                lea     8(a2),a2

                dbf     d7,.l

                move.l  #NullSprite,d3
                moveq   #8-3-1,d7
.l1:
                move.w  d3,4(a2)
                swap    d3
                move.w  d3,(a2)
                swap    d3
                lea     8(a2),a2

                dbf     d7,.l1

                rts


LINE_WAIT       macro
; Same as previous Y?
                cmp.w   d1,d2
                beq     .s\@
; PAL fix needed?
                cmp.w   #$100,d1
                blt     .noFix\@
                cmp.w   #$100,d2
                bge     .noFix\@
                move.l  #$ffdffffe,(a0)+
.noFix\@:
; Write copper wait
                move.b  d1,(a0)+
                move.b  #5,(a0)+
                move.w  #$fffe,(a0)+
                move.w  d1,d2
.s\@:
                endm

********************************************************************************
DoBars:
                ; Frame offset
                move.l  fw_FrameCounterLong(a6),d6
                lsl.l   #2,d6
                divu    #H,d6
                clr.w   d6
                swap    d6
                neg.w   d6

                ; Start Z
                add.l   #(COUNT+1)*H+1,d6

                lea     CopBars,a0
                moveq   #0,d2           ; prev y
                move.w  #DIW_YSTRT+DIW_H/2,d3 ; y offset
                move.w  #COUNT-1,d7
.l:
                ; platform
                move.l  #BASE_H,d1
                divu    d6,d1
                add.w   d3,d1

; Y from perspective
                move.l  #BASE_H,d1
                divu    d6,d1
                move.w  d1,d4
                add.w   d3,d1
                LINE_WAIT
                move.w  #color16,(a0)+
                move.w  #$346,d0
                bsr     Fade
                move.w  d0,(a0)+
                move.w  #color20,(a0)+
                move.w  #$6a9,d0
                bsr     Fade
                move.w  d0,(a0)+
                sub.w   #PLATFORM_H,d6

; Y from perspective
                move.l  #BASE_H,d1
                divu    d6,d1
                add.w   d3,d1
                LINE_WAIT
                move.w  #color16,(a0)+
                move.w  #$79a,d0
                bsr     Fade
                move.w  d0,(a0)+
                move.w  #color20,(a0)+
                move.w  #$9dc,d0
                bsr     Fade
                move.w  d0,(a0)+
                addq    #1,d1
                LINE_WAIT
                move.l  #(color16<<16)!COL_BG,(a0)+
                move.l  #(color20<<16)!COL_BG,(a0)+
                sub.w   #GAP_H,d6

                dbf     d7,.l

                move.l  #-2,(a0)

                rts

Fade:
                movem.l d1-a6,-(sp)
                move.w  d0,d3
                move.w  #$0,d4
                sub.w   #DIW_YSTRT+DIW_H/2,d1 ; y offset
                lsl.w   #7,d1
                move.w  d1,d0
                bsr     LerpCol
                move.w  d7,d0
                movem.l (sp)+,d1-a6
                rts


Fade2:
                movem.l d0/d2-a6,-(sp)
                move.w  d1,d3
                move.w  #0,d4
                move.w  d5,d0
                bsr     LerpCol
                move.w  d7,d1
                movem.l (sp)+,d0/d2-a6
                rts

                include transitons.asm


********************************************************************************
* Data
********************************************************************************

; Col0Pal:
;                 dc.w    $011,$011,$011,$021,$021,$021,$122,$122,$122,$132,$132,$132,$132,$132,$132,$132,$132,$132,$023,$023,$023,$023,$023,$023,$023,$023,$023,$022,$022,$022,$012,$012,$012,$011,$011,$011
; COL0_COUNT = (*-Col0Pal)/2
Col1Pal:
                dc.w    $233,$233,$233,$233,$233,$333,$333,$333,$333,$333,$333,$333,$333,$334,$334,$244,$244,$245,$245,$245,$245,$245,$245,$245,$245,$334,$334,$334,$334,$334,$334,$334,$334,$344,$344,$345,$345,$355,$355,$355,$355,$355,$355,$344,$344,$244,$244,$233,$233,$233
COL1_COUNT = (*-Col1Pal)/2
Col2Pal:
                dc.w    $254,$254,$254,$254,$364,$364,$364,$364,$364,$364,$353,$353,$253,$253,$242,$242,$242,$242,$242,$242,$133,$133,$133,$133,$133,$133,$143,$143,$244,$244,$254,$254
COL2_COUNT = (*-Col2Pal)/2
Col3Pal:
                dc.w    $376,$376,$376,$367,$367,$367,$367,$367,$367,$257,$257,$257,$257,$257,$267,$366,$376,$376
COL3_COUNT = (*-Col3Pal)/2
Col4Pal:
                dc.w    $598,$598,$589,$589,$579,$579,$578,$678,$667,$666,$666,$677,$687,$588,$598
COL4_COUNT = (*-Col4Pal)/2
Col5Pal:
                dc.w    $8ba,$8ba,$8ab,$8ab,$8ab,$9aa,$aa9,$ba8,$ba8,$aa9,$9b9,$8ba
COL5_COUNT = (*-Col5Pal)/2
Col6Pal:
                dc.w    $bdc,$cfd,$cfd,$ade,$ade,$bdc
COL6_COUNT = (*-Col6Pal)/2
Col7Pal:
                dc.w    $cff,$afc,$afc,$7cb,$7cb,$cce,$cce,$feb,$feb,$fbe,$fbe,$dfb,$dfb,$cff
COL7_COUNT = (*-Col7Pal)/2


********************************************************************************
BasePal:
                dc.w    $011
                dc.w    $233
                dc.w    $254
                dc.w    $376
                dc.w    $598
                dc.w    $8ba
                dc.w    $bdc
                dc.w    $fff

********************************************************************************
ArchHighColors:
                dc.w    $365
                dc.w    $365
                dc.w    $365
                dc.w    $365
                dc.w    $365
                dc.w    $365
                dc.w    $365
                dc.w    $365
                dc.w    $365
                dc.w    $365
                dc.w    $365
                dc.w    $6ba
                dc.w    $afc
                dc.w    $cff
                dc.w    $8ba
                ; repeat
                dc.w    $365
                dc.w    $365
                dc.w    $365
                dc.w    $365
                dc.w    $365

ArchLowColors:
                dc.w    $122
                dc.w    $122
                dc.w    $122
                dc.w    $122
                dc.w    $122
                dc.w    $122
                dc.w    $122
                dc.w    $122
                dc.w    $122
                dc.w    $122
                dc.w    $122
                dc.w    $233
                dc.w    $376
                dc.w    $254
                dc.w    $233
                ; repeat
                dc.w    $122
                dc.w    $122
                dc.w    $122
                dc.w    $122
                dc.w    $122

SegmentColorsDark:
                dc.w    $233
                dc.w    $122
                dc.w    $122
                dc.w    $122
                dc.w    $122
                dc.w    $122
                dc.w    $122
                dc.w    $122
                dc.w    $122
                dc.w    $122
                dc.w    $122
                dc.w    $122
                dc.w    $233
                dc.w    $376
                dc.w    $254
                ; repeat
                dc.w    $233
                dc.w    $122

SegmentColorsMedium:
                ; shifted 4
                dc.w    $364
                dc.w    $364
                dc.w    $364
                dc.w    $364
                dc.w    $364
                dc.w    $364
                dc.w    $364
                dc.w    $364
                dc.w    $486
                dc.w    $5b8
                dc.w    $485
                dc.w    $485
                dc.w    $465
                dc.w    $364
                dc.w    $364
                ; repeat
                dc.w    $364
                dc.w    $364

SegmentColorsLight:
                ; shifted 6
                dc.w    $5ba
                dc.w    $5ba
                dc.w    $5ba
                dc.w    $5ba
                dc.w    $5ba
                dc.w    $5ba
                dc.w    $6ba
                dc.w    $dfd
                dc.w    $cfc
                dc.w    $6ba
                dc.w    $5ba
                dc.w    $5ba
                dc.w    $5ba
                dc.w    $5ba
                dc.w    $5ba
                ; repeat
                dc.w    $5ba
                dc.w    $5ba


*******************************************************************************
                data_c
*******************************************************************************

Cop:
                dc.w    diwstrt,DIW_YSTRT<<8!DIW_XSTRT
                dc.w    diwstop,(DIW_YSTOP-256)<<8!(DIW_XSTOP-256)
                dc.w    ddfstrt,(DIW_XSTRT-17)>>1&$fc-SCROLL*8
                dc.w    ddfstop,(DIW_XSTRT-17+(DIW_W>>4-1)<<4)>>1&$fc
                dc.w    bpl1mod,DIW_MOD
                dc.w    bpl2mod,DIW_MOD
                dc.w    bplcon0,BPLS<<12!DPF<<10!$200
CopScroll:      dc.w    bplcon1,0
                dc.w    dmacon,DMAF_SETCLR!DMAF_SPRITE
CopBplPt:       rept    BPLS*2
                dc.w    bpl0pt+REPTN*2,0
                endr
CopSprPt:
                rept    8*2
                dc.w    sprpt+REPTN*2,0
                endr
CopBars:
                ; TODO
                ds.w    256

NullSprite:     ds.w    2


CopE:

ImgOrig:        incbin  data/tunnel.BPL

SpritePts:
                dc.l    Sprite01
                dc.l    Sprite02
                dc.l    Sprite03
                dc.l    Sprite04
                dc.l    Sprite05
                dc.l    Sprite06
                dc.l    Sprite07
                dc.l    Sprite08
                dc.l    Sprite09
                dc.l    Sprite10
                dc.l    Sprite11
                dc.l    Sprite12
                dc.l    Sprite13
                dc.l    Sprite14
                dc.l    Sprite15
                dc.l    Sprite15

Sprite01:       incbin  data/runner/01.SPR
Sprite02:       incbin  data/runner/02.SPR
Sprite03:       incbin  data/runner/03.SPR
Sprite04:       incbin  data/runner/04.SPR
Sprite05:       incbin  data/runner/05.SPR
Sprite06:       incbin  data/runner/06.SPR
Sprite07:       incbin  data/runner/07.SPR
Sprite08:       incbin  data/runner/08.SPR
Sprite09:       incbin  data/runner/09.SPR
Sprite10:       incbin  data/runner/10.SPR
Sprite11:       incbin  data/runner/11.SPR
Sprite12:       incbin  data/runner/12.SPR
Sprite13:       incbin  data/runner/13.SPR
Sprite14:       incbin  data/runner/14.SPR
Sprite15:       incbin  data/runner/15.SPR
