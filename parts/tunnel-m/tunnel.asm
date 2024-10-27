PROFILE = 0
                include tunnel.i

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
                jsr     InitCopper

                ifd     FW_DEMO_PART
                move.w  #TUNNEL_M_START,d0
                CALLFW  WaitForFrame
                PUTMSG  10,<10,"%d TIMING: start part TunnelM">,fw_FrameCounter(a6)
                endc

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
                bsr     SwapBuffers
                bsr     PokeCopper

                bsr     BlitIRQStart
                bsr     StartC2pBlit
                bsr     Update
                bsr     SetSprites
                bsr     DrawTable
                bsr     SetPalOffs

                bsr     BlitIRQEnd
                PROFILE_BG $f00
                CALLFW  CopSyncWithTask
                PROFILE_BG $000

                cmp.w   #TUNNEL_M_END,fw_FrameCounter(a6)
                blt     .loop
                CALLFW  SetBaseCopper
                rts


;-------------------------------------------------------------------------------
.script:


********************************************************************************
* Routines
********************************************************************************

********************************************************************************
InitVars:
                move.l  #SCREEN_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,DrawChunky
                bsr     ClearScreen

                move.l  #SCREEN_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,ViewScreen
                bsr     ClearScreen

                move.l  #SCREEN_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,DrawScreen
                bsr     ClearScreen

                move.l  #SCREEN_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,ChunkyTmp

                move.l  #TEXTURE_SIZE,d0
                printv  TEXTURE_SIZE
                CALLFW  AllocFast
                move.l  a0,Texture

                ifne    GENERATE_TABLE
                move.l  #SMC_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,Smc
                endc

                PUSHM   a5/a6
                bsr     InitFadeRGBScrambled

                lea     TextureSrc1,a0
                move.l  Texture(pc),a1
                bsr     InitTextureBlackToWhite
                clr.w   BGCol

                ifne    GENERATE_TABLE
                move.l  Smc,a3
                lea     Table(pc),a0
                bsr     GenerateTable
                else
                lea     Table(pc),a0
                bsr     InitTable
                endc
                POPM
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
                movem.l DblBuffers(pc),a0-a2
                exg     a0,a1
                exg     a2,a0
                movem.l a0-a2,DblBuffers

                move.l  a0,C2pChunky

                movem.l DrawPan(pc),a0-a1
                exg     a0,a1
                movem.l a0-a1,DrawPan
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

                move.w  PanY(pc),d0
                ifne    INTERLACE
                and.w   #1,d0
                btst.b  #0,fw_FrameCounter+1(a6)
                bne     .odd
                addq.w  #2,d0
.odd:
                else
                and.w   #3,d0
                endc
                jsr     SetCopVOffset


                ; Poke scroll values
                move.w  #bplcon1,d0
                moveq   #-1,d1
                move.w  PanX(pc),d2
                not.w   d2
                and.w   #3,d2
                lsl.w   #2,d2
                move.l  .scrollValues(pc,d2.w),d2

                ; Interlace ALT pattern
                ifne    INTERLACE_ALT
                move.w  fw_FrameCounter(a6),d7
                btst    #0,d7
                bne     .even
                swap    d2
.even:
                endc

                move.w  d2,CopBplcon1
                swap    d2
.l:
                move.w  (a0)+,d3
                cmp.w   d1,d3
                beq     .done           ; end of copper list?
                cmp.w   d0,d3           ; bplcon1?
                bne     .notScroll
                move.w  d2,(a0)         ; set scroll value
                swap    d2              ; flip for alternating
.notScroll:
                addq    #2,a0           ; skip value
                bra     .l
.done:

                rts

.scrollValues:
                dc.w    (ALT<<4)!ALT,0
                dc.w    ((1+ALT)<<4)!(1+ALT),(1<<4)!1
                dc.w    ((2+ALT)<<4)!(2+ALT),(2<<4)!2
                dc.w    ((3+ALT)<<4)!(3+ALT),(3<<4)!3


