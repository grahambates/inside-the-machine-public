PROFILE = 0
                include tmap.i

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
                bsr     InitAga

                move.l  DrawCop(pc),a1
                bsr     InitCopper
                move.l  ViewCop(pc),a1
                bsr     InitCopper

                move.l  DrawCop(pc),a1
                bsr     SetSprites
                move.l  ViewCop(pc),a1
                bsr     SetSprites


                bsr     SetPal
                move.w  #DMAF_SETCLR!DMAF_SPRITE,dmacon(a5)

                lea     Object(pc),a0
                move.l  Transformed,a1
                move.l  TransformedNorms,a2
                lea     ObjTex,a3
                bsr     LoadObject

                move.l  a6,FWBase       ; Store Framework base for use in interrupt
                move.l  fw_VBR(a6),a0
                move.l  #Interrupt,$6c(a0)

                move.l  #VBlank,fw_VBlankIRQ(a6)

                move.w  #DMAF_BLITHOG,dmacon(a5) ; Blithog off
                move.w  #INTF_SETCLR!INTF_BLIT,intena(a5)
                CALLFW  VSync

;-------------------------------------------------------------------------------
.loop:
                bsr     Update
                bsr     NextDraw

                bsr     Clear           ; Start blit clear and c2p ops

                PUSHM   a5/a6
                bsr     Transform
                bsr     DrawObject
                POPM
                bsr     BlitIRQWait

                bsr     RotateTripleBuffers ; Triple bufferd chunky buffers and sizes

                cmp.w   #TMAP_END,fw_FrameCounter(a6)
                blt     .loop
                CALLFW  SetBaseCopper
                rts

********************************************************************************
SetSprites:
                lea     CopSprPt+2-Cop(a1),a2
                move.l  #Sprite1+4,d1
                move.l  #Sprite2+4,d2
                move.l  #Sprite3+4,d3
                move.l  #Sprite4+4,d4

                move.w  d1,4(a2)
                swap    d1
                move.w  d1,(a2)
                swap    d1
                lea     8(a2),a2

                add.l   #$88,d1
                move.w  d1,4(a2)
                swap    d1
                move.w  d1,(a2)
                lea     8(a2),a2

                move.w  d2,4(a2)
                swap    d2
                move.w  d2,(a2)
                swap    d2
                lea     8(a2),a2

                add.l   #$88,d2
                move.w  d2,4(a2)
                swap    d2
                move.w  d2,(a2)
                lea     8(a2),a2

                move.w  d3,4(a2)
                swap    d3
                move.w  d3,(a2)
                swap    d3
                lea     8(a2),a2

                add.l   #$88,d3
                move.w  d3,4(a2)
                swap    d3
                move.w  d3,(a2)
                lea     8(a2),a2

                move.w  d4,4(a2)
                swap    d4
                move.w  d4,(a2)
                swap    d4
                lea     8(a2),a2

                add.l   #$88,d4
                move.w  d4,4(a2)
                swap    d4
                move.w  d4,(a2)
                lea     8(a2),a2

                rts



********************************************************************************
UpdateSprites:
SPRITE_SIZE = $88
TEX_W = 128
                move.l  ViewGeo(pc),a4
                move.w  Geo_TexX(a4),d5
                move.w  Geo_TexY(a4),d6
; blue
                lea     Sprite1+4,a0
                move.w  d5,d0
                move.w  d6,d1
                add.w   #(TEX_W-97)*4,d0
                add.w   #(TEX_W-96)*4,d1
                bsr     SetSpritePos
                add.l   #SPRITE_SIZE,a0
                sub.w   #16,d0
                bsr     SetSpritePos

; green
                lea     Sprite2+4,a0
                move.w  d5,d0
                move.w  d6,d1
                add.w   #(TEX_W-94)*4,d0
                add.w   #(TEX_W-39)*4,d1
                bsr     SetSpritePos
                add.l   #SPRITE_SIZE,a0
                sub.w   #16,d0
                bsr     SetSpritePos

; red
                lea     Sprite3+4,a0
                move.w  d5,d0
                move.w  d6,d1
                add.w   #(TEX_W-39)*4,d0
                add.w   #(TEX_W-90)*4,d1
                bsr     SetSpritePos
                add.l   #SPRITE_SIZE,a0
                sub.w   #16,d0
                bsr     SetSpritePos

