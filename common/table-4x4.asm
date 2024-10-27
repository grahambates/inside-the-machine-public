********************************************************************************
DrawTable:
                movem.l a5/a6,-(sp)
                move.l  Texture(pc),a1

; Texture offset
                movem.w TexX(pc),d0-d1
                add.w   d0,d0
                lsl.w   #7,d1           ; *TEX_W*2
                add.w   d1,d0
                and.w   #TEX_SIZE-1,d0
                adda.w  d0,a1

                move.w  fw_FrameCounter(a6),d7
                move.l  Smc,a6

                tst.l   PanXAmt
                beq     .noPan
; Pan:
; Add x/y offsets to entry point of SMC
                movem.w PanX(pc),d0-d1
                movem.w PanXAmt(pc),d2-d3

                ifne    INTERLACE
                btst    #0,d7
                beq     .odd
                addq.w  #2,d1
.odd:
                endc

                ; Clamp to prevent overflow
                CLAMP_MIN_W #0,d0
                CLAMP_MIN_W #0,d1
                CLAMP_MAX_W d2,d0
                CLAMP_MAX_W d3,d1

                asr.w   #2,d0           ; x/4 for chunky pixels
                ifne    INTERLACE
                asr.w   #1,d1           ; y/(PIXH/2)
                else
                asr.w   #2,d1           ; y/PIXH
                endc
                
                muls    TableW(pc),d1
                ext.l   d0
                add.l   d0,d1
                lsl.l   #2,d1           ; *4 for code offset
                adda.l  d1,a6


; The generated code contains intructions to write lines much longer than the chunky buffer
; We need to add jmp instructions to apply a modulo and skip the necessary number of moves
; The original instructions we overwrite need to be backed up and restored
                lea     CHUNKY_W*4(a6),a2 ; end of first line
                move.w  #$6000,d0
                swap    d0
                move.w  #-CHUNKY_W*4-2,d0
                move.w  TableWx4(pc),d1
                ifne    INTERLACE
                add.w   d1,d1           ; double for interlace
                endc
                add.w   d1,d0
                move.w  #CHUNKY_H-2,d7
.l:
; TODO: optimal unroll
; rept	CHUNKY_H-1
                move.l  (a2),-(sp)      ; backup instruction
                move.l  d0,(a2)         ; write bra
                adda.w  d1,a2
; endr
                dbf     d7,.l
; Also need to add an rts to return once enough lines have been written
                move.l  (a2),-(sp)      ; backup instruction
                move.w  #$4e75,(a2)     ; write rts

                move.l  a2,-(sp)        ; backup restore ptr
.noPan:

; Shade offsets:
; Each register allows offsets +-1 TEX_PAIR, allowing access to 3 shades
; 5 registers give us access to all 15 shades
; See: InitDrawCode

                moveq   #$f,d6
                move.w  Fade(pc),d5
                ifeq    POS_FADE
                CLAMP_MAX_W #15,d5
                endc
                sub.w   d5,d6
; muls	#TEX_PAIR,d6	; fade offset
                swap    d6              ; opt
                clr.w   d6
                asr.l   #2,d6

; Minimum allowed offset, clamp to this later
; lowest offset in each register is -TEX_PAIR
                move.l  a1,d2
                add.l   #TEX_PAIR,d2

                sub.l   d6,a1
                move.l  #TEX_PAIR*3,d1
                lea     (a1,d1.l),a1
                lea     (a1,d1.l),a2
                lea     (a2,d1.l),a3
                lea     (a3,d1.l),a4
                lea     (a4,d1.l),a5

; Clamp min/max offsets
.fade           macro
                cmp.l   d2,\1
                bge     .minOk
                move.l  d2,\1
                endm
                .fade          a1
                .fade          a2
                .fade          a3
                .fade          a4
                .fade          a5
.minOk:
;
                ifne    POS_FADE
; Max offset
                add.l   #TEX_PAIR*16,d2
