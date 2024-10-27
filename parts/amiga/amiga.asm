                include amiga.i


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

                ; Precalc palettes
                lea     BlankPal,a0
                lea     Pal,a1
                move.l  pd_PalStepData(a6),a2
                lea     PalStepPtrs,a3
                move.w  #16-1,d0
                move.w  #ORIG_COLS-1,d1
                bsr     PreLerpPal

                ifd     FW_DEMO_PART
                move.w  #AMIGA_START,d0
                CALLFW  WaitForFrame
                PUTMSG  10,<10,"%d TIMING: start part Amiga">,fw_FrameCounter(a6)
                endc

                lea     .script(pc),a0
                CALLFW  InstallScript

                ; Start pal fade in
                moveq   #16-1,d0
                moveq   #6,d1
                lea     pd_PalFade(a6),a1
                bsr     LerpWordU
                move.w  #SCREEN_W-DIW_W,pd_PanX(a6)

                bsr     SetPal
                bsr     SetBplPtrs
                lea     Cop,a0
                CALLFW  SetCopper

                bsr     StartPan

;-------------------------------------------------------------------------------
.loop:
                CALLFW  VSyncWithTask
                CALLFW  CheckScript

                bsr     LerpWordsStep
                bsr     Update
                bsr     SetPal

                lea     MaskDraw1,a0
                bsr     BlitMask

                lea     MaskDraw2,a0
                bsr     BlitMask

                bsr     SetBplPtrs

                cmp.w   #AMIGA_END,fw_FrameCounter(a6)
                blt     .loop
                CALLFW  SetBaseCopper
                rts

;-------------------------------------------------------------------------------
.script:
                dc.w    T_BAR,.mask1-*
                dc.w    T_BAR*2+T_BEAT*2,.mask2-*
                dc.w    T_BAR*2+T_BEAT*4,.mask3-*
                dc.w    T_BAR*3,.fadeOut-*
                dc.w    T_BAR*3+T_BEAT*2,.mask4-*
                dc.w    T_BAR*4,.mask5-*
                dc.w    AMIGA_DURATION-32,.fadeOutChrome-*
                dc.w    0

ANIM_MASK       macro
                lea     \5,a0
                move.l  #\1,MaskDraw_Mask(a0)
                move.w  #\2,MaskDraw_X(a0)
                move.w  #\3,d0
                moveq   #\4,d1
                lea     MaskDraw_X(a0),a1
                bra     LerpWordU
                endm
.mask1:
                ANIM_MASK MaskKb,-32,288,7,MaskDraw1
.mask2:
                ANIM_MASK MaskTop,-32,352,6,MaskDraw2
.mask3:
                ANIM_MASK MaskSide,-32,250,6,MaskDraw1
.mask4:
                ANIM_MASK MaskMouse,192,-32,6,MaskDraw2
.mask5:
                ANIM_MASK MaskHand,304,-32,7,MaskDraw1

.fadeOut:
                moveq   #2,d0
                moveq   #8,d1
                lea     pd_PalFade(a6),a1
                bra     LerpWordU
.fadeOutChrome:
                moveq   #0,d0
                moveq   #5,d1
                lea     pd_ChromeFade(a6),a1
                bra     LerpWordU


********************************************************************************
* Routines
********************************************************************************

                include transitons.asm

StartPan:
                moveq   #0,d0
                moveq   #9,d1
                lea     pd_PanX(a6),a1
                bsr     LerpWordU

                moveq   #SCREEN_H-DIW_H,d0
                moveq   #9,d1
                lea     pd_PanY(a6),a1
                bra     LerpWordU

********************************************************************************
InitVars:
                clr.w   pd_PanX(a6)
                clr.w   pd_PanY(a6)
                clr.w   pd_PalCyclePos(a6)
                move.w  #1,pd_PalFade(a6)
                move.w  #$8000,pd_ChromeFade(a6)

                move.l  #MASK_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,pd_Mask(a6)

                move.l  #PAL_DATA_SIZE,d0
                CALLFW  AllocFast
                move.l  a0,pd_PalStepData(a6)

                rts


********************************************************************************
SetPal:
                move.w  pd_PalFade(a6),d0
                lea     PalStepPtrs,a0
                lsl.w   #2,d0
                move.l  (a0,d0.w),a0
                lea     color00(a5),a1
                move.w  #ORIG_COLS-1,d7
