                ifnd    FW_DEMO_PART
CHIPMEM_SIZE = SCREEN_SIZE*4+SMC_SIZE+4
FASTMEM_SIZE = TEXTURE_SIZE+4

DEBUG_DETAIL    set     10
NEWAGE_DEBUG = 1
                endc
                include ../../demo/part.i

********************************************************************************
* Constants
********************************************************************************

GENERATE_TABLE = 1

SMC_SIZE = MAX_TABLE_SIZE+1             ; Actual allocation is dynamic
MAX_TABLE_SIZE = 150*110*4

;-------------------------------------------------------------------------------
; Texture

TEX_W = 64
TEX_H = 64
TEX_SIZE = TEX_W*TEX_H*2
TEX_PAIR = TEX_SIZE*2                   ; Texture is repeated to allow offset scrolling

POS_FADE = 1
SHADES = 14                             ; excluding zero (black) and original

; SHADES+4 if don't need >15 fade
; 3*min
; 14*shades
; 3*max
; TODO: only need 2*min if POS_FADE==0, but need to adjust implementation
TEXTURE_SIZE = TEX_PAIR*(SHADES+4+(POS_FADE*2))

RGB_TBL_SIZE = 16*16*2

;-------------------------------------------------------------------------------
; Sprite

SPRITE_FRAMES = 31
SPRITE_H = 80
SPRITE_X = 280
SPRITE_Y = 110

CHROME_COLS = 15

TEX_REPT = 1


;-------------------------------------------------------------------------------
; Chunky display:

ALT = 2
PIXH = 4
INTERLACE = 1
INTERLACE_ALT = 1
CHUNKY_W = DIW_W/4
CHUNKY_H = DIW_H/PIXH

;-------------------------------------------------------------------------------
; Screen buffer:

BPLS = 4
DIW_W = 320
DIW_H = 196

SCREEN_W = DIW_W
SCREEN_H = DIW_H/PIXH

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
                LABEL   pd_SIZEOF


********************************************************************************
* Structs
********************************************************************************
