
********************************************************************************
; For AGA need 6 real bitplanes - no 7bpl trick
;-------------------------------------------------------------------------------
AgaFix:
                tst.w   fw_AgaChipset(a6)
                beq     .noaga
                move.w  #(6<<12)!(1<<11)!$200,CopBplcon0 

                bsr     InitAga

                lea     CopBplPt+4*8+2,a1
                move.w  AgaBpl4(pc),(a1)
                move.w  AgaBpl4+2(pc),4(a1)
                move.w  AgaBpl5(pc),8(a1)
                move.w  AgaBpl5+2(pc),12(a1)
.noaga:
                rts


********************************************************************************
InitAga:
                tst.w   fw_AgaChipset(a6)
                beq     .noaga
                move.w  #-1,IsAga       ; set local var for use in 3d transform

                move.l  #SCREEN_BPL,d0
                CALLFW  AllocChip
                move.l  a0,AgaBpl4
                move.l  a0,a4

                move.l  #SCREEN_BPL,d0
                CALLFW  AllocChip
                move.l  a0,AgaBpl5

                move.l  #$77777777,d0
                move.l  #$cccccccc,d1
                move.w  #SCREEN_BPL/4-1,d7
.l:
                move.l  d0,(a4)+
                move.l  d1,(a0)+
                dbf     d7,.l
.noaga:
                rts


********************************************************************************
; For AGA need 6 real bitplanes - no 7bpl trick
;-------------------------------------------------------------------------------
AgaFixA1:
                tst.w   fw_AgaChipset(a6)
                beq     .noaga
                move.w  #(6<<12)!(1<<11)!$200,CopBplcon0-Cop(a1)

                lea     CopBplPt+4*8+2-Cop(a1),a2
                move.w  AgaBpl4(pc),(a2)
                move.w  AgaBpl4+2(pc),4(a2)
                move.w  AgaBpl5(pc),8(a2)
                move.w  AgaBpl5+2(pc),12(a2)
.noaga:
                rts

IsAga:          dc.w    0
AgaBpl4:        dc.l    0
AgaBpl5:        dc.l    0
; Blitter interrupt chaining:
; Ptr to routine for next blit operation, or 0.
BlitNext:       dc.l    0


********************************************************************************
BlitIRQStart:
                move.l  fw_DefaultIRQ(a6),DefaultIRQ
                move.l  fw_VBR(a6),a0
                move.l  #BlitIRQ,$6c(a0)
                move.w  #INTF_SETCLR|INTF_BLIT,intena(a5)
                rts


********************************************************************************
; Wait till all blits complete and restore interrupt
BlitIRQEnd:
                bsr     BlitIRQWait
                ; Restore original IRQ
                move.l  fw_VBR(a6),a0
                move.l  DefaultIRQ(pc),$6c(a0)
                rts


********************************************************************************
; Wait till all blits complete
BlitIRQWait:
.bltq:          tst.l   BlitNext
                bne     .bltq
                BLTWAIT
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
.checkNext:     move.l  BlitNext(pc),d0
                beq     .end
                move.l  d0,a0
                jsr     (a0)            ; Call blit routine
.end:           movem.l (sp)+,d0/d1/a0/a5
                rte

DefaultIRQ:     dc.l    0

********************************************************************************
; Scramble RGB bits:
;    [-- -- -- -- 11 10  9  8  7  6  5  4  3  2  1  0]
;    [-- -- -- -- r3 r2 r1 r0 g3 g2 g1 g0 b3 b2 b1 b0]
;    [11  7  3  3 10  6  2  2  9  5  1  1  8  4  0  0]
;    [r3 g3 b3 b3 r2 g2 b2 b2 r1 g1 b1 b1 r0 g0 b0 b0]
;-------------------------------------------------------------------------------
; a0 - src
; a1 - dest
; d0.w - TEX_W*TEX_H
;-------------------------------------------------------------------------------
ScrambleTexture:
                move.w  d0,d6
                subq    #1,d6

                ifne    TEX_REPT 
                move.l  a1,a2
                ext.l   d0
                add.l   d0,d0
                adda.l  d0,a2
                endc
                moveq   #0,d0
