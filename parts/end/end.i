                ifnd    FW_DEMO_PART
CHIPMEM_SIZE = 0
FASTMEM_SIZE = 0
DEBUG_DETAIL    set     10
NEWAGE_DEBUG = 1
                endc
                include ../../demo/part.i

********************************************************************************
* Constants
********************************************************************************

FADE_DURATION = 32

; Display window:
DIW_W = 128
DIW_H = 128
BPLS = 3
SCROLL = 0                              ; enable playfield scroll
INTERLEAVED = 1
DPF = 0                                 ; enable dual playfield

; Screen buffer:
SCREEN_W = DIW_W
SCREEN_H = DIW_H

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
                LABEL   pd_SIZEOF


********************************************************************************
* Structs
********************************************************************************