.fadeMax        macro
                cmp.l   d2,\1
                ble     .maxOk
                move.l  d2,\1
                endm
                .fadeMax       a5
                .fadeMax       a4
                .fadeMax       a3
                .fadeMax       a2
                .fadeMax       a1
.maxOk:
                endc

                move.l  DrawChunky(pc),a0
                move.w  BGCol(pc),d0
                jsr     (a6)            ; jump into SMC

                tst.l   PanXAmt
                beq     .noPan2
; Restore the backed up instructions we put on the stack
                move.l  (sp)+,a2
                move.w  TableWx4(pc),d1
                ifne    INTERLACE
                add.w   d1,d1           ; double for interlace
                endc
                move.w  #CHUNKY_H-1,d7
.l1:
                ; rept    CHUNKY_H
                move.l  (sp)+,(a2)      ; restore from bra
                suba.w  d1,a2
                ; endr
                dbf     d7,.l1

.noPan2:
                movem.l (sp)+,a5/a6
                rts


********************************************************************************
TableVars:
TableW:         dc.w    0
TableH:         dc.w    0
PanXAmt:        dc.w    0
PanYAmt:        dc.w    0
TableWx4:       dc.w    0

Fade:           dc.w    0
TexX:           dc.w    0
TexY:           dc.w    0

DrawPan:
PanX:           dc.w    0
PanY:           dc.w    0
ViewPan:        
ViewPanX:       dc.w    0
ViewPanY:       dc.w    0

********************************************************************************
; a0 - table struct
;-------------------------------------------------------------------------------
InitTable:
                moveq   #0,d0
                moveq   #0,d1
                move.b  (a0)+,d0        ; w
                move.b  (a0)+,d1        ; h
                lea     TableVars(pc),a1
                move.w  d0,TableW-TableVars(a1)
                move.w  d1,TableH-TableVars(a1)

                move.w  d0,d2
                mulu    d1,d2           ; delta table size (for each u,v,shade)

                ; Calculate pan ammount
                lsl.w   #2,d0           ; TableW * 4
                ifne    INTERLACE
                add.w   d1,d1           ; TableH * 2
                else
                lsl.w   #2,d1           ; TableH * 4
                endc
                move.w  d0,TableWx4-TableVars(a1) ; width in real pixels
                sub.w   #CHUNKY_W*4,d0  ; PanXAmt 
                sub.w   #CHUNKY_H*PIXH,d1 ; PanYAmt 
                move.w  d0,PanXAmt-TableVars(a1)
                move.w  d1,PanYAmt-TableVars(a1)
                rts


********************************************************************************
; Generates SMC for draw routine from table data
;-------------------------------------------------------------------------------
; a0 - Table deltas 
; a3 - SMC destination
;-------------------------------------------------------------------------------
GenerateTable:
                bsr     InitTable

                ; a0 = u deltas
                lea     (a0,d2),a1      ; v deltas
                lea     (a1,d2),a2      ; shade deltas
                lea     .shadeLut(pc),a4
                move.w  d2,d7
                moveq   #0,d0
                moveq   #0,d1
                moveq   #0,d2
                move.l  #$30e80000,d4   ; move.w OFFSET(aN),(a0)+

; special case for shade zero
; needs to be same length as move for panning to work
                move.l  #$30c04e71,d5   ; move.w d0,(a0)+, nop

;-------------------------------------------------------------------------------
; Code for rept loop
.loopItem       macro
                add.b   (a0)+,d0        ; apply deltas
                add.b   (a1)+,d1

; Add texture offset to instruction template
                move.l  d4,d3           ; move.w OFFSET(aN),(a0)+
                move.b  d1,d3
                lsl.w   #6,d3           ; *TEX_W
                add.w   d0,d3
                add.w   d3,d3

; Add shade:
                add.b   (a2)+,d2
                ifeq    POS_FADE