.l:
                move.b  (a0)+,d0        ; red
                move.w  .red(pc,d0.w),d1
                move.b  (a0)+,d0
                or.w    .green(pc,d0.w),d1
                move.b  (a0)+,d0
                or.w    .blue(pc,d0.w),d1
                move.w  d1,(a1)+
                ifne    TEX_REPT 
                move.w  d1,(a2)+
                endc
                dbf     d6,.l
                rts

.red:           dc.w    $0000,$0008,$0080,$0088,$0800,$0808,$0880,$0888,$8000,$8008,$8080,$8088,$8800,$8808,$8880,$8888
.green:         dc.w    $0000,$0004,$0040,$0044,$0400,$0404,$0440,$0444,$4000,$4004,$4040,$4044,$4400,$4404,$4440,$4444
.blue:          dc.w    $0000,$0003,$0030,$0033,$0300,$0303,$0330,$0333,$3000,$3003,$3030,$3033,$3300,$3303,$3330,$3333


C2pVars:
C2pScreenSize:  dc.w    0
C2pBpl:         dc.w    0
C2pBpl3:        dc.w    0
C2pBlitSize:    dc.w    0

GeometryVars:
DrawSize:
DrawW:          dc.w    CHUNKY_W
DrawH:          dc.w    CHUNKY_H
C2pSize:
C2pW:           dc.w    CHUNKY_W
C2pH:           dc.w    CHUNKY_H
ClearSize:
ClearW:         dc.w    CHUNKY_W
ClearH:         dc.w    CHUNKY_H


********************************************************************************
StartC2pBlit:
; Input: Chunky buffer (consecutive words)
; [Ar3 Ag3 Ab3 Ab3 Ar2 Ag2 Ab2 Ab2 Ar1 Ag1 Ab1 Ab1 Ar0 Ag0 Ab0 Ab0]
; [Br3 Bg3 Bb3 Bb3 Br2 Bg2 Bb2 Bb2 Br1 Bg1 Bb1 Bb1 Br0 Bg0 Bb0 Bb0]
; [Cr3 Cg3 Cb3 Cb3 Cr2 Cg2 Cb2 Cb2 Cr1 Cg1 Cb1 Cb1 Cr0 Cg0 Cb0 Cb0]
; [Dr3 Dg3 Db3 Db3 Dr2 Dg2 Db2 Db2 Dr1 Dg1 Db1 Db1 Dr0 Dg0 Db0 Db0]
; ...
;
; Output: Bitplanes (not interleaved)
; [Ar0 Ag0 Ab0 Ab0 Br0 Bg0 Bb0 Bb0 Cr0 Cg0 Cb0 Cb0 Dr0 Dg0 Db0 Db0]... bpl0
; [Ar1 Ag1 Ab1 Ab1 Br1 Bg1 Bb1 Bb1 Cr1 Cg1 Cb1 Cb1 Dr1 Dg1 Db1 Db1]... bpl1
; [Ar2 Ag2 Ab2 Ab2 Br2 Bg2 Bb2 Bb2 Cr2 Cg2 Cb2 Cb2 Dr2 Dg2 Db2 Db2]... bpl2
; [Ar3 Ag3 Ab3 Ab3 Br3 Bg3 Bb3 Bb3 Cr3 Cg3 Cb3 Cb3 Dr3 Dg3 Db3 Db3]... bpl3
********************************************************************************
                BLTWAIT
                move.w  C2pW(pc),d0
                move.w  C2pH(pc),d1
                lsr.w   d0              ; chunk w/2 = bit width
                mulu    d1,d0
                lea     C2pVars(pc),a0
                move.w  d0,C2pBpl-C2pVars(a0)
                move.w  d0,d1
                add.w   d0,d1
                add.w   d0,d1
                move.w  d1,C2pBpl3-C2pVars(a0)
                lsl.w   #2,d0
                move.w  d0,C2pScreenSize-C2pVars(a0)
                lsr.w   #4,d0
                lsl.w   #6,d0
                addq    #1,d0
                move.w  d0,C2pBlitSize-C2pVars(a0)
