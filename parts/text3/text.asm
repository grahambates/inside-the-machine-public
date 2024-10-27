                include text.i

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

                lea     pd_Palette(a6),a1
                moveq   #COLORS,d0
                move.w  #0,d1
                CALLFW  InitPaletteLerpSameColor

                moveq   #COLORS,d0
                move.w  #FADE_DURATION,d1
                lea     Pal(pc),a0
                lea     pd_Palette(a6),a1
                CALLFW  FadePaletteTo

                lea     .script(pc),a0
                CALLFW  InstallScript

                bsr     PokeCopper
                lea     Cop,a0
                CALLFW  SetCopper
                
;-------------------------------------------------------------------------------
.loop:
                CALLFW  VSyncWithTask
                CALLFW  CheckScript

                bsr     Update
                bsr     PokeCopper

                lea     pd_Palette(a6),a1
                move.w  #COLORS,d0
                CALLFW  DoFadePaletteStep
                bsr     SetPal

                cmp.w   #TEXT3_END,fw_FrameCounter(a6)
                blt     .loop
                CALLFW  SetBaseCopper
                rts

;-------------------------------------------------------------------------------
.script:
                dc.w    TEXT3_DURATION-FADE_DURATION,.fadeOut-*
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
PokeCopper:
                move.w  ScrollX(pc),d1
                add.w   #7<<4,d1
                move.w  d1,CopScroll+2
                lea     ImgMain,a1
                lea     CopBplPt+2,a0

                ; bpl1
                move.l  a1,d0
                swap    d0
                move.w  d0,8(a0)        ; hi
                move.w  a1,12(a0)       ; lo

                move.w  ScrollY(pc),d1
                muls    #SCREEN_BW,d1
                adda.w  d1,a1

                ; bpl2
                move.l  a1,d0
                swap    d0
                move.w  d0,(a0)         ; hi
                move.w  a1,4(a0)        ; lo

                rts


********************************************************************************
Update:
                ; Perlin  noise
                lea     Noise,a0
                move.w  fw_FrameCounter(a6),d1
                and.w   #1024*2-2,d1
                move.w  (a0,d1.w),d1
                asr.w   #6,d1
                move.w  d1,ScrollX

                move.w  fw_FrameCounter(a6),d1
                add.w   #$1234,d1
                and.w   #1024*2-2,d1
                move.w  (a0,d1.w),d1
                asr.w   #8,d1
                sub.w   #2,d1
                move.w  d1,ScrollY

                rts

********************************************************************************
Vars:
********************************************************************************
ScrollX:        dc.w    0
ScrollY:        dc.w    0

********************************************************************************
* Data
********************************************************************************

Pal:            
                dc.w    0
                dc.w    $600
                dc.w    $eee
                dc.w    $fff
BlankPal:       
                ds.w    COLORS

                include noise.i

*******************************************************************************
                data_c
*******************************************************************************

Cop:
CopBplPt:       rept    BPLS*2
                dc.w    bpl0pt+REPTN*2,0
                endr
CopScroll:      dc.w    bplcon1,4<<4!0
                dc.w    bplcon0,BPLS<<12!$200
                dc.w    diwstrt,DIW_YSTRT<<8!DIW_XSTRT
                dc.w    diwstop,(DIW_YSTOP-256)<<8!(DIW_XSTOP-256)
                dc.w    ddfstrt,(DIW_XSTRT-17)>>1&$fc-SCROLL*8
                dc.w    ddfstop,(DIW_XSTRT-17+(DIW_W>>4-1)<<4)>>1&$fc
                dc.w    bpl1mod,DIW_MOD
                dc.w    bpl2mod,DIW_MOD
                dc.l    -2
CopE:

                ds.b    SCREEN_BW*8
ImgMain:        
                incbin  data/text.BPL
                ds.b    SCREEN_BW*8
                ; TODO: Investigtate obvious overflow here
                ds.w    1
