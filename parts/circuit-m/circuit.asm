                include circuit.i

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

                lea     .script(pc),a0
                CALLFW  InstallScript

; Init palette lerps
                lea     pd_PalLerpLight(a6),a1
                moveq   #6,d0
                move.l  pd_Pal(a6),a2
                move.w  (a2),d1
                CALLFW  InitPaletteLerpSameColor

                lea     pd_PalLerpDark(a6),a1
                moveq   #6,d0
                move.l  pd_Pal(a6),a2
                move.w  2(a2),d1
                CALLFW  InitPaletteLerpSameColor

                move.l  pd_Pal(a6),a0
                lea     pd_PalLerpBg(a6),a1
                moveq   #2,d0
                CALLFW  InitPaletteLerp

; Init copper:
                bsr     PokeBpls
                lea     Cop,a0
                CALLFW  SetCopper

;-------------------------------------------------------------------------------
.loop:
                CALLFW  VSyncWithTask
                CALLFW  CheckScript

                bsr     LerpWordsStep

                lea     pd_PalLerpLight(a6),a1
                move.w  #6,d0
                CALLFW  DoFadePaletteStep

                lea     pd_PalLerpDark(a6),a1
                move.w  #6,d0
                CALLFW  DoFadePaletteStep

                lea     pd_PalLerpBg(a6),a1
                move.w  #2,d0
                CALLFW  DoFadePaletteStep

                bsr     SetPal
                move.l  pd_Screen(a6),a0
                bsr     DrawLines
                bsr     DrawDots
                bsr     PokeBpls

                cmp.w   #CIRCUIT_M_END,fw_FrameCounter(a6)
                blt     .loop
                CALLFW  SetBaseCopper
                rts

;-------------------------------------------------------------------------------
.script:
                dc.w    T_BAR*2,.fadeIn-*
                dc.w    CIRCUIT_M_DURATION-64,.fadeOut-*
                dc.w    0

.fadeIn:
                move.l  pd_Pal(a6),a0
                addq    #2*2,a0
                moveq   #6,d0
                move.w  #128,d1
                lea     pd_PalLerpLight(a6),a1
                CALLFW  FadePaletteTo

                move.l  pd_Pal(a6),a0
                addq    #2*2,a0
                moveq   #6,d0
                move.w  #128,d1
                lea     pd_PalLerpDark(a6),a1
                CALLFW  FadePaletteTo
              
                moveq   #32,d0
                moveq   #5,d1
                lea     pd_ImageScroll(a6),a1
                bsr     LerpWordU

                rts

.fadeOut:
                move.w  #1,DoClear

                lea     BlankPal,a0
                moveq   #6,d0
                move.w  #64,d1
                lea     pd_PalLerpLight(a6),a1
                CALLFW  FadePaletteTo

                lea     BlankPal,a0
                moveq   #6,d0
                move.w  #64,d1
                lea     pd_PalLerpDark(a6),a1
                CALLFW  FadePaletteTo

                lea     BlankPal,a0
                moveq   #2,d0
                move.w  #64,d1
                lea     pd_PalLerpBg(a6),a1
                CALLFW  FadePaletteTo

                moveq   #0,d0
                moveq   #5,d1
                lea     pd_LineColFade(a6),a1
                bsr     LerpWordU
                  
                rts


********************************************************************************
* Routines
********************************************************************************

                include transitons.asm

********************************************************************************
InitVars:
                move.w  #$8000,pd_LineColFade(a6)

                clr.w   pd_ImageScroll(a6)

                move.l  #Ma2eImg,pd_Image(a6)
                move.l  #Ma2ePal,pd_Pal(a6)

                move.l  #SCREEN_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,pd_Screen(a6)
                ; fall through

********************************************************************************
ClearScreen:
                BLTWAIT
                clr.w   bltdmod(a5)
                move.l  #$01000000,bltcon0(a5)
                move.l  a0,bltdpt(a5)
                move.w  #SCREEN_H*BPLS*64/2+SCREEN_BW,bltsize(a5)
                rts


********************************************************************************
; a0 - bpl 0
;-------------------------------------------------------------------------------
DrawDots:
                lea     SCREEN_BPL(a0),a1 ; bpl 1
                lea     SCREEN_BPL(a1),a2 ; highlight bpl
		
                lea     Dots,a4
                move.w  (a4)+,d7        ; dot count
