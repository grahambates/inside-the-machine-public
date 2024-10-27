                include tunnelx4.i

                ifnd    FW_DEMO_PART
                xdef    _start
_start:
                include "../framework/framework.asm"
                else
                bra.s   entrypoint
                bra     precalc
                endc

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

                bsr     PokeCopper
                lea     Cop,a0
                CALLFW  SetCopper
                move.w  #DIW_YSTOP,d0
                CALLFW  EnableCopperSync

;-------------------------------------------------------------------------------
.loop:
                BLTHOGOFF
                bsr     SetPal
                bsr     SetPalOffs

                bsr     BlitIRQStart
                bsr     StartBlit
                bsr     Update
                bsr     DrawTable

                bsr     BlitIRQEnd
                bsr     SwapBuffers
                bsr     PokeCopper
                bsr     SetSprites

                PROFILE_BG $f00
                CALLFW  CopSyncWithTask
                PROFILE_BG $000

                cmp.w   #TUNNEL_X4_END,fw_FrameCounter(a6)
                blt     .loop
                CALLFW  SetBaseCopper
                rts


********************************************************************************
precalc:
********************************************************************************
                move.l  #SMC_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,TableCode

                lea     TableData+2,a0
                bsr     GenerateTable

                move.l  #TOTAL_TEXTURE_SIZE,d0
                CALLFW  AllocFast
                move.l  a0,ScrambledTex

                move.l  ScrambledTex(pc),a0
                lea     TextureSrc1,a4
                bsr     ScrambleTexture

                move.l  ScrambledTex(pc),a0
                add.l   #TOTAL_SCRAMBLED_SIZE,a0
                lea     TextureSrc2,a4
                bsr     ScrambleTexture

                move.l  ScrambledTex(pc),a0
                add.l   #TOTAL_SCRAMBLED_SIZE*2,a0
                lea     TextureSrc3,a4
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

                rts


********************************************************************************
* Routines
********************************************************************************

********************************************************************************
SetPal:
                move.l  PalStepPtrs,a0
                move.w  Fade(pc),d0
                lsl.w   #2,d0
                move.l  (a0,d0.w),a0
                moveq.l #COLORS/2-1,d7
                lea     color00(a5),a1
.l:
                move.l  (a0)+,(a1)+
                dbra    d7,.l
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


********************************************************************************
InitVars:
                move.l  #CHUNKY_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,DrawChunky
                bsr     ClearChunky

                move.l  #CHUNKY_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,ViewChunky

                move.l  #PLANAR_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,ViewScreen

                move.l  #PLANAR_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,DrawScreen
                bsr     ClearScreen

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
ClearChunky:
                BLTWAIT
                clr.w   bltdmod(a5)
                move.l  #$01000000,bltcon0(a5)
                move.l  a0,bltdpt(a5)
                move.w  #SCREEN_H/2*2*64+SCREEN_BW/2,bltsize(a5)
                rts


********************************************************************************
Update:
                move.l  fw_FrameCounterLong(a6),d0
                sub.w   #TUNNEL_X4_START,d0

                ; Fade in
                cmp.w   #15<<1,d0
                bgt     .fadeInDone
                move.w  d0,d1
                lsr.w   #1,d1
                move.w  d1,Fade
                bra     .fadeDone
.fadeInDone:


                ; Fade out
                cmp.w   #TUNNEL_X4_DURATION-15<<2,d0
                blt     .noFadeOut
                move.w  #TUNNEL_X4_DURATION,d1
                sub.w   d0,d1
                lsr.w   #2,d1
                move.w  d1,Fade
                bra     .fadeDone
.noFadeOut:
                lea     Noise,a0
                move.w  d0,d1
                and.w   #1024*2-2,d1
                move.w  (a0,d1.w),d1
                lsr.w   #8,d1
                add.w   #12,d1
                move.w  d1,Fade
.fadeDone:

; Tex offset 1
                move.l  fw_FrameCounterLong(a6),d1 ; V
                lsr.w   #1,d1
                and.w   #TEX_H-1,d1
                clr.w   d0              ; U
                lsl.w   #7,d1
                add.w   d1,d0
                and.w   #TEX_SIZE-1,d0
                add.w   d0,d0
                move.w  d0,TexOffset
; Tex offset 2
                move.l  fw_SinTable(a6),a0
                move.w  fw_FrameCounter(a6),d1 
                lsl.w   #2,d1
                and.w   #$7fe,d1
                move.w  (a0,d1.w),d0    ; U
                asr.w   #8,d0
                and.w   #TEX_W-1,d0

                move.w  fw_FrameCounter(a6),d1 ; V
                asr.w   d1
                and.w   #TEX_H-1,d1

                lsl.w   #7,d1
                add.w   d1,d0
                and.w   #TEX_SIZE-1,d0
                add.w   d0,d0
                move.w  d0,TexOffset2

