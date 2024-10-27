PROFILE = 0
                include face-lights.i

                ifnd    FW_DEMO_PART
                xdef    _start
_start:
                include "../framework/framework.asm"
                else
                bra.s   entrypoint
                endc

********************************************************************************
precalc:
********************************************************************************
                move.l  #TOTAL_TEXTURE_SIZE,d0
                CALLFW  AllocFast
                move.l  a0,ScrambledTex

                lea     TextureSrc,a4
                move.w  #TEX_SIZE,d0
                bsr     ScrambleTexture

                bsr     InitFadeRGB

                move.l  #COLORS*FADE_STEPS*2,d0
                CALLFW  AllocFast
                move.l  a0,PalData

                move.l  #FADE_STEPS*4,d0
                CALLFW  AllocFast
                move.l  a0,PalStepPtrs

                lea     BlankPal,a0
                lea     Pal,a1
                move.l  PalData,a2
                move.l  PalStepPtrs,a3
                move.w  #FADE_STEPS-1,d0
                move.w  #COLORS-1,d1
                bsr     PreLerpPal

                move.l  #SMC_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,TableCode

                move.l  a0,a1
                lea     TableData+2,a0
                bra     GenerateTable
                ; rts

********************************************************************************
entrypoint:
********************************************************************************
                ifd     FW_DEMO_PART
                move.l  #pd_SIZEOF,d0
                CALLFW  InitPart
                else
                bsr     precalc
                endc
                bsr     InitVars

; Precalc:
                bsr     SetSprites
                bsr     SetPal
                bsr     PokeCopper

                move.w  #DIW_YSTOP,d0
                CALLFW  EnableCopperSync
                move.l  #Update,fw_VBlankIRQ(a6)
                move.w  #DMAF_SETCLR!DMAF_SPRITE,dmacon(a5)

                lea     Cop,a0
                CALLFW  SetCopper

;-------------------------------------------------------------------------------
.loop:
                BLTHOGOFF
                bsr     BlitIRQStart
                bsr     StartBlit
                bsr     DrawTable
                bsr     SetPal

                BLTHOGON
                bsr     BlitIRQEnd
                bsr     SwapBuffers
                bsr     PokeCopper

                PROFILE_BG $f00
                CALLFW  CopSyncWithTask
                PROFILE_BG $000

                cmp.w   #FACELIGHTS_END,fw_FrameCounter(a6)
                blt     .loop
                CALLFW  SetBaseCopper
                CALLFW  DisableCopperSync
                rts


********************************************************************************
* Routines
********************************************************************************

********************************************************************************
InitVars:
                move.l  #CHUNKY_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,DrawChunky

                move.l  #CHUNKY_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,ViewChunky

                move.l  #PLANAR_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,ViewScreen

                move.l  #PLANAR_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,DrawScreen

                rts


********************************************************************************
ClearScreen:
                BLTWAIT
                clr.w   bltdmod(a5)
                move.l  #$01000000,bltcon0(a5)
                move.l  a0,bltdpt(a5)
                move.w  #SCREEN_H/2*BPLS*64+SCREEN_BW/2,bltsize(a5)
                rts


********************************************************************************
SetPal:
                move.l  PalStepPtrs,a0
                move.w  Fade(pc),d0
                lsl.w   #2,d0
                move.l  (a0,d0.w),a0
                moveq.l #COLORS/4-1,d7
                lea     color00(a5),a1
.l:
                move.l  (a0)+,(a1)+
                move.l  (a0)+,(a1)+
                dbra    d7,.l
                rts


SetSpritePos    macro
                and.w   #511,d0
                and.w   #511,d1
                sub.w   #256-8+DIW_XSTRT+DIW_W/2,d0
                sub.w   #256+8+DIW_YSTRT+DIW_H/2,d1
                neg.w   d0
                neg.w   d1
                ; CLAMP_MIN_W #DIW_XSTRT-32,d0
                ; CLAMP_MIN_W #DIW_YSTRT-32,d1
                ; CLAMP_MAX_W #DIW_XSTOP+48,d0
                ; CLAMP_MAX_W #DIW_YSTOP+48,d1

                moveq   #SPRITE_H,d2    ; height
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

                move.w  d1,(a0)
                move.w  d2,2(a0)

                addq.w  #8,d1
                move.w  d1,SPRITE_SIZE(a0)
                move.w  d2,SPRITE_SIZE+2(a0)
                endm

********************************************************************************
Update:
                PUSHM   d0-d5/a0

                move.l  fw_FrameCounterLong(a6),d0
                sub.w   #FACELIGHTS_START,d0

                ; Fade in
                cmp.w   #15<<1,d0
                bgt     .fadeInDone
                move.w  d0,d1
                lsr.w   #1,d1
                move.w  d1,Fade
                bra     .fadeDone
.fadeInDone:

                ; Fade out
                cmp.w   #FACELIGHTS_DURATION-15<<2,d0
                blt     .noFadeOut
                move.w  #FACELIGHTS_DURATION,d1
                sub.w   d0,d1
                lsr.w   #2,d1
                move.w  d1,Fade
                bra     .fadeDone
