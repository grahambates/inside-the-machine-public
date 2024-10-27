PROFILE = 0
                include credits.i

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
                bsr     InitDrawCode

                ifd     FW_DEMO_PART
                move.w  #CREDITS_START,d0
                CALLFW  WaitForFrame
                PUTMSG  10,<10,"%d TIMING: start part Credits">,fw_FrameCounter(a6)
                endc

                bsr     SetPal
                bsr     PokeCopper
                lea     Cop,a0
                CALLFW  SetCopper
                move.w  #DIW_YSTOP,d0
                CALLFW  EnableCopperSync

                move.l  #VBlank,fw_VBlankIRQ(a6)
                move.w  #DMAF_SETCLR!DMAF_SPRITE,dmacon(a5)

                and.w   #$fffe,fw_FrameCounter(a6) ; Start on an even frame :-/
                lea     .script,a0
                CALLFW  InstallScript

;-------------------------------------------------------------------------------
.loop:
                BLTHOGOFF
                bsr     SwapBuffers
                bsr     PokeCopper

                bsr     BlitIRQStart
                bsr     StartC2pBlit
                bsr     Flip
                bsr     DrawTable

                bsr     BlitIRQEnd

                PROFILE_BG $f00
.sync:
                CALLFW  CopSyncWithTask
                PROFILE_BG $000

                ; Force 2 frames on fast Amigas
                ; This is terrible
                btst    #0,fw_FrameCounter+1(a6)
                bne     .sync

                cmp.w   #CREDITS_END,fw_FrameCounter(a6)
                blt     .loop
                CALLFW  SetBaseCopper
                rts


;-------------------------------------------------------------------------------
.script:
                dc.w    T_BAR*2,.startFlip-*
                dc.w    T_BAR*2,.title1-*
                dc.w    T_BAR*8,.title2-*
                dc.w    T_BAR*16,.title3-*
                dc.w    T_BAR*24,.title4-*
                dc.w    0

.startFlip:
                move.l  #FlipData,FlipPt
                rts

.title1:
                lea     SpriteX,a1
                move.w  #DIW_XSTRT-128,(a1)
                move.w  #DIW_XSTOP,d0
                move.w  #8,d1
                bsr     LerpWordU

                lea     SpriteY,a1
                move.w  #100,(a1)
                move.w  #150,d0
                move.w  #8,d1
                bra     LerpWordU

.title2:
                move.l  #Sprite2,Sprite
                lea     SpriteX,a1
                move.w  #DIW_XSTRT-128,(a1)
                move.w  #DIW_XSTOP,d0
                move.w  #9,d1
                bsr     LerpWordU

                lea     SpriteY,a1
                move.w  #120,(a1)
                move.w  #220,d0
                move.w  #9,d1
                bra     LerpWordU
                ; rts

.title3:
                move.l  #Sprite3,Sprite
                lea     SpriteX,a1
                move.w  #DIW_XSTRT-128,(a1)
                move.w  #DIW_XSTOP,d0
                move.w  #9,d1
                bsr     LerpWordU

                lea     SpriteY,a1
                move.w  #150,(a1)
                move.w  #100,d0
                move.w  #9,d1
                bra     LerpWordU
                ; rts

.title4:
                move.l  #Sprite4,Sprite
                lea     SpriteX,a1
                move.w  #DIW_XSTRT-128,(a1)
                move.w  #DIW_XSTOP,d0
                move.w  #9,d1
                bsr     LerpWordU

                lea     SpriteY,a1
                move.w  #180,(a1)
                move.w  #120,d0
                move.w  #9,d1
                bra     LerpWordU
                ; rts

********************************************************************************
VBlank:
                PUSHM   d0-a6
                bsr     Update
                bsr     PokeYOffset
                bsr     PokeXScroll

                CALLFW  CheckScript
                bsr     LerpWordsStep
                bsr     SetSprites
                POPM
                rts


********************************************************************************
* Routines
********************************************************************************

                include transitons.asm

********************************************************************************
SetPal:
                ; Set sprite palette
                lea     color16(a5),a0
                move.l  #$00000555,d0
                move.l  #$0aaa0fff,d1
                moveq   #4-1,d7
.l:
                move.l  d0,(a0)+
                move.l  d1,(a0)+
                dbf     d7,.l
                rts

********************************************************************************
SetSprites:
                move.l  Sprite(pc),a0   ; sprite base
                move.w  SpriteX(pc),d4  ; x
                move.w  SpriteY(pc),d5  ; y
                move.l  a0,a1           ; offset pointer
                lea     CopSprPt+2,a3   ; copper dest


                moveq   #8-1,d7
.l:
                ; get sprite slice
                move.w  (a1)+,d0
                lea     (a0,d0.w),a2

                ; set copper ptrs
                move.l  a2,d0
                move.w  d0,4(a3)
                swap    d0
                move.w  d0,(a3)
                lea     8(a3),a3        ; next sprite

                ; set control words
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
                move.w  d1,(a2)+
                move.w  d2,(a2)+

                add.w   #16,d4          ; inc x

                dbf     d7,.l

                rts

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

                move.l  #TOTAL_TEX_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,TextureCol

                ; rts

