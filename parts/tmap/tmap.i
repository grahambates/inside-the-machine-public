                ifnd    FW_DEMO_PART
CHIPMEM_SIZE = SCREEN_SIZE*4+SCREEN_SIZE*SCREEN_BUFFERS+SCREEN_BPL*4+SCREEN_BPL*2+COP_SIZE+4
FASTMEM_SIZE = GEO_SIZE+TRANSFORMED_SIZE*2+4
DEBUG_DETAIL    set     80
NEWAGE_DEBUG = 1
                endc

                include ../../demo/part.i


********************************************************************************
* Constants:
********************************************************************************

; Wait until this many frames are ready before starting display
PREFILL_FRAMES = 10

GEO_SIZE = Geo_SIZEOF*SCREEN_BUFFERS
TRANSFORMED_SIZE = MAX_VERTS*Vec2_SIZEOF

TEX_REPT = 1

LIMIT_FRAMERATE = 1


VCLIPPING = 1
MAX_VERTS = 100
OBJECT_BOUNDS = 1

; Alternate horizontal scroll pos on odd/even rows to disguise chunky pixels a bit
; This reduces max window size little a bit due to copper DMA cycles
ALT = 2
INTERLACE_ALT = 0

PIXH = 4
DIW_W = 320
DIW_H = 196

Y_SPEED = 17*2
Z_SPEED = 10*2
DIST = 320+512

SCREEN_BUFFERS = 20 

BPLS = 4

;-------------------------------------------------------------------------------

; Chunky buffer:
CHUNKY_W = DIW_W/4
CHUNKY_H = DIW_H/PIXH

; Screen buffer:
SCREEN_W = DIW_W
SCREEN_H = DIW_H/PIXH

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


********************************************************************************
* Part vars
********************************************************************************

                STRUCTURE PartData,fw_SIZEOF
                UWORD   pd_PartCountDown
                LABEL   pd_SIZEOF


********************************************************************************
* Structs
********************************************************************************

                rsreset
Geo_W           rs.w    1
Geo_H           rs.w    1
Geo_X           rs.w    1
Geo_Y           rs.w    1
Geo_TexX        rs.w    1
Geo_TexY        rs.w    1
Geo_SIZEOF      rs.b    0