.noFadeOut:
                move.w  #15,Fade
.fadeDone:


                move.l  fw_CosTable(a6),a0
                move.w  fw_FrameCounter(a6),d1
                lsl.w   #2,d1
                and.w   #$7fe,d1

                move.w  (a0,d1.w),d0
                asr.w   #6,d0
                move.w  fw_FrameCounter(a6),d1
                lsl.w   #2,d1

                move.w  d0,pd_XPos(a6)
                move.w  d1,pd_YPos(a6)

; Position to texture offset
                asr.w   #2,d0
                asr.w   #2,d1
                and.w   #TEX_H-1,d1
                lsl.w   #7,d1
                add.w   d1,d0
                and.w   #TEX_SIZE-1,d0
                add.w   d0,d0
                move.w  d0,TexOffset

; Update sprites
                move.w  pd_XPos(a6),d4
                move.w  pd_YPos(a6),d5
; blue
                lea     Sprite1+4,a0
                move.w  d4,d0
                move.w  d5,d1
                add.w   #(SPRITE_X_OFFSET-97)*4,d0
                add.w   #(SPRITE_Y_OFFSET-96)*4,d1
                SetSpritePos

; green
                adda.w  #SPRITE_PAIR_SIZE,a0
                move.w  d4,d0
                move.w  d5,d1
                add.w   #(SPRITE_X_OFFSET-94)*4,d0
                add.w   #(SPRITE_Y_OFFSET-39)*4,d1
                SetSpritePos

; red
                adda.w  #SPRITE_PAIR_SIZE,a0
                move.w  d4,d0
                move.w  d5,d1
                add.w   #(SPRITE_X_OFFSET-39)*4,d0
                add.w   #(SPRITE_Y_OFFSET-90)*4,d1
                SetSpritePos

; purple
                adda.w  #SPRITE_PAIR_SIZE,a0
                move.w  d4,d0
                move.w  d5,d1
                add.w   #(SPRITE_X_OFFSET-36)*4,d0
                add.w   #(SPRITE_Y_OFFSET-33)*4,d1
                SetSpritePos
                POPM
                rts

********************************************************************************
PokeCopper:
                move.l  ViewScreen(pc),d1

; Set bitplane ptrs
                lea     CopBplpts,a0
                moveq   #4-1,d0         ; bpls 0-3
.l:             SET_COP_PTR d1,a0
                add.l   #SCREEN_SIZE,d1
                dbf     d0,.l

                rts


********************************************************************************
SetSprites:
                lea     CopSprPt+2,a2
                move.l  #Sprite1+4,d1

                rept    4
                move.w  d1,4(a2)
                swap    d1
                move.w  d1,(a2)
                swap    d1
                lea     8(a2),a2

                add.l   #SPRITE_SIZE,d1
                move.w  d1,4(a2)
                swap    d1
                move.w  d1,(a2)
                swap    d1
                lea     8(a2),a2
                add.l   #SPRITE_PAIR_SIZE-SPRITE_SIZE,d1
                endr
                rts

********************************************************************************
InitFadeRGB:
                lea     RGBTbl,a0
                moveq   #0,d2           ; step size (FP8)
                moveq   #16-1,d0
.y:             moveq   #0,d3           ; value (always start at zero)
                moveq   #16-1,d1
.x:             move.w  d3,d4
                add.w   #$88,d4         ; round, not floor
                lsr.w   #8,d4           ; rgb component 0-f
                move.b  d4,(a0)+

                add.w   d2,d3           ; increment value
                dbf     d1,.x
                add.w   #$11,d2         ; increment step size per row
                dbf     d0,.y
                rts


                include table-2x2.asm
                include c2p-2x2.asm

                include transitons.asm

********************************************************************************
Vars:
********************************************************************************

Fade:           dc.w    0
PalStepPtrs:    dc.l    0
PalData:        dc.l    0


********************************************************************************
* Data
********************************************************************************

Pal:
; Texture
                incbin  data/phong-x4.pal
; Sprites
                dc.w    0,$147,$17c,$fff ; blue
                dc.w    0,$7a6,$ad7,$fff ; green
                dc.w    0,$a00,$f44,$fff ; red
                dc.w    0,$b6a,$f9d,$fff ; purple

BlankPal:
                ds.w    COLORS

TextureSrc:     incbin  data/phong-x4.chk
TableData:
                incbin  data/face-160.bin

*******************************************************************************
                data_c
*******************************************************************************

                include cop-2x2.asm

Sprite1:
                incbin  data/light-32.SPR
SPRITE_PAIR_SIZE = *-Sprite1
Sprite2:
                incbin  data/light-32.SPR
Sprite3:
                incbin  data/light-32.SPR
Sprite4:
                incbin  data/light-32.SPR

*******************************************************************************
                bss
*******************************************************************************

RGB_TBL_SIZE = 16*16*2
RGBTbl:         ds.b    RGB_TBL_SIZE/2