BlitSwap1:
; Chunky -> ChunkyTmp
; 8x2 swap to temporary buffer;
                move.w  #4,bltbmod(a5)
                move.l  #4<<16!4,bltamod(a5)
                move.w  #$00ff,bltcdat(a5)
                move.l  #-1,bltafwm(a5)
;-------------------------------------------------------------------------------
; ((a > 8) & 0x00FF) | (b & 0xFF00)
; Chunky -> ChunkyTmp:
; [Ar3 Ag3 Ab3 Ab3 Ar2 Ag2 Ab2 Ab2 Cr3 Cg3 Cb3 Cb3 Cr2 Cg2 Cb2 Cb2]
; [Br3 Bg3 Bb3 Bb3 Br2 Bg2 Bb2 Bb2 Dr3 Dg3 Db3 Db3 Dr2 Dg2 Db2 Db2]
; [                                                               ]
; [                                                               ]
                move.l  #(BLTEN_ABD!(BLT_A&BLT_C)!(BLT_B&~BLT_C)!(8<<12))<<16,bltcon0(a5)
                move.l  C2pChunky(pc),a0
                move.l  a0,bltbpt(a5)
                lea     4(a0),a0
                move.l  a0,bltapt(a5)
                move.l  ChunkyTmp(pc),bltdpt(a5)
                move.w  C2pBlitSize(pc),d0
                addq    #1,d0
                move.w  d0,bltsize(a5)  ; Height > max for OCS - split into two ops
                move.l  #BlitSwap1Cont,BlitNext
                rts
BlitSwap1Cont:
                move.w  C2pBlitSize(pc),d0
                addq    #1,d0
                move.w  d0,bltsize(a5)
                move.l  #BlitSwap2,BlitNext
                rts
********************************************************************************
BlitSwap2:
; Chunky -> ChunkyTmp
;-------------------------------------------------------------------------------
; ((a << 8) & 0xFF00) | (b & 0x00FF)
; ChunkyTmp:
; [Ar3 Ag3 Ab3 Ab3 Ar2 Ag2 Ab2 Ab2 Cr3 Cg3 Cb3 Cb3 Cr2 Cg2 Cb2 Cb2]
; [Br3 Bg3 Bb3 Bb3 Br2 Bg2 Bb2 Bb2 Dr3 Dg3 Db3 Db3 Dr2 Dg2 Db2 Db2]
; [Ar1 Ag1 Ab1 Ab1 Ar0 Ag0 Ab0 Ab0 Cr1 Cg1 Cb1 Cb1 Cr0 Cg0 Cb0 Cb0]
; [Br1 Bg1 Bb1 Bb1 Br0 Bg0 Bb0 Bb0 Dr1 Dg1 Db1 Db1 Dr0 Dg0 Db0 Db0]
                move.l  #(BLTEN_ABD!(BLT_A&~BLT_C)!(BLT_B&BLT_C)!(8<<12))<<16!BC1F_DESC,bltcon0(a5)
                move.l  C2pChunky(pc),a0
                adda.w  C2pScreenSize(pc),a0
                subq    #6,a0
                move.l  a0,bltapt(a5)
                lea     4(a0),a0
                move.l  a0,bltbpt(a5)
                move.l  ChunkyTmp(pc),a0
                adda.w  C2pScreenSize(pc),a0
                subq    #2,a0
                move.l  a0,bltdpt(a5)
                move.w  C2pBlitSize(pc),d0
                addq    #1,d0
                move.w  d0,bltsize(a5)  ; Height > max for OCS - split into two ops
                move.l  #BlitSwap2Cont,BlitNext
                rts
BlitSwap2Cont:
                move.w  C2pBlitSize(pc),d0
                addq    #1,d0
                move.w  d0,bltsize(a5)
                move.l  #BlitBpl3,BlitNext
                rts
********************************************************************************
BlitBpl3:
; ChunkyTmp -> DrawScreen
; Copy from tmp buffer to bitplanes
                move.w  #6,bltbmod(a5)
                move.l  #(6<<16),bltamod(a5)
                move.w  #$0f0f,bltcdat(a5)
