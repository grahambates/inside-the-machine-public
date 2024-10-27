PROFILE = 0
                include roto.i

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
                bsr     AgaFix

                ; Precalc palettes
                lea     Pal,a0
                lea     Pal2,a1
                move.l  PalStepData(pc),a2
                lea     PalStepPtrs,a3
                move.w  #PAL_STEPS-1,d0 ; steps
                move.w  #PAL_COLORS-1,d1 ; colours
                bsr     PreLerpPal

                ifd     FW_DEMO_PART
                move.w  #ROTO_START,d0
                CALLFW  WaitForFrame
                PUTMSG  10,<10,"%d TIMING: start part Roto">,fw_FrameCounter(a6)
                endc

                move.w  #0,d0
                move.w  #4,d1
                lea     SpriteX,a1
                bsr     LerpWordU

                bsr     SwapBuffers
                bsr     PokeCopper
                bsr     SetSprites
                move.w  #DMAF_SETCLR!DMAF_SPRITE,dmacon(a5)

                bsr     SetPal
                lea     Cop,a0
                CALLFW  SetCopper
                move.w  #DIW_YSTOP,d0
                CALLFW  EnableCopperSync

;-------------------------------------------------------------------------------
.loop:
                BLTHOGOFF
                bsr     LerpWordsStep
                bsr     SetSprites
                bsr     SetPal

                bsr     BlitIRQStart
                bsr     StartC2pBlit

                bsr     UpdateVars
                bsr     UpdateOffsets
                bsr     Draw

                bsr     BlitIRQEnd
                bsr     SwapBuffers
                bsr     PokeCopper
                PROFILE_BG $f00
                CALLFW  CopSyncWithTask
                PROFILE_BG $000

                cmp.w   #ROTO_END,fw_FrameCounter(a6)
                blt     .loop
                CALLFW  SetBaseCopper
                rts

********************************************************************************
* Routines
********************************************************************************

                include transitons.asm

CopCounter:     dc.w    0
CopIRQ:
                addq.w  #1,CopCounter
                rts


********************************************************************************
InitVars:
                move.l  #SCREEN_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,DrawScreen
                bsr     ClearScreen

                move.l  #SCREEN_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,ViewScreen

                move.l  #SCREEN_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,C2pChunky

                move.l  #SCREEN_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,DrawChunky
                bsr     ClearScreen

                move.l  #SCREEN_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,ChunkyTmp

                move.l  #CHUNKY_H*2,d0
                CALLFW  AllocFast
                move.l  a0,YOffsets

                move.l  #PAL_DATA_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,PalStepData

                rts


********************************************************************************
ClearScreen:
                BLTWAIT
                clr.w   bltdmod(a5)
                move.l  #$01000000,bltcon0(a5)
                move.l  a0,bltdpt(a5)
                move.w  #SCREEN_H*BPLS*64+SCREEN_BW/2,bltsize(a5)
                rts


********************************************************************************
SwapBuffers:
                movem.l DblBuffers(pc),a0-a3
                exg     a0,a1
                exg     a2,a3
                movem.l a0-a3,DblBuffers
                rts


********************************************************************************
SetPal:
                lea     Noise,a0
                move.w  fw_FrameCounter(a6),d0
                and.w   #1024*2-2,d0
                move.w  (a0,d0.w),d0

                lsr.w   #6,d0
 
                lsl.w   #2,d0
                lea     PalStepPtrs,a0
                move.l  (a0,d0.w),a0
                lea     color17(a5),a1
                moveq   #PAL_COLORS-1,d7
.l:             move.w  (a0)+,(a1)+
                dbf     d7,.l
                rts


********************************************************************************
PokeCopper:
                move.l  ViewScreen(pc),a0
; Set bpl pointers in copper:
                lea     CopBplPt+2,a1
                rept    BPLS
                move.l  a0,d0
                swap    d0
                move.w  d0,(a1)         ; hi
                move.w  a0,4(a1)        ; lo
                lea     8(a1),a1
                lea     SCREEN_BPL(a0),a0
                endr
                rts


********************************************************************************
Draw:
                move.l  DrawChunky(pc),a0
                move.l  Texture(pc),a1
                move.w  TexOffset(pc),d0
                and.w   #TEX_W-1,d0
                add.w   d0,d0
                lea     (a1,d0.w),a1
                jmp     RotCode

********************************************************************************
SetSprites:

                move.w  #DIW_XSTRT-4,d4
                move.w  #DIW_YSTRT-5,d5

                ; Add offset to scroll in
                add.w   SpriteX(pc),d4

                ; Add some random movement
                lea     Noise,a0
                move.w  fw_FrameCounter(a6),d0
                asr.w   d0
                move.w  d0,d2
                and.w   #1024*2-2,d2
                move.w  (a0,d2.w),d1
                asr.w   #8,d1
                add.w   d1,d4
                add.w   #$375,d0
                and.w   #1024*2-2,d0
                move.w  (a0,d0.w),d1
                asr.w   #8,d1
                add.w   d1,d5

                lea     Sprite,a0
                move.l  a0,a1
                lea     CopSprPt+2,a2
                moveq   #3-1,d7
.l:
                moveq   #2-1,d6
.l1:
                move.w  (a1)+,d3
                lea     (a0,d3),a3

                move.w  d4,d0
                move.w  d5,d1
                move.w  #SPRITE_H,d2
                add.w   d1,d2           ; d2 is vstop
                moveq   #0,d3         
                lsl.w   #8,d1           ; vstart low 8 bits to top of word
                addx.b  d3,d3           ; left shift and vstart high bit to d3
                lsl.w   #8,d2           ; vstop low 8 bits to top of word
                addx.b  d3,d3           ; left shift and vstop high bit to d3 
                lsr.w   #1,d0           ; shift out hstart low bit
                addx.b  d3,d3           ; left shift and h start low bit to d3
                move.b  d0,d1           ; make first control word
                move.b  d3,d2           ; second control word

                bset    #7,d2

                move.w  d1,(a3)
                move.w  d2,2(a3)
		
                move.l  a3,d3
                move.w  d3,4(a2)
                swap    d3
                move.w  d3,(a2)
                lea     8(a2),a2

                dbf     d6,.l1

                add.w   #16,d4
                dbf     d7,.l

                ; Set null sprites
                lea     NullSprite,a0
                move.l  a0,d0
                swap    d0
                move.w  d0,(a2)
                move.w  a0,4(a2)
                move.w  d0,8(a2)
                move.w  a0,8+4(a2)

                rts


                include c2p-4x4.asm


********************************************************************************
UpdateVars:
                move.w  fw_FrameCounter(a6),d7
                sub.w   #ROTO_START,d7
                add.w   #T_PATTERN,d7   ; adjust for good section :-)

                lsl.w   #1,d7
                move.l  fw_SinTable(a6),a0

; Angle
                move.w  d7,d0           ; d0 = a
                and.w   #SIN_MASK,d0
                add.w   d0,d0
                move.w  (a0,d0.w),d0
                asr.w   #4,d0
                move.w  d0,Angle

; Scale
                move.w  d7,d0
                and.w   #SIN_MASK*2,d0
                move.w  (a0,d0.w),d0
                asr.w   #3,d0

                move.w  d7,d1
                mulu    #3,d1
                and.w   #SIN_MASK,d1
                add.w   d1,d1
                move.w  (a0,d1.w),d1
                asr.w   #2,d1
                add.w   #$1000,d0       ; 0 - $1000

                add.w   d1,d0
                muls    ScaleAmp(pc),d0
                asr.l   #8,d0

                add.w   #DIST+$1000,d0  ; 0 - $2000

                move.l  #(DIST+$1000)*64,d1
                divs    d0,d1
                bgt     .ok
                move.w  #1,d1
.ok:
                move.w  d1,Scale

