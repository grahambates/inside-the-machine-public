BLITPASS_SIZE = SCREEN_SIZE/2


DblBuffers:
DrawScreen:     dc.l    0
ViewScreen:     dc.l    0
DrawChunky:     dc.l    0
ViewChunky:     dc.l    0

; Blitter interrupt chaining:
; Ptr to routine for next blit operation, or 0.
BlitNext:       dc.l    0

; Number of words remaining for current blit operation.
; For swap operations we exceed the maximum blit size of 1024*1, so need to
; continue by poking bltsize again until complete.
BlitWords:      dc.w    0


********************************************************************************
BlitIRQStart:
                move.l  fw_DefaultIRQ(a6),DefaultIRQ
                move.l  fw_VBR(a6),a0
                move.l  #BlitIRQ,$6c(a0)
                move.w  #INTF_SETCLR|INTF_BLIT,intena(a5)
                rts


********************************************************************************
; Wait till all blits complete
BlitIRQEnd:
.bltq:          tst.l   BlitNext
                bne     .bltq
                BLTWAIT
                ; Restore original IRQ
                move.l  fw_VBR(a6),a0
                move.l  DefaultIRQ(pc),$6c(a0)
                rts

********************************************************************************
BlitIRQ:
********************************************************************************
                btst    #INTB_BLIT,intreqr+custom+1
                bne     .blit
                move.l  DefaultIRQ(pc),-(sp)
                rts
.blit:
                movem.l d0/d1/a0/a5,-(sp)
                lea     custom,a5
                move.w  #INTF_BLIT,intreq(a5) ; acknowledge the blitter irq
; Continue previous blit?
                move.w  BlitWords(pc),d0
                ble     .checkNext
                moveq   #0,d1           ; d1 = blit size
                cmp.w   #1024,d0        ; Max size?
                bge     .max
                move.w  #1023,d1        ; Get remainder
                and.w   d0,d1
                lsl.w   #6,d1
.max:           addq    #1,d1           ; Width: 1 word
                move.w  d1,bltsize(a5)
                sub.w   #1024,BlitWords ; Update remaining count
                bra     .end
; Check next blit operation
.checkNext:     move.l  BlitNext(pc),d0
                beq     .end
                move.l  d0,a0
                jsr     (a0)            ; Call blit routine
.end:           movem.l (sp)+,d0/d1/a0/a5
                rte

DefaultIRQ:     dc.l    0


********************************************************************************
SwapBuffers:
                movem.l DblBuffers(pc),d0-d3
                exg     d0,d1           ; view/draw screen
                exg     d2,d3           ; view/draw chunky
                movem.l d0-d3,DblBuffers
                rts


********************************************************************************
; Scramble pixels in texture and repeat
;-------------------------------------------------------------------------------
ScrambleTexture:
                ifeq    SCRAMBLE_OPTS
;-------------------------------------------------------------------------------
; no scramble opts:
; can write in groups of 4

                move.l  #SCRAMBLED_TEX_SIZE,d0
                ; low:	__ __ a3 a2 __ __ a1 a0
                lea     (a0,d0.l),a1    ; high:		a3 a2 __ __ a1 a0 __ __

; Texture is repeated for shift
                move.l  #(%11<<24)!(%11<<16)!(%11<<8)!%11,d5
                move.l  #(%1100<<24)!(%1100<<16)!(%1100<<8)!%1100,d6

; Do we need a longword offset for repeat?
                iflt    SCRAMBLED_TEX_SIZE/2-$8000
.writeGroup     macro
                swap    \1
                move.w  \1,SCRAMBLED_TEX_SIZE/2(\2)
                move.w  \1,(\2)+
                move.b  \1,-(sp)
                move.w  (sp)+,d2
                move.w  d2,SCRAMBLED_TEX_SIZE/2(\2)
                move.w  d2,(\2)+
                swap    \1
                move.w  \1,SCRAMBLED_TEX_SIZE/2(\2)
                move.w  \1,(\2)+
                move.b  \1,-(sp)
                move.w  (sp)+,d2
                move.w  d2,SCRAMBLED_TEX_SIZE/2(\2)
                move.w  d2,(\2)+
                endm

                else
                move.l  #SCRAMBLED_TEX_SIZE/2,d3 ; repeat offset
.writeGroup     macro
                swap    \1
                move.w  \1,(\2,d3.l)
                move.w  \1,(\2)+
                move.b  \1,-(sp)
                move.w  (sp)+,d2
                move.w  d2,(\2,d3.l)
                move.w  d2,(\2)+
                swap    \1
                move.w  \1,(\2,d3.l)
                move.w  \1,(\2)+
                move.b  \1,-(sp)
                move.w  (sp)+,d2
                move.w  d2,(\2,d3.l)
                move.w  d2,(\2)+
                endm
                endc
; Do we need a longword offset for repeat?
.unroll = 8
                move.w  #TEX_SIZE/4/.unroll-1,d7
.scramble:
                rept    .unroll
                move.l  (a4)+,d0        ; ....3210
                move.l  d0,d1
                and.l   d5,d0           ; ......10
                and.l   d6,d1           ; ....32..
                lsl.l   #2,d1           ; ..32....

                or.l    d1,d0           ; ..32..10
                .writeGroup d0,a1

                lsl.l   #2,d0           ; 32..10..
                .writeGroup d0,a0

                endr
                dbf     d7,.scramble
                rts

                else
;-------------------------------------------------------------------------------
; scramble opts:
; need to write individal bytes to compare previous values

                move.l  #SCRAMBLED_TEX_SIZE,d0
                ; low:	__ __ a3 a2 __ __ a1 a0
                lea     (a0,d0.l),a1    ; high:		a3 a2 __ __ a1 a0 __ __
                lea     (a1,d0.l),a2    ; dupe:		a3 a2 a3 a2 a1 a0 a1 a0       Where b = a
                lea     (a2,d0.l),a3    ; seq: 		a3 a2 b3 b2 a1 a0 b1 b0       Where b = a+1
                moveq   #0,d3           ; init prev value

                move.w  #%11,d5
                move.w  #%1100,d6

; Do we need a longword offset for repeat?
                iflt    SCRAMBLED_TEX_SIZE/2-$8000
.writePair      macro
                move.b  \1,SCRAMBLED_TEX_SIZE/2(\2)
                move.b  \1,(\2)+
                addq    #1,\2           ; skip next byte
                endm
                else
                move.l  #SCRAMBLED_TEX_SIZE/2,d2 ; repeat offset
.writePair      macro
                move.b  \1,(\2,d2.l)
                move.b  \1,(\2)+
                addq    #1,\2
                endm
                endc

.unroll = 8
                move.w  #TEX_SIZE/.unroll-1,d7
.scramble:
                rept    .unroll
                move.b  (a4)+,d0        ; ....3210
                move.b  d0,d1
                and.b   d5,d0           ; ......10
                and.b   d6,d1           ; ....32..
                ; lsl.b   #2,d1           ; ..32....
                add.b   d1,d1
                add.b   d1,d1

                or.b    d1,d0           ; ..32..10
                .writePair d0,a1

                move.b  d0,d1
                move.b  d3,d4           ; get prev
                move.b  d0,d3           ; update prev

                ; lsl.b   #2,d0           ; 32..10..
                add.b   d0,d0
                add.b   d0,d0
                .writePair d0,a0

                or.b    d0,d4           ; combine prev / current
                .writePair d4,a3
                or.b    d1,d0           ; 32321010
                .writePair d0,a2

                endr
                dbf     d7,.scramble
                rts

                endc                    ; opt/no-opt
;-------------------------------------------------------------------------------


********************************************************************************
StartBlit:
                BLTWAIT
                move.l  #-1,bltafwm(a5)
                clr.w   bltdmod(a5)
********************************************************************************
BlitSwap1:
                move.l  #BlitSwap2,BlitNext
                move.w  #BLITPASS_SIZE-1024,BlitWords
                move.w  #2,bltamod(a5)
                move.w  #2,bltbmod(a5)
                move.w  #%1111000011110000,bltcdat(a5)
; D = (A & C) | ((B >> 4) & ~C)
                move.l  #($de4<<16)!(4<<12),bltcon0(a5)
                move.l  ViewChunky(pc),a0
                move.l  a0,bltapth(a5)  ; A = chunky buffer
                addq    #2,a0
                move.l  a0,bltbpth(a5)  ; B = A+2 i.e. next word
                move.l  DrawScreen(pc),a0 ; D = bpl0
                lea     SCREEN_SIZE(a0),a0
                move.l  a0,bltdpth(a5)
                move.w  #1,bltsize(a5)
                rts

********************************************************************************
BlitSwap2:
                move.l  #BlitExtend1,BlitNext
                move.w  #BLITPASS_SIZE-1024,BlitWords
; D = ((A<<4) & C) | (B & ~C)
                move.l  #($4de4<<16)!BLITREVERSE,bltcon0(a5)
                move.l  ViewChunky(pc),a0
                lea     CHUNKY_SIZE-4(a0),a0 ; A = chunky buffer (end for desc)
                move.l  a0,bltapth(a5)
                addq    #2,a0
                move.l  a0,bltbpth(a5)  ; B = A+2 i.e. prev word in desc
                move.l  DrawScreen(pc),a0
                lea     SCREEN_SIZE-2(a0),a0 ; D = bpl2 (end for desc)
                move.l  a0,bltdpth(a5)
                move.w  #1,bltsize(a5)
                rts


********************************************************************************
; Copy to bpls 1/3 and apply pixel doubling
;-------------------------------------------------------------------------------
BlitExtend1:
                move.l  #BlitExtend2,BlitNext
                clr.l   bltcmod(a5)
                clr.l   bltamod(a5)
                move.w  #%1010101010101010,bltcdat(a5)
; D = (A & C) | ((B >> 1) & ~C)
                move.l  #($de4<<16)!(1<<12),bltcon0(a5)
                move.l  DrawScreen(pc),a0
                move.l  a0,bltapth(a5)  ; A = bpl0/bpl2
                move.l  a0,bltbpth(a5)  ; B = A
                lea     SCREEN_SIZE*2(a0),a0
                move.l  a0,bltdpth(a5)  ; D = bpl1/bpl3
                move.w  #(SCREEN_H<<6)!(SCREEN_BW/2),bltsize(a5)
                rts


********************************************************************************
; Apply pixel doubling in place on bpls 0/2
;-------------------------------------------------------------------------------
BlitExtend2:
                clr.l   BlitNext
; D = ((A << 1) & C) | (B & ~C)
                move.l  #($1de4<<16)!BLITREVERSE,bltcon0(a5)
                move.l  DrawScreen(pc),a0
                lea     SCREEN_SIZE*2-2(a0),a0
                move.l  a0,bltapth(a5)  ; A = bpl0/bpl2 (end for desc)
                move.l  a0,bltbpth(a5)  ; B = A
                move.l  a0,bltdpth(a5)  ; D = A
                move.w  #(SCREEN_H<<6)!(SCREEN_BW/2),bltsize(a5)
                rts