; Tex offset 3
                move.l  fw_SinTable(a6),a0
                move.w  fw_FrameCounter(a6),d1 
                lsl.w   #1,d1
                and.w   #$7fe,d1
                move.w  (a0,d1.w),d0    ; U
                asr.w   #7,d0
                and.w   #TEX_W-1,d0

                move.l  fw_CosTable(a6),a0
                move.w  fw_FrameCounter(a6),d1 
                lsl.w   #1,d1
                and.w   #$7fe,d1
                move.w  (a0,d1.w),d1    ; U
                asr.w   #7,d1
                and.w   #TEX_W-1,d1

                lsl.w   #7,d1
                add.w   d1,d0
                and.w   #TEX_SIZE-1,d0
                add.w   d0,d0
                move.w  d0,TexOffset3

; Sprite palette offset
                move.w  fw_FrameCounter(a6),d0
                asr.w   d0
                ext.l   d0
                divs    #CHROME_COLS*4,d0
                swap    d0
                move.w  d0,PalCyclePos

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
                move.l  fw_FrameCounterLong(a6),d0
                sub.w   #TUNNEL_X4_START,d0

                move.w  #SPRITE2_X,d4
                move.w  #SPRITE2_Y,d5

                ; Sinus movement on flyer
                move.l  d0,d1
                move.l  fw_SinTable(a6),a4
                lsl.w   #4,d1
                and.w   #$7fe,d1
                move.w  (a4,d1.w),d1
                add.w   #$4000,d1
                lsl.l   #4,d1
                swap    d1
                add.w   d1,d4

                ; Get sprite for frame number
                lea     CopSprPt+2,a2
                lea     SpritePts,a0
                asr.w   d0
                divu    #SPRITE_FRAMES,d0 ; modulo
                swap    d0
                lsl.w   #2,d0
                move.l  (a0,d0),a0

                ; Write copper ptrs
                move.l  a0,a1
                moveq   #6-1,d7
.l:
                move.w  (a1)+,d3
                lea     (a0,d3),a3
                move.l  a3,d3
                move.w  d3,4(a2)
                swap    d3
                move.w  d3,(a2)
                lea     8(a2),a2
                dbf     d7,.l

                ; Set control words to move flyer
                move.w  #4+SPRITE1_H*4,d6 ; sprite 2 offset
                move.l  a0,a1
                moveq   #2-1,d7         ; first two slices
.slice:
                rept    2
                move.w  (a1)+,d3
                lea     (a0,d3),a3

                move.w  d4,d0
                move.w  d5,d1
                move.w  #SPRITE2_H,d2
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
                move.w  d1,(a3,d6)
                move.w  d2,2(a3,d6)
                endr

                add.w   #16,d4
                dbf     d7,.slice

                tst.w   d6
                beq     .done
                
                ; go back and to one more slice without offset
                ; 3rd slice is not used in sprite 1, sprite 2 offset = 0
                moveq   #0,d6
                moveq   #0,d7
                bra     .slice

.done:          rts


                include table-2x2.asm
                include c2p-2x2.asm


********************************************************************************
SetPalOffs:
                lea     Pal2(pc),a0
                move.w  PalCyclePos(pc),d0
                add.w   d0,d0
                lea     (a0,d0.w),a0
                lea     color17(a5),a1
                move.w  #CHROME_COLS-1,d7

                move.w  Fade(pc),d0
                cmp.w   #16,d0
                blt     .fade
.l0:
                move.w  (a0)+,(a1)+
                addq    #3*2,a0
                dbf     d7,.l0
                rts

.fade:
                PROFILE_BG $ff0
                lsl.w   #4,d0           ; *16
                lea     RGBTbl,a2
                lea     (a2,d0.w),a2    ; Move to row in LUTs for fade value
                moveq   #0,d1
                lea     .tmp,a3
                moveq   #$f,d3

.l1:
                move.b  (a0)+,d1        ; r
                move.b  (a2,d1.w),(a3)
                move.b  (a0)+,d1        ; g/b
                move.w  d1,d2
                and.w   d3,d2           ; b
                lsr.b   #4,d1           ; g
                move.b  (a2,d1.w),d1
                lsl.b   #4,d1
                or.b    (a2,d2.w),d1
                move.b  d1,1(a3)
                move.w  (a3),(a1)+

                addq    #3*2,a0
                dbf     d7,.l1
                PROFILE_BG $000
                rts

.tmp:           ds.w    1


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
                incbin  data/tex1.pal
BlankPal:       
                ds.w    COLORS

PalCyclePos:    dc.w    0

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
                dc.l    Sprite16
                dc.l    Sprite17
                dc.l    Sprite18
                dc.l    Sprite19
                dc.l    Sprite20
                dc.l    Sprite21
                dc.l    Sprite22
                dc.l    Sprite23
                dc.l    Sprite24
                dc.l    Sprite25


Pal2:
                rept    2
