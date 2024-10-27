                ifnd    FW_DEMO_PART
CHIPMEM_SIZE = SCREEN_SIZE*5+PAL_DATA_SIZE+4
FASTMEM_SIZE = CHUNKY_H*2+4
DEBUG_DETAIL    set     10
NEWAGE_DEBUG = 1

                printv  FASTMEM_SIZE
                endc
                include ../../demo/part.i

********************************************************************************
* Constants:
********************************************************************************

TEX_REPT = 1
BLANK_LINES = 0

; Alternate horizontal scroll pos on odd/even rows to disguise chunky pixels a bit
; This reduces max window size little a bit due to copper DMA cycles
ALT = 2

PIXH = 4
DIW_W = 320
DIW_H = 196

SPRITE_H = 209
SPRITE_W = 48

; PIXH = 3
; DIW_W = 304
; DIW_H = 180

BPLS = 4

; Chunky buffer:
CHUNKY_W = DIW_W/4
CHUNKY_H = DIW_H/PIXH

; Screen buffer:
SCREEN_W = DIW_W
SCREEN_H = DIW_H/PIXH

; Texture
TEX_W = 128
TEX_H = 128
TEX_SIZE = TEX_W*TEX_H*2

SCREEN_BW = SCREEN_W/16*2               ; byte-width of 1 bitplane line
SCREEN_BPL = SCREEN_BW*SCREEN_H         ; bitplane offset (non-interleaved)
SCREEN_SIZE = SCREEN_BW*SCREEN_H*BPLS   ; byte size of screen buffer

DIW_BW = DIW_W/16*2
DIW_SIZE = DIW_BW*DIW_H*BPLS
DIW_XSTRT = ($242-DIW_W)/2
DIW_YSTRT = ($158-DIW_H)/2
DIW_XSTOP = DIW_XSTRT+DIW_W
DIW_YSTOP = DIW_YSTRT+DIW_H

SIN_LEN = 1024
SIN_POW = 14
SIN_AMP = 1<<SIN_POW
SIN_MASK = SIN_LEN-1

                printv  DIW_YSTRT
                printv  DIW_XSTRT

DIST = 800

PAL_COLORS = 16
PAL_STEPS = 16
PAL_DATA_SIZE = PAL_STEPS*PAL_COLORS*2

********************************************************************************
* Part vars
********************************************************************************

                STRUCTURE PartData,fw_SIZEOF
                LABEL   pd_SIZEOF


********************************************************************************
* Structs
********************************************************************************
