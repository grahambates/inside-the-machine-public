                include macros.i
Cop:
                COP_WAITV 10 
                dc.w    dmacon,DMAF_BLITHOG
                dc.w    dmacon,DMAF_SETCLR!DMAF_SPRITE
                dc.w    diwstrt,DIW_YSTRT<<8!DIW_XSTRT
                dc.w    diwstop,(DIW_YSTOP-256)<<8!(DIW_XSTOP-256)
                dc.w    ddfstrt,(DIW_XSTRT-17)>>1&$fc
                dc.w    ddfstop,(DIW_XSTRT-17+(DIW_W>>4-1)<<4)>>1&$fc
; 7 bitplane hack - all bitplanes enabled, but DMA off for 5/6
                dc.w    bplcon0 
CopBplcon0:     dc.w    (7<<12)!(1<<11)!$200
; 1   r0 g0 b0 b0
; 2   r1 g1 b1 b1
; 3   r2 g2 b2 b2
; 4   r3 g3 b3 b3
; 5 - 0  1  1  1  rgbb
; 6 - 1  1  0  0  rbbb
CopBplPt:       rept    8*2
                dc.w    bpl0pt+REPTN*2,0
                endr
                dc.w    bpldat+4*2,$7777 ; fixed data for bpl 5 - rgbb: 0111
                dc.w    bpldat+5*2,$cccc ; fixed data for bpl 6 - rgbb: 1100
                dc.w    bplcon1,0
CopSprPt:
                rept    8*2
                dc.w    sprpt+REPTN*2,0
                endr
CopPal:
                dc.w    color00,$000    ; initial / bg colour
; Repeat lines:
CopY            set     DIW_YSTRT-1

                ifeq    BLANK_LINES

                rept    DIW_H/PIXH
                COP_WAIT CopY,$df
                dc.w    bpl1mod,-SCREEN_BW
                dc.w    bpl2mod,-SCREEN_BW

                ifne    ALT
                dc.w    bplcon1,ALT!ALT<<4
                COP_WAIT CopY+1,$df
                ifge    PIXH-3
                dc.w    bplcon1,0
                COP_WAIT CopY+2,$df
                endc
                ifge    PIXH-4
                dc.w    bplcon1,ALT!ALT<<4
                COP_WAIT CopY+3,$df
                endc
                dc.w    bplcon1,0
                else
; PAL fix required withourn ALT
; ifge (CopY&$ff)-$fd
; COP_WAIT $ff,$df
; endc
                COP_WAIT CopY+PIXH-1,$df
                endc

                dc.w    bpl1mod,0
                dc.w    bpl2mod,0
CopY            set     CopY+PIXH
                endr


                else

                rept    DIW_H/PIXH
                COP_WAIT CopY,$df
                dc.w    bplcon0,$200
                dc.w    bpl1mod,-SCREEN_BW
                dc.w    bpl2mod,-SCREEN_BW
                COP_WAIT CopY+1,$df
                dc.w    bplcon0,(7<<12)!(1<<11)!$200
                COP_WAIT CopY+2,$df
                dc.w    bplcon0,$200
                COP_WAIT CopY+3,$df
                dc.w    bplcon0,(7<<12)!(1<<11)!$200
                dc.w    bpl1mod,0
                dc.w    bpl2mod,0
CopY            set     CopY+PIXH
                endr

                endc

                dc.w    intreq,INTF_SETCLR!INTF_COPER

                dc.l    -2
CopE:
