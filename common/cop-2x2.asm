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

                dc.w    bplcon0,(BPLS<<12)!$200
                dc.w    bplcon1,0
                dc.w    diwstrt,(DIW_YSTRT<<8)!DIW_XSTRT
                dc.w    diwstop,(((DIW_YSTRT+SCREEN_H)<<8)&$ff00)!((DIW_XSTRT+SCREEN_W)&$ff)
                dc.w    ddfstrt,DIW_XSTRT/2-8
                dc.w    ddfstop,DIW_XSTRT/2-8+8*((SCREEN_W+15)/16-1)

.y              set     DIW_YSTRT-1
                rept    SCREEN_H/2
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

                COP_WAITV DIW_YSTOP
                dc.w    intreq,INTF_SETCLR!INTF_COPER

                dc.l    -2

COP_SIZE = *-Cop
