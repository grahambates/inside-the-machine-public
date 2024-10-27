PROFILE = 0
                include tunnel-p.i

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

                ifd     FW_DEMO_PART
                move.w  #TUNNEL_P_START,d0
                CALLFW  WaitForFrame
                PUTMSG  10,<10,"%d TIMING: start part TunnelP">,fw_FrameCounter(a6)
                endc

                move.w  fw_FrameCounter(a6),ActualStart
 
                bsr     PokeCopper
                bsr     SetSprites
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

                cmp.w   #TUNNEL_P_END,fw_FrameCounter(a6)
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
                sub.w   ActualStart(pc),d0

                ; Fade in
                cmp.w   #15<<1,d0
                bgt     .fadeInDone
                move.w  d0,d1
                lsr.w   #1,d1
                move.w  d1,Fade
                bra     .fadeDone
.fadeInDone:

                move.l  fw_FrameCounterLong(a6),d0
                sub.w   #TUNNEL_P_START,d0

                ; Fade out
                cmp.w   #TUNNEL_P_DURATION-15<<2,d0
                blt     .noFadeOut
                move.w  #TUNNEL_P_DURATION,d1
                sub.w   d0,d1
                lsr.w   #2,d1
                move.w  d1,Fade
                bra     .fadeDone
.noFadeOut:
                lea     Noise,a0
                move.w  d0,d1
                and.w   #1024*2-2,d1
                move.w  (a0,d1.w),d1
                lsr.w   #7,d1
                add.w   #8,d1
                move.w  d1,Fade
.fadeDone:

; Tex offset 1/2
                move.w  fw_FrameCounter(a6),d1 ; V
                lsr.w   #1,d1
                and.w   #TEX_H-1,d1
                move.w  d1,d0
                and.w   #TEX_SIZE-1,d0
                add.w   d0,d0
                move.w  d0,TexOffset2
                lsl.w   #7,d1
                and.w   #TEX_SIZE-1,d1
                add.w   d1,d1
                move.w  d1,TexOffset

; Tex offset 3
                move.l  fw_SinTable(a6),a0
                move.w  fw_FrameCounter(a6),d1 
                lsl.w   #2,d1
                and.w   #$7fe,d1
                move.w  (a0,d1.w),d0    ; U
                asr.w   #6,d0
                and.w   #TEX_W-1,d0

                move.w  fw_FrameCounter(a6),d1 
                lsr.w   #1,d1
                and.w   #TEX_W-1,d1

                lsl.w   #7,d1
                add.w   d1,d0
                and.w   #TEX_SIZE-1,d0
                add.w   d0,d0
                move.w  d0,TexOffset3

; Sprite palette offset
                move.l  fw_SinTable(a6),a0
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


                include table-2x2.asm
                include c2p-2x2.asm


********************************************************************************
SetSprites:
                lea     CopSprPt+2,a2
                lea     SpritePts,a0
                move.l  fw_FrameCounterLong(a6),d0
                asr.w   d0
                divu    #SPRITE_FRAMES,d0 ; modulo
                swap    d0
                lsl.w   #2,d0
                move.l  (a0,d0),a0
                move.l  a0,a1

                moveq   #3-1,d7
.l:
                moveq   #2-1,d6
.l1:
                move.w  (a1)+,d3
                lea     (a0,d3),a3
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


********************************************************************************
SetPalOffs:
                lea     Pal2(pc),a0
                move.w  PalCyclePos(pc),d0
                add.w   d0,d0
                lea     (a0,d0.w),a0
                lea     color18(a5),a1
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

ActualStart:    dc.w    0
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
                dc.l    Sprite26

Pal2:		
                rept    2		
; https://gradient-blaster.grahambates.com/?points=001@0,bef@16,000@24,589@38,c77@42,9dd@46,000@59&steps=60&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=0
                dc.w    $001,$011,$012,$123,$234,$335,$345,$456
                dc.w    $567,$578,$689,$79a,$8ab,$9bc,$acd,$aee
                dc.w    $bef,$acd,$8ab,$688,$466,$344,$223,$111
                dc.w    $000,$000,$000,$011,$111,$122,$133,$234
                dc.w    $244,$345,$356,$467,$478,$478,$589,$789
                dc.w    $988,$b87,$c77,$c99,$caa,$bcc,$9dd,$8cc
                dc.w    $7bb,$7aa,$588,$577,$466,$355,$244,$233
                dc.w    $122,$111,$000,$000
                endr