; purple
                lea     Sprite4+4,a0
                move.w  d5,d0
                move.w  d6,d1
                add.w   #(TEX_W-36)*4,d0
                add.w   #(TEX_W-33)*4,d1
                bsr     SetSpritePos
                add.l   #SPRITE_SIZE,a0
                sub.w   #16,d0
                bsr     SetSpritePos

                rts

SetSpritePos:
                movem.w d0-d1,-(sp)
                and.w   #511,d0
                and.w   #511,d1
                sub.w   #256-8,d0
                sub.w   #256+8,d1

                neg.w   d0
                neg.w   d1
                add.w   #DIW_XSTRT+DIW_W/2,d0
                add.w   #DIW_YSTRT+DIW_H/2,d1
                CLAMP_MIN_W #DIW_XSTRT-32,d0
                CLAMP_MIN_W #DIW_YSTRT-32,d1
                CLAMP_MAX_W #DIW_XSTOP+48,d0
                CLAMP_MAX_W #DIW_YSTOP+48,d1

                moveq   #32,d2          ; height

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
                movem.w (sp)+,d0-d1
                rts

********************************************************************************
SetPal:
                lea     SpritePal,a0
                lea     color16(a5),a1
                moveq   #16/2-1,d7
.l:
                move.l  (a0)+,(a1)+
                dbf     d7,.l
                rts


********************************************************************************
InitVars:
                ; +SCREEN_BPL to avoid unexplained overflow
                ; Possibly connected with clear size issue
                move.l  #SCREEN_SIZE+SCREEN_BPL,d0
                CALLFW  AllocChip
                move.l  a0,DrawChunky
                bsr     ClearScreen

                move.l  #SCREEN_SIZE+SCREEN_BPL,d0
                CALLFW  AllocChip
                move.l  a0,ClearChunky

                move.l  #SCREEN_SIZE+SCREEN_BPL,d0
                CALLFW  AllocChip
                move.l  a0,C2pChunky

                move.l  #SCREEN_SIZE+SCREEN_BPL,d0
                CALLFW  AllocChip
                move.l  a0,ChunkyTmp

                move.l  #SCREEN_SIZE*SCREEN_BUFFERS,d0
                CALLFW  AllocChip
                move.l  a0,Screens
                move.l  a0,DrawScreen
                move.l  a0,ViewScreen

                bsr     ClearScreen
                adda.l  #SCREEN_SIZE,a0

                move.l  #GEO_SIZE,d0
                CALLFW  AllocFast
                move.l  a0,Geometry
                move.l  a0,ViewGeo
                move.l  a0,DrawGeo

                move.l  #TRANSFORMED_SIZE,d0
                CALLFW  AllocFast
                move.l  a0,Transformed

                move.l  #TRANSFORMED_SIZE,d0
                CALLFW  AllocFast
                move.l  a0,TransformedNorms

                move.l  #COP_SIZE,d0
                CALLFW  AllocChip
                move.l  a0,DrawCop
                lea     Cop,a1
                move.l  a1,ViewCop

                move.w  #COP_SIZE/4-1,d7
.copCopy:       move.l  (a1)+,(a0)+
                dbf     d7,.copCopy

                rts

********************************************************************************
ClearScreen:
                BLTWAIT
                clr.w   bltdmod(a5)
                move.l  #$01000000,bltcon0(a5)
                move.l  a0,bltdpt(a5)
                move.w  #SCREEN_H*BPLS*64/2+SCREEN_BW,bltsize(a5)
                rts


********************************************************************************
Interrupt:
********************************************************************************
                btst    #INTB_BLIT,intreqr+custom+1
                beq.s   .notBlit
; Blitter:
                move.w  #INTF_BLIT,intreq+custom
                tst.l   BlitNext        ; Is there another blit operation queued?
                beq     .blitDone
                PUSHM   d0-a6
                lea     custom,a5
                move.l  BlitNext(pc),a0
                jsr     (a0)
                POPM
.blitDone:
                rte
.notBlit:
; VBI:
                bsr     VBlank
                move.w  #INTF_VERTB,intreq+custom
                move.w  #INTF_VERTB,intreq+custom
                rte