********************************************************************************
SetPalOffs:
                lea     Pal(pc),a0
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
SetSprites:
                lea     CopSprPt+2,a2
                lea     SpritePts,a0
                move.l  fw_FrameCounterLong(a6),d0
                sub.w   fw_ScriptFrameOffset(a6),d0
                move.l  d0,d1
                asr.l   d1
                divu    #SPRITE_FRAMES,d1 ; modulo
                swap    d1
                lsl.w   #2,d1
                move.l  (a0,d1),a0
                move.l  a0,a1

                move.w  #DIW_XSTRT+SPRITE_X,d4
                move.l  d0,d1
                asr.w   #1,d1
                add.w   d1,d4
                move.w  #DIW_YSTRT+SPRITE_Y,d5
                sub.w   PanX(pc),d4
                sub.w   PanY(pc),d5

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


********************************************************************************
Update:
                move.l  fw_FrameCounterLong(a6),d0
                sub.w   fw_ScriptFrameOffset(a6),d0

                move.w  d0,d1
                ; asr.w   #1,d1
                move.w  d1,PanX

                ; Fade in
                cmp.w   #15,d0
                bgt     .fadeInDone
                move.w  d0,d1
                move.w  d1,Fade
                bra     .fadeDone
.fadeInDone:
                ; cmp.w   #T_BAR,d0
                ; blt     .fadeDone

;                 ; Fade out
;                 cmp.w   #TUNNEL_M_DURATION-20<<1,d0
;                 blt     .noFadeOut
;                 move.w  #TUNNEL_M_DURATION,d1
;                 sub.w   d0,d1
;                 lsr.w   #1,d1
;                 move.w  d1,Fade
;                 bra     .fadeDone
; .noFadeOut:

                ; lea     Noise,a0
                ; move.w  d0,d1
                ; and.w   #1024*2-2,d1
                ; move.w  (a0,d1.w),d1
                ; lsr.w   #8,d1
                ; add.w   #20,d1
                ; move.w  d1,Fade
                move.w  #20,Fade

                ; sync flash
                move.w  fw_FrameCounter(a6),d1
                sub.w   #TUNNEL_M_START,d1
                add.w   #T_BEAT*2,d1
                ext.l   d1
                divu    #T_BAR,d1
                swap    d1
                asr.w   #3,d1
                neg.w   d1
                add.w   d1,Fade
.fadeDone:

                move.l  fw_SinTable(a6),a0
                lsl.w   #4,d0
                and.w   #$7fe,d0
                move.w  (a0,d0.w),d0
                add.w   #$4000,d0
                lsl.l   #5,d0
                swap    d0

; Texture offset:
                move.w  fw_FrameCounter(a6),d1
                ; neg.w   d1
                move.w  d1,TexY
                lsr.w   #2,d1
                move.w  d1,TexX
;
                move.w  PanYAmt(pc),d0
                asr.w   d0
                move.w  fw_FrameCounter(a6),d2
                lsl.w   #2,d2
                and.w   #$7fe,d2
                move.l  fw_SinTable(a6),a0
                move.w  (a0,d2.w),d2
                muls    d0,d2           ; Scale
                FP2I14  d2
                add.w   d0,d2           ; center

                move.w  d2,PanY

                move.l  fw_SinTable(a6),a0
                move.w  fw_FrameCounter(a6),d0
                add.w   d0,d0
                add.w   d0,d0
                and.w   #$7fe,d0
                move.w  (a0,d0.w),d0
                add.w   #$4000,d0
                lsr.w   #8,d0

                ext.l   d0
                divs    #CHROME_COLS*4,d0
                swap    d0
                move.w  d0,PalCyclePos

                rts


                include c2p-4x4.asm
                include table-4x4.asm

********************************************************************************
Vars:
********************************************************************************

DblBuffers:
DrawScreen:     dc.l    0
ViewScreen:     dc.l    0
DrawChunky:     dc.l    0
C2pChunky:      dc.l    0

ChunkyTmp:      dc.l    0

BGCol:          dc.w    0

Texture:        dc.l    0
Smc:            dc.l    Table+2

PalCyclePos:    dc.w    0


********************************************************************************
* Data
********************************************************************************
Pal:		
                rept    2		
