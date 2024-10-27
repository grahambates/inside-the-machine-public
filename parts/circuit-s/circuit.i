                ifnd    FW_DEMO_PART
CHIPMEM_SIZE = SCREEN_SIZE
FASTMEM_SIZE = 0
DEBUG_DETAIL    set     10
NEWAGE_DEBUG = 1
                endc
                include ../../demo/part.i

********************************************************************************
* Constants
********************************************************************************

END_FRAME = 32*3000/175

HIGHLIGHT_COLOR = $fea

HL_PROB = $100                          ; /$8000
HL_DELAY = 5
RANDOM_SEED = $a162b2c9

; Display window:
DIW_W = 320
DIW_H = 240
BPLS = 6
SCROLL = 0                              ; enable playfield scroll
INTERLEAVED = 0
DPF = 1                                 ; enable dual playfield

; Screen buffer:
SCREEN_W = DIW_W
SCREEN_H = DIW_H

DMASET = DMAF_SETCLR!DMAF_MASTER!DMAF_RASTER!DMAF_COPPER!DMAF_BLITTER
INTSET = INTF_SETCLR!INTF_INTEN!INTF_VERTB

;-------------------------------------------------------------------------------
; Derived

COLORS = 1<<BPLS

SCREEN_BW = SCREEN_W/16*2               ; byte-width of 1 bitplane line
                ifne    INTERLEAVED
SCREEN_MOD = SCREEN_BW*(BPLS-1)         ; modulo (interleaved)
SCREEN_BPL = SCREEN_BW                  ; bitplane offset (interleaved)
                else
SCREEN_MOD = 0                          ; modulo (non-interleaved)
SCREEN_BPL = SCREEN_BW*SCREEN_H         ; bitplane offset (non-interleaved)
                endc
SCREEN_SIZE = SCREEN_BW*SCREEN_H*BPLS   ; byte size of screen buffer

DIW_BW = DIW_W/16*2
DIW_MOD = SCREEN_BW-DIW_BW+SCREEN_MOD-SCROLL*2
DIW_SIZE = DIW_BW*DIW_H*BPLS
DIW_XSTRT = ($242-DIW_W)/2
DIW_YSTRT = ($158-DIW_H)/2
DIW_XSTOP = DIW_XSTRT+DIW_W
DIW_YSTOP = DIW_YSTRT+DIW_H


********************************************************************************
* Part vars
********************************************************************************

                STRUCTURE PartData,fw_SIZEOF
                APTR    pd_Screen
                APTR    pd_Image
                APTR    pd_Pal
                UWORD   pd_ImageScroll
                UWORD   pd_LineColFade
                STRUCT  pd_PalLerpLight,6*cl_SIZEOF
                STRUCT  pd_PalLerpDark,6*cl_SIZEOF
                STRUCT  pd_PalLerpBg,2*cl_SIZEOF
                LABEL   pd_SIZEOF


********************************************************************************
* Structs
********************************************************************************

                rsreset
Line_DrawPos    rs.w    1
Line_HlPos      rs.w    1
Line_ColorIndex rs.w    1
Line_StartDot   rs.w    1
Line_EndDot     rs.w    1
Line_DrawSpeed  rs.w    1
Line_HlSpeed    rs.w    1
Line_StartX     rs.w    1
Line_StartY     rs.w    1
Line_EndX       rs.w    1
Line_EndY       rs.w    1
Line_HeadX      rs.w    1
Line_HeadY      rs.w    1
Line_TailX      rs.w    1
Line_TailY      rs.w    1
Line_Ptr        rs.l    1
Line_HeadPtr    rs.l    1
Line_TailPtr    rs.l    1
Line_SIZEOF     rs.b    0

                rsreset
Dot_Delay       rs.w    1
Dot_ColorIndex  rs.w    1
Dot_X           rs.w    1
Dot_Y           rs.w    1
Dot_SIZEOF      rs.b    0

                rsreset
Sect_Count      rs.w    1
Sect_HeadCount  rs.w    1
Sect_TailCount  rs.w    1
Sect_Dx         rs.w    1
Sect_Dy         rs.w    1
Sect_SIZEOF     rs.b    0


********************************************************************************
* Macros
********************************************************************************

COUNT           macro
                dc.w    \1-1
                endm

EOL             macro
                dc.w    -1
                endm

********************************************************************************
; \1 i
; \2 delay
; \3 colorIndex
; \4 start
; \5 end
; \6 speed
; \7 x start
; \8 y start
; \9 x end
; \10 y end
;-------------------------------------------------------------------------------
LINE            macro
                dc.w    -1-\2           ; Line_DrawPos
                dc.w    -4              ; Line_HlPos
                dc.w    \3+1            ; Line_ColorIndex
                dc.w    \4,\5           ; Line_StartDot/EndDot
                dc.w    \6-1            ; Line_DrawSpeed
                dc.w    -1              ; Line_HlSpeed
                dc.w    \7,\8*SCREEN_BW ; start x/y
                dc.w    \9,\a*SCREEN_BW ; end x/y
                dc.w    \7,\8*SCREEN_BW ; head x/y
                dc.w    \7,\8*SCREEN_BW ; tail x/y
                dc.l    Coords\1        ; Line_Coords
                dc.l    Coords\1        ; Line_Ptr
                dc.l    Coords\1        ; Line_TailPtr
                endm

********************************************************************************
; \1 delay
; \2 colorIndex
; \3 x
; \4 y
;-------------------------------------------------------------------------------
DOT             macro
                dc.w    \1,\2,\3,\4*SCREEN_BW
                endm

********************************************************************************
; \1 count
; \2 dx
; \3 dy
;-------------------------------------------------------------------------------
SECT            macro
                dc.w    \1-1            ; Sect_Count
                dc.w    \1-1            ; Sect_HeadCount
                dc.w    \1-1            ; Sect_TailCount
                dc.w    \2,\3*SCREEN_BW
                endm