********************************************************************************
VBlank:
                PUSHM   d0-a6
                move.l  FWBase(pc),a6
                addq.w  #1,fw_FrameCounter(a6) ; Increment frame counter
                bsr     FlipScreen
                POPM
                rts

********************************************************************************
FlipScreen:
                ; Initial buffering
                ; Wait until the buffer starts to fill before starting display
                cmp.w   #PREFILL_FRAMES,DrawFrame
                blt     .skip

                ifne    INTERLACE_ALT
                ; Alternate scroll pattern
                move.w  #(2<<4)+2,d0
                move.w  #0,d1
                btst    #0,fw_FrameCounter+1(a6)
                beq     .noExg
                exg     d0,d1
.noExg:
                move.l  DrawCop(pc),a1
                lea     CopMods1+14-Cop(a1),a0
                move.w  d0,(a0)
                move.w  d1,8(a0)
                move.w  d0,16(a0)
                move.w  d1,32(a0)
                lea     CopMods2+14-Cop(a1),a0
                move.w  d0,(a0)
                move.w  d1,8(a0)
                move.w  d0,16(a0)
                move.w  d1,32(a0)
                lea     CopMods3+14-Cop(a1),a0
                move.w  d0,(a0)
                move.w  d1,8(a0)
                move.w  d0,16(a0)
                move.w  d1,32(a0)
                endc

                bsr     UpdateSprites

                ; Force 25hz and only flip on even frames
                ifne    LIMIT_FRAMERATE
                btst    #0,fw_FrameCounter+1(a6)
                beq     .skip
                endc
                bsr     NextView
                bsr     SetScreen

                ; Swap copper lists
                movem.l DrawCop(pc),a3-a4
                exg     a3,a4
                movem.l a3-a4,DrawCop
                cmp.w   #PREFILL_FRAMES+2,DrawFrame
                blt     .skip
                move.l  a4,cop1lc+custom
.skip:
                rts


********************************************************************************
* Routines
********************************************************************************


********************************************************************************
RotateTripleBuffers:
                movem.l ChunkyBuffers(pc),d0-d2
; Draw/View/C2P chunky
                exg     d0,d1
                exg     d0,d2
                movem.l d0-d2,ChunkyBuffers
; Draw/View/C2P size
                movem.l GeometryVars,d0-d2
                exg     d0,d1
                exg     d0,d2
                movem.l d0-d2,GeometryVars
                rts


********************************************************************************
; a0 - Screen buffer
; a1 - Geometry
;-------------------------------------------------------------------------------
SetScreen:
                movem.w (a1),d0/d1/d6/d7

; Set bitplane ptrs in copper
                move.l  DrawCop(pc),a1
                lea     CopBplPt+2-Cop(a1),a2
                move.w  d0,d2
                lsr.w   d2              ; chunk w/2 = bit width
                mulu    d1,d2
                rept    BPLS
                move.l  a0,d3
                swap    d3
                move.w  d3,(a2)
                move.w  a0,4(a2)
                lea     (a0,d2.w),a0    ; next blitplane
                addq    #8,a2
                endr

; chunky offsets to px
                lsl.w   #2,d6
                lsl.w   #2,d7

; Set copper modulo
                move.w  d0,d2
                lsr.w   d2              ; SCREEN_BW
                neg.w   d2
                lea     CopMods1+2-Cop(a1),a0
                move.w  d2,(a0)
                move.w  d2,4(a0)
                lea     CopMods2+2-Cop(a1),a0
                move.w  d2,(a0)
                move.w  d2,4(a0)
                lea     CopMods3+2-Cop(a1),a0
                move.w  d2,(a0)
                move.w  d2,4(a0)
                lea     CopMods4+2-Cop(a1),a0
                move.w  d2,(a0)
                move.w  d2,4(a0)

                lea     CopScreen+2-Cop(a1),a0
; DIW_YSTRT
                add.w   d1,d1           ; DIW_H/2 (chunky is /4)
                move.w  #$ac,d3
                add.w   d7,d3
                sub.w   d1,d3           ; center + y offset - DIW_H/2
                move.b  d3,(a0)+