.l:             move.w  (a0)+,(a1)+
                dbf     d7,.l

                lea     Pal2(pc),a0
                move.w  pd_PalCyclePos(a6),d0
                add.w   d0,d0
                lea     (a0,d0.w),a0
                lea     color09(a5),a1
                rept    CHROME_COLS
                move.w  (a0),d4
                move.w  pd_ChromeFade(a6),d0
                moveq   #0,d3
                bsr     LerpCol
                move.w  d7,(a1)+
                addq    #4*2,a0
                endr
                rts

********************************************************************************
; a0 - Mask draw struct
;-------------------------------------------------------------------------------
BlitMask:
                move.l  a6,-(sp)
                tst.l   (a0)
                beq     .done
                move.l  pd_Mask(a6),-(sp)
                move.l  (a0)+,a6
                movem.w (a0),d0/d1      ; line x/y

                lea     ImgMaskLine,a4
                move.l  Mask_Img(a6),a3
                lea     ImgOrig,a2
                lea     ImgChrome,a1
                move.l  (sp)+,a0

; bltcon0 table offset
                moveq   #15,d4
                and.w   d0,d4
                add.w   d4,d4

; Offset src/dest
                asr.w   #3,d0           ; x bytes
                lea     (a1,d0.w),a1    ; src
                lea     (a2,d0.w),a2    ; dest
                lea     (a3,d0.w),a3    ; mask image

                move.l  Mask_Offset(a6),d0
                add.l   d0,a1
                add.l   d0,a2

; Offset mask line
                mulu    #MASK_LINE_BW,d1
                lea     (a4,d1.w),a4

                move.w  Mask_BlitSize(a6),d5

; First need to create the mask, merging shape and line
                BLTWAIT
                move.w  .bltcon(pc,d4),bltcon0(a5)
                clr.w   bltcon1(a5)
                move.l  #-1,bltafwm(a5)
                move.w  Mask_Mod(a6),bltbmod(a5)
                clr.w   bltamod(a5)
                clr.w   bltdmod(a5)
                move.l  a4,bltapt(a5)   ; A = shape
                move.l  a3,bltbpt(a5)   ; B = line
                move.l  a0,bltdpt(a5)   ; D = Mask
                move.w  d5,bltsize(a5)

                move.w  #SCREEN_BW*BPLS-MASK_LINE_BW,d3 ; src/dest mod

; Now blit the image using our mask

                BLTWAIT
                move.w  #$fe2,bltcon0(a5)
                move.w  d3,bltcmod(a5)
                clr.w   bltbmod(a5)
                move.w  d3,bltamod(a5)
                move.w  d3,bltdmod(a5)

; Need to blit each bitplane individually
                move.w  #BPLS-1,d7
.l:
                BLTWAIT
                move.l  a2,bltcpt(a5)   ; C = ImageOrig
                movem.l a0-a2,bltbpt(a5) ; B = Mask, A = ImageChrome ; D = ImageOrig
                move.w  d5,bltsize(a5)
                lea     SCREEN_BW(a1),a1
                lea     SCREEN_BW(a2),a2
                dbf     d7,.l
.done:
                move.l  (sp)+,a6
                rts

.bltcon:
                rept    16
                dc.w    $dc0+REPTN<<12  ; A OR B
                endr


********************************************************************************
Update:
                move.l  fw_SinTable(a6),a0
                move.w  fw_FrameCounter(a6),d0
                sub.w   #AMIGA_START,d0
                ; add.w   d0,d0
                ; and.w   #$7fe,d0
                ; move.w  (a0,d0.w),d0
                ; add.w   #$4000,d0
                lsr.w   #2,d0

                ext.l   d0
                divs    #CHROME_COLS*4,d0
                swap    d0
                move.w  d0,pd_PalCyclePos(a6)

                move.w  fw_FrameCounter(a6),d0
                lsl.w   #4,d0
                and.w   #$7fe,d0
                move.w  (a0,d0.w),d0
                asr.w   #8,d0
                add.w   #64,d0
                move.w  d0,MaskDraw1+MaskDraw_Y
                move.w  d0,MaskDraw2+MaskDraw_Y

                rts

