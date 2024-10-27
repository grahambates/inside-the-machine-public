                ifnd    FW_DEMO_PART
CHIPMEM_SIZE = SCREEN_SIZE*5+TOTAL_TEX_SIZE+4
FASTMEM_SIZE = 0
DEBUG_DETAIL    set     0
NEWAGE_DEBUG = 0
                endc
                include ../../demo/part.i

********************************************************************************
* Constants:
********************************************************************************

TOTAL_TEX_SIZE = TEX_PAIR*15

SPRITE_H = 36

SMC_SIZE = TABLE_W*TABLE_H*4+2

TABLE_W = 354
TABLE_H = 130

TEX_REPT = 0
INTERLACE_ALT = 1

; Alternate horizontal scroll pos on odd/even rows to disguise chunky pixels a bit
; This reduces max window size little a bit due to copper DMA cycles
ALT = 2
PIXH = 2
DIW_W = 320
DIW_H = 204

BPLS = 4

; Chunky buffer:
CHUNKY_W = DIW_W/4
CHUNKY_H = DIW_H/PIXH

; Screen buffer:
SCREEN_W = DIW_W
SCREEN_H = DIW_H/PIXH

; Texture
TEX_W = 64
TEX_H = 48
TEX_COLORS = 16
TEX_SIZE = TEX_W*TEX_H*2
TEX_PAIR = TEX_SIZE*2                   ; Texture is repeated to allow offset scrolling

SCREEN_BW = SCREEN_W/16*2               ; byte-width of 1 bitplane line
SCREEN_BPL = SCREEN_BW*SCREEN_H         ; bitplane offset (non-interleaved)
SCREEN_SIZE = SCREEN_BW*SCREEN_H*BPLS   ; byte size of screen buffer

DIW_BW = DIW_W/16*2
DIW_SIZE = DIW_BW*DIW_H*BPLS
DIW_XSTRT = ($242-DIW_W)/2+3
DIW_YSTRT = ($158-DIW_H)/2+2            ; nneds to be +2 to align with loops
DIW_XSTOP = DIW_XSTRT+DIW_W
DIW_YSTOP = DIW_YSTRT+DIW_H-3           ; trim end for scroll


********************************************************************************
* Part vars
********************************************************************************

                STRUCTURE PartData,fw_SIZEOF
                UWORD   pd_PartCountDown
                LABEL   pd_SIZEOF


********************************************************************************
* Structs
********************************************************************************
