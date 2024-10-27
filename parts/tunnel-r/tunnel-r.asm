PROFILE = 0
                include tunnel-r.i

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


                lea     .script,a0
                CALLFW  InstallScript

                bsr     PokeCopper
                lea     Cop,a0
                CALLFW  SetCopper
                move.w  #DIW_YSTOP,d0
                CALLFW  EnableCopperSync

;-------------------------------------------------------------------------------
.loop:
                BLTHOGOFF
                CALLFW  CheckScript
                bsr     SetPal

                bsr     BlitIRQStart
                bsr     StartBlit
                bsr     Update
                bsr     DrawTable

                bsr     BlitIRQEnd
                bsr     SwapBuffers
                bsr     PokeCopper

                PROFILE_BG $f00
                CALLFW  CopSyncWithTask
                PROFILE_BG $000

                cmp.w   #TUNNEL_R_END,fw_FrameCounter(a6)
                blt     .loop
                CALLFW  SetBaseCopper
                rts

;-------------------------------------------------------------------------------
.script:
                dc.w    5,.setPal-*
                dc.w    T_BEAT*12,.switchScene-*
                dc.w    0
.setPal:
                bsr     PokeGradient
                rts

.switchScene:
                move.l  TableCode2,TableCode
                rts

********************************************************************************
precalc:
********************************************************************************
                move.l  #SMC_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,TableCode

                lea     TableData2+2,a0
                bsr     GenerateTable

                move.l  TableCode(pc),TableCode2

                move.l  #SMC_SIZE,d0
                CALLFW  AllocFast
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
                lea     TextureSrc3,a4
                bsr     ScrambleTexture

                move.l  ScrambledTex(pc),a0
                add.l   #TOTAL_SCRAMBLED_SIZE*2,a0
                lea     TextureSrc2,a4
                bsr     ScrambleTexture

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

LINE_SZ = 16

PokeGradient:
                lea     GradientSteps,a0
                move.l  PalStepPtrs,a1
                lea     CopLinesTop+4,a2

                ; 7 steps in top half
                move.w  #7-1,d7
.l:
                move.l  (a1)+,a3
                move.w  #color01,LINE_SZ*0(a2)
                move.w  #color02,LINE_SZ*1(a2)
                move.w  #color03,LINE_SZ*2(a2)
                move.w  #color04,LINE_SZ*3(a2)
                move.w  2(a3),LINE_SZ*0+2(a2)
                move.w  4(a3),LINE_SZ*1+2(a2)
                move.w  6(a3),LINE_SZ*2+2(a2)
                move.w  8(a3),LINE_SZ*3+2(a2)

                move.w  (a0)+,d0        ; next offset
                adda.w  d0,a2           ; next step in copper lines
                dbf     d7,.l

                ; Remaining steps in bottom half
                cmp.l   #CopLinesBottom,a2
                bgt     .done
                lea     CopLinesBottom+4,a2
                move.w  #7-1,d7
                bra     .l
.done:
                rts

********************************************************************************
SetPal:
                move.l  PalStepPtrs,a0
                move.w  Fade(pc),d0
                lsl.w   #2,d0
                move.l  (a0,d0.w),a0
                lea     CopPal+2,a1
                moveq.l #16-1,d7
.l:
                move.w  (a0)+,(a1)
                addq    #4,a1
                dbra    d7,.l

                lea     CopPalMid+2,a1
                moveq.l #EXTRA_COLORS-1,d7
.l1:
                move.w  (a0)+,(a1)
                addq    #4,a1
                dbra    d7,.l1
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
                move.w  fw_FrameCounter(a6),d0
                sub.w   #TUNNEL_R_START,d0

                ; Fade in
                cmp.w   #15<<1,d0
                bgt     .fadeInDone
                move.w  d0,d1
                lsr.w   #1,d1
                move.w  d1,Fade
                bra     .fadeDone
.fadeInDone:

                ; Fade out
                cmp.w   #TUNNEL_R_DURATION-15<<2,d0
                blt     .noFadeOut
                move.w  #TUNNEL_R_DURATION,d1
                sub.w   d0,d1
                lsr.w   #2,d1
                move.w  d1,Fade
                bra     .fadeDone
.noFadeOut:
                move.w  #15,Fade
.fadeDone:

; Tex offset 1
                move.w  fw_FrameCounter(a6),d1 ; V
                lsr.w   #2,d1
                and.w   #TEX_H-1,d1
                clr.w   d0              ; U
                lsl.w   #7,d1
                add.w   d1,d0
                and.w   #TEX_SIZE-1,d0
                add.w   d0,d0
                move.w  d0,TexOffset

                move.l  fw_CosTable(a6),a0
                move.w  fw_FrameCounter(a6),d1
                lsl.w   #1,d1
                and.w   #$7fe,d1
                move.w  (a0,d1.w),d1
                asr.w   #8,d1
                and.w   #TEX_H-1,d1
                lsl.w   #7,d1
                move.w  fw_FrameCounter(a6),d0
                add.w   d1,d0
                and.w   #TEX_SIZE-1,d0
                add.w   d0,d0
                move.w  d0,TexOffset3

                move.w  fw_FrameCounter(a6),d1 ; V
                asr.w   #2,d1
                and.w   #TEX_H-1,d1
                lsl.w   #7,d1
                move.w  fw_FrameCounter(a6),d0 ; U
                asr.w   #2,d0
                add.w   d1,d0
                and.w   #TEX_SIZE-1,d0
                add.w   d0,d0
                move.w  d0,TexOffset2

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


                include transitons.asm