; DIW_XSTRT
                add.w   d0,d0           ; DIW_W/2
                move.w  #$121,d2
                add.w   d6,d2
                sub.w   d0,d2           ; center + x offset - DIW_W/2
                ; move.b  d2,(a0)+
                move.b  #$81,(a0)+      ; Need full x range for sprite trick
; DIW_YSTOP
                move.w  d3,d5
                add.w   d1,d1           ; DIW_H
                add.w   d1,d5
                sub.w   #2,d5           ; prevent additional lines of trash - not sure why
                move.b  d5,2(a0)
; DIW_XSTOP
                move.w  d2,d4
                add.w   d0,d0           ; DIW_W
                add.w   d0,d4
                ; move.b  d4,3(a0)
                move.b  #$c1,3(a0)      ; Need full x range for sprite trick
; DDF Start
                sub.w   #15,d2
                lsr.w   d2
                and.w   #$fc,d2
                move.b  d2,7(a0)
; DDF Stop
; Assumes width is word multiple
                lsr.w   d0              ; DIW_W/2
                subq    #8,d0
                add.w   d0,d2
                move.b  d2,11(a0)
                rts


********************************************************************************
; a1 = Copper
InitCopper:
                lea     CopLoop1-Cop(a1),a2
                move.l  a2,d0
                lea     Cop2Lc1+2-Cop(a1),a0
                move.w  d0,4(a0)
                swap    d0
                move.w  d0,(a0)
                lea     CopLoop2-Cop(a1),a2
                move.l  a2,d0
                lea     Cop2Lc2+2-Cop(a1),a0
                move.w  d0,4(a0)
                swap    d0
                move.w  d0,(a0)
                lea     CopLoop3-Cop(a1),a2
                move.l  a2,d0
                lea     Cop2Lc3+2-Cop(a1),a0
                move.w  d0,4(a0)
                swap    d0
                move.w  d0,(a0)

                bra     AgaFixA1



********************************************************************************
Clear:
                move.w  ClearW(pc),d0
                move.w  ClearH(pc),d1
                add.w   #20,d1          ; Dirty fix - not sure why needed
; Blit size
                lsl.w   #8,d1
                lsr.w   #2,d0
                add.w   d1,d0

                move.l  #StartC2pBlit,BlitNext
                move.l  #$1000000,bltcon0(a5)
                clr.w   bltdmod(a5)
                move.l  ClearChunky(pc),bltdpt(a5)
                move.w  d0,bltsize(a5)
                rts

********************************************************************************
Update:
                move.w  DrawFrame(pc),d0

                move.w  d0,d3
                mulu    #$100000*BPM/3000,d3
                lsl.l   #5,d3
                swap    d3
                ext.l   d3

; Texture offset
                lsl.w   #3,d0
                move.l  fw_SinTable(a6),a0
                and.w   #$7fe,d0
                move.w  (a0,d0),d0
                asr.w   #5,d0
                add.w   #256,d0

                move.w  DrawFrame(pc),d1
                lsl.w   #1,d1
                move.w  d0,d2
                add.w   d2,d1

                asr.w   #1,d0

                and.w   #511,d0
                and.w   #511,d1

                move.l  DrawGeo(pc),a3
                move.w  d0,Geo_TexX(a3)
                move.w  d1,Geo_TexY(a3)

                asr.w   #2,d0
                asr.w   #2,d1
                bsr     OffsetObjectTexture

                move.l  Speed(pc),d0
                add.l   d0,Angles

                move.w  DrawFrame(pc),d0
                ; Zoom in
                cmp.w   #32,d0
                bgt     .zoomInDone
                lsl.w   #4,d0
                neg.w   d0
                move.w  d0,Dist
                bra     .zoomDone
.zoomInDone:

                ; Zoom out
                cmp.w   #TMAP_DURATION/2-14,d0
                blt     .noZoomOut
                sub.w   #TMAP_DURATION/2,d0
                lsl.w   #5,d0
                CLAMP_MAX_W #500,d0
                move.w  d0,Dist
                  
                bra     .zoomDone
.noZoomOut:
                move.w  #-512,Dist
.zoomDone:


                and.w   #$7fe,d3
                move.l  fw_SinTable(a6),a0
                move.w  (a0,d3.w),d3
                bge     .pos
                neg.w   d3
.pos:
                asr.w   #7,d3
                add.w   BaseDist(pc),d3
                add.w   d3,Dist

                rts


********************************************************************************
; Next view buffer
;-------------------------------------------------------------------------------
NextView:
                move.w  ViewIdx(pc),d0
                move.w  ViewFrame(pc),d1
                move.l  ViewScreen(pc),a0
                move.l  ViewGeo(pc),a1
                move.w  d0,PrevView
                addq    #1,d0           ; Increment view index
                addq    #1,d1
                lea     SCREEN_SIZE(a0),a0 ; Increment screen ptr
                lea     Geo_SIZEOF(a1),a1
                cmp.w   #SCREEN_BUFFERS,d0 ; wrap?
                bne     .noWrap
                moveq   #0,d0           ; reset index and ptr
                move.l  Screens(pc),a0
                move.l  Geometry(pc),a1
.noWrap:
; Is buffer empty?
; Check if frame is ready i.e. not the view buffer
                cmp.w   DrawFrame(pc),d1
                blt     .ready

; Next frame not ready - return current value
                PROFILE_BG $f00
                move.l  ViewScreen(pc),a0
                move.l  ViewGeo(pc),a1
                rts
.ready:
                PROFILE_BG $000
                move.w  d0,ViewIdx      ; update vars and return new value
                move.w  d1,ViewFrame
                move.l  a0,ViewScreen
                move.l  a1,ViewGeo
                rts

********************************************************************************
NextDraw:
                move.w  DrawIdx(pc),d0
                move.w  DrawFrame(pc),d1
                move.l  DrawScreen(pc),a0
                move.l  DrawGeo(pc),a1
; Increment index
                addq    #1,d0
                addq    #1,d1
                lea     SCREEN_SIZE(a0),a0
                lea     Geo_SIZEOF(a1),a1
                cmp.w   #SCREEN_BUFFERS,d0 ; wrap?
                bne     .noWrap
                moveq   #0,d0           ; reset index and ptr
                move.l  Screens(pc),a0
                move.l  Geometry(pc),a1
.noWrap:
                move.w  d0,DrawIdx      ; update vars and return new value
                move.w  d1,DrawFrame
                move.l  a0,DrawScreen
                move.l  a1,DrawGeo

; Is buffer full?
; Wait until frame is free i.e. not the view buffer
.wait:
                cmp.w   PrevView(pc),d0
                beq     .wait
                ; bne     .done
                ; PROFILE_BG $0f0
                ; PUSHM   d0/a0-a1
                ; CALLFW  VSyncWithTask
                ; CALLFW  VSync
                ; BLTHOGOFF
                ; move.l  fw_VBR(a6),a0
                ; move.l  #Interrupt,$6c(a0)
                ; POPM
                ; bra     .wait

.done:
                movem.w NextGeo(pc),d0-d3
                movem.w d0-d3,(a1)
                rts

                include 3d.asm
                include c2p-4x4.asm



********************************************************************************
Vars:
********************************************************************************

DrawFrame:      dc.w    0
ViewFrame:      dc.w    0
PrevView:       dc.w    0

Speed:
YSpeed:         dc.w    Y_SPEED
ZSpeed:         dc.w    Z_SPEED

BaseDist:       dc.w    DIST

FWBase:         dc.l    0

ChunkyTmp:      dc.l    0

ChunkyBuffers:
DrawChunky:     dc.l    0
C2pChunky:      dc.l    0
ClearChunky:    dc.l    0

DrawCop:        dc.l    0
ViewCop:        dc.l    0

Screens:        dc.l    0

Geometry:       dc.l    0
Transformed:    dc.l    0
TransformedNorms: dc.l  0

DrawIdx:        dc.w    0
DrawScreen:     dc.l    0
DrawGeo:        dc.l    0
ViewIdx:        dc.w    0
ViewScreen:     dc.l    0
ViewGeo:        dc.l    0

NextGeo:        ds.b    Geo_SIZEOF

SpTmp:          dc.l    0

; Vertex bounds
VertBounds:
VertMinX:       dc.w    0
VertMaxX:       dc.w    0
VertMinY:       dc.w    0
VertMaxY:       dc.w    0

********************************************************************************
* Data
********************************************************************************