; special case for shade zero
                bne     .notZero\@
                move.l  d5,(a3)+        ; move.w d0,(a0)+ nop
                bra     .endLoop\@
.notZero\@:
                endc
; Lookup register number and additional offset required for shade.
                add.l   (a4,d2.w),d3

                move.l  d3,(a3)+        ; write instruction
.endLoop\@:
                endm
;-------------------------------------------------------------------------------

; Unrolled loop:
; The plan is to use this in background task to prepare the next effect, so need to optimise
.unrollPow = 3                          ; needs to be a factor of table size
                lsr.w   #.unrollPow,d7
                subq    #1,d7
.l:             rept    1<<.unrollPow
                .loopItem
                endr
                dbf     d7,.l
                move.w  #$4e75,(a3)+    ; write rts
                rts

; Register number and offset for each shade (excluding zero)
.shadeLut:
; 3 shades per reg
                dc.w    1,-TEX_PAIR     ; 1
                dc.w    1,0             ; 2
                dc.w    1,TEX_PAIR      ; 3
                dc.w    2,-TEX_PAIR     ; 4
                dc.w    2,0             ; 5
                dc.w    2,TEX_PAIR      ; 6
                dc.w    3,-TEX_PAIR     ; 7
                dc.w    3,0             ; 8
                dc.w    3,TEX_PAIR      ; 9
                dc.w    4,-TEX_PAIR     ; 10
                dc.w    4,0             ; 11
                dc.w    4,TEX_PAIR      ; 12
                dc.w    5,-TEX_PAIR     ; 13
                dc.w    5,0             ; 14
                dc.w    5,TEX_PAIR      ; 15
                dc.w    5,TEX_PAIR      ; TODO: why is this needed?


; Uee movem trick to clear bytes:
; 8 blank regs * 4 bytes
; = 32 bytes written on each iteration, descending
BYTES_PER_ITERATION = 8*4

********************************************************************************
; Clear blank space at start of texture
; (3 texture pairs)
;-------------------------------------------------------------------------------
ClearTextureBlank:
                add.l   #TEX_PAIR*3,a1
                move.l  a1,a2

                move.l  d0,d1          
                move.l  d0,d2
                move.l  d0,d3
                move.l  d0,d4
                move.l  d0,d5
                move.l  d0,d6
                move.l  d0,a4
                move.w  #(TEX_PAIR*3)/BYTES_PER_ITERATION-1,d7
.c:             
                movem.l d0-d6/a4,-(a2)
                dbf     d7,.c
                rts


********************************************************************************
; Creates shade variants of texture, scrambles and repeats
; Fade from black to original colour
;-------------------------------------------------------------------------------
; a0 - src
; a1 - dest
;-------------------------------------------------------------------------------
InitTextureBlack:
                moveq   #0,d0
                bsr     ClearTextureBlank

                move.l  a0,a5
                move.l  a1,a4
                moveq   #SHADES-1,d7
.f:
                move.l  a5,a0
                move.l  a4,a1
                lea     RGBTblBlack,a2
                moveq   #SHADES,d0
                sub.w   d7,d0
                bsr     FadeRGBScrambled
                lea     TEX_PAIR(a4),a4
                dbf     d7,.f
                rts


********************************************************************************
; Creates shade variants of texture, scrambles and repeats
; Fade from white to original colour
;-------------------------------------------------------------------------------
; a0 - src
; a1 - dest
;-------------------------------------------------------------------------------
InitTextureWhite:
; Clear blank space
                move.w  #$ffff,d0
                bsr     ClearTextureBlank

                move.l  a0,a5
                move.l  a1,a4
                moveq   #SHADES-1,d7
.f:
                move.l  a5,a0
                move.l  a4,a1
                lea     RGBTblWhite,a2
                moveq   #SHADES,d0
                sub.w   d7,d0
                bsr     FadeRGBScrambled
                lea     TEX_PAIR(a4),a4
                dbf     d7,.f
                rts