********************************************************************************
Vars:
********************************************************************************

Fade:           dc.w    0
PalStepPtrs:    dc.l    0
PalData:        dc.l    0
TableCode2:     dc.l    0


********************************************************************************
* Data
********************************************************************************

GradientSteps:
                dc.w    4*LINE_SZ
                dc.w    4*LINE_SZ
                dc.w    5*LINE_SZ
                dc.w    4*LINE_SZ
                dc.w    8*LINE_SZ
                dc.w    6*LINE_SZ
                dc.w    9*LINE_SZ
                dc.w    9*LINE_SZ
                dc.w    9*LINE_SZ
                dc.w    13*LINE_SZ
                dc.w    13*LINE_SZ
                dc.w    20*LINE_SZ
                dc.w    22*LINE_SZ
                dc.w    26*LINE_SZ

Pal:            
                incbin  data/tex1.pal
                dc.w    $203,$417,$53a,$47c,$3ce
BlankPal:       
                ds.w    COLORS

PalCyclePos:    dc.w    0

Pal2:		
                rept    2		
; https://gradient-blaster.grahambates.com/?points=001@0,eee@13,678@24,ddc@36,fef@46,000@59&steps=60&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=0
                dc.w    $001,$012,$112,$223,$334,$455,$567,$777
                dc.w    $889,$99a,$abb,$ccc,$ddd,$eee,$eee,$ddd
                dc.w    $ccd,$bbc,$bbb,$9ab,$9aa,$89a,$789,$788
                dc.w    $678,$788,$789,$789,$899,$9aa,$aaa,$abb
                dc.w    $bbb,$bcb,$ccc,$cdc,$ddc,$edc,$eed,$eed
                dc.w    $eed,$fee,$fee,$fee,$fef,$fef,$fef,$ede
                dc.w    $dcc,$bab,$99a,$888,$767,$656,$445,$333
                dc.w    $222,$111,$000,$000
                endr

TextureSrc1:    incbin  data/tex1.chk
TextureSrc2:    incbin  data/tex2.chk
TextureSrc3:    incbin  data/tex3.chk

TableData:      
                incbin  assets/16mm_R_tunnel_UVL_160x90_t64_Delta.ggb
TableData2:      
                incbin  data/arms-160.ggb
                dc.b    4
                dcb.b   CHUNKY_W*CHUNKY_H,0

                include noise.i


*******************************************************************************
                data_c
*******************************************************************************

Cop:
                dc.w    dmacon,DMAF_BLITHOG
                dc.w    bplcon0,(BPLS<<12)!$200
                dc.w    bplcon1,0
                dc.w    diwstrt,(DIW_YSTRT<<8)!DIW_XSTRT
                dc.w    diwstop,(((DIW_YSTRT+SCREEN_H)<<8)&$ff00)!((DIW_XSTRT+SCREEN_W)&$ff)
                dc.w    ddfstrt,DIW_XSTRT/2-8
                dc.w    ddfstop,DIW_XSTRT/2-8+8*((SCREEN_W+15)/16-1)

CopPal:
                rept    16
                dc.w    color00+(REPTN*2),$000
                endr

                dc.w    color01,0
                dc.w    color02,0
                dc.w    color03,0
                dc.w    color04,0

CopLinesTop:
                ; Top half rept
CopY            set     DIW_YSTRT-1
                rept    SCREEN_H/4
                COP_WAIT CopY,$df
                COP_NOP
                ifne    ALT
                dc.w    bplcon1,0
                endc
                dc.w    bpl1mod,-SCREEN_BW
                dc.w    bpl2mod,-SCREEN_BW
                COP_WAIT CopY+1,$df
                COP_NOP
; move to next scanline
                ifne    ALT
                dc.w    bplcon1,ALT+(ALT<<4)
                endc
                dc.w    bpl1mod,0
                dc.w    bpl2mod,0
CopY            set     CopY+2
                endr

CopPalMid:
                dc.w    color11,0
                dc.w    color12,0
                dc.w    color13,0
                dc.w    color14,0
                dc.w    color15,0

CopLinesBottom:
                ; Bottom half rept
                rept    SCREEN_H/4
                COP_WAIT CopY,$df
                COP_NOP
                ifne    ALT
                dc.w    bplcon1,0
                endc
                dc.w    bpl1mod,-SCREEN_BW
                dc.w    bpl2mod,-SCREEN_BW
                COP_WAIT CopY+1,$df
                COP_NOP
; move to next scanline
                ifne    ALT
                dc.w    bplcon1,ALT+(ALT<<4)
                endc
                dc.w    bpl1mod,0
                dc.w    bpl2mod,0
CopY            set     CopY+2
                endr

                COP_WAITH CopY,$df

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
