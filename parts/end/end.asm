                include end.i

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

                bsr     SetBplPtrs
                bsr     SetPal

                lea     Cop,a0
                CALLFW  SetCopper

                move.w  #ENDPART_START+T_BAR*2,d0
                CALLFW  WaitForFrame
                CALLFW  StopMusic
                
;-------------------------------------------------------------------------------
.loop:
                CALLFW  VSync
                bra     .loop


********************************************************************************
* Routines
********************************************************************************

********************************************************************************
SetPal:
                lea     Pal(pc),a1
                moveq.l #COLORS/2-1,d7
                lea     color00(a5),a0
.l:
                move.l  (a1)+,(a0)+
                dbra    d7,.l
                rts


********************************************************************************
SetBplPtrs:
                lea     ImgMain,a1

; Set bpl pointers in copper:
                lea     CopBplPt+2,a0
                moveq   #BPLS-1,d7
.bpl:           move.l  a1,d0
                swap    d0
                move.w  d0,(a0)         ; hi
                move.w  a1,4(a0)        ; lo
                lea     8(a0),a0
                lea     SCREEN_BPL(a1),a1
                dbf     d7,.bpl

                rts


********************************************************************************
* Data
********************************************************************************

Pal:            
                incbin  data/logo.PAL
BlankPal:       
                ds.w    COLORS

*******************************************************************************
                data_c
*******************************************************************************

Cop:
CopBplPt:       rept    BPLS*2
                dc.w    bpl0pt+REPTN*2,0
                endr
CopScroll:      dc.w    bplcon1,0
                dc.w    bplcon0,BPLS<<12!$200
                dc.w    diwstrt,DIW_YSTRT<<8!DIW_XSTRT
                dc.w    diwstop,(DIW_YSTOP-256)<<8!(DIW_XSTOP-256)
                dc.w    ddfstrt,(DIW_XSTRT-17)>>1&$fc-SCROLL*8
                dc.w    ddfstop,(DIW_XSTRT-17+(DIW_W>>4-1)<<4)>>1&$fc
                dc.w    bpl1mod,DIW_MOD
                dc.w    bpl2mod,DIW_MOD
                dc.l    -2
CopE:

ImgMain:        incbin  data/logo.BPL
                ; TODO: Investigtate obvious overflow here
                ds.w    1
