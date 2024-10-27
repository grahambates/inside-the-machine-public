ScrambledTex:   dc.l    0
TableCode:      dc.l    0
TexOffset:      dc.w    0
TexOffset2:     dc.w    0
TexOffset3:     dc.w    0

; Tmp tables for generate
XOffsets:       dc.l    0
YOffsets:       dc.l    0
TexIdxs:        dc.l    0

                ifeq    TEX_W-128
BLANK_PX = $8000
                else
BLANK_PX = $bf00
                endc


********************************************************************************
DrawTable:
                PUSHM   a5/a6
                move.l  DrawChunky(pc),a0
                lea     CHUNKY_SIZE(a0),a0 ; Descending write

                move.l  ScrambledTex(pc),a1
                move.w  TexOffset(pc),d1

                ; Avoid using a reg
                pea     .ret
                move.l  TableCode(pc),-(sp)

; Alternate scrambled versions
                move.l  #SCRAMBLED_TEX_SIZE,d0
                lea     (a1,d0.l),a2

                ifne    SCRAMBLE_OPTS
                lea     (a2,d0.l),a3
                lea     (a3,d0.l),a4
                endc

                ifne    MULTI_TEX
                move.w  TexOffset2(pc),d2
                lea     (a2,d0.l),a3
                lea     (a3,d0.l),a4
                ifge    TEX_COUNT-2
                move.w  TexOffset3(pc),d3
                lea     (a4,d0.l),a5
                lea     (a5,d0.l),a6
                adda.w  d3,a3
                adda.w  d3,a4
                endc
                adda.w  d2,a5
                adda.w  d2,a6
                endc

                adda.w  d1,a1
                adda.w  d1,a2
                ifne    SCRAMBLE_OPTS
                adda.w  d1,a3
                adda.w  d1,a4
                endc

                ; jump to smc we set up in stack
                rts
.ret:
                POPM
                rts

********************************************************************************
; Generate table speed code from offset delta tables
; a0 - table data
;-------------------------------------------------------------------------------
GenerateTable:
                PUSHM   a0
                CALLFW  PushMemoryState
                move.l  #OFFSETS_SIZE,d0
                CALLFW  AllocFast
                move.l  a0,XOffsets

                move.l  #OFFSETS_SIZE,d0
                CALLFW  AllocFast
                move.l  a0,YOffsets

                move.l  #OFFSETS_SIZE,d0
                CALLFW  AllocFast
                move.l  a0,TexIdxs
                POPM

                PUSHM   a5/a6
; Apply deltas and write to offsets table (reversed)
                lea     CHUNKY_W*CHUNKY_H(a0),a1

                move.l  XOffsets(pc),a2
                lea     CHUNKY_W*CHUNKY_H(a2),a2
                move.l  YOffsets(pc),a3
                lea     CHUNKY_W*CHUNKY_H(a3),a3

                ifne    MULTI_TEX
                lea     CHUNKY_W*CHUNKY_H(a1),a5
                move.l  TexIdxs(pc),a4
                lea     CHUNKY_W*CHUNKY_H(a4),a4
                moveq   #0,d2
                endc

                moveq   #0,d0
                moveq   #0,d1
                move.w  #CHUNKY_W*CHUNKY_H-1,d7
.l:
                add.b   (a0)+,d0
                move.b  d0,-(a2)
                add.b   (a1)+,d1
                move.b  d1,-(a3)
                ifne    MULTI_TEX
                add.b   (a5)+,d2
                move.b  d2,-(a4)
                endc
                dbf     d7,.l

                move.l  YOffsets(pc),a0
                move.l  XOffsets(pc),a1
                ifne    MULTI_TEX
                move.l  TexIdxs(pc),a2
                endc
                move.l  TableCode(pc),a3

                move.w  #(CHUNKY_W*CHUNKY_H)/8-1,d7
.l0:
; Get 8 pixel offsets and write to temporary buffer:
                lea     .tmp,a4
                moveq   #8-1,d2
.deltaPair:
                ifne    MULTI_TEX
                move.b  (a2)+,8*2(a4)   ; tex idx
                ; move.b  #2,8*2(a4)      ; tex idx
                endc
; Write to tmp buffer:
                ifeq    TEX_W-128
; y is already shifted << 8 by virtue of being in its own byte,
; so leave as-is for 128*2 (doubled for word offset)
                move.b  (a0)+,(a4)+
; add x delta twice to double
                move.b  (a1)+,d1
                add.b   d1,d1
                move.b  d1,(a4)+
                else
                ; assume 64x64
                move.b  (a0)+,d1
                ext.w   d1
                lsl.w   #6,d1           ; * 64
                move.b  (a1)+,d3
                ext.w   d3
                add.w   d3,d1
                add.w   d1,d1           ; *2 for offset
                move.w  d1,(a4)+
                endc
                dbf     d2,.deltaPair