********************************************************************************
SetBplPtrs:
                lea     ImgOrig,a1

                movem.w pd_PanX(a6),d0-d1
                move.w  d0,d2
                not.w   d2
                and.w   #$f,d2
                move.w  d2,d3
                lsl.w   #4,d3
                or.w    d2,d3
                move.w  d3,CopScroll+2
                lsr.w   #4,d0
                add.w   d0,d0
                mulu    #SCREEN_BW*BPLS,d1
                add.w   d1,d0
                adda.w  d0,a1

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
; \1 - Offset X
; \2 - Offset Y
; \3 - Width
; \4 - Height
; \5 - Image
;-------------------------------------------------------------------------------
MASK            macro
                dc.w    (\3)/8-MASK_LINE_BW ; Mask_Mod
                dc.w    (\4)*64+MASK_LINE_BW/2 ; Mask_BlitSize
                dc.l    (\2)*SCREEN_BW*BPLS+(\1)/8 ; Mask_Offset
                dc.l    \5              ; Mask_Img
                endm


MaskTop:        MASK    128,0,352+64,139,ImgMaskTop
MaskKb:         MASK    16,25,288+64,194,ImgMaskKb
MaskSide:       MASK    160,110,250+64,105,ImgMaskSide
MaskMouse:      MASK    224,158,192+64,102,ImgMaskMouse
MaskHand:       MASK    0,179,304+64,109,ImgMaskHand


********************************************************************************
* Data
********************************************************************************

Pal:            incbin  data/amiga-original.PAL,0,ORIG_COLS*2
Pal2:
                rept    2               ; https://gradient-blaster.grahambates.com/?points=001@0,eee@18,678@34,ddc@50,fef@65,000@83&steps=84&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=0
; Gradient:
                dc.w    $001,$001,$112,$122,$223,$334,$345,$455
                dc.w    $556,$667,$777,$888,$999,$9aa,$abb,$ccc
                dc.w    $ddd,$eee,$eee,$eee,$ddd,$ddd,$ccd,$ccc
                dc.w    $bbc,$bbb,$abb,$9ab,$9ab,$89a,$89a,$789
                dc.w    $789,$679,$678,$678,$789,$789,$789,$899
                dc.w    $99a,$9aa,$aaa,$aaa,$abb,$bbb,$bcb,$ccb
                dc.w    $cdc,$ddc,$ddc,$edc,$eed,$eed,$eed,$eed
                dc.w    $eed,$fee,$fee,$fee,$fee,$fee,$fef,$fef
                dc.w    $fef,$fef,$fde,$dcd,$cbc,$bbb,$a9a,$999
                dc.w    $888,$777,$666,$556,$445,$433,$333,$222
                dc.w    $111,$111,$000,$000
                endr


*******************************************************************************
                data_c
*******************************************************************************

Cop:
                COP_WAITV 20
CopScroll:      dc.w    bplcon1,0
CopBplPt:       rept    BPLS*2
                dc.w    bpl0pt+REPTN*2,0
                endr
                dc.w    diwstrt,DIW_YSTRT<<8!DIW_XSTRT
                dc.w    diwstop,(DIW_YSTOP-256)<<8!(DIW_XSTOP-256)
                dc.w    ddfstrt,(DIW_XSTRT-17)>>1&$fc-SCROLL*8
                dc.w    ddfstop,(DIW_XSTRT-17+(DIW_W>>4-1)<<4)>>1&$fc
                dc.w    bpl1mod,DIW_MOD
                dc.w    bpl2mod,DIW_MOD
                dc.w    bplcon0,BPLS<<12!DPF<<10!$200
                dc.l    -2
CopE:

ImgOrig:        incbin  data/amiga-original.BPL
ImgChrome:      incbin  data/amiga-chrome.BPL
ImgMaskLine:    incbin  data/amiga-mask-line.BPL
ImgMaskTop:     incbin  data/amiga-mask-top.BPL
ImgMaskKb:      incbin  data/amiga-mask-kb.BPL
ImgMaskSide:    incbin  data/amiga-mask-side.BPL
ImgMaskMouse:   incbin  data/amiga-mask-mouse.BPL
ImgMaskHand:    incbin  data/amiga-mask-hand.BPL

BlankPal:       dcb.w   ORIG_COLS,$0

*******************************************************************************
                bss
*******************************************************************************

PalStepPtrs:    ds.l    16
MaskDraw1:      ds.b    MaskDraw_SIZEOF
MaskDraw2:      ds.b    MaskDraw_SIZEOF