.dot:
                subq.w  #1,Dot_Delay(a4)
                bge     .nextDot

                move.w  Dot_X(a4),d0
                move.w  Dot_Y(a4),d1
                move.w  #1,d2           ; Dot size
                move.w  Dot_ColorIndex(a4),d3
                bsr     DrawDot

.nextDot:
                lea     Dot_SIZEOF(a4),a4
                dbf     d7,.dot
                rts

                include circuits.asm

********************************************************************************
* Data
********************************************************************************

Ma2ePal:        incbin  data/ma2e.PAL

                include data/ma2e.i

; https://gradient-blaster.grahambates.com/?points=3c7@0,287@4,696@9,353@15,885@21,455@26,3c7@31&steps=32&blendMode=oklab&ditherMode=off&target=amigaOcs
Gradient1:
                dc.w    $3c7,$1b7,$2a7,$297,$287,$387,$487,$596
                dc.w    $596,$696,$586,$585,$474,$464,$363,$353
                dc.w    $453,$463,$663,$674,$775,$885,$775,$675
                dc.w    $565,$455,$455,$465,$486,$596,$3b7,$3c7

; https://gradient-blaster.grahambates.com/?points=685@0,255@4,588@9,565@15,875@21,576@26,685@31&steps=32&blendMode=oklab&ditherMode=off&target=amigaOcs
Gradient2:
                dc.w    $685,$575,$465,$265,$255,$355,$366,$477
                dc.w    $577,$588,$588,$577,$577,$576,$566,$565
                dc.w    $565,$665,$665,$775,$775,$875,$875,$775
                dc.w    $675,$676,$576,$576,$675,$585,$685,$685

; https://gradient-blaster.grahambates.com/?points=241@0,385@4,677@9,665@15,356@21,666@26,241@31&steps=32&blendMode=oklab&ditherMode=off&target=amigaOcs
Gradient3:
                dc.w    $241,$252,$263,$274,$385,$485,$486,$576
                dc.w    $577,$677,$677,$676,$676,$666,$665,$665
                dc.w    $565,$555,$456,$455,$456,$356,$356,$456
                dc.w    $556,$566,$666,$555,$454,$453,$342,$241

BlankPal:
                ds.w    16


*******************************************************************************
                data_c
*******************************************************************************

Cop:
CopBplPt:       
                dc.w    bpl0pt,0
                dc.w    bpl0pt+2,0
                dc.w    bpl2pt,0
                dc.w    bpl2pt+2,0
                dc.w    bpl4pt,0
                dc.w    bpl4pt+2,0
CopBplPt2:       
                dc.w    bpl1pt,0
                dc.w    bpl1pt+2,0
                dc.w    bpl3pt,0
                dc.w    bpl3pt+2,0
                dc.w    bpl5pt,0
                dc.w    bpl5pt+2,0

                dc.w    diwstrt,DIW_YSTRT<<8!DIW_XSTRT
                dc.w    diwstop,(DIW_YSTOP-256)<<8!(DIW_XSTOP-256)
                dc.w    ddfstrt,(DIW_XSTRT-17)>>1&$fc
                dc.w    ddfstop,(DIW_XSTRT-17+(DIW_W>>4-1)<<4)>>1&$fc-SCROLL*8
                dc.w    bpl1mod,DIW_MOD
                dc.w    bpl2mod,DIW_MOD
                dc.w    bplcon0,BPLS<<12!DPF<<10!$200
                dc.w    bplcon1
CopScroll:      dc.w    0

                dc.w    color00
Bg1:            dc.w    0
                dc.w    color10,0
                dc.w    color11,0
                dc.w    color12,0
                dc.w    color13,0
                dc.w    color14,0
                dc.w    color15,0

                COP_WAIT DIW_YSTRT+80,$de
                dc.w    color00 
Bg2:            dc.w    0
                dc.w    color10,0
                dc.w    color11,0
                dc.w    color12,0
                dc.w    color13,0
                dc.w    color14,0
                dc.w    color15,0

                COP_WAIT DIW_YSTRT+120,$de
                dc.w    color00 
Bg1a:           dc.w    0
                dc.w    color10,0
                dc.w    color11,0
                dc.w    color12,0
                dc.w    color13,0
                dc.w    color14,0
                dc.w    color15,0

                dc.l    -2
CopE:

DotsImg:        incbin  data/circuit-dots.BPL
                ds.w    4
Ma2eImg:        incbin  data/ma2e.BPL

