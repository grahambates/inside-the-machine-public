                include motherboard.i

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

                lea     pd_Palette(a6),a1
                move.w  #COLORS,d0
                move.w  #000,d1
                CALLFW  InitPaletteLerpSameColor

FADE_IN_FRAMES = 32
                
                moveq   #COLORS,d0
                move.w  #FADE_IN_FRAMES,d1
                lea     Pal(pc),a0
                lea     pd_Palette(a6),a1
                CALLFW  FadePaletteTo

                clr.w   fw_FrameCounter(a6)
                lea     .script(pc),a0
                CALLFW  InstallScript

                bsr     ClearSprites
                bsr     SetPal
                bsr     SetBplPtrs
                lea     Cop,a0
                CALLFW  SetCopper

                ; Audio interrupt
                move.l  fw_VBR(a6),a0
                lea     L4Int(pc),a1
                move.l  a1,$70(a0)
                move.w  #INTF_SETCLR!INTF_AUD0,intena(a5)

;-------------------------------------------------------------------------------
.loop:
                CALLFW  VSyncWithTask
                CALLFW  CheckScript

                tst.w   pd_CycleOn
                lea     pd_Palette(a6),a1
                move.w  #COLORS,d0
                CALLFW  DoFadePaletteStep

                bsr     SetPal
                bsr     Update
                bsr     SetBplPtrs
                bsr     DrawSpark

                cmp.w   #MOTHERBOARD_END,fw_FrameCounter(a6)
                blt     .loop
                CALLFW  SetBaseCopper
                rts


;-------------------------------------------------------------------------------
.script:
                dc.w    MOTHERBOARD_END-FADE_OUT_FRAMES,.fadeOut-*
                dc.w    0

.fadeOut:
                clr.w   pd_CycleOn(a6)

                ; Re-init from modified palette
                lea     Pal(pc),a0
                lea     pd_Palette(a6),a1
                move.w  #COLORS,d0
                CALLFW  InitPaletteLerp

                moveq   #COLORS,d0
                move.w  #FADE_OUT_FRAMES,d1
                lea     PalWhite,a0
                lea     BlankPal,a0
                lea     pd_Palette(a6),a1
                CALLFW  FadePaletteTo

                rts


********************************************************************************
L4Int:
                btst    #INTB_AUD0,intreqr+custom+1
                beq.s   .notAud0
                move.w  #INTF_AUD0,intreq+custom
                tst.w   LoopSound
                bne     .loop
                move.l  #NullSprite,aud0lch+custom
                move.w  #2,aud0len+custom
.loop:
.notAud0:
                rte


********************************************************************************
* Routines
********************************************************************************
                include transitons.asm

********************************************************************************
SetPal:
                lea     pd_Palette(a6),a1
                moveq.l #COLORS-1,d7
                lea     color00(a5),a0

                ; Flicker when spark is on
                tst.w   pd_SparkOn(a6)
                beq     .noSpark
                move.w  fw_FrameCounter(a6),d0
.l0:
                move.w  d7,-(sp)
                ; Lerp color
                move.w  #$8000,d0       ; step (0-$8000)
                move.w  fw_FrameCounter(a6),d1
                and.w   #7,d1           ; $8000-(frame%8)
                sub.w   d1,d0
                moveq   #0,d3           ; src1 (black)
                move.w  cl_Color(a1),d4 ; src2 (color)
                bsr     LerpCol
                move.w  d7,(a0)+
                lea     cl_SIZEOF(a1),a1
                move.w  (sp)+,d7
                dbra    d7,.l0
                rts
.noSpark:

                ; Cycle colours on CPU
                tst.w   pd_CycleOn(a6)
                beq     .noCycle
                move.w  CyclePos(pc),d0
                cmp.w   #(CYCLE_COLS-2)*4,d0
                blt     .ok
                moveq   #0,d0
                clr.w   CyclePos
.ok:
                lsr.w   #2,d0
                add.w   d0,d0
                lea     CycleColors(pc),a2
                adda.w  d0,a2
                lea     cl_SIZEOF*24(a1),a3 ; Write cycled values to struct
                lea     Pal+24*2(pc),a4 ; Update original palette too for fade out
                moveq   #8-1,d7
