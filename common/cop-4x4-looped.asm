********************************************************************************
InitCopper:
                ; Poke loop addresses for all 4 offset lists
                move.l  #CopLoop0a,d0
                lea     CopLoop0LcA+2,a0
                move.w  d0,4(a0)
                swap    d0
                move.w  d0,(a0)
                move.l  #CopLoop0b,d0
                lea     CopLoop0LcB+2,a0
                move.w  d0,4(a0)
                swap    d0
                move.w  d0,(a0)

                move.l  #CopLoop1a,d0
                lea     CopLoop1LcA+2,a0
                move.w  d0,4(a0)
                swap    d0
                move.w  d0,(a0)
                move.l  #CopLoop1b,d0
                lea     CopLoop1LcB+2,a0
                move.w  d0,4(a0)
                swap    d0
                move.w  d0,(a0)

                move.l  #CopLoop2a,d0
                lea     CopLoop2LcA+2,a0
                move.w  d0,4(a0)
                swap    d0
                move.w  d0,(a0)
                move.l  #CopLoop2b,d0
                lea     CopLoop2LcB+2,a0
                move.w  d0,4(a0)
                swap    d0
                move.w  d0,(a0)

                move.l  #CopLoop3a,d0
                lea     CopLoop3LcA+2,a0
                move.w  d0,4(a0)
                swap    d0
                move.w  d0,(a0)
                move.l  #CopLoop3b,d0
                lea     CopLoop3LcB+2,a0
                move.w  d0,4(a0)
                swap    d0
                move.w  d0,(a0)

                moveq   #0,d0
                bsr     SetCopVOffset

                jmp     AgaFix


********************************************************************************
; d0.w - Vertical offset
; returns:
; a0 - Selected cop2 list
;-------------------------------------------------------------------------------
SetCopVOffset:
                add.w   d0,d0
                lea     OffsetLists(pc),a0
                move.w  (a0,d0),d0
                adda.w  d0,a0
                move.l  a0,d0
                lea     Cop2Lc+2,a1
                move.w  d0,4(a1)
                swap    d0
                move.w  d0,(a1)
                rts


********************************************************************************
Cop:
                dc.w    dmacon,DMAF_BLITHOG
                dc.w    dmacon,DMAF_SETCLR!DMAF_SPRITE
CopScreen:
                dc.w    diwstrt,DIW_YSTRT<<8!DIW_XSTRT
                dc.w    diwstop,(DIW_YSTOP-256)<<8!(DIW_XSTOP-256)
                dc.w    ddfstrt,(DIW_XSTRT-17)>>1&$fc
                dc.w    ddfstop,(DIW_XSTRT-17+(DIW_W>>4-1)<<4)>>1&$fc
                dc.w    bplcon0 
CopBplcon0:     dc.w    (7<<12)!(1<<11)!$200
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
                dc.w    bplcon1 
CopBplcon1:     dc.w    0
CopSprPt:
                rept    8*2
                dc.w    sprpt+REPTN*2,0
                endr
CopPal:
                dc.w    color00,$000    ; initial / bg colour


Cop2Lc:
                dc.w    cop2lc,0
                dc.w    cop2lc+2,0

                COP_WAITV DIW_YSTRT     
                dc.w    bpl1mod,-SCREEN_BW
                dc.w    bpl2mod,-SCREEN_BW
                dc.w    copjmp2,0


********************************************************************************

OffsetLists:
                dc.w    CopLoop0-OffsetLists
                dc.w    CopLoop1-OffsetLists
                dc.w    CopLoop2-OffsetLists
                dc.w    CopLoop3-OffsetLists

WAIT1 = $80

********************************************************************************

COPLOOP_0       macro
                COP_WAITH \1,$df
                ifne    ALT
                dc.w    bplcon1,(ALT)!(ALT)<<4
                endc

                COP_WAITH \1,$df
                ifne    ALT
                dc.w    bplcon1,0
                endc

                COP_WAITH \1,$df
                ifne    ALT
                dc.w    bplcon1,(ALT)!(ALT)<<4
                endc

                dc.w    bpl1mod,0
                dc.w    bpl2mod,0
                COP_WAITH \1,$df
                ifne    ALT
                dc.w    bplcon1,0
                endc
                dc.w    bpl1mod,-SCREEN_BW
                dc.w    bpl2mod,-SCREEN_BW
                endm


********************************************************************************
CopLoop0:
                COPLOOP_0 0
                COP_SKIPV WAIT1
                dc.w    copjmp2,0
CopLoop0LcA:
                dc.w    cop2lc,0
                dc.w    cop2lc+2,0
CopLoop0a:
                COPLOOP_0 $80
                COP_SKIPV $fc
                dc.w    copjmp2,0
                COPLOOP_0 $80