TextureSrc1:    incbin  data/tex1.chk
TextureSrc2:    incbin  data/tex2.chk
TextureSrc3:    incbin  data/tex3.chk

TableData:       
                incbin  assets/16mm_P_tunnel_UVL_160x90_t64_Delta.ggb

                include noise.i

*******************************************************************************
                data_c
*******************************************************************************

Cop:
                dc.w    dmacon,DMAF_SETCLR!DMAF_SPRITE
                dc.w    bplcon0,(BPLS<<12)!$200
                dc.w    bplcon1,0
                dc.w    diwstrt,(DIW_YSTRT<<8)!DIW_XSTRT
                dc.w    diwstop,(((DIW_YSTRT+SCREEN_H)<<8)&$ff00)!((DIW_XSTRT+SCREEN_W)&$ff)
                dc.w    ddfstrt,DIW_XSTRT/2-8
                dc.w    ddfstop,DIW_XSTRT/2-8+8*((SCREEN_W+15)/16-1)
CopSprPt:
                rept    8*2
                dc.w    sprpt+REPTN*2,0
                endr
                dc.w    color17,0

.y              set     DIW_YSTRT-1
                rept    SCREEN_H/4
                COP_WAITH .y,$df
                ifne    ALT
                dc.w    bplcon1,0
                endc
                dc.w    bpl1mod,-SCREEN_BW
                dc.w    bpl2mod,-SCREEN_BW
                COP_WAIT .y+1,$df
; move to next scanline
                ifne    ALT
                dc.w    bplcon1,ALT+(ALT<<4)
                endc
                dc.w    bpl1mod,0
                dc.w    bpl2mod,0
.y              set     .y+2
                endr

                rept    SCREEN_H/4
                COP_WAITH .y,$df
                ifne    ALT
                dc.w    bplcon1,0
                endc
                dc.w    bpl1mod,-SCREEN_BW
                dc.w    bpl2mod,-SCREEN_BW
                COP_WAIT .y+1,$df
; move to next scanline
                ifne    ALT
                dc.w    bplcon1,ALT+(ALT<<4)
                endc
                dc.w    bpl1mod,0
                dc.w    bpl2mod,0
.y              set     .y+2
                endr
                COP_WAITH .y,$df

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

                COP_WAITV DIW_YSTOP
                dc.w    intreq,INTF_SETCLR!INTF_COPER

                dc.l    -2

Sprite01:       incbin  data/sa_P_strutter/0001.ASP
Sprite02:       incbin  data/sa_P_strutter/0002.ASP
Sprite03:       incbin  data/sa_P_strutter/0003.ASP
Sprite04:       incbin  data/sa_P_strutter/0004.ASP
Sprite05:       incbin  data/sa_P_strutter/0005.ASP
Sprite06:       incbin  data/sa_P_strutter/0006.ASP
Sprite07:       incbin  data/sa_P_strutter/0007.ASP
Sprite08:       incbin  data/sa_P_strutter/0008.ASP
Sprite09:       incbin  data/sa_P_strutter/0009.ASP
Sprite10:       incbin  data/sa_P_strutter/0010.ASP
Sprite11:       incbin  data/sa_P_strutter/0011.ASP
Sprite12:       incbin  data/sa_P_strutter/0012.ASP
Sprite13:       incbin  data/sa_P_strutter/0013.ASP
Sprite14:       incbin  data/sa_P_strutter/0014.ASP
Sprite15:       incbin  data/sa_P_strutter/0015.ASP
Sprite16:       incbin  data/sa_P_strutter/0016.ASP
Sprite17:       incbin  data/sa_P_strutter/0017.ASP
Sprite18:       incbin  data/sa_P_strutter/0018.ASP
Sprite19:       incbin  data/sa_P_strutter/0019.ASP
Sprite20:       incbin  data/sa_P_strutter/0020.ASP
Sprite21:       incbin  data/sa_P_strutter/0021.ASP
Sprite22:       incbin  data/sa_P_strutter/0022.ASP
Sprite23:       incbin  data/sa_P_strutter/0023.ASP
Sprite24:       incbin  data/sa_P_strutter/0024.ASP
Sprite25:       incbin  data/sa_P_strutter/0025.ASP
Sprite26:       incbin  data/sa_P_strutter/0026.ASP

NullSprite:     ds.w    2


*******************************************************************************
                bss
*******************************************************************************

RGB_TBL_SIZE = 16*16*2
RGBTbl:         ds.b    RGB_TBL_SIZE/2
