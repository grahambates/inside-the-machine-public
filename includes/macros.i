                ifnd    MACROS_I
MACROS_I        set     1

                ifnd    PROFILE
PROFILE = 0
                endc

PROFILE_BG:     macro
                ifne    PROFILE
                move.w  #\1,$dff180
                endc
                endm

********************************************************************************
* Blitter
********************************************************************************

WAIT_BLIT       macro
; tst.w	(a6)					;for compatibility with A1000
.\@:            btst    #DMAB_BLTDONE,dmaconr(a6)
                bne.s   .\@
                endm

********************************************************************************
* Fixed point
********************************************************************************

I2FP16          macro
                swap    \1
                clr.w   \1
                endm

********************************************************************************
; Fixed point to integer (15)
; \1 - Fixed point value (mutated)
;-------------------------------------------------------------------------------
FP2I15          macro
                add.l   \1,\1
                swap    \1
                endm

FP2I15R         macro
                add.l   \1,\1
                add.l   #$8000,\1
                swap    \1
                endm

********************************************************************************
; Fixed point to integer (14)
; \1 - Fixed point value (mutated)
;-------------------------------------------------------------------------------
FP2I14          macro
                lsl.l   #2,\1
                swap    \1
                endm

********************************************************************************
; Fixed point to integer (8)
; \1 - Fixed point value (mutated)
;-------------------------------------------------------------------------------
FP2I8           macro
                lsr.l   #8,\2
                endm


FPMULS15        macro
                muls.w  \1,\2
                FP2I15  \2
                endm

FPMULS15_16     macro
                muls.w  \1,\2
                add.l   \2,\2
                endm

FPMULS15R       macro
                muls.w  \1,\2
                FP2I15R \2
                endm

FPMULU15        macro
                mulu.w  \1,\2
                FP2I15  \2
                endm

FPMULS14        macro
                muls.w  \1,\2
                FP2I14  \2
                endm

FPMULU14        macro
                mulu.w  \1,\2
                FP2I14  \2
                endm

FPMULS8         macro
                muls    \1,\2
                asr.l   #8,\2
                endm

FPMULU8         macro
                mulu    \1,\2
                lsr.l   #8,\2
                endm


********************************************************************************
; Copper
********************************************************************************

;--------------------------------------------------------------------------------
; Copper instruction data

COP_MOVE:       macro
                dc.w    (\2)&$1fe,\1
                endm

COP_WAIT:       macro
                dc.w    (((\1)&$ff)<<8)+((\2)&$fe)+1,$fffe
                endm

COP_WAITV:      macro
                COP_WAIT \1&$ff,4
                endm

COP_WAITH:      macro
                dc.w    ((\1&$80)<<8)+(\2&$fe)+1,$80fe
                endm

COP_WAITBLIT:   macro
                dc.l    $10000
                endm

COP_SKIP:       macro
                dc.w    (((\1)&$ff)<<8)+((\2)&$fe)+1,$ffff
                endm

COP_SKIPV:      macro
                COP_SKIP \1,4
                endm

COP_SKIPH:      macro
                dc.w    (((\1)&$80)<<8)+((\2)&$fe)+1,$80ff
                endm

COP_NOP:        macro
                COP_MOVE 0,$1fe
                endm

COP_END:        macro
                dc.l    $fffffffe
                endm

;--------------------------------------------------------------------------------
; Copper write to buffer:

COPW_WAITBLIT   macro
                move.l  #$10000,(a0)+
                endm

COPW_END        macro
                move.l  #-2,(a0)+
                endm

COPW_MOVEI      macro
                move.l  #(\2<<16)!\1,(a0)+
                endm

COPW_MOVEW      macro
                move.w  #\2,(a0)+
                move.w  \1,(a0)+
                endm

COPW_NOP        macro
                move.l  #$1fe<<16,(a0)+
                endm


********************************************************************************
; Write hi/lo pair to copper
;-------------------------------------------------------------------------------
SET_COP_PTR     macro
                move.w  \1,6(\2)
                swap    \1
                move.w  \1,2(\2)
                swap    \1
                add.l   #8,\2
                endm

********************************************************************************
* Clamping
********************************************************************************
CLAMP_MIN_W     macro
                cmp.w   \1,\2
                bge     .noClamp\@
                move.w  \1,\2
.noClamp\@:
                endm

CLAMP_MAX_W     macro
                cmp.w   \1,\2
                ble     .noClamp\@
                move.w  \1,\2
.noClamp\@:
                endm

                endif                   ; MACROS_I