; Get data reg number from counter and shift << 9 to merge with op codes
                move.w  d7,d2
                add.w   d2,d2           ; (i * 2 + 1) & 7
                addq    #1,d2
                and.w   #7,d2           ; d2 = d reg index << 9
                ror.w   #7,d2

.writeInst      macro
                ifne    MULTI_TEX
                add.b   .tmpIdx+(\2+\1)*2(pc),d2
                move.w  d2,(a3)+
                sub.b   .tmpIdx+(\2+\1)*2(pc),d2
                else
                move.w  d2,(a3)+
                endc
                endm

; Macro to process 4 px from buffer
.group          macro
; Grab four pixel offsets from buffer in scrambled order
                move.w  .tmp+(0+\1)*2(pc),d3
                move.w  .tmp+(1+\1)*2(pc),d4
                move.w  .tmp+(4+\1)*2(pc),d5
                move.w  .tmp+(5+\1)*2(pc),d6

;-------------------------------------------------------------------------------
; Upper nibble:
                and.w   #$0f00,d2       ; start inst with just bits for source reg number

                ifne    MASK_BLANK_PX
                ; Zero value in first px?
                cmp.w   #BLANK_PX,d6
                bne     .notZeroUpper\@
                add.w   #$7000,d2       ; 7000 moveq #0,dN
                move.w  d2,(a3)+
                add.w   #$806a-$7000,d2 ; 806a or.w a2
                bra     .zeroUpper\@
.notZeroUpper\@:
                endc

                ifne    SCRAMBLE_OPTS
; Optimiation: Duplicate offsets?
                cmp.w   d5,d6
                bne     .noDupeUpper\@
                add.w   #$302b,d2       ; 3029 move.w a3
                move.w  d2,(a3)+
                move.w  d6,(a3)+
                bra     .endUpper\@
.noDupeUpper\@:
; Optimiation: Sequential offsets?
                move.w  d6,d0
                sub.w   d5,d0
                subq    #2,d0
                bne     .noSeqUpper\@
                add.w   #$302c,d2       ; 3029 move.w a4
                move.w  d2,(a3)+
                move.w  d6,(a3)+
                bra     .endUpper\@
.noSeqUpper\@:
                endc

; Default: OR two values
                add.w   #$3029,d2       ; 3029 move.w a1
                .writeInst \1,5
                move.w  d6,(a3)+
                add.w   #$806a-$3029,d2 ; 806a or.w a2

.zeroUpper\@:
                ifne    MASK_BLANK_PX
                ; Zero value in second px?
                cmp.w   #BLANK_PX,d5
                beq     .endUpper\@     ; no OR to do if second pix blank
                endc
                .writeInst \1,4
                move.w  d5,(a3)+
.endUpper\@:

;-------------------------------------------------------------------------------
; Lower nibble
                and.w   #$0f00,d2

                ifne    MASK_BLANK_PX
                cmp.w   #BLANK_PX,d4
                bne     .notZeroLower\@
                add.w   #$103c,d2       ; 103c move.b #0
                move.w  d2,(a3)+
                clr.w   (a3)+
                sub.w   #$103c-$802a,d2 ; 802a or.b a2
                bra     .zeroLower\@
.notZeroLower\@:
                endc

                ifne    SCRAMBLE_OPTS
; Optimiation: Duplicate offsets?
                cmp.w   d3,d4
                bne     .noDupeLower\@
                add.w   #$102b,d2       ; 102b move.b a3
                move.w  d2,(a3)+
                move.w  d4,(a3)+
                bra     .endLower\@
.noDupeLower\@:
; Optimiation: Sequential offsets?
                move.w  d4,d0
                sub.w   d3,d0
                subq    #2,d0
                bne     .noSeqLower\@
                add.w   #$102c,d2       ; 1029 move.b a4
                move.w  d2,(a3)+
                move.w  d4,(a3)+
                bra     .endLower\@
.noSeqLower\@:
                endc

; Default: OR two values
                add.w   #$1029,d2       ; 1029 move.b a1
                .writeInst \1,1
                move.w  d4,(a3)+
                sub.w   #$1029-$802a,d2 ; 802a or.b a2
.zeroLower\@:
                ifne    MASK_BLANK_PX
                cmp.w   #BLANK_PX,d3
                beq     .endLower\@
                endc
                .writeInst \1,0
                move.w  d3,(a3)+
.endLower\@:
                endm

                .group        0
                sub.w   #1<<9,d2        ; Decrement data reg number
                .group         2

; Insert movem after last register
                and.w   #$0f00,d2
                bne     .next
                move.l  #$48a0ff00,(a3)+ ; movem.w	d0-d7,-(a0)
.next:
                dbf     d7,.l0
                move.w  #$4e75,(a3)+    ; rts

                CALLFW  PopMemoryState
                POPM
                rts

.tmp:           ds.w    8
.tmpIdx:        ds.w    8