RAMP_W = 32
RAMP_COLORS = 15
RAMP_BW = RAMP_W*2
RAMPS_SIZE = RAMP_BW*RAMP_COLORS

InitTextureCol:
                ; a0 = TextureCol
                lea     Ramps(pc),a1
                lea     RAMPS_SIZE(a1),a2 ; gradient offsets after ramps

                moveq   #RAMP_COLORS-1,d7
.col:
                lea     TEX_SIZE(a0),a3 ; end of tex pair for color
                move.l  a2,a4           ; start of gradient offsets

                move.w  #TEX_W*TEX_H/2-1,d6
.pix:
                move.w  (a4)+,d0        ; get gradient pixel
                move.w  (a1,d0.w),d0    ; lookup color from ramp
                move.w  d0,TEX_SIZE(a0)
                move.w  d0,(a0)+
                move.w  d0,-(a3)
                move.w  d0,TEX_SIZE(a3)
                dbf     d6,.pix

                adda.w  #RAMP_BW,a1     ; next ramp
                adda.w  #TEX_SIZE+TEX_SIZE/2,a0 ; next color in texture
                dbf     d7,.col

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
; Init draw routine from table data
;-------------------------------------------------------------------------------
InitDrawCode:
                lea     TableData,a0    ; u
                move.w  (a0)+,d0        ; w
                move.w  (a0)+,d1        ; h
                lea     Vars(pc),a1
                move.w  d0,TableW-Vars(a1)
                move.w  d1,TableH-Vars(a1)

                ; Calculate pan ammount
                lsl.w   #2,d0           ; TableW * 4
                add.w   d1,d1           ; TableH * 2
                move.w  d0,TableWx4-Vars(a1) ; width in real pixels
                sub.w   #CHUNKY_W*4,d0  ; PanXAmt 
                sub.w   #CHUNKY_H*PIXH,d1 ; PanYAmt 
                move.w  d0,PanXAmt-Vars(a1)
                move.w  d1,PanYAmt-Vars(a1)

                rts


********************************************************************************
Flip:
                move.l  FlipPt(pc),d0
                beq     .done
                move.l  d0,a0
                move.l  Smc,a1
                moveq   #0,d0
                moveq   #-1,d1
                moveq   #18-1,d7
.l:
                moveq   #0,d0
                move.w  (a0)+,d0
                cmp.w   d1,d0
                beq     .finished
                lsl.l   #2,d0           ; convert to longword offset for instruction
                add.w   #3,(a1,d0.l)    ; change source register
                dbf     d7,.l
                move.l  a0,FlipPt
.done:
                rts
.finished:
                move.l  #0,FlipPt
                rts


********************************************************************************
Update:
; Texture offset:
                move.l  fw_FrameCounterLong(a6),d0
                sub.w   fw_ScriptFrameOffset(a6),d0
                subq    #1,d0
                move.l  d0,d1
                divu    #6,d1
                move.w  d1,TexY

                move.l  d0,d1
                divu    #3,d1
                move.w  d1,TexX
; Pan:
; x
                move.l  d0,d1
                mulu    #$10000/3,d1
                add.l   d1,d1
                swap    d1

                move.w  d1,PanX
; y
                move.w  fw_FrameCounter(a6),d2
                lsl.w   #2,d2
                and.w   #$7fe,d2
                move.l  fw_SinTable(a6),a0
                move.w  (a0,d2.w),d2
                add.w   #$4000,d2
                lsr.w   #8,d2
                lsr.w   #1,d2
                move.w  d2,PanY

                rts


********************************************************************************
DrawTable:
                movem.l a5/a6,-(sp)
                move.l  TextureCol(pc),a4
                ; Registers point to 3rd pair, to allow offsets +-2
                adda.w  #TEX_PAIR*2,a4
                lea     TextureChrome+TEX_PAIR*2,a1

; Texture offset
                movem.w TexOffset(pc),d0-d1 ; x,y
                and.w   #TEX_W-1,d0
                ext.l   d1              ; Y not pow 2, use div
                divu    #TEX_H,d1
                swap    d1
                lsl.w   #6,d1           ; *TEX_W
                add.w   d1,d0          
                add.w   d0,d0           ; word offset
                adda.w  d0,a1           ; add to chrome tex
                adda.w  d0,a4           ; add to color tex

                move.w  fw_FrameCounter(a6),d7
                move.l  Smc,a6

                tst.l   PanXAmt
                beq     .noPan
