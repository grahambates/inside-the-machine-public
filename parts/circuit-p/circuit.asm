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

                ifd     FW_DEMO_PART
                move.w  #CIRCUIT_P_START,d0
                CALLFW  WaitForFrame
                PUTMSG  10,<10,"%d TIMING: start part Amiga">,fw_FrameCounter(a6)
                endc
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

                cmp.w   #CIRCUIT_P_END,fw_FrameCounter(a6)
                blt     .loop
                CALLFW  SetBaseCopper
                rts

;-------------------------------------------------------------------------------
.script:
                dc.w    T_BAR*2,.fadeIn-*
                dc.w    CIRCUIT_P_DURATION-64,.fadeOut-*
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

Ma2ePal:        incbin  data/pellicus.PAL

                include data/pellicus.i

; https://gradient-blaster.grahambates.com/?points=c83@0,882@4,976@9,543@15,885@21,554@26,c83@31&steps=32&blendMode=oklab&ditherMode=off&target=amigaOcs
Gradient1:
                dc.w    $c83,$b82,$a82,$982,$882,$883,$884,$984
                dc.w    $976,$976,$966,$865,$754,$654,$643,$543
                dc.w    $543,$653,$764,$774,$875,$885,$775,$775
                dc.w    $664,$554,$554,$654,$864,$974,$b84,$c83

; https://gradient-blaster.grahambates.com/?points=a84@0,542@4,865@9,665@15,a74@21,765@26,a84@31&steps=32&blendMode=oklab&ditherMode=off&target=amigaOcs
Gradient2:
                dc.w    $a84,$973,$763,$652,$542,$543,$653,$754
                dc.w    $854,$865,$865,$865,$765,$765,$665,$665
                dc.w    $765,$865,$874,$975,$974,$a74,$974,$975
                dc.w    $865,$864,$765,$865,$874,$974,$984,$a84

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
Ma2eImg:        incbin  data/pellicus.BPL