; https://gradient-blaster.grahambates.com/?points=001@0,269@14,012@18,c8c@40,fda@46,000@59&steps=60&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=0
                dc.w    $001,$001,$002,$012,$013,$023,$024,$035
                dc.w    $135,$136,$046,$157,$258,$258,$269,$157
                dc.w    $135,$123,$012,$112,$113,$213,$223,$224
                dc.w    $324,$335,$435,$435,$546,$547,$647,$758
                dc.w    $758,$859,$869,$96a,$a7a,$a7a,$b7b,$c8c
                dc.w    $c8c,$d9c,$dac,$ebc,$ecb,$fdb,$fda,$ec9
                dc.w    $cb8,$ba7,$a86,$875,$765,$654,$443,$332
                dc.w    $221,$110,$000,$000
                endr

TextureSrc1:    
                incbin  data/tex.rgb

Table:
                ifne    GENERATE_TABLE
                incbin  assets/tcmm_M_tunnel_UVL_150x110_t64_Delta.ggb
                else
                incbin  data/tcmm_M_tunnel_UVL_150x110_t64_Delta.bin
                endc

                ; include noise.i


*******************************************************************************
                data_c
*******************************************************************************

                include cop-4x4-looped.asm

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
                dc.l    Sprite27
                dc.l    Sprite28
                dc.l    Sprite29
                dc.l    Sprite30
                dc.l    Sprite31

Sprite01:       incbin  data/sa_M_jogger/0001.ASP
Sprite02:       incbin  data/sa_M_jogger/0002.ASP
Sprite03:       incbin  data/sa_M_jogger/0003.ASP
Sprite04:       incbin  data/sa_M_jogger/0004.ASP
Sprite05:       incbin  data/sa_M_jogger/0005.ASP
Sprite06:       incbin  data/sa_M_jogger/0006.ASP
Sprite07:       incbin  data/sa_M_jogger/0007.ASP
Sprite08:       incbin  data/sa_M_jogger/0008.ASP
Sprite09:       incbin  data/sa_M_jogger/0009.ASP
Sprite10:       incbin  data/sa_M_jogger/0010.ASP
Sprite11:       incbin  data/sa_M_jogger/0011.ASP
Sprite12:       incbin  data/sa_M_jogger/0012.ASP
Sprite13:       incbin  data/sa_M_jogger/0013.ASP
Sprite14:       incbin  data/sa_M_jogger/0014.ASP
Sprite15:       incbin  data/sa_M_jogger/0015.ASP
Sprite16:       incbin  data/sa_M_jogger/0016.ASP
Sprite17:       incbin  data/sa_M_jogger/0017.ASP
Sprite18:       incbin  data/sa_M_jogger/0018.ASP
Sprite19:       incbin  data/sa_M_jogger/0019.ASP
Sprite20:       incbin  data/sa_M_jogger/0020.ASP
Sprite21:       incbin  data/sa_M_jogger/0021.ASP
Sprite22:       incbin  data/sa_M_jogger/0022.ASP
Sprite23:       incbin  data/sa_M_jogger/0023.ASP
Sprite24:       incbin  data/sa_M_jogger/0024.ASP
Sprite25:       incbin  data/sa_M_jogger/0025.ASP
Sprite26:       incbin  data/sa_M_jogger/0026.ASP
Sprite27:       incbin  data/sa_M_jogger/0027.ASP
Sprite28:       incbin  data/sa_M_jogger/0028.ASP
Sprite29:       incbin  data/sa_M_jogger/0029.ASP
Sprite30:       incbin  data/sa_M_jogger/0030.ASP
Sprite31:       incbin  data/sa_M_jogger/0031.ASP

NullSprite:     ds.w    2

*******************************************************************************
                bss
*******************************************************************************

RGBTblBlack:
RGBTblR:        ds.b    RGB_TBL_SIZE
RGBTblG:        ds.b    RGB_TBL_SIZE
RGBTblB:        ds.b    RGB_TBL_SIZE

RGBTblWhite:
RGBTblRW:       ds.b    RGB_TBL_SIZE
RGBTblGW:       ds.b    RGB_TBL_SIZE
RGBTblBW:       ds.b    RGB_TBL_SIZE

RGBTbl:         ds.b    RGB_TBL_SIZE/2