; Tex Offset
                move.w  ScrollAmp,d0
                add.w   d0,TexOffset

                rts

********************************************************************************
; Write XOffsets,YOffsets and CenterOfs for current angle/scale
;-------------------------------------------------------------------------------
UpdateOffsets:
; duCol = sin(a) / scale;
; dvCol = cos(a) / scale;
; duRow = dvCol;
; dvRow = -duCol;

                move.w  Angle(pc),d0
                and.w   #SIN_MASK,d0
                add.w   d0,d0
                move.l  fw_CosTable(a6),a0
                move.w  (a0,d0.w),d1    ; d1 = cos(a) FP 1:14

; add.w	#128,d0		; this messes with the speed

                move.l  fw_SinTable(a6),a0
                move.w  (a0,d0.w),d0    ; d0 = sin(a) PF 1:14

                move.w  Scale(pc),d2
; /64 = 1 at FP 7:9
                ext.l   d0
                add.l   d0,d0
                divs    d2,d0           ; d0 = duCol 7:9
                ext.l   d1
                add.l   d1,d1
                divs    d2,d1           ; d1 = dvCol 7:9

; Center offset:
; u = TEX_W/2 - (CHUNKY_W/2 * dvCol + CHUNKY_H/2 * duCol);
; v = TEX_H/2 - (CHUNKY_W/2 * dvRow + CHUNKY_H/2 * duRow);

                move.w  #CHUNKY_W/2,d2
                muls    d1,d2           ; CHUNKY_W/2 * dvCol
                move.w  #CHUNKY_H/2,d3
                muls    d0,d3           ; CHUNKY_H/2 * duCol
                add.w   d3,d2
                neg.w   d2              ; -(CHUNKY_W/2 * dvCol + CHUNKY_H/2 * duCol)
                add.w   #(TEX_W/2)<<9,d2 ; u = TEX_W/2 - (CHUNKY_W/2 * dvCol + CHUNKY_H/2 * duCol);

; dvRow = -duCol
                move.w  #CHUNKY_W/2,d3
                muls    d0,d3           ; CHUNKY_W/2 * dvRow
                neg.w   d3
; duRow = dvCol
                move.w  #CHUNKY_H/2,d4
                muls    d1,d4           ; CHUNKY_H/2 * duRow
                add.w   d4,d3
                neg.w   d3
                add.w   #(TEX_H/2)<<9,d3 ; v = TEX_H/2 - (CHUNKY_W/2 * dvRow + CHUNKY_H/2 * duRow);

                lsr.w   d3
                lsr.w   #8,d2
                move.b  d2,d3
                and.w   #$7ffe,d3

                move.w  d3,CenterOfs

                lea     RotCodeInner+2,a0
                move.l  YOffsets,a1

; start values
                move.w  #0,d2           ; u
                move.w  #0,d3           ; v

                neg.w   d0              ; dvRow = -duCol
                lsr.w   d0
                lsr.w   d1
                move.w  #$7fff,d5

;-------------------------------------------------------------------------------
; Combine X and Y calculations up to H
                move.w  #CHUNKY_H-1,d7
.l:
; increment
                add.w   d0,d2           ; duCol
                and.w   d5,d2           ; duCol&$7fff
                add.w   d1,d3           ; dvCol

; Set upper byte for y using FP value
; y*TEX_W*2 (can use 8:8 value, *2 is for word offset)
; lower byte will be overwritten with x value
                move.w  d2,(a0)         ; dvRow -> XOffsets upper byte
                move.w  d3,(a1)+        ; dvCol -> YOffsets upper byte

; Read value back out to get shifted >> 8
                move.b  -2(a1),d4
                add.b   d4,d4           ; *2 for word offset
                move.b  d4,1(a0)        ; dvCol -> XOffsets lower byte

                move.b  (a0),d4
                add.b   d4,d4           ; *2 for word offset
                neg.b   d4
                move.b  d4,-1(a1)       ; -dvRow -> YOffsets lower byte

                addq.l  #4,a0
                dbf     d7,.l

