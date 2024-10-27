PROFILE = 0
                include combo.i

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
                bsr     AgaFix

                lea     Object,a0
                move.l  Transformed(pc),a1
                move.l  TransformedNorms(pc),a2
                lea     ObjTex,a3
                bsr     LoadObject
                or.w    #OBJTYPE_SHADE,ObjectType

                ifd     FW_DEMO_PART
                move.w  #COMBO_START,d0
                CALLFW  WaitForFrame
                PUTMSG  10,<10,"%d TIMING: start part Combo">,fw_FrameCounter(a6)
                endc

                lea     .script,a0
                CALLFW  InstallScript
                move.w  #COMBO_START,fw_ScriptFrameOffset(a6)

                lea     XOffset,a1
                move.w  #0,d0
                move.w  #6,d1
                bsr     LerpWordU

                lea     BaseDist,a1
                move.w  #1500,(a1)
                move.w  #DIST,d0
                move.w  #6,d1
                bsr     LerpWordU

                ; Set sprite palette
                move.l  #$0fff0000,d0
                move.l  d0,color17(a5)
                move.l  d0,color21(a5)
                move.l  d0,color25(a5)

                move.l  #Update,fw_VBlankIRQ(a6)

                lea     Cop,a0
                CALLFW  SetCopper
                move.w  #DIW_YSTOP,d0
                CALLFW  EnableCopperSync

;-------------------------------------------------------------------------------
.loop:
                BLTHOGOFF
                bsr     SwapBuffers
                bsr     PokeCopper
                bsr     SetSprites

                bsr     BlitIRQStart
                bsr     StartC2pBlit

                bsr     DrawTable
                PUSHM   a5/a6
                bsr     Transform

                move.l  XOffsetLong,d0
                add.w   d0,d0
                move.l  d0,-(sp)
                add.l   d0,DrawChunky
                bsr     DrawObject
                move.l  (sp)+,d0
                sub.l   d0,DrawChunky

                POPM

                bsr     BlitIRQEnd
                PROFILE_BG $f00
                CALLFW  CopSyncWithTask
                PROFILE_BG $000
                
                ; bra     .loop
                cmp.w   #COMBO_END,fw_FrameCounter(a6)
                blt     .loop
                CALLFW  SetBaseCopper
                rts

.script:        
                dc.w    T_BAR*4,.spriteIn-*
                dc.w    COMBO_DURATION-128,.spriteOut-*
                dc.w    COMBO_DURATION-128,.moveOut-*
                dc.w    0

.spriteIn:
                lea     SpriteY,a1
                move.w  #DIW_YSTOP-SPRITE_H-3,d0
                move.w  #4,d1
                bra     LerpWordU
.spriteOut:
                lea     SpriteY,a1
                move.w  #DIW_YSTOP,d0
                move.w  #4,d1
                bra     LerpWordU

.moveOut:
                lea     XOffset,a1
                move.w  #20,d0
                move.w  #7,d1
                bsr     LerpWordU

                lea     BaseDist,a1
                move.w  #1700,d0
                move.w  #7,d1
                bra     LerpWordU
                ; rts


********************************************************************************
precalc:
********************************************************************************
                move.l  #SMC_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,Smc

                move.l  #TABLE_TEX_SIZE,d0
                CALLFW  AllocFast
                move.l  a0,Texture

                PUSHM   a5/a6
                bsr     InitFadeRGBScrambled

                lea     Table(pc),a0
                move.l  Smc(pc),a3
                bsr     GenerateTable

                lea     BgTex,a0
                move.l  Texture(pc),a1
                bsr     InitTextureBlack
                clr.w   BGCol
                POPM

                rts


********************************************************************************
* Routines
********************************************************************************

                include transitons.asm

********************************************************************************
InitVars:
                move.l  #SCREEN_SIZE+1024,d0 ; Prevent buffer overflow in descending allocation
                CALLFW  AllocChip
                move.l  a0,DrawChunky
                bsr     ClearScreen

                move.l  #SCREEN_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,ViewScreen

                move.l  #SCREEN_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,DrawScreen
                bsr     ClearScreen

                move.l  #SCREEN_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,ChunkyTmp

                move.l  #MAX_VERTS*Vec2_SIZEOF,d0
                CALLFW  AllocFast
                move.l  a0,Transformed
                move.l  #MAX_VERTS*Vec2_SIZEOF,d0
                CALLFW  AllocFast
                move.l  a0,TransformedNorms

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
Update:
                PUSHM   d0-a6
                CALLFW  CheckScript