********************************************************************************
; Creates shade variants of texture, scrambles and repeats
; Fade from black to original colour to white
;-------------------------------------------------------------------------------
; a0 - src
; a1 - dest
;-------------------------------------------------------------------------------
InitTextureBlackToWhite:
; Clear blank space
                moveq   #0,d0
                bsr     ClearTextureBlank

                ; offsets for R,G,B component tables combined with bytes values for LUT
                moveq   #0,d1
                move.w  #RGB_TBL_SIZE,d2 
                move.w  #RGB_TBL_SIZE*2,d3

                move.w  #2<<5,d6        ; amount to increment table for shade
                move.l  a0,d5           ; store start of RGB data

                lea     RGBTblBlack+(2<<5),a2
                lea     RGBTblWhite+(13<<5),a3
                moveq   #SHADES/2-1,d7
.f:
                move.l  d5,a0
                lea     TEX_SIZE(a1),a4
                move.l  a1,a5
                adda.l  #TEX_PAIR*(SHADES/2),a5
                lea     TEX_SIZE(a5),a6

.unroll         equ     16
                move.w  #TEX_W*TEX_H/.unroll-1,d0
.l:             rept    .unroll
                move.b  (a0)+,d1        ; r
                move.b  (a0)+,d2        ; g
                move.b  (a0)+,d3        ; b
                ; black
                move.w  (a2,d1.w),d4
                or.w    (a2,d2.w),d4
                or.w    (a2,d3.w),d4
                move.w  d4,(a1)+
                move.w  d4,(a4)+
                ; white
                move.w  (a3,d1.w),d4
                or.w    (a3,d2.w),d4
                or.w    (a3,d3.w),d4
                move.w  d4,(a5)+
                move.w  d4,(a6)+
                endr
                dbf     d0,.l

                adda.w  d6,a2
                suba.w  d6,a3
                adda.w  #TEX_SIZE,a1
                adda.w  #TEX_SIZE,a5
                dbf     d7,.f

                move.l  a5,a1           ; set a1 to end for ClearTextureBlank


                ifne    POS_FADE
                moveq   #-1,d0
                bra     ClearTextureBlank
                endc

                rts

********************************************************************************
; Creates shade variants of texture, scrambles and repeats
; Fade from white to original colour to black
;-------------------------------------------------------------------------------
; a0 - src
; a1 - dest
;-------------------------------------------------------------------------------
InitTextureBlackToWhite2:
; Clear blank space
                moveq   #0,d0
                bsr     ClearTextureBlank

                move.l  a0,a5
                move.l  a1,a4
                moveq   #SHADES/2-1,d7
.f:
                move.l  a5,a0
                move.l  a4,a1
                lea     RGBTblBlack,a2
                moveq   #SHADES,d0
                sub.w   d7,d0
                sub.w   d7,d0
                bsr     FadeRGBScrambled
                lea     TEX_PAIR(a4),a4
                dbf     d7,.f

                moveq   #SHADES/2-1,d7
.f1:
                move.l  a5,a0
                move.l  a4,a1
                lea     RGBTblWhite,a2
                move.w  d7,d0
                add.w   #8,d0
                bsr     FadeRGBScrambled
                lea     TEX_PAIR(a4),a4
                dbf     d7,.f1

                ifne    POS_FADE
                moveq   #-1,d0
                bsr     ClearTextureBlank
                endc

                rts


********************************************************************************
; Creates shade variants of texture, scrambles and repeats
; Fade from white to original colour to black
;-------------------------------------------------------------------------------
; a0 - src
; a1 - dest
;-------------------------------------------------------------------------------
InitTextureWhiteToBlack:
; Clear blank space
                moveq   #-1,d0
                bsr     ClearTextureBlank

                move.l  a0,a5
                move.l  a1,a4
                moveq   #SHADES/2-1,d7