;-------------------------------------------------------------------------------
; Just calc X offsets for remainder
                lea     .tmp,a1
                move.w  #CHUNKY_W-CHUNKY_H-1,d7
.l1:
; increment
                add.w   d0,d2           ; duCol
                and.w   d5,d2           ; duCol&$7fff
                add.w   d1,d3           ; dvCol

; Set upper byte for y using FP value
; y*TEX_W*2 (can use 8:8 value, *2 is for word offset)
; lower byte will be overwritten with x value
                move.w  d2,(a0)         ; dvRow -> XOffsets upper byte

; Use tmp for shift >> 8
                move.w  d3,(a1)
                move.b  (a1),d4
                add.b   d4,d4           ; *2 for word offset
                move.b  d4,1(a0)        ; dvCol -> XOffsets lower byte

                addq.l  #4,a0
                dbf     d7,.l1

                rts

.tmp:           dc.w    0


********************************************************************************
; Routine to write to chunky buffer
; Inner loop is SMC
;-------------------------------------------------------------------------------
; a0 - Chunky buffer
; a1 - Tex inc offset
;-------------------------------------------------------------------------------
RotCode:
                move.l  a1,a2           ; store original tex offset
                move.l  YOffsets,a3
                move.w  CenterOfs,d1
                move.w  #$7ffe,d2       ; mask for tex size modulo
                move.w  #CHUNKY_H-1,d7
RotCodeL:
                move.w  (a3)+,d0        ; next y offset
                add.w   d1,d0           ; add CenterOfs
                and.w   d2,d0           ; mod to tex size
                lea     (a2,d0.w),a1    ; offset Tex
RotCodeInner:
                rept    CHUNKY_W
                move.w  1234(a1),(a0)+  ; 30e9 1234
                endr
                dbf     d7,RotCodeL
                rts


********************************************************************************
Vars:
********************************************************************************

SpriteX:        dc.w    -SPRITE_W

DblBuffers:
DrawScreen:     dc.l    0
ViewScreen:     dc.l    0
TriBuffers:
DrawChunky:     dc.l    0
C2pChunky:      dc.l    0

ChunkyTmp:      dc.l    0


Fade:           dc.w    0
TexX:           dc.w    0
TexY:           dc.w    0
PanX:           dc.w    0
PanY:           dc.w    0

BGCol:          dc.w    0

Texture:        dc.l    Texture1

; roto
TexOffset:      dc.w    0
Angle:          dc.w    0
Scale:          dc.w    64
CenterOfs:      dc.w    0

AngleAmp:       dc.w    $300
ScaleAmp:       dc.w    $80
ScrollAmp:      dc.w    $2

SpTmp:          dc.l    0

YOffsets:       dc.l    0

PalStepData:    dc.l    0


********************************************************************************
* Data
********************************************************************************

PalStepPtrs:    ds.l    PAL_STEPS

Texture1:	
                rept    2
                incbin  data/tex.rgbs
                endr

Pal:
; https://gradient-blaster.grahambates.com/?points=000@0,d6c@5,4dd@10,fff@15&steps=16&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40
; Gradient:
                dc.w    $000,$211,$414,$736,$a4a,$d6c,$d8c,$c9d
                dc.w    $abd,$8cd,$4dd,$8ee,$aee,$cff,$dff,$fff

Pal2:
; https://gradient-blaster.grahambates.com/?points=000@0,969@8,4d8@11,cff@15&steps=16&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40
Gradient:
                dc.w    $000,$000,$101,$212,$424,$535,$646,$858
                dc.w    $969,$899,$7b9,$4d8,$7e9,$9fc,$bfd,$cff

                include noise.i

*******************************************************************************
                data_c
*******************************************************************************

Sprite:
                incbin  data/side-man.ASP

NullSprite:     ds.w    2

                include cop-4x4.asm