; Pan:
; Add x/y offsets to entry point of SMC
                movem.w PanX(pc),d0-d1
                movem.w PanXAmt(pc),d2-d3
                subq    #1,d3

                ; Clamp to prevent overflow
                CLAMP_MIN_W #0,d0
                CLAMP_MIN_W #0,d1
                ; CLAMP_MAX_W d2,d0
                CLAMP_MAX_W d3,d1

                asr.w   #2,d0           ; x/4 for chunky pixels
                asr.w   #1,d1           ; y/PIXH
                
                muls    TableW(pc),d1
                ext.l   d0
                add.l   d0,d1
                lsl.l   #2,d1           ; *4 for code offset
                adda.l  d1,a6


; The generated code contains intructions to write lines much longer than the chunky buffer
; We need to add jmp instructions to apply a modulo and skip the necessary number of moves
; The original instructions we overwrite need to be backed up and restored
                lea     CHUNKY_W*4(a6),a0 ; end of first line
                move.w  #$6000,d0
                swap    d0
                move.w  #-CHUNKY_W*4-2,d0
                move.w  TableWx4(pc),d1
                ; ifne    INTERLACE
                ; add.w   d1,d1           ; double for interlace
                ; endc
                add.w   d1,d0
                move.w  #CHUNKY_H-2,d7
.l:
; TODO: optimal unroll
; rept	CHUNKY_H-1
                move.l  (a0),-(sp)      ; backup instruction
                move.l  d0,(a0)         ; write bra
                adda.w  d1,a0
; endr
                dbf     d7,.l
; Also need to add an rts to return once enough lines have been written
                move.l  (a0),-(sp)      ; backup instruction
                move.w  #$4e75,(a0)     ; write rts

                move.l  a0,-(sp)        ; backup restore ptr
.noPan:

                ; shenanigans to call SMC and return to cleanup code, without using a register
                pea     .restore
                move.l  a6,-(sp)

                move.l  DrawChunky(pc),a0
                ; Chrome a1-a3
                move.l  a1,a2
                move.l  a1,a3
                ; Colours - a4-a6
                move.l  a4,a5
                adda.l  #TEX_PAIR*5,a5
                move.l  a5,a6
                adda.l  #TEX_PAIR*5,a6
                rts                     ; jump into SMC

; SMC returns here
.restore:
                tst.l   PanXAmt
                beq     .noPan2
; Restore the backed up instructions we put on the stack
                move.l  (sp)+,a0
                move.w  TableWx4(pc),d1
                move.w  #CHUNKY_H-1,d7
.l1:
                ; rept    CHUNKY_H
                move.l  (sp)+,(a0)      ; restore from bra
                suba.w  d1,a0
                ; endr
                dbf     d7,.l1

.noPan2:
                movem.l (sp)+,a5/a6
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
; Set bpl pointers in copper:
                move.l  ViewScreen(pc),a0
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
PokeYOffset:
                move.w  PanY(pc),d0
                and.w   #1,d0
                jsr     SetCopVOffset
                move.l  a0,VList
                rts

VList:          dc.l    0

********************************************************************************
PokeXScroll:
                move.l  VList,a0
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

                ; Poke scroll values
                move.w  #bplcon1,d0
                moveq   #-1,d1

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
.done:          rts

.scrollValues:
                dc.w    (ALT<<4)!ALT,0
                dc.w    ((1+ALT)<<4)!(1+ALT),(1<<4)!1
                dc.w    ((2+ALT)<<4)!(2+ALT),(2<<4)!2
                dc.w    ((3+ALT)<<4)!(3+ALT),(3<<4)!3

                include c2p-4x4.asm


********************************************************************************
Vars:
********************************************************************************

DblBuffers:
DrawScreen:     dc.l    0
ViewScreen:     dc.l    0
DrawChunky:     dc.l    0
C2pChunky:      dc.l    0

ChunkyTmp:      dc.l    0

TableW:         dc.w    0
TableH:         dc.w    0
PanXAmt:        dc.w    0
PanYAmt:        dc.w    0
TableWx4:       dc.w    0

TexOffset:
TexX:           dc.w    0
TexY:           dc.w    0
DrawPan:
PanX:           dc.w    0
PanY:           dc.w    0
ViewPan:        
ViewPanX:       dc.w    0
ViewPanY:       dc.w    0

FlipPt:         dc.l    0
Smc:            dc.l    TableData+4

Sprite:         dc.l    Sprite1
SpriteX:        dc.w    DIW_XSTRT-128
SpriteY:        dc.w    100

TextureCol:     dc.l    0


********************************************************************************
* Data
********************************************************************************

Ramps:
                incbin  data/ramps.bin

FlipData:      
                incbin  data/flip.bin

TextureChrome:	
                ; TODO: ok let let compression handle this?
                ; 5 per register * 2 (pairs)
                rept    5*2
                incbin  data/phong-32x32.rgbs
                endr

TableData:      
                incbin  data/code.bin

*******************************************************************************
                data_c
*******************************************************************************

                include cop-4x2-looped.asm

Sprite1:
                incbin  data/credit-text1.SPR
Sprite2:
                incbin  data/credit-text2.SPR
Sprite3:
                incbin  data/credit-text3.SPR
Sprite4:
                incbin  data/credit-text4.SPR