.l1:
                move.w  (a2),cl_Color(a3)
                move.w  (a2),(a4)+
                addq    #6,a2
                lea     cl_SIZEOF(a3),a3
                dbra    d7,.l1

                addq.w  #1,CyclePos
.noCycle:

                ; copy from lerped colour destination
                moveq.l #COLORS-1,d7
.l2:
                move.w  cl_Color(a1),(a0)+
                lea     cl_SIZEOF(a1),a1
                dbra    d7,.l2
                rts

CYCLE_COLS = 24

CyclePos:       dc.w    8
CycleColors:
                rept    2
                dc.w    $765,$876,$986,$a97,$ba8,$ba9,$cca,$ddb 
                dc.w    $ddc,$eed,$eee,$fff,$eee,$eed,$ddc,$ddb 
                dc.w    $cca,$ba9,$ba8,$a97,$986,$876
                endr

********************************************************************************
InitVars:
                move.w  #SCREEN_W_VIS-DIW_W,pd_PanX(a6)
                clr.w   pd_PanY(a6)
                 
                clr.w   pd_SparkOn(a6)
                clr.w   pd_CycleOn(a6)
                move.w  #427,pd_SparkX(a6)
                move.w  #193,pd_SparkY(a6)
                rts


********************************************************************************
Update:
                move.w  fw_FrameCounter(a6),d0
                sub.w   fw_ScriptFrameOffset(a6),d0

;-------------------------------------------------------------------------------
; pan around image
                sub.w   #(SCREEN_W_VIS-DIW_W),d0
                bgt     .a
                sub.w   #1,pd_PanX(a6)
                rts
.a:
                sub.w   #(SCREEN_H-DIW_H)/2,d0
                bgt     .b
                add.w   #2,pd_PanY(a6)
                rts
.b:
                sub.w   #(SCREEN_W_VIS-DIW_W)/2,d0
                bgt     .c
                add.w   #2,pd_PanX(a6)
                rts
.c:

;-------------------------------------------------------------------------------
; blit accelerator
ACC_START_X = 65
ACC_PAUSE_X = 28
ACC_PAUSE_FRAMES = 40
ACC_END_X = 9
                sub.w   #(ACC_START_X-ACC_PAUSE_X)/2,d0 ; start
                bgt     .d
                neg.w   d0
                lsl.w   #1,d0
                add.w   #ACC_PAUSE_X,d0
                bra     BlitAcc
.d:

                sub.w   #ACC_PAUSE_FRAMES,d0 ; pause
                bgt     .d1
                rts
.d1:

                cmp.w   #12,d0
                bne     .d2a
                lea     ClickSample,a0
                move.w  #(ClickSampleE-ClickSample)/2,d0
                move.w  #600,d1
                move.w  #64,d2
                moveq   #0,d3
                bsr     PlaySound 
.d2a:

                sub.w   #ACC_PAUSE_X-ACC_END_X+1,d0 ; connect
                bge     .d2
                neg.w   d0
                add.w   #ACC_END_X,d0
                bra     BlitAcc
.d2:

;-------------------------------------------------------------------------------
; Start spark anim and sound
                tst.w   d0
                bne     .d3a
                move.w  #1,pd_SparkOn(a6)
.d3a:

                cmp.w   #20,d0
                bne     .noStart
                lea     LaserSample,a0
                move.w  #(LaserSampleE-LaserSample)/2,d0
                move.w  #100,d1         ; period
                move.w  #0,d2           ; volume
                moveq   #1,d3           ; loop
                bsr     PlaySound 
.noStart:

                ; Fade in laser sound
                move.w  d0,d1
                sub.w   #20,d1
                add.w   d1,d1
                blt     .noSetVol
                cmp.w   #64,d1
                bgt     .noSetVol
                move.w  d1,aud0vol(a5)
.noSetVol:

;-------------------------------------------------------------------------------
; Move spark:
SPARK_DIR1_L = 22
SPARK_DIR2_LD = 26
SPARK_DIR3_L = 44
SPARK_DIR4_LD = 30
SPARK_DIR5_L = 55
SPARK_PAN1_L = SCREEN_W_VIS-DIW_W       ; ???
SPARK_PAN2_U = 22
                sub.w   #SPARK_DIR1_L,d0
                bgt     .d3
                sub.w   #1,pd_SparkX(a6)
                rts