CopLoop0LcB:
                dc.w    cop2lc,0
                dc.w    cop2lc+2,0
CopLoop0b:
                COPLOOP_0 0
                COP_SKIPV DIW_YSTOP
                dc.w    copjmp2,0

                dc.w    intreq,INTF_SETCLR!INTF_COPER
                COP_END


********************************************************************************

COPLOOP_1       macro
                COP_WAITH \1,$df
                ifne    ALT
                dc.w    bplcon1,0
                endc

                COP_WAITH \1,$df
                ifne    ALT
                dc.w    bplcon1,(ALT)!(ALT)<<4
                endc

                dc.w    bpl1mod,0
                dc.w    bpl2mod,0
                COP_WAITH \1,$df
                ifne    ALT
                dc.w    bplcon1,0
                endc
                dc.w    bpl1mod,-SCREEN_BW
                dc.w    bpl2mod,-SCREEN_BW

                COP_WAITH \1,$df
                ifne    ALT
                dc.w    bplcon1,(ALT)!(ALT)<<4
                endc
                endm


********************************************************************************
CopLoop1:
                COPLOOP_1 0
                COP_SKIPV WAIT1
                dc.w    copjmp2,0
CopLoop1LcA:
                dc.w    cop2lc,0
                dc.w    cop2lc+2,0
CopLoop1a:
                COPLOOP_1 $80
                COP_SKIPV $fc
                dc.w    copjmp2,0
                COPLOOP_1 $80
CopLoop1LcB:
                dc.w    cop2lc,0
                dc.w    cop2lc+2,0
CopLoop1b:
                COPLOOP_1 0
                COP_SKIPV DIW_YSTOP
                dc.w    copjmp2,0

                dc.w    intreq,INTF_SETCLR!INTF_COPER
                COP_END


********************************************************************************

COPLOOP_2       macro
                COP_WAITH \1,$df
                ifne    ALT
                dc.w    bplcon1,(ALT)!(ALT)<<4
                endc

                dc.w    bpl1mod,0
                dc.w    bpl2mod,0
                COP_WAITH \1,$df
                ifne    ALT
                dc.w    bplcon1,0
                endc
                dc.w    bpl1mod,-SCREEN_BW
                dc.w    bpl2mod,-SCREEN_BW

                COP_WAITH \1,$df
                ifne    ALT
                dc.w    bplcon1,(ALT)!(ALT)<<4
                endc

                COP_WAITH \1,$df
                ifne    ALT
                dc.w    bplcon1,0
                endc
                endm


********************************************************************************
CopLoop2:
                COPLOOP_2 0
                COP_SKIPV WAIT1
                dc.w    copjmp2,0
CopLoop2LcA:
                dc.w    cop2lc,0
                dc.w    cop2lc+2,0
CopLoop2a:
                COPLOOP_2 $80
                COP_SKIPV $fc
                dc.w    copjmp2,0
                COPLOOP_2 $80
CopLoop2LcB:
                dc.w    cop2lc,0
                dc.w    cop2lc+2,0
CopLoop2b:
                COPLOOP_2 0
                COP_SKIPV DIW_YSTOP
                dc.w    copjmp2,0

                dc.w    intreq,INTF_SETCLR!INTF_COPER
                COP_END


********************************************************************************

COPLOOP_3       macro
                dc.w    bpl1mod,0
                dc.w    bpl2mod,0
                COP_WAITH \1,$df
                ifne    ALT
                dc.w    bplcon1,0
                endc
                dc.w    bpl1mod,-SCREEN_BW
                dc.w    bpl2mod,-SCREEN_BW

                COP_WAITH \1,$df
                ifne    ALT
                dc.w    bplcon1,(ALT)!(ALT)<<4
                endc

                COP_WAITH \1,$df
                ifne    ALT
                dc.w    bplcon1,0
                endc

                COP_WAITH \1,$df
                ifne    ALT
                dc.w    bplcon1,(ALT)!(ALT)<<4
                endc
                endm


********************************************************************************
CopLoop3:
                COPLOOP_3 0
                COP_SKIPV WAIT1
                dc.w    copjmp2,0
CopLoop3LcA:
                dc.w    cop2lc,0
                dc.w    cop2lc+2,0
CopLoop3a:
                COPLOOP_3 $80
                COP_SKIPV $fc
                dc.w    copjmp2,0
                COPLOOP_3 $80
CopLoop3LcB:
                dc.w    cop2lc,0
                dc.w    cop2lc+2,0
CopLoop3b:
                COPLOOP_3 0
                COP_SKIPV DIW_YSTOP
                dc.w    copjmp2,0

                dc.w    intreq,INTF_SETCLR!INTF_COPER
                COP_END