; https://gradient-blaster.grahambates.com/?points=001@0,eee@20,58b@25,000@35,ffd@38,a88@46,000@59&steps=60&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=0
                dc.w    $001,$001,$112,$112,$223,$233,$334,$445
                dc.w    $456,$566,$667,$777,$888,$899,$99a,$aab
                dc.w    $bbb,$ccc,$ddd,$eee,$eee,$cde,$bcd,$8bd
                dc.w    $79c,$58b,$47a,$468,$357,$246,$235,$123
                dc.w    $112,$011,$000,$000,$443,$998,$ffd,$eed
                dc.w    $eec,$ecb,$dcb,$cba,$ba9,$b99,$a88,$977
                dc.w    $866,$766,$655,$544,$533,$433,$322,$222
                dc.w    $111,$100,$000,$000
                endr

TextureSrc1:    incbin  data/tex1.chk
TextureSrc2:    incbin  data/tex2.chk
TextureSrc3:    incbin  data/tex3.chk

TableData:      
                incbin  assets/16_tunnel4x_UVL_160x90_t64_Delta.ggb

                include noise.i

*******************************************************************************
                data_c
*******************************************************************************

Cop:
CopSprPt:
                rept    8*2
                dc.w    sprpt+REPTN*2,0
                endr
CopBplpts:
                dc.w    bpl0pt,0
                dc.w    bpl0ptl,0
                dc.w    bpl2pt,0
                dc.w    bpl2ptl,0
                dc.w    bpl1pt,0
                dc.w    bpl1ptl,0
                dc.w    bpl3pt,0
                dc.w    bpl3ptl,0
                dc.w    bpl4pt,0
                dc.w    bpl4ptl,0

                dc.w    dmacon,DMAF_SETCLR!DMAF_SPRITE
                dc.w    bplcon0,(BPLS<<12)!$200
                dc.w    bplcon1,0
                dc.w    diwstrt,(DIW_YSTRT<<8)!DIW_XSTRT
                dc.w    diwstop,(((DIW_YSTRT+SCREEN_H)<<8)&$ff00)!((DIW_XSTRT+SCREEN_W)&$ff)
                dc.w    ddfstrt,DIW_XSTRT/2-8
                dc.w    ddfstop,DIW_XSTRT/2-8+8*((SCREEN_W+15)/16-1)

CopY            set     DIW_YSTRT-1

                rept    SCREEN_H/4
                COP_WAITH CopY,$df
                ifne    ALT
                dc.w    bplcon1,0
                endc
                dc.w    bpl1mod,-SCREEN_BW
                dc.w    bpl2mod,-SCREEN_BW
                COP_WAIT CopY+1,$df
; move to next scanline
                ifne    ALT
                dc.w    bplcon1,ALT+(ALT<<4)
                endc
                dc.w    bpl1mod,0
                dc.w    bpl2mod,0
CopY            set     CopY+2
                endr

                rept    SCREEN_H/4
                COP_WAITH CopY,$df
                ifne    ALT
                dc.w    bplcon1,0
                endc
                dc.w    bpl1mod,-SCREEN_BW
                dc.w    bpl2mod,-SCREEN_BW
                COP_WAIT CopY+1,$df
; move to next scanline
                ifne    ALT
                dc.w    bplcon1,ALT+(ALT<<4)
                endc
                dc.w    bpl1mod,0
                dc.w    bpl2mod,0
CopY            set     CopY+2
                endr
                COP_WAITH CopY,$df

                COP_WAITV DIW_YSTOP
                dc.w    intreq,INTF_SETCLR!INTF_COPER

                dc.l    -2

Sprite01:       incbin  data/Sprites-0001.ASP
Sprite02:       incbin  data/Sprites-0002.ASP
Sprite03:       incbin  data/Sprites-0003.ASP
Sprite04:       incbin  data/Sprites-0004.ASP
Sprite05:       incbin  data/Sprites-0005.ASP
Sprite06:       incbin  data/Sprites-0006.ASP
Sprite07:       incbin  data/Sprites-0007.ASP
Sprite08:       incbin  data/Sprites-0008.ASP
Sprite09:       incbin  data/Sprites-0009.ASP
Sprite10:       incbin  data/Sprites-0010.ASP
Sprite11:       incbin  data/Sprites-0011.ASP
Sprite12:       incbin  data/Sprites-0012.ASP
Sprite13:       incbin  data/Sprites-0013.ASP
Sprite14:       incbin  data/Sprites-0014.ASP
Sprite15:       incbin  data/Sprites-0015.ASP
Sprite16:       incbin  data/Sprites-0016.ASP
Sprite17:       incbin  data/Sprites-0017.ASP
Sprite18:       incbin  data/Sprites-0018.ASP
Sprite19:       incbin  data/Sprites-0019.ASP
Sprite20:       incbin  data/Sprites-0020.ASP
Sprite21:       incbin  data/Sprites-0021.ASP
Sprite22:       incbin  data/Sprites-0022.ASP
Sprite23:       incbin  data/Sprites-0023.ASP
Sprite24:       incbin  data/Sprites-0024.ASP
Sprite25:       incbin  data/Sprites-0025.ASP


*******************************************************************************
                bss
*******************************************************************************

RGB_TBL_SIZE = 16*16*2
RGBTbl:         ds.b    RGB_TBL_SIZE/2