.d3:
                sub.w   #SPARK_DIR2_LD,d0
                bgt     .d4
                sub.w   #1,pd_SparkX(a6)
                add.w   #1,pd_SparkY(a6)
                rts
.d4:
                sub.w   #SPARK_DIR3_L,d0
                bgt     .d5
                sub.w   #1,pd_SparkX(a6)
                rts
.d5:
                sub.w   #SPARK_DIR4_LD,d0
                bgt     .d6
                sub.w   #1,pd_SparkX(a6)
                add.w   #1,pd_SparkY(a6)
                rts
.d6:
                sub.w   #SPARK_DIR5_L,d0
                bgt     .d7
                sub.w   #1,pd_SparkX(a6)
                rts
.d7:
; Pan while drawing spark
                sub.w   #SPARK_PAN1_L,d0
                bge     .e
                sub.w   #1,pd_PanX(a6)
                sub.w   #1,pd_SparkX(a6)
                rts
.e:
                sub.w   #SPARK_PAN2_U,d0
                bge     .f
                sub.w   #1,pd_PanY(a6)
                sub.w   #1,pd_SparkY(a6)
                rts
.f:

;-------------------------------------------------------------------------------
; Start fade to hot palette
HOT_FADE_FRAMES = 32
                tst.w   d0
                bne     .f1
                moveq   #COLORS,d0      ; colors
                move.w  #HOT_FADE_FRAMES,d1 ; frames?
                lea     PalHot(pc),a0   ; dest
                lea     pd_Palette(a6),a1 ; src
                CALLFW  FadePaletteTo

                ; Turn off spark
                clr.w   pd_SparkOn(a6)
                bsr     StopSound

                ; Start music
                ifd     FW_DEMO_PART
                PUSHM   d0-a6
                CALLFW  StartMusic
                PUTMSG  10,<10,"%d TIMING: Start music">,fw_FrameCounter(a6)
                POPM
                endc

                rts
.f1:
                ; wait fade
                sub.w   #HOT_FADE_FRAMES,d0
                bgt     .g
                rts
.g:


;-------------------------------------------------------------------------------
; Burn animation
BURN_FRAMES = 12
                sub.w   #BURN_FRAMES*2-1,d0
                bge     .h
                asr     #1,d0
                add.w   #BURN_FRAMES,d0
                move.w  #BURN_H,d1
                bsr     BlitBurn
                rts
.h:

;-------------------------------------------------------------------------------
; Enable color cycle
                tst.w   d0
                bne     .i
                move.w  #1,pd_CycleOn(a6)
.i:

;-------------------------------------------------------------------------------
; Blit final CPU frame for cycle
                sub.w   #BURN_H/8,d0
                bgt     .j
                move.w  d0,d1
                lsl.w   #3,d1
                add.w   #BURN_H,d1
                moveq   #BURN_FRAMES+1,d0
                bra     BlitBurn
.j:

                rts


********************************************************************************
SetBplPtrs:
                lea     ImgBoard,a1

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

                adda.w  d0,a1
                mulu    #SCREEN_BW*BPLS,d1
                add.l   d1,a1

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
; d0 - frame
; d1 - height
BlitBurn:
                lea     ImgBurn,a0
                lea     ImgBoard+4+SCREEN_BW*BPLS*67,a1
                lea     ImgBurnMask,a2
                mulu    #BURN_SIZE,d0
                adda.l  d0,a0
                BLTWAIT
                move.l  #$fe20000,bltcon0(a5)
                clr.w   bltamod(a5)
                clr.w   bltbmod(a5)
                move.w  #SCREEN_BW-BURN_BW,d0
                move.w  d0,bltcmod(a5)
                move.w  d0,bltdmod(a5)
                move.l  #-1,bltafwm(a5)
                move.l  a0,bltapt(a5)
                move.l  a2,bltbpt(a5)
                move.l  a1,bltcpt(a5)
                move.l  a1,bltdpt(a5)
                mulu    #BPLS*64,d1
                add.w   #BURN_BW/2,d1
                move.w  d1,bltsize(a5)
                rts