; Object Distance
                add.l   #Y_SPEED<<16!Z_SPEED,Angles
                move.w  fw_FrameCounter(a6),d1
                mulu    #$100000*BPM/3000,d1
                lsl.l   #3,d1
                swap    d1

                ; add.w   #$200,d1
                ; and.w   #$7fe,d1
                ; move.l  fw_SinTable(a6),a1
                ; move.w  (a1,d1.w),d1
                ; move.w  d1,d2
                ; asr.w   #8,d1
                ;
                ; add.w   BaseDist(pc),d1
                ; move.w  d1,Dist
                move.w  BaseDist(pc),Dist

; ; Fade

                lea     Noise,a0
                move.w  fw_FrameCounter(a6),d0
                and.w   #1024*2-2,d0
                move.w  (a0,d0.w),d0
                lsr.w   #8,d0
                add.w   #14,d0
                move.w  d0,Fade

; Texture offset
                move.w  fw_FrameCounter(a6),d1
                move.w  d1,TexY
                lsr.w   #1,d1
                move.w  d1,TexX

                bsr     LerpWordsStep
                POPM
                rts


                include 3d.asm
                include c2p-4x4.asm
                include table-4x4.asm


********************************************************************************
SwapBuffers:
                movem.l DblBuffers(pc),a0-a2
                exg     a0,a1
                exg     a2,a0
                movem.l a0-a2,DblBuffers

                move.l  a0,C2pChunky
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

SPRITE_H = 23

********************************************************************************
SetSprites:
                lea     CopSprPt+2,a2
                lea     Sprite,a1
                move.l  a1,a0

                move.w  #DIW_XSTOP-48-3,d4
                move.w  SpriteY(pc),d5

                moveq   #3-1,d7
.l:
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

                move.w  d1,(a3)
                move.w  d2,2(a3)

                move.l  a3,d3
                move.w  d3,4(a2)
                swap    d3
                move.w  d3,(a2)
                lea     8(a2),a2

                add.w   #16,d4
                dbf     d7,.l

                rts


********************************************************************************
Vars:
********************************************************************************

SpriteY:        dc.w    DIW_YSTOP

XOffsetLong:    dc.w    0
XOffset:        dc.w    20

BGCol:          dc.w    0

DblBuffers:
DrawScreen:     dc.l    0
ViewScreen:     dc.l    0
DrawChunky:     dc.l    0
C2pChunky:      dc.l    0               ; Same as DrawScreen

ChunkyTmp:      dc.l    0
Smc:            dc.l    0

Transformed:    dc.l    0
TransformedNorms: dc.l  0

Texture:        dc.l    0

SpTmp:          dc.l    0

BaseDist:       dc.w    0

********************************************************************************
* Data
********************************************************************************

Object:
                ; include data/ico.i
                include data/torus-6x4q.i
Table:
                ; incbin  data/tunnel.bin
                incbin  assets/tcmm_Combo_tunnel_UVL_80x49_t64_Delta.ggb
                ; incbin  ../tunnel-s/assets/tcmm_S_tunnel_UVLM_110x70_t64_Delta.ggb
                ;incbin  ../tunnel-s/assets/tcmm_S_tunnel_UVLM_110x70_t64_Delta.ggb
BgTex:	
                incbin  data/bgtex.rgb
ObjTex:	
                incbin  data/texshade.rgbs

                include noise.i

*******************************************************************************
                data_c
*******************************************************************************

                include cop-4x4.asm

Sprite:
                incbin  data/tek.SPR


*******************************************************************************
                bss
*******************************************************************************

RGB_TBL_SIZE = 16*16*2

RGBTblBlack:
RGBTblR:        ds.b    RGB_TBL_SIZE
RGBTblG:        ds.b    RGB_TBL_SIZE
RGBTblB:        ds.b    RGB_TBL_SIZE

RGBTblWhite:
RGBTblRW:       ds.b    RGB_TBL_SIZE
RGBTblGW:       ds.b    RGB_TBL_SIZE
RGBTblBW:       ds.b    RGB_TBL_SIZE

RGBTbl:         ds.b    RGB_TBL_SIZE/2
