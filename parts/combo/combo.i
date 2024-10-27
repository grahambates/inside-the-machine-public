                ifnd    FW_DEMO_PART
CHIPMEM_SIZE = SCREEN_SIZE*4+1024+SCREEN_BPL*2+SMC_SIZE+8
FASTMEM_SIZE = TRANSFORMED_SIZE+TABLE_TEX_SIZE+8
DEBUG_DETAIL    set     10
NEWAGE_DEBUG = 1
                endc
                include ../../demo/part.i

********************************************************************************
* Constants:
********************************************************************************

SMC_SIZE = MAX_TABLE_SIZE+1             ; Actual allocation is dynamic
TRANSFORMED_SIZE = (MAX_VERTS*Vec2_SIZEOF)*2 ; vertices and normals

TABLE_TEX_SIZE = TEX_PAIR*(SHADES+3)    ; original + shades

TEX_REPT = 0

VCLIPPING = 0
MAX_VERTS = 100
OBJECT_BOUNDS = 0

Y_SPEED = 12
Z_SPEED = 28
DIST = 450

; Alternate horizontal scroll pos on odd/even rows to disguise chunky pixels a bit
; This reduces max window size little a bit due to copper DMA cycles

POS_FADE = 0
BLANK_LINES = 0
INTERLACE = 0
;
; ALT = 0
; PIXH = 3
; DIW_W = 320
; DIW_H = 180

ALT = 1
PIXH = 4
DIW_W = 320
DIW_H = 196

BPLS = 4

; Chunky buffer:
CHUNKY_W = DIW_W/4
CHUNKY_H = DIW_H/PIXH

MAX_TABLE_SIZE = 110*70*4

; Screen buffer:
SCREEN_W = DIW_W
SCREEN_H = DIW_H/PIXH

; Texture
TEX_W = 64
TEX_H = 64
TEX_SIZE = TEX_W*TEX_H*2
TEX_PAIR = TEX_SIZE*2                   ; Texture is repeated to allow offset scrolling

SHADES = 14                             ; excluding zero (black) and original

SCREEN_BW = SCREEN_W/16*2               ; byte-width of 1 bitplane line
SCREEN_BPL = SCREEN_BW*SCREEN_H         ; bitplane offset (non-interleaved)
SCREEN_SIZE = SCREEN_BW*SCREEN_H*BPLS   ; byte size of screen buffer

DIW_BW = DIW_W/16*2
DIW_SIZE = DIW_BW*DIW_H*BPLS
DIW_XSTRT = ($242-DIW_W)/2
DIW_YSTRT = ($158-DIW_H)/2
DIW_XSTOP = DIW_XSTRT+DIW_W
DIW_YSTOP = DIW_YSTRT+DIW_H


********************************************************************************
* Part vars
********************************************************************************

                STRUCTURE PartData,fw_SIZEOF
                LABEL   pd_SIZEOF


********************************************************************************
* Structs
********************************************************************************