********************************************************************************
; d0 - x offset
BlitAcc:
                lea     ImgAccelerator,a0
                lea     ImgAcceleratorMask,a2
                lea     ImgBoard+52+SCREEN_BW*BPLS*148,a1

                moveq   #$f,d1
                and.w   d0,d1
                ror.w   #4,d1

                lsr.w   #4,d0
                add.w   d0,d0
                adda.w  d0,a1

                BLTWAIT
                move.w  d1,bltcon1(a5)
                add.w   #$0fe2,d1
                move.w  d1,bltcon0(a5)
                clr.w   bltamod(a5)
                clr.w   bltbmod(a5)
                move.w  #SCREEN_BW-ACC_BW,d0
                move.w  d0,bltcmod(a5)
                move.w  d0,bltdmod(a5)
                move.l  #-1,bltafwm(a5)
                move.l  a0,bltapt(a5)
                move.l  a2,bltbpt(a5)
                move.l  a1,bltcpt(a5)
                move.l  a1,bltdpt(a5)
                move.w  #ACC_H*BPLS*64+ACC_BW/2,bltsize(a5)
                rts


********************************************************************************
DrawSpark:
                tst.w   pd_SparkOn(a6)
; Set null sprites if not enabled
                beq     ClearSprites

; animation frame 0-2
                move.l  fw_FrameCounterLong(a6),d0
                asr.l   d0
                divu    #3,d0
                swap    d0

; Blit accelerator sparkle
                lea     AccSparkle,a0
                move.w  d0,d1
                mulu    #ACC_SPARKLE_SIZE,d1
                adda.w  d1,a0
                lea     ImgBoard+(ACC_SPARKLE_X/8)+SCREEN_BW*BPLS*ACC_SPARKLE_Y,a1
                BLTWAIT
                move.l  #$09f00000,bltcon0(a5)
                clr.w   bltamod(a5)
                move.w  #SCREEN_BW-ACC_SPARKLE_BW,bltdmod(a5)
                move.l  #-1,bltafwm(a5)
                move.l  a0,bltapt(a5)
                move.l  a1,bltdpt(a5)
                move.w  #ACC_SPARKLE_H*BPLS*64+ACC_SPARKLE_BW/2,bltsize(a5)

; Set sprites
                lea     CopSprPt+2,a2
                lea     SpritePts,a0
                lsl.w   #2,d0
                move.l  (a0,d0),a0
                move.l  a0,a1

                move.w  (a1)+,d3
                lea     (a0,d3),a3

                move.w  pd_SparkX(a6),d0
                move.w  pd_SparkY(a6),d1

                sub.w   pd_PanX(a6),d0
                sub.w   pd_PanY(a6),d1

                add.w   #DIW_XSTRT-8,d0
                add.w   #DIW_YSTRT-3,d1
                move.w  #10,d2          ; height

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
                bset    #7,d2           ; attached

                move.w  d1,(a3)
                move.w  d2,2(a3)

                move.l  a3,d3
                move.w  d3,4(a2)
                swap    d3
                move.w  d3,(a2)
                lea     8(a2),a2


                move.l  #NullSprite,d3
                moveq   #8-1-1,d7
.l1:
                move.w  d3,4(a2)
                swap    d3
                move.w  d3,(a2)
                swap    d3
                lea     8(a2),a2

                dbf     d7,.l1

                ; plot pixels
                move.w  pd_SparkX(a6),d0
                move.w  pd_SparkY(a6),d1
                mulu    #SCREEN_BW*BPLS,d1
                move.w  d0,d2
                asr.w   #3,d2

                not.w   d0
                lea     ImgBoard,a0
                adda.l  d1,a0
                adda.w  d2,a0

                ; 0b01110 14
                bclr    d0,(a0)
                bset    d0,SCREEN_BW(a0)
                bset    d0,SCREEN_BW*2(a0)
                bset    d0,SCREEN_BW*3(a0)
                bclr    d0,SCREEN_BW*4(a0)

                ; 0b10000 16
                lea     SCREEN_BW*BPLS(a0),a0
                bclr    d0,(a0)
                bclr    d0,SCREEN_BW(a0)
                bclr    d0,SCREEN_BW*2(a0)
                bclr    d0,SCREEN_BW*3(a0)
                bset    d0,SCREEN_BW*4(a0)

                ; 0b10001 17
                lea     SCREEN_BW*BPLS(a0),a0
                bset    d0,(a0)
                bclr    d0,SCREEN_BW(a0)
                bclr    d0,SCREEN_BW*2(a0)
                bclr    d0,SCREEN_BW*3(a0)
                bset    d0,SCREEN_BW*4(a0)

                rts