.f:
                move.l  a5,a0
                move.l  a4,a1
                lea     RGBTblWhite,a2
                moveq   #SHADES,d0
                sub.w   d7,d0
                sub.w   d7,d0
                bsr     FadeRGBScrambled
                lea     TEX_PAIR(a4),a4
                dbf     d7,.f

                moveq   #SHADES/2-1,d7
.f1:
                move.l  a5,a0
                move.l  a4,a1
                lea     RGBTblBlack,a2
                move.w  d7,d0
                add.w   d0,d0
                bsr     FadeRGBScrambled
                lea     TEX_PAIR(a4),a4
                dbf     d7,.f1

                ifne    POS_FADE
                moveq   #0,d0
                bsr     ClearTextureBlank
                endc

                rts


********************************************************************************
; Populate multiplication LUTs for RGB fade
;-------------------------------------------------------------------------------
InitFadeRGBScrambled:
                lea     RGBTblR,a0
                lea     RGBTblG,a1
                lea     RGBTblB,a2
                lea     RGBTblRW,a3
                lea     RGBTblGW,a4
                lea     RGBTblBW,a5
                lea     RGBTbl,a6

                moveq   #0,d2           ; step size (FP8)
                move.w  #$f*2,d5        ; white value
                moveq   #16-1,d0
.y:             moveq   #0,d3           ; value (always start at zero)
                moveq   #16-1,d1
.x:             move.w  d3,d4
                add.w   #$88,d4         ; round, not floor
                lsr.w   #8,d4           ; rgb component 0-f
                move.b  d4,(a6)+
                add.w   d4,d4

                move.w  .red(pc,d4.w),(a0)+
                move.w  .green(pc,d4.w),(a1)+
                move.w  .blue(pc,d4.w),(a2)+

                add.w   d5,d4
; look up scrambled values per channel
                move.w  .red(pc,d4.w),(a3)+
                move.w  .green(pc,d4.w),(a4)+
                move.w  .blue(pc,d4.w),(a5)+

                add.w   d2,d3           ; increment value
                dbf     d1,.x
                add.w   #$11,d2         ; increment step size per row
                sub.w   #$2,d5
                dbf     d0,.y
                rts

.red:           dc.w    $0000,$0008,$0080,$0088,$0800,$0808,$0880,$0888,$8000,$8008,$8080,$8088,$8800,$8808,$8880,$8888
.green:         dc.w    $0000,$0004,$0040,$0044,$0400,$0404,$0440,$0444,$4000,$4004,$4040,$4044,$4400,$4404,$4440,$4444
.blue:          dc.w    $0000,$0003,$0030,$0033,$0300,$0303,$0330,$0333,$3000,$3003,$3030,$3033,$3300,$3303,$3330,$3333


;   fff-0
; + 0-val


********************************************************************************
; Fade texture from black to original - combined with scramble op
;-------------------------------------------------------------------------------
; a0 - Source
; a1 - Dest
; a2 - Table (black/white)
; d0.w - shade 0-15 (only useful for 1-14)
;-------------------------------------------------------------------------------
FadeRGBScrambled:
                lea     RGB_TBL_SIZE(a2),a3
                lea     RGB_TBL_SIZE(a3),a6
                lsl.w   #5,d0
                lea     (a2,d0.w),a2    ; Move to row in LUTs for fade value
                lea     (a3,d0.w),a3
                lea     (a6,d0.w),a6
                moveq   #0,d1
.unroll         equ     16
                move.w  #TEX_W*TEX_H/.unroll-1,d0
.l:             rept    .unroll
                move.b  (a0)+,d1        ; r
                move.w  (a2,d1.w),d3
                move.b  (a0)+,d1        ; g
                or.w    (a3,d1.w),d3
                move.b  (a0)+,d1        ; b
                or.w    (a6,d1.w),d3
                move.w  d3,TEX_SIZE(a1)
                move.w  d3,(a1)+
                endr
                dbf     d0,.l
                rts
