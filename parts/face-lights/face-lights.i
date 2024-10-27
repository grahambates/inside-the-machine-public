                ifnd    FW_DEMO_PART
CHIPMEM_SIZE = CHUNKY_SIZE*2+PLANAR_SIZE*2+SMC_SIZE+COP_SIZE+4
FASTMEM_SIZE = TOTAL_TEXTURE_SIZE+OFFSETS_SIZE*2+4
DEBUG_DETAIL    set     10
NEWAGE_DEBUG = 1
                endc
                include ../../demo/part.i

********************************************************************************
* Constants
********************************************************************************

SPRITE_SIZE = $88
SPRITE_X_OFFSET = 16
SPRITE_Y_OFFSET = 32
SPRITE_H = 32

FADE_DURATION = 32
FADE_STEPS = 16
COLORS = 32

SMC_SIZE = CHUNKY_W*CHUNKY_H*4+CHUNKY_W*CHUNKY_H/8+2
TOTAL_TEXTURE_SIZE = SCRAMBLED_TEX_SIZE*(1+SCRAMBLE_OPTS)*2
OFFSETS_SIZE = CHUNKY_W*(CHUNKY_H+1)
PLANAR_SIZE = SCREEN_SIZE*4

ALT = 0

MASK_BLANK_PX = 1
MULTI_TEX = 0
SCRAMBLE_OPTS = 1

; Display window:
DIW_W = 320
DIW_H = 180
BPLS = 4

; Screen buffer:
SCREEN_W = DIW_W
SCREEN_H = DIW_H

SCREEN_BW = SCREEN_W/8
SCREEN_SIZE = (SCREEN_H/2)*SCREEN_BW

DIW_XSTRT = $81+(320-SCREEN_W)/2
DIW_YSTRT = $2c+(256-SCREEN_H)/2
DIW_YSTOP = DIW_YSTRT+SCREEN_H
DIW_XSTOP = DIW_XSTRT+SCREEN_W

CHUNKY_W = SCREEN_W/2
CHUNKY_H = SCREEN_H/2
CHUNKY_SIZE = SCREEN_SIZE*2

TEX_W = 128
TEX_H = 128
TEX_SIZE = TEX_W*TEX_H

SCRAMBLED_TEX_SIZE = TEX_SIZE*4         ; word per byte and repeated for scroll

SIN_MASK = $7fe


********************************************************************************
* Part vars
********************************************************************************

                STRUCTURE PartData,fw_SIZEOF
                UWORD   pd_XPos
                UWORD   pd_YPos
                STRUCT  pd_Palette,32*cl_SIZEOF
                LABEL   pd_SIZEOF


********************************************************************************
* Structs
********************************************************************************