ClearSprites:
                lea     CopSprPt+2,a2
                move.l  #NullSprite,d3
                moveq   #8-1,d7
.l2:
                move.w  d3,4(a2)
                swap    d3
                move.w  d3,(a2)
                swap    d3
                lea     8(a2),a2

                dbf     d7,.l2
                rts


********************************************************************************
; Start playing sample on channel 0
;-------------------------------------------------------------------------------
; a0 - sample data
; d0.w - length in words
; d1.w - period
; d2.w - valume
; d3.w - loop?
;-------------------------------------------------------------------------------
PlaySound:
                move.w  #DMAF_AUD0,dmacon(a5)
                move.l  a0,aud0lch(a5)
                move.w  d0,aud0len(a5)  ; length in words
                move.w  d1,aud0per(a5)
                move.w  d2,aud0vol(a5)
                move.w  d3,LoopSound
                move.w  #DMAF_SETCLR!DMAF_AUD0,dmacon(a5)
                rts


********************************************************************************
StopSound:
                move.w  #DMAF_AUD0,dmacon(a5)
                move.w  #INTF_AUD0,intena(a5)
                rts

LoopSound:      dc.w    0


********************************************************************************
* Data
********************************************************************************

SpritePts:
                dc.l    Sprite1
                dc.l    Sprite2
                dc.l    Sprite3

Pal:            incbin  data/board.PAL
PalHot:         incbin  data/board-hot.PAL
BlankPal:       
                ds.w    COLORS

PalWhite:       dcb.w   COLORS,$fff


*******************************************************************************
                data_c
*******************************************************************************

Cop:
                dc.w    dmacon,DMAF_SETCLR!DMAF_SPRITE
                dc.w    bplcon0,BPLS<<12!$200
CopScroll:      dc.w    bplcon1,0
CopBplPt:       rept    BPLS*2
                dc.w    bpl0pt+REPTN*2,0
                endr
CopSprPt:
                rept    8*2
                dc.w    sprpt+REPTN*2,0
                endr
                dc.w    diwstrt,DIW_YSTRT<<8!DIW_XSTRT
                dc.w    diwstop,(DIW_YSTOP-256)<<8!(DIW_XSTOP-256)
                dc.w    ddfstrt,(DIW_XSTRT-17)>>1&$fc-SCROLL*8
                dc.w    ddfstop,(DIW_XSTRT-17+(DIW_W>>4-1)<<4)>>1&$fc
                dc.w    bpl1mod,DIW_MOD
                dc.w    bpl2mod,DIW_MOD
                dc.l    -2
CopE:


ImgBoard:       incbin  data/board.BPL
ImgAccelerator: incbin  data/accelerator.BPL
ImgAcceleratorMask: 
                incbin  data/accelerator-mask.BPL
ImgBurnMask:    incbin  data/burn-mask.BPL

ImgBurn:
Burn01:         incbin  data/burn/01.BPL
Burn02:         incbin  data/burn/02.BPL
Burn03:         incbin  data/burn/03.BPL
Burn04:         incbin  data/burn/04.BPL
Burn05:         incbin  data/burn/05.BPL
Burn06:         incbin  data/burn/06.BPL
Burn07:         incbin  data/burn/07.BPL
Burn08:         incbin  data/burn/08.BPL
Burn09:         incbin  data/burn/09.BPL
Burn10:         incbin  data/burn/10.BPL
Burn11:         incbin  data/burn/11.BPL
Burn12:         incbin  data/burn/12.BPL
Burn13:         incbin  data/burn/13.BPL
Burn14:         incbin  data/burn/14.BPL

Sprite1:        incbin  data/sparkle1.ASP
Sprite2:        incbin  data/sparkle2.ASP
Sprite3:        incbin  data/sparkle3.ASP

AccSparkle:
AccSparkle01:   incbin  data/acc-sparkle1.BPL
AccSparkle02:   incbin  data/acc-sparkle2.BPL
AccSparkle03:   incbin  data/acc-sparkle3.BPL

NullSprite:     ds.w    2

LaserSample:
                incbin  assets/laser.raw,0,512
LaserSampleE:

ClickSample:
                incbin  assets/click.raw,0,700
ClickSampleE:
