                ifnd    FW_DEMO_PART
CHIPMEM_SIZE = CHUNKY_SIZE*2+PLANAR_SIZE*2+SMC_SIZE+4
FASTMEM_SIZE = TOTAL_TEXTURE_SIZE+OFFSETS_SIZE*3+COLORS*FADE_STEPS*2+FADE_STEPS*4+4
DEBUG_DETAIL    set     10
NEWAGE_DEBUG = 1
                endc
                include ../../demo/part.i

********************************************************************************
* Constants
********************************************************************************

SPRITE1_H = 54
SPRITE2_X = 350
SPRITE2_Y = 137
SPRITE2_H = 29

FADE_DURATION = 64
FADE_STEPS = 16
COLORS = 16
SPRITE_FRAMES = 25
CHROME_COLS = 15

MASK_BLANK_PX = 0
TEX_COUNT = 3
MULTI_TEX = 1

SMC_SIZE = CHUNKY_W*CHUNKY_H*4+CHUNKY_W*CHUNKY_H/8+2
TOTAL_SCRAMBLED_SIZE = SCRAMBLED_TEX_SIZE*(1+SCRAMBLE_OPTS)*2
TOTAL_TEXTURE_SIZE = TOTAL_SCRAMBLED_SIZE*TEX_COUNT
OFFSETS_SIZE = CHUNKY_W*(CHUNKY_H+1)
PLANAR_SIZE = SCREEN_SIZE*4

ALT = 0

SCRAMBLE_OPTS = 0

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

TEX_W = 64
TEX_H = 64
TEX_SIZE = TEX_W*TEX_H

SCRAMBLED_TEX_SIZE = TEX_SIZE*4         ; word per byte and repeated for scroll

SIN_MASK = $7fe


********************************************************************************
* Part vars
********************************************************************************

                STRUCTURE PartData,fw_SIZEOF
                STRUCT  pd_Palette,COLORS*cl_SIZEOF
                LABEL   pd_SIZEOF


********************************************************************************
* Structs
********************************************************************************
