                ifnd    FW_DEMO_PART
CHIPMEM_SIZE = MASK_SIZE+2
FASTMEM_SIZE = PAL_DATA_SIZE
DEBUG_DETAIL    set     10
NEWAGE_DEBUG = 1
                endc
                include ../../demo/part.i

********************************************************************************
* Constants
********************************************************************************

ORIG_COLS = 9
CHROME_COLS = 21

PAL_DATA_SIZE = ORIG_COLS*16*2

MASK_LINE_BW = 80/8
MASK_LINE_H = 400
MASK_SIZE = MASK_LINE_BW*194

; Display window:
DIW_W = 320
DIW_H = 256
BPLS = 5
SCROLL = 1                              ; enable playfield scroll
INTERLEAVED = 1
DPF = 0                                 ; enable dual playfield

; Screen buffer:
SCREEN_W = 480
SCREEN_H = 288

DMASET = DMAF_SETCLR!DMAF_MASTER!DMAF_RASTER!DMAF_COPPER!DMAF_BLITTER!DMAF_BLITHOG
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
                UWORD   pd_PanX
                UWORD   pd_PanY
                UWORD   pd_PalCyclePos
                UWORD   pd_PalFade
                UWORD   pd_ChromeFade
                APTR    pd_Mask
                APTR    pd_PalStepData
                LABEL   pd_SIZEOF


********************************************************************************
* Structs
********************************************************************************

                rsreset
MaskDraw_Mask   rs.l    1
MaskDraw_X      rs.w    1
MaskDraw_Y      rs.w    1
MaskDraw_SIZEOF rs.b    0

                rsreset
Mask_Mod        rs.w    1
Mask_BlitSize   rs.w    1
Mask_Offset     rs.l    1
Mask_Img        rs.l    1
Mask_SIZEOF     rs.b    0