Object:
                include data/torus-8x4q.norm.i
                ; include data/torus-9x5q.norm.i

;-------------------------------------------------------------------------------
ObjTex:
                incbin  data/objtex.rgbs
                ifne    TEX_REPT
                incbin  data/objtex.rgbs
                endc

SpritePal:
                dc.w    0,$147,$17c,$fff ; blue
                dc.w    0,$7a6,$ad7,$fff ; green
                dc.w    0,$a00,$f44,$fff ; red
                dc.w    0,$b6a,$f9d,$fff ; purple


*******************************************************************************
                data_c
*******************************************************************************

Cop:
CopSprPt:
                rept    8*2
                dc.w    sprpt+REPTN*2,0
                endr
; 1   r0 g0 b0 b0
; 2   r1 g1 b1 b1
; 3   r2 g2 b2 b2
; 4   r3 g3 b3 b3
; 5 - 0  1  1  1  rgbb
; 6 - 1  1  0  0  rbbb
CopBplPt:       rept    6*2
                dc.w    bpl0pt+REPTN*2,0
                endr
                dc.w    bpldat+4*2,$7777 ; fixed data for bpl 5 - rgbb: 0111
                dc.w    bpldat+5*2,$cccc ; fixed data for bpl 6 - rgbb: 1100
                dc.w    bplcon1,0
CopScreen:
                dc.w    diwstrt,DIW_YSTRT<<8!DIW_XSTRT
                dc.w    diwstop,(DIW_YSTOP-256)<<8!(DIW_XSTOP-256)
                dc.w    ddfstrt,(DIW_XSTRT-17)>>1&$fc
                dc.w    ddfstop,(DIW_XSTRT-17+(DIW_W>>4-1)<<4)>>1&$fc
                dc.w    bplcon0
CopBplcon0:     dc.w    (7<<12)!(1<<11)!$200
CopPal:
                ifeq    PROFILE
                dc.w    color00,$000    ; initial / bg colour
                ; dc.w    color00,$004    ; initial / bg colour
                endc

SPRITE_WAIT = $28

CHUNKY_COPL     macro
                dc.w    bpl1mod,0
                dc.w    bpl2mod,0
                COP_WAITH \1,SPRITE_WAIT
                dc.w    bpldat,0
                COP_WAITH \1,$df
                ifne    ALT
                dc.w    bplcon1,ALT!ALT<<4
                endc
                COP_WAITH \1,SPRITE_WAIT
                dc.w    bpldat,0
                COP_WAITH \1,$df
                ifne    ALT
                dc.w    bplcon1,0
                endc
                COP_WAITH \1,SPRITE_WAIT
                dc.w    bpldat,0
                COP_WAITH \1,$df
                ifne    ALT
                dc.w    bplcon1,ALT!ALT<<4
                endc
                dc.w    bpl1mod,0
                dc.w    bpl2mod,0
                COP_WAITH \1,SPRITE_WAIT
                dc.w    bpldat,0
                COP_WAITH \1,$df
                ifne    ALT
                dc.w    bplcon1,0
                endc
                endm

                COP_WAITV DIW_YSTRT-1
Cop2Lc1:
                dc.w    cop2lc,0
                dc.w    cop2lc+2,0
CopLoop1:
CopMods1:
                CHUNKY_COPL 0
                COP_SKIPV $80
                dc.w    copjmp2,0

Cop2Lc2:
                dc.w    cop2lc,0
                dc.w    cop2lc+2,0
CopLoop2:
CopMods2:
                CHUNKY_COPL $80
                COP_SKIPV $fc
                dc.w    copjmp2,0

CopMods3:
                CHUNKY_COPL $80

Cop2Lc3:
                dc.w    cop2lc,0
                dc.w    cop2lc+2,0
CopLoop3:
CopMods4:
                CHUNKY_COPL 0
                COP_SKIPV DIW_YSTOP
                dc.w    copjmp2,0

                dc.l    -2
CopE:

COP_SIZE = CopE-Cop

Sprite1:
                incbin  ../face-lights/data/light-32.SPR
Sprite2:
                incbin  ../face-lights/data/light-32.SPR
Sprite3:
                incbin  ../face-lights/data/light-32.SPR
Sprite4:
                incbin  ../face-lights/data/light-32.SPR
