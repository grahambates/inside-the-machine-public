                include title.i

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

                ifd     FW_DEMO_PART
                move.w  #TITLE_START,d0
                CALLFW  WaitForFrame
                PUTMSG  10,<10,"%d TIMING: start part Title">,fw_FrameCounter(a6)
                endc

                lea     Pal(pc),a0
                lea     pd_Palette(a6),a1
                move.w  #COLORS,d0
                CALLFW  InitPaletteLerp

                lea     .script(pc),a0
                CALLFW  InstallScript

                bsr     PokeCopper
                bsr     FlipScreen

;-------------------------------------------------------------------------------
.loop:
                CALLFW  VSyncWithTask
                CALLFW  CheckScript

                lea     pd_Palette(a6),a1
                move.w  #COLORS,d0
                CALLFW  DoFadePaletteStep

                bsr     SetPal
                bsr     Update
                bsr     PokeCopper
                bsr     FlipScreen

                cmp.w   #TITLE_END,fw_FrameCounter(a6)
                blt     .loop
                CALLFW  SetBaseCopper
                rts

;-------------------------------------------------------------------------------
.script:
                dc.w    TITLE_DURATION-FADE_DURATION,.fadeOut-*
                dc.w    0

.fadeOut:
                moveq   #COLORS,d0
                move.w  #FADE_DURATION,d1
                lea     BlankPal(pc),a0
                lea     pd_Palette(a6),a1
                CALLFW  FadePaletteTo
                rts

********************************************************************************
* Routines
********************************************************************************

********************************************************************************
SetPal:
                lea     pd_Palette(a6),a1
                moveq.l #COLORS-1,d7
                lea     color00(a5),a0
.l:
                move.w  cl_Color(a1),(a0)+
                lea     cl_SIZEOF(a1),a1
                dbra    d7,.l
                rts


********************************************************************************
Update:
                move.w  fw_FrameCounter(a6),d0
                sub.w   fw_ScriptFrameOffset(a6),d0

                move.w  fw_FrameCounter(a6),d7
                sub.w   #TITLE_START,d7

; Initial pan
                cmp.w   #STRIP_W/2-1,d0
                bge     .initialPanDone
                add.w   #4,pd_PanX(a6)
                rts
.initialPanDone:

; Wait
                sub.w   #T_PATTERN/2,d7
                blt     .wait
; Blit strip
                cmp.w   #DIW_H/BLIT_LINES,d7
                bge     .stripDone
                lea     ImgStrip,a0
                move.w  d7,d1
                mulu    #STRIP_BW*BPLS*BLIT_LINES,d1
                add.l   d1,a0
                lea     ImgMain+DIW_BW,a1
                mulu    #SCREEN_BW*BPLS*BLIT_LINES,d7
                add.l   d7,a1
                BLTWAIT
                move.l  #$9f00000,bltcon0(a5)
                move.w  #SCREEN_BW-STRIP_BW,bltdmod(a5)
                clr.w   bltamod(a5)
                move.l  #-1,bltafwm(a5)
                move.l  a0,bltapt(a5)
                move.l  a1,bltdpt(a5)
                move.w  #BLIT_LINES*BPLS*64+STRIP_BW/2,bltsize(a5)
                rts
.stripDone:

; Wait
                cmp.w   #T_PATTERN/2,d7
                blt     .wait
; Main pan
                add.w   #2,pd_PanX(a6)
.wait:
                rts

********************************************************************************
PokeCopper:
                move.l  DrawCop(pc),a0
                lea     ImgMain,a1

                movem.w pd_PanX(a6),d0
                asr.w   d0
                move.w  d0,d2
                not.w   d2
                and.w   #$f,d2
                move.w  d2,d3
                lsl.w   #4,d3
                or.w    d2,d3
                move.w  d3,CopScroll+2-Cop(a0)
                lsr.w   #4,d0
                add.w   d0,d0
                adda.w  d0,a1

; Set bpl pointers in copper:
                lea     CopBplPt+2-Cop(a0),a0
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
FlipScreen:
                movem.l DrawCop(pc),a0-a1
                exg     a0,a1
                movem.l a0-a1,DrawCop
                move.l  a1,cop1lc(a5)
                rts

********************************************************************************
* Data
********************************************************************************

Pal:            
                incbin  data/machine-32a.PAL
BlankPal:       
                ds.w    32

DrawCop:        dc.l    Cop
ViewCop:        dc.l    Cop2

*******************************************************************************
                data_c
*******************************************************************************

Cop:
CopBplPt:       rept    BPLS*2
                dc.w    bpl0pt+REPTN*2,0
                endr
CopScroll:      dc.w    bplcon1,0
                dc.w    bplcon0,BPLS<<12!$200
                dc.w    diwstrt,DIW_YSTRT<<8!DIW_XSTRT
                dc.w    diwstop,(DIW_YSTOP-256)<<8!(DIW_XSTOP-256)
                dc.w    ddfstrt,(DIW_XSTRT-17)>>1&$fc-SCROLL*8
                dc.w    ddfstop,(DIW_XSTRT-17+(DIW_W>>4-1)<<4)>>1&$fc
                dc.w    bpl1mod,DIW_MOD
                dc.w    bpl2mod,DIW_MOD
                dc.l    -2

Cop2:
CopBplPt2:      rept    BPLS*2
                dc.w    bpl0pt+REPTN*2,0
                endr
CopScroll2:     dc.w    bplcon1,0
                dc.w    bplcon0,BPLS<<12!$200
                dc.l    -2

ImgMain:        incbin  data/machine-32a.BPL
                ds.b    DIW_W
ImgStrip:       incbin  data/machine-32b.BPL
