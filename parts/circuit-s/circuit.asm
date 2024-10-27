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

                cmp.w   #CIRCUIT_S_END,fw_FrameCounter(a6)
                blt     .loop
                CALLFW  SetBaseCopper
                rts

;-------------------------------------------------------------------------------
.script:
                dc.w    T_BAR*2,.fadeIn-*
                dc.w    CIRCUIT_S_DURATION-64,.fadeOut-*
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

                move.l  #Img,pd_Image(a6)
                move.l  #ImagePal,pd_Pal(a6)

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

ImagePal:       incbin  data/steffest.PAL

                include data/steffest.i

; https://gradient-blaster.grahambates.com/?points=c36@0,728@4,968@9,435@15,865@21,544@26,c36@31&steps=32&blendMode=oklab&ditherMode=off&target=amigaOcs
Gradient1:
                dc.w    $c36,$b37,$a37,$828,$728,$738,$848,$858
                dc.w    $858,$968,$858,$757,$646,$546,$535,$435
                dc.w    $435,$545,$645,$755,$755,$865,$754,$755
                dc.w    $654,$544,$544,$744,$845,$945,$b35,$c36

; https://gradient-blaster.grahambates.com/?points=a74@0,523@4,865@9,656@15,74a@21,755@26,a74@31&steps=32&blendMode=oklab&ditherMode=off&target=amigaOcs
Gradient2:
                dc.w    $a74,$964,$843,$633,$523,$523,$633,$744
                dc.w    $854,$865,$865,$865,$755,$756,$656,$656
                dc.w    $657,$657,$758,$749,$74a,$74a,$749,$758
                dc.w    $757,$756,$755,$855,$864,$964,$a64,$a74

; https://gradient-blaster.grahambates.com/?points=412@0,833@4,776@9,875@15,643@21,311@26,412@31&steps=32&blendMode=oklab&ditherMode=off&target=amigaOcs
Gradient3:
                dc.w    $412,$512,$622,$723,$833,$843,$854,$865
                dc.w    $766,$776,$776,$876,$876,$875,$875,$875
                dc.w    $865,$764,$754,$753,$643,$643,$532,$522
                dc.w    $421,$311,$311,$311,$311,$301,$412,$412

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
Img:            incbin  data/steffest.BPL