;-------------------------------------------------------------------------------
; ((a >> 4) & 0x0F0F) | (b & 0xF0F0)
; [Ar3 Ag3 Ab3 Ab3 Br3 Bg3 Bb3 Bb3 Cr3 Cg3 Cb3 Cb3 Dr3 Dg3 Db3 Db3]
                move.l  #(BLTEN_ABD!(BLT_A&BLT_C)!(BLT_B&~BLT_C)!(4<<12))<<16,bltcon0(a5)
                move.l  ChunkyTmp(pc),a0
                move.l  a0,bltbpt(a5)
                addq.l  #2,a0
                move.l  a0,bltapt(a5)
                move.l  DrawScreen(pc),a0
                adda.w  C2pBpl3(pc),a0  ; bpl 3
                move.l  a0,bltdpt(a5)
                move.w  C2pBlitSize(pc),bltsize(a5)
                move.l  #BlitBpl3Cont,BlitNext
                rts
BlitBpl3Cont:
                move.w  C2pBlitSize(pc),bltsize(a5)
                move.l  #BlitBpl1,BlitNext
                rts
********************************************************************************
BlitBpl1:
;-------------------------------------------------------------------------------
; ((a >> 4) & 0x0F0F) | (b & 0xF0F0)
; [Ar1 Ag1 Ab1 Ab1 Br1 Bg1 Bb1 Bb1 Cr1 Cg1 Cb1 Cb1 Dr1 Dg1 Db1 Db1]
                move.l  ChunkyTmp(pc),a0
                addq.l  #4,a0
                move.l  a0,bltbpt(a5)
                addq.l  #2,a0
                move.l  a0,bltapt(a5)
                move.l  DrawScreen(pc),a0
                adda.w  C2pBpl(pc),a0   ; bpl 1
                move.l  a0,bltdpt(a5)
                move.w  C2pBlitSize(pc),bltsize(a5)
                move.l  #BlitBpl1Cont,BlitNext
                rts
BlitBpl1Cont:
                move.w  C2pBlitSize(pc),bltsize(a5)
                move.l  #BlitBpl2,BlitNext
                rts
********************************************************************************
BlitBpl2:
;-------------------------------------------------------------------------------
; ((a << 8) & ~0x0F0F) | (b & 0x0F0F)
; [Ar2 Ag2 Ab2 Ab2 Br2 Bg2 Bb2 Bb2 Cr2 Cg2 Cb2 Cb2 Dr2 Dg2 Db2 Db2]
                move.l  #(BLTEN_ABD!(BLT_A&~BLT_C)!(BLT_B&BLT_C)!(4<<12))<<16!BC1F_DESC,bltcon0(a5)
                move.l  ChunkyTmp(pc),a0
                adda.w  C2pScreenSize(pc),a0
                subq    #8,a0
                move.l  a0,bltapt(a5)
                addq    #2,a0
                move.l  a0,bltbpt(a5)
                move.l  DrawScreen(pc),a0
                adda.w  C2pBpl3(pc),a0  ; bpl2 (rev)
                subq    #2,a0
                move.l  a0,bltdpt(a5)
                move.w  C2pBlitSize(pc),bltsize(a5)
                move.l  #BlitBpl2Cont,BlitNext
                rts
BlitBpl2Cont:
                move.w  C2pBlitSize(pc),bltsize(a5)
                move.l  #BlitBpl0,BlitNext
                rts

BlitBpl0:
;-------------------------------------------------------------------------------
; [Ar0 Ag0 Ab0 Ab0 Br0 Bg0 Bb0 Bb0 Cr0 Cg0 Cb0 Cb0 Dr0 Dg0 Db0 Db0]
                move.l  ChunkyTmp(pc),a0
                adda.w  C2pScreenSize(pc),a0
                subq    #4,a0
                move.l  a0,bltapt(a5)
                addq    #2,a0
                move.l  a0,bltbpt(a5)
                move.l  DrawScreen(pc),a0
                adda.w  C2pBpl(pc),a0   ; bpl0 (rev)
                subq    #2,a0
                move.l  a0,bltdpt(a5)
                move.w  C2pBlitSize(pc),bltsize(a5)
                move.l  #BlitBpl0Cont,BlitNext
                rts
BlitBpl0Cont:
                move.w  C2pBlitSize(pc),bltsize(a5)
                clr.l   BlitNext
                rts
