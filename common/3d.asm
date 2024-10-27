                include 3d.i

SHADE_SHIFT = 5
RECIP_RANGE_NEG = 100
RECIP_RANGE_POS = 2000

OBJTEX_W = 128
OBJTEX_H = 128
OBJTEX_SIZE = OBJTEX_W*OBJTEX_H*2


********************************************************************************
; a0 - Object
; a1 - transformed verts buffer
; a2 - transformed norms buffer
; a3 - texture
;-------------------------------------------------------------------------------
LoadObject:
                lea     ObjectLoaded(pc),a4

                move.l  a1,ObjectTransformed-ObjectLoaded(a4)
                move.l  a2,ObjectNormsTransformed-ObjectLoaded(a4)
                move.l  a3,ObjectTexture-ObjectLoaded(a4)
                move.l  a3,ObjectTexturePos-ObjectLoaded(a4) ; init offset 0

                move.w  Obj_Type(a0),ObjectType-ObjectLoaded(a4)

                move.w  Obj_Faces(a0),d0
                lea     (a0,d0),a1
                move.w  Obj_Verts(a0),d0
                lea     (a0,d0),a2
                move.w  Obj_Norms(a0),d0
                sub.l   a3,a3
                beq     .noNorms
                lea     (a0,d0),a3
.noNorms:
                movem.l a1-a3,(a4)
                rts


;-------------------------------------------------------------------------------
ObjectLoaded:
ObjectFaces:    dc.l    0
ObjectVerts:    dc.l    0
ObjectNorms:    dc.l    0
ObjectTransformed: 
                dc.l    0
ObjectNormsTransformed: 
                dc.l    0
ObjectTexture:  dc.l    0
ObjectTexturePos: dc.l  0
ObjectType:     dc.w    0

Angles:         ds.w    2
Dist:           dc.w    DIST

********************************************************************************
; d0 - X offset
; d1 - Y offset
;-------------------------------------------------------------------------------
OffsetObjectTexture:
                move.l  ObjectTexture(pc),a0
                and.w   #OBJTEX_W-1,d0
                add.w   d0,d0
                lsl.w   #8,d1           ; *OBJTEX_W*2
                add.w   d1,d0
                and.w   #OBJTEX_SIZE-1,d0
                adda.w  d0,a0
                move.l  a0,ObjectTexturePos
                rts


********************************************************************************
DrawObject:
                move.w  ObjectType(pc),d0
                btst    #OBJTYPE_QUAD_B,d0
                beq     .tri
; quads
                btst    #OBJTYPE_NORM_B,d0
                bne     DrawObjectQuadNorm
                btst    #OBJTYPE_SHADE_B,d0
                bne     DrawObjectQuadShade
                bra     DrawObjectQuad
.tri:
                btst    #OBJTYPE_NORM_B,d0
                bne     DrawObjectTriNorm
                btst    #OBJTYPE_SHADE_B,d0
                bne     DrawObjectTriShade

********************************************************************************
DrawObjectTri:
                move.l  ObjectFaces(pc),a0
                move.w  (a0)+,d0
.l:
                movem.l d0/a0,-(sp)

; Read vertex data
                lea     TV_SIZEOF(a0),a1
                lea     TV_SIZEOF(a1),a2
                move.w  TV_VertOffs(a2),d0
                move.l  ObjectTransformed(pc),a3
                lea     (a3,d0.w),a5
                move.w  TV_VertOffs(a1),d0
                lea     (a3,d0.w),a4
                move.w  TV_VertOffs(a0),d0
                lea     (a3,d0.w),a3

                bsr     DotProduct
                bge     .skip

                bsr     DrawTri

.skip:
                movem.l (sp)+,d0/a0
                lea     TV_SIZEOF*3(a0),a0
                dbf     d0,.l

                rts


********************************************************************************
DrawObjectTriShade:
                move.l  ObjectFaces(pc),a0
                move.w  (a0)+,d0
.l:
                movem.l d0/a0,-(sp)

; Read vertex data
                lea     TV_SIZEOF(a0),a1
                lea     TV_SIZEOF(a1),a2
                move.w  TV_VertOffs(a2),d0
                move.l  ObjectTransformed(pc),a3
                lea     (a3,d0.w),a5
                move.w  TV_VertOffs(a1),d0
                lea     (a3,d0.w),a4
                move.w  TV_VertOffs(a0),d0
                lea     (a3,d0.w),a3

                bsr     DotProduct
                bge     .skip

; Set shade offset
                neg.w   d0
                swap    d0
                clr.w   d0
                swap    d0
                lsr.w   #SHADE_SHIFT,d0
                add.w   d0,d0
                lea     ShadeOffsets,a6
                move.w  (a6,d0),d0
                move.l  ObjectTexture(pc),a6
                lea     (a6,d0.l),a6
                move.l  a6,ObjectTexturePos

                bsr     DrawTri

.skip:
                movem.l (sp)+,d0/a0
                lea     TV_SIZEOF*3(a0),a0
                dbf     d0,.l

                rts


********************************************************************************
DrawObjectTriNorm:
                move.l  ObjectFaces(pc),a0
                move.w  (a0)+,d0
.l:
                movem.l d0/a0,-(sp)

; Read vertex data
                lea     NV_SIZEOF(a0),a1
                lea     NV_SIZEOF(a1),a2
                move.l  ObjectTransformed(pc),a3
                move.w  NV_VertOffs(a2),d0
                lea     (a3,d0.w),a5
                move.w  NV_VertOffs(a1),d0
                lea     (a3,d0.w),a4
                move.w  NV_VertOffs(a0),d0
                lea     (a3,d0.w),a3

                bsr     DotProduct
                bge     .skip

; norms
                move.l  ObjectNormsTransformed(pc),a6
                move.w  NV_NormOffs(a0),d0
                lea     (a6,d0.w),a0
                move.w  NV_NormOffs(a1),d0
                lea     (a6,d0.w),a1
                move.w  NV_NormOffs(a2),d0
                lea     (a6,d0.w),a2

                bsr     DrawTri
.skip:
                movem.l (sp)+,d0/a0
                lea     NV_SIZEOF*3(a0),a0
                dbf     d0,.l

                rts


********************************************************************************
DrawObjectQuad:
                move.l  ObjectFaces(pc),a0
                move.w  (a0)+,d0
.l:
                movem.l d0/a0,-(sp)

; Read vertex data
                lea     TV_SIZEOF(a0),a1
                lea     TV_SIZEOF(a1),a2
                move.w  TV_VertOffs(a2),d0
                move.l  ObjectTransformed(pc),a3
                lea     (a3,d0.w),a5
                move.w  TV_VertOffs(a1),d0
                lea     (a3,d0.w),a4
                move.w  TV_VertOffs(a0),d0
                lea     (a3,d0.w),a3

                bsr     DotProduct
                bge     .skip

; Draw first tri
                move.l  a0,-(sp)
                bsr     DrawTri
                move.l  (sp)+,a0

; Draw second tri
                lea     TV_SIZEOF*2(a0),a1
                lea     TV_SIZEOF(a1),a2
                move.w  TV_VertOffs(a2),d0
                move.l  ObjectTransformed(pc),a3
                lea     (a3,d0.w),a5
                move.w  TV_VertOffs(a1),d0
                lea     (a3,d0.w),a4
                move.w  TV_VertOffs(a0),d0
                lea     (a3,d0.w),a3

                bsr     DrawTri

.skip:
                movem.l (sp)+,d0/a0
                lea     TV_SIZEOF*4(a0),a0
                dbf     d0,.l

                rts


********************************************************************************
DrawObjectQuadShade:
                move.l  ObjectFaces(pc),a0
                move.w  (a0)+,d0
.l:
                movem.l d0/a0,-(sp)

; Read vertex data
                lea     TV_SIZEOF(a0),a1
                lea     TV_SIZEOF(a1),a2
                move.w  TV_VertOffs(a2),d0
                move.l  ObjectTransformed(pc),a3
                lea     (a3,d0.w),a5
                move.w  TV_VertOffs(a1),d0
                lea     (a3,d0.w),a4
                move.w  TV_VertOffs(a0),d0
                lea     (a3,d0.w),a3

                bsr     DotProduct
                bge     .skip

; Set shade offset
                neg.w   d0
                swap    d0
                clr.w   d0
                swap    d0
                lsr.w   #SHADE_SHIFT,d0
                add.w   d0,d0
                move.w  ShadeOffsets(pc,d0),d0
                move.l  ObjectTexture(pc),a6
                lea     (a6,d0.l),a6
                move.l  a6,ObjectTexturePos

; Draw first tri
                move.l  a0,-(sp)
                bsr     DrawTri
                move.l  (sp)+,a0

; Draw second tri
                lea     TV_SIZEOF*2(a0),a1
                lea     TV_SIZEOF(a1),a2
                move.w  TV_VertOffs(a2),d0
                move.l  ObjectTransformed(pc),a3
                lea     (a3,d0.w),a5
                move.w  TV_VertOffs(a1),d0
                lea     (a3,d0.w),a4
                move.w  TV_VertOffs(a0),d0
                lea     (a3,d0.w),a3

                bsr     DrawTri

.skip:
                movem.l (sp)+,d0/a0
                lea     TV_SIZEOF*4(a0),a0
                dbf     d0,.l

                rts

ShadeOffsets:
; y, x
                dc.w    (OBJTEX_W*3+1)*64*2
                dc.w    (OBJTEX_W*3)*64*2
                dc.w    (OBJTEX_W*2+1)*64*2
                dc.w    (OBJTEX_W*2)*64*2
                dc.w    (OBJTEX_W*1+1)*64*2
                dc.w    (OBJTEX_W*1)*64*2
                dc.w    (OBJTEX_W*0+1)*64*2
                rept    50              ; prevent overflow
                dc.w    (OBJTEX_W*0)*64*2
                endr


********************************************************************************
DrawObjectQuadNorm:
                move.l  ObjectFaces(pc),a0
                move.w  (a0)+,d0
.l:
                movem.l d0/a0,-(sp)

; Read vertex data
                lea     NV_SIZEOF(a0),a1
                lea     NV_SIZEOF(a1),a2
                move.l  ObjectTransformed(pc),a3
                move.w  NV_VertOffs(a2),d0
                lea     (a3,d0.w),a5
                move.w  NV_VertOffs(a1),d0
                lea     (a3,d0.w),a4
                move.w  NV_VertOffs(a0),d0
                lea     (a3,d0.w),a3

                bsr     DotProduct
                bge     .skip

                move.l  a0,-(sp)

; norms
                move.l  ObjectNormsTransformed(pc),a6
                move.w  NV_NormOffs(a0),d0
                lea     (a6,d0.w),a0
                move.w  NV_NormOffs(a1),d0
                lea     (a6,d0.w),a1
                move.w  NV_NormOffs(a2),d0
                lea     (a6,d0.w),a2

                bsr     DrawTri

                move.l  (sp)+,a0

; Draw second tri
                lea     NV_SIZEOF*2(a0),a1
                lea     NV_SIZEOF(a1),a2
                move.l  ObjectTransformed(pc),a3
                move.w  NV_VertOffs(a2),d0
                lea     (a3,d0.w),a5
                move.w  NV_VertOffs(a1),d0
                lea     (a3,d0.w),a4
                move.w  NV_VertOffs(a0),d0
                lea     (a3,d0.w),a3

; norms
                move.l  ObjectNormsTransformed(pc),a6
                move.w  NV_NormOffs(a0),d0
                lea     (a6,d0.w),a0
                move.w  NV_NormOffs(a1),d0
                lea     (a6,d0.w),a1
                move.w  NV_NormOffs(a2),d0
                lea     (a6,d0.w),a2

                bsr     DrawTri

.skip:
                movem.l (sp)+,d0/a0
                lea     NV_SIZEOF*4(a0),a0
                dbf     d0,.l

                rts


********************************************************************************
; a3-a5 - Vertices
;-------------------------------------------------------------------------------
DotProduct:
; (Y2-Y3)*(X1-X2)-(Y1-Y2)*(X2-X3)
                movem.w (a5),d0-d1
                movem.w (a4),d2-d3
                movem.w (a3),d4-d5
                sub.w   d2,d0
                sub.w   d4,d2
                sub.w   d3,d1
                sub.w   d5,d3
                muls    d1,d2
                muls    d3,d0
                sub.w   d2,d0
                rts

********************************************************************************
; a0-a2 - UVs (TV or NV)
; a3-a5 - Vertices (Vec2)
;-------------------------------------------------------------------------------
DrawTri:
                move.w  Vec2_Y(a3),d0   ; y1
                move.w  Vec2_Y(a4),d1   ; y2
                move.w  Vec2_Y(a5),d2   ; y3

;----------------------------------------------------------------------------
; Sort vertices by Y
                cmp.w   d0,d1
                bge     .noSwap1
                exg     d0,d1
                exg     a0,a1
                exg     a3,a4
.noSwap1:
                cmp.w   d0,d2
                bge     .noSwap2
                exg     d0,d2
                exg     a0,a2
                exg     a3,a5
.noSwap2:
                cmp.w   d1,d2
                bge     .noSwap3
                exg     d1,d2
                exg     a1,a2
                exg     a4,a5
.noSwap3:

;----------------------------------------------------------------------------
; OOB checks:
                ifne    VCLIPPING
                tst.w   d2
                blt     .done
                cmp.w   DrawH(pc),d0
                bge     .done
                endc
;----------------------------------------------------------------------------

                move.w  Vec2_X(a3),d3   ; x1
                move.w  Vec2_X(a4),d4   ; x2
                move.w  Vec2_X(a5),d5   ; x3

                lea     ObjectVars(pc),a6

                movem.w d0/d1/d3/d4,(a6)
                move.l  TV_U(a0),TopU-ObjectVars(a6) ; TopU, TopV

; Get basic x/y deltas
                move.w  d2,d6
                move.w  d4,a4
                move.w  d5,d7
                sub.w   d1,d6           ; (y3-y2) BottomH
                sub.w   d0,d1           ; (y2-y1) TopH
                sub.w   d0,d2           ; (y3-y1) LongH
                sub.w   d4,d7           ; (x3-x2) BottomW
                sub.w   d3,d4           ; (x2-x1) TopW
                sub.w   d3,d5           ; (x3-x1) LongW
                movem.w d1-d2/d4-d7,TopH-ObjectVars(a6)

;----------------------------------------------------------------------------
; UV Gradients:

; Interpolate to get intersection point on long side
; This will be our longest span and we can use this to calculate DuDX/DVDX needed for SMC

; Lookup $8000/n for fixed point divide as muls
                lea     RecipTbl,a5     ; FP [17:15]
RECIPLU         macro
                add.w   \1,\1
                move.w  (a5,\1),\1
                endm

                RECIPLU d2
                mulu    d1,d2           ; 1 / long h * short h [17:15]

; Interpolate X
                FPMULS15 d2,d5          ; LongW * top height / total height
                add.w   d3,d5           ; + topx = midX
                move.w  d5,BottomX2-ObjectVars(a6)
                sub.w   a4,d5           ; = width

                beq     .done           ; Skip zero width

                move.w  d5,d6
                bge     .notNegWidth    ; Absolute width
                neg.w   d5
.notNegWidth:
                RECIPLU d6              ; 1 / BottomW [17:15]

; Interpolate U
                move.w  TV_U(a0),d0
                move.w  TV_U(a2),d4
                sub.w   d0,d4           ; total du for long side
                FPMULS15 d2,d4          ; * top height / total height
                add.w   d0,d4           ; + u1 = u at intersection
                move.w  d4,BottomU-ObjectVars(a6)

; DuDx
                sub.w   TV_U(a1),d4     ; DU
                FPMULS15_16 d6,d4       ; / w = DUDX [16:16]

; Interpolate V
                move.w  TV_V(a0),d0
                move.w  TV_V(a2),d3     ; [8:8]
                sub.w   d0,d3           ; total dv for long side
                FPMULS15 d2,d3          ; * top height / total height
                add.w   d0,d3           ; + v1 = v at intersection
                move.w  d3,BottomV-ObjectVars(a6)

; DvDx
                sub.w   TV_V(a1),d3     ; DV
                FPMULS15_16 d6,d3       ; / w = DVDX [8:8]

; Combine UV fixed point values for addx trick
                move.w  d4,d3		
                swap    d3              ; uu--VVvv
                swap    d4              ; ------UU

; Write offsets to SMC
                moveq   #0,d1           ; ------UU
                moveq   #0,d2           ; uu--VVvv
                lea     .drawLineSmcE(pc),a4 ; first offset always zero - skip this
SMC_UNROLL = 2
                move.l  #$352b0000,d6   ; 0(a3),-(a2)
                lsr.w   #SMC_UNROLL,d5  ; unroll
.gradL:
                rept    1<<SMC_UNROLL
; inc UV - do on first loop as skipping zero
                add.l   d3,d2
                addx.b  d4,d1

                move.w  d2,d6
                move.b  d1,d6
                add.b   d6,d6
                move.l  d6,-(a4)
                endr
                dbf     d5,.gradL

;----------------------------------------------------------------------------
; DxDy:

; DxDy Long - d5,d3
                move.w  LongW(pc),d5
                move.w  LongH(pc),d2
                RECIPLU d2              ; 1/LongH [17:15]
                FPMULS15_16 d2,d5       ; (x3-x1)/(y3-y1)
                move.l  d5,d3           ; continued for bottom...

; DxDy Top - d4
                move.w  TopW(pc),d4
                move.w  TopH(pc),d1
                beq     .zeroTopHeight
                RECIPLU d1              ; 1/TopH [17:15]
                FPMULS15_16 d1,d4       ; (x2-x1)/(y2-y1)
                bra     .topDone
.zeroTopHeight:
                I2FP16  d4              ; no divide - just conv to [16:16]
                clr.l   d5              ; no change for long edge
.topDone:
; DxDy Bottom - d7
                move.w  BottomW(pc),d7
                move.w  BottomH(pc),d6
                beq     .zeroBottomHeight
                RECIPLU d6              ; 1/BottomH [17:15]
                FPMULS15_16 d6,d7       ; (x3-x2)/(y3-y2)
.zeroBottomHeight:


;----------------------------------------------------------------------------
; Check direction - 
; Ensure x left to right and set DUDY,DVDY based on direction

; Maybe need to swap these:
; d4 - top DXDY1 = TopDxDy
; d5 - top DXDY2 = LongDxDy
; d7 - bottom DXDY1 = BottomDxDy
; d3 - bottom DXDY2 = LongDxDy
; and BottomX1/BottomX2 (not in regs)

                cmp.l   d4,d5           ; is mid point left or right of top?
                bgt     .right
;------------------------------------------------------------
; Long side is on left - Need to swap

; Long UV deltas - use for both top and bottom
                move.w  TV_U(a2),d0     ; DU
                sub.w   TV_U(a0),d0
                move.w  TV_V(a2),d1     ; DV
                sub.w   TV_V(a0),d1
                FPMULS15_16 d2,d0       ; DUDY
                FPMULS15 d2,d1          ; DVDY
                move.l  d0,TopDuDy-ObjectVars(a6)
                move.l  d0,BottomDuDy-ObjectVars(a6)
                move.w  d1,TopDvDy-ObjectVars(a6)
                move.w  d1,BottomDvDy-ObjectVars(a6)

; Swap top and bottom DxDy
                exg     d4,d5
                exg     d3,d7
; Swap bottom xl/x2
                movem.w BottomX1(pc),d0/d2
                exg     d0,d2
                movem.w d0/d2,BottomX1-ObjectVars(a6)

                bra     .deltasDone
.right:
;------------------------------------------------------------
; Long side is on right - Don't need to swap

; Use mid UV:
                move.l  TV_U(a1),BottomU-ObjectVars(a6)

; Top UV deltas:
                tst.w   d1
                beq     .zeroTopHeight1
                move.w  TV_U(a1),d0     ; DU
                sub.w   TV_U(a0),d0
                move.w  TV_V(a1),d2     ; DV
                sub.w   TV_V(a0),d2
                FPMULS15_16 d1,d0       ; DUDY
                FPMULS15 d1,d2          ; DUDV
                move.l  d0,TopDuDy-ObjectVars(a6)
                move.w  d2,TopDvDy-ObjectVars(a6)
.zeroTopHeight1:

; Bottom UV deltas:
                tst.w   d6
                beq     .zeroBottomHeight1

                move.w  TV_U(a2),d0     ; DU
                sub.w   TV_U(a1),d0
                move.w  TV_V(a2),d2     ; DV
                sub.w   TV_V(a1),d2
                FPMULS15_16 d6,d0       ; DUDY
                FPMULS15 d6,d2          ; DVDY
                move.l  d0,BottomDuDy-ObjectVars(a6)
                move.w  d2,BottomDvDy-ObjectVars(a6)
.zeroBottomHeight1:
.deltasDone:
                move.l  d7,BottomDxDy1-ObjectVars(a6)
                move.l  d3,BottomDxDy2-ObjectVars(a6)

                move.l  DrawChunky(pc),a0
                move.l  ObjectTexturePos(pc),a1

;----------------------------------------------------------------------------
; Skip top section?

; Skip if OOB
                move.w  BottomY(pc),d2
                bgt     .notOOB
.skipTop:
; Set initial buffer and UV offsets for bottom, and skip top
; Normally bottom section continues from current offsets, so these aren't set,
; But we need to set them if it's first.
                muls    DrawW(pc),d2
                move.w  BottomX1(pc),d1
                add.w   d2,d1           ; Initial start offset
                add.w   BottomX2(pc),d2 ; Iniital end offset
                I2FP16  d1
                I2FP16  d2

; Combine u fractional part with V for addx trick
                moveq   #0,d4
                move.w  BottomV(pc),d4  ; uuuuVVvv
                move.w  BottomU(pc),d0  ; ------UU

                bra     .bottom

.notOOB:
; Skip if Zero height
                move.w  TopH(pc),d7
                subq    #1,d7           ; d7 = DY-1
                blt     .skipTop	


;----------------------------------------------------------------------------
; Draw top section:

                move.l  d4,a5           ; dxdy1
                move.l  d5,a6           ; dxdy2
                move.w  TopY(pc),d2     ; Initial draw offset
                mulu    DrawW(pc),d2
                add.w   TopX(pc),d2
                I2FP16  d2
                move.l  d2,d1           ; same initial offset for start/end
                move.w  TopY(pc),a4

                move.l  TopDuDy+2(pc),d5 ; uuuuVVvv
                move.w  TopDuDy(pc),d3  ; ------UU

                moveq   #0,d4           ; fractional part is empty initially
                move.w  TopV(pc),d4     ; uuuuVVvv
                move.w  TopU(pc),d0     ; ------UU

                bsr     .drawSection


;----------------------------------------------------------------------------
; Draw bottom section
.bottom:
                move.w  BottomY(pc),a4
                move.l  BottomDxDy1(pc),a5
                move.l  BottomDxDy2(pc),a6
                move.w  BottomH(pc),d7
                move.l  BottomDuDy+2(pc),d5 ; uuuuVVvv
                move.w  BottomDuDy(pc),d3 ; ------UU

********************************************************************************
; d0 - U          ------UU
; d1 - X1
; d2 - X2
; d3 - dUdy       ------UU
; d4 - u,V        uuuuVVvv
; d5 - dudy,dVdy  uuuuVVvv
; d7 - dy (height)
; a0 - draw buffer
; a1 - texture
; a4 - Y
; a5 - dX1/dy
; a6 - dX2/dy
; 
; d6 used as tmp
; a2/a3 used for offset draw/texture ptrs in inner loop
; a7 used as SMC ptr (sp is backed up)
;-------------------------------------------------------------------------------
.drawSection:
                move.l  DrawW(pc),d6    ; add line to x delta
                clr.w   d6
                add.l   d6,a5
                add.l   d6,a6

.step           macro
                add.l   d5,d4           ; Increment UV
                addx.w  d3,d0
                add.l   a5,d1           ; increment X1
                add.l   a6,d2           ; increment X2
                endm

                ifne    VCLIPPING
; Vertical clipping:
; Bottom Clip
                move.w  DrawH(pc),d6
                sub.w   a4,d6
                sub.w   d7,d6
                bge     .bottomClipOk
                add.w   d6,d7
                subq    #1,d7
.bottomClipOk:
; Top Clip
                move.w  a4,d6
                bge     .topClipOk
                add.w   d6,d7
                neg.w   d6
                subq    #1,d6
.topClipL:
; Step without drawing until first visible line
; TODO: is multiply quicker?
                .step
                dbf     d6,.topClipL
.topClipOk:

; Zero height check
                tst.w   d7
                bge     .notZeroHeightBottom
                .step
                rts
.notZeroHeightBottom:
                endc

                add.l   #$8000,d2       ; round up X2

                move.l  sp,SpTmp
                lea     .drawLineSmcE+4(pc),a7
.l:
; Offset texture to UV
                move.w  d4,d6           ; d6 = VVvv
                move.b  d0,d6           ; d6 = VVUU
                add.b   d6,d6           ; U * 2 for word offset, V is already doubled
                lea     (a1,d6),a3	

; Offset draw buffer to X2 (we're drawing the line RTL)
                move.l  d2,d6		
                swap    d6
                add.w   d6,d6
                lea     (a0,d6),a2

; jmp into SMC - negative offset to determine width
                move.l  d1,d6           ; X1 - X2 to get negative width (still [16:16])
                sub.l   d2,d6		

                ifne    VCLIPPING
; end when x1/x2 are swapped
; TODO: try to remove this workaround 
; why does this happen?
; seems to happen with clipping
                bgt     .endLoop		
                endc

                swap    d6              ; to int
                lsl.w   #2,d6           ; * 4 for longword instruction offset
                .step
                ; bra     .drawLineSmcE  ; test wireframe
                jmp     (a7,d6)

; SMC
                rept    CHUNKY_W
                move.w  $1234(a3),-(a2) ; 4b
                endr
.drawLineSmcE:
                move.w  (a3),-(a2)      ; 2b
                dbf     d7,.l
.endLoop:
                move.l  SpTmp(pc),sp
.done:
                rts


                ifne    OBJECT_BOUNDS


********************************************************************************
Transform:
                move.l  sp,SpTmp

                move.l  Angles(pc),d0
                and.l   #$7fe07fe,d0    ; sin mask
                move.l  fw_SinTable(a6),a1
                move.l  fw_CosTable(a6),a0
                move.w  (a0,d0),a2      ; SIN(Y)
                move.w  (a1,d0),a3      ; COS(Y)
                swap    d0
                move.w  (a0,d0),a0      ; SIN(z)
                move.w  (a1,d0),a1      ; COS(z)

                move.l  ObjectVerts(pc),a4
                move.l  ObjectTransformed(pc),a5
                lea     RecipTbl,a6

                lea     Vars(pc),a7
                move.l  #$7fff0000,d0
                move.l  d0,VertMinX-Vars(a7)
                move.l  d0,VertMinY-Vars(a7)

                move.w  (a4)+,d7
;-------------------------------------------------------------------------------
.l:
                movem.w (a4)+,d0-d2

;	NX=X*COS(Z)-Y*SIN(Z)
;	NY=X*SIN(Z)+Y*COS(Z)
                move.w  a0,d4           ; SIN(z)
                move.w  a1,d3           ; COS(z)
                move.w  d1,d5           ; y
                move.w  d0,d6           ; x
                muls    d4,d5           ; d5 = y*SIN(z)
                muls    d4,d6           ; d6 = x*SIN(z)
                muls    d3,d1           ; d1 = y*COS(z)
                muls    d0,d3           ; d3 = x*COS(z)
                sub.l   d5,d3           ; d3 = x*COS(z)-y*SIN(z)
                add.l   d6,d1           ; d1 = x*SIN(z)+y*COS(z)
                FP2I14  d3              ; d3 = nx

;	NX=X*COS(Y)-Z*SIN(Y)
;	NZ=X*SIN(Y)+Z*COS(Y)
                move.w  a2,d4           ; SIN(Y)
                move.w  a3,d0           ; COS(Y)
                move.w  d3,d5           ; x
                move.w  d2,d6           ; z
                muls    d4,d5           ; d5 = X*SIN(Y)
                muls    d4,d6           ; d6 = z*SIN(Y)
                muls    d0,d3           ; d3 = x*COS(Y)
                muls    d2,d0           ; d0 = z*COS(Y)
                sub.l   d5,d0           ; X*COS(Y)-Z*SIN(Y)
                add.l   d6,d3           ; X*SIN(Y)+Z*COS(Y)
                FP2I14  d3              ; d3 = nz
; Leave final values fixed point
; FP2I14	d0		; d0 = nx

; Perspective
                add.w   Dist(pc),d3
                FP2I15  d0
                FP2I15  d1
                add.w   d3,d3
                move.w  (a6,d3),d3
                muls    d3,d0
                muls    d3,d1

; TODO: can we leave this fixed point?
                asr.w   #8,d1
                asr.w   #8,d0

; Update bounds
                cmp.w   VertMaxX(pc),d0
                ble     .notMaxX
                move.w  d0,VertMaxX-Vars(a7)
.notMaxX:
                cmp.w   VertMaxY(pc),d1
                ble     .notMaxY
                move.w  d1,VertMaxY-Vars(a7)
.notMaxY:
                cmp.w   VertMinX(pc),d0
                bge     .notMinX
                move.w  d0,VertMinX-Vars(a7)
.notMinX:
                cmp.w   VertMinY(pc),d1
                bge     .notMinY
                move.w  d1,VertMinY-Vars(a7)
.notMinY:

; Write transformed vertex
                move.w  d0,(a5)+
                move.w  d1,(a5)+

                dbf     d7,.l
;-------------------------------------------------------------------------------

                movem.w VertBounds(pc),d0-d3

; Round max/min
; needs to be multiple of 4
                moveq   #-4,d6
                subq    #3,d0           ; round down min
                and.w   d6,d0
                addq    #4,d1           ; round up max
                and.w   d6,d1
; subq	#3,d2
                and.w   d6,d2
                addq    #4,d3
                and.w   d6,d3

; Clamp min/max offsets to screen bounds
                CLAMP_MIN_W #-CHUNKY_W/2,d0
                CLAMP_MAX_W #-12,d0
                CLAMP_MAX_W #CHUNKY_W/2,d1
                CLAMP_MIN_W #12,d1
                CLAMP_MIN_W #-CHUNKY_H/2,d2
                CLAMP_MAX_W #CHUNKY_H/2,d3

.setGeo:
; Chunky screen w/h
                move.w  d1,d4           ; width
                sub.w   d0,d4
                move.w  d3,d5           ; height
                sub.w   d2,d5

; screen offsets
                add.w   d0,d1
                add.w   d2,d3
                asr.w   d1
                asr.w   d3

; Persist geometry for display
                movem.w d4/d5,NextGeo-Vars(a7)
                movem.w d1/d3,NextGeo+4-Vars(a7)

; Use these for next draw
                movem.w d4/d5,DrawW-Vars(a7)

; Center in chunky screen
                swap    d0              ; Combined x/y for longword subtraction
                move.w  d2,d0
                move.l  ObjectVerts(pc),a4
                move.w  (a4)+,d7
                move.l  ObjectTransformed(pc),a7
.l1:
                sub.l   d0,(a7)+
                dbf     d7,.l1
;-------------------------------------------------------------------------------

                tst.w   ObjectNorms+2
                beq     .noNorms

                move.l  ObjectNorms(pc),a4
                move.l  ObjectNormsTransformed(pc),a5
                move.w  (a4)+,d7
;-------------------------------------------------------------------------------
.normLoop:
                movem.w (a4)+,d0-d2

;	NX=X*COS(Z)-Y*SIN(Z)
;	NY=X*SIN(Z)+Y*COS(Z)
                move.w  a0,d4           ; SIN(z)
                move.w  a1,d3           ; COS(z)
                move.w  d1,d5           ; y
                move.w  d0,d6           ; x
                muls    d4,d5           ; d5 = y*SIN(z)
                muls    d4,d6           ; d6 = x*SIN(z)
                muls    d3,d1           ; d1 = y*COS(z)
                muls    d0,d3           ; d3 = x*COS(z)
                sub.l   d5,d3           ; d3 = x*COS(z)-y*SIN(z)
                add.l   d6,d1           ; d1 = x*SIN(z)+y*COS(z)
                FP2I14  d3              ; d3 = nx

;	NX=X*COS(Y)-Z*SIN(Y)
                move.w  a2,d4           ; SIN(Y)
                move.w  a3,d0           ; COS(Y)
                muls    d4,d3           ; d3 = X*SIN(Y)
                muls    d2,d0           ; d0 = z*COS(Y)
                sub.l   d3,d0           ; X*COS(Y)-Z*SIN(Y)
                FP2I14  d0              ; d0 = nx

; Write transformed vertex
                asr.l   #6,d1
                add.w   #64,d0
                add.w   #64<<8,d1
                move.w  d0,(a5)+        ; U
                move.w  d1,(a5)+        ; V

                dbf     d7,.normLoop
;-------------------------------------------------------------------------------
.noNorms:

                move.l  SpTmp,sp
                rts


                else


********************************************************************************
Transform:
                move.l  Angles(pc),d0
                and.l   #$7fe07fe,d0    ; sin mask
                move.l  fw_SinTable(a6),a1
                move.l  fw_CosTable(a6),a0
                move.w  (a0,d0),a2      ; SIN(Y)
                move.w  (a1,d0),a3      ; COS(Y)
                swap    d0
                move.w  (a0,d0),a0      ; SIN(z)
                move.w  (a1,d0),a1      ; COS(z)

                move.l  ObjectVerts(pc),a4
                move.l  ObjectTransformed(pc),a5
                lea     RecipTbl,a6

                move.w  (a4)+,d7
;-------------------------------------------------------------------------------
.l:
                movem.w (a4)+,d0-d2

;	NX=X*COS(Z)-Y*SIN(Z)
;	NY=X*SIN(Z)+Y*COS(Z)
                move.w  a0,d4           ; SIN(z)
                move.w  a1,d3           ; COS(z)
                move.w  d1,d5           ; y
                move.w  d0,d6           ; x
                muls    d4,d5           ; d5 = y*SIN(z)
                muls    d4,d6           ; d6 = x*SIN(z)
                muls    d3,d1           ; d1 = y*COS(z)
                muls    d0,d3           ; d3 = x*COS(z)
                sub.l   d5,d3           ; d3 = x*COS(z)-y*SIN(z)
                add.l   d6,d1           ; d1 = x*SIN(z)+y*COS(z)
                FP2I14  d3              ; d3 = nx

;	NX=X*COS(Y)-Z*SIN(Y)
;	NZ=X*SIN(Y)+Z*COS(Y)
                move.w  a2,d4           ; SIN(Y)
                move.w  a3,d0           ; COS(Y)
                move.w  d3,d5           ; x
                move.w  d2,d6           ; z
                muls    d4,d5           ; d5 = X*SIN(Y)
                muls    d4,d6           ; d6 = z*SIN(Y)
                muls    d0,d3           ; d3 = x*COS(Y)
                muls    d2,d0           ; d0 = z*COS(Y)
                sub.l   d5,d0           ; X*COS(Y)-Z*SIN(Y)
                add.l   d6,d3           ; X*SIN(Y)+Z*COS(Y)
                FP2I14  d3              ; d3 = nz
; Leave final values fixed point
; FP2I14	d0		; d0 = nx

; Perspective
                add.w   Dist(pc),d3
                FP2I15  d0
                FP2I15  d1
                add.w   d3,d3
                move.w  (a6,d3),d3
                muls    d3,d0
                muls    d3,d1

; TODO: can we leave this fixed point?
                asr.w   #8,d1
                asr.w   #8,d0

                add.w   #CHUNKY_W/2,d0
                add.w   #CHUNKY_H/2,d1

; Write transformed vertex
                move.w  d0,(a5)+
                move.w  d1,(a5)+

                dbf     d7,.l
;-------------------------------------------------------------------------------

                tst.w   ObjectNorms+2
                beq     .noNorms

                move.l  ObjectNorms(pc),a4
                move.l  ObjectNormsTransformed(pc),a5
                move.w  (a4)+,d7
;-------------------------------------------------------------------------------
.normLoop:
                movem.w (a4)+,d0-d2

;	NX=X*COS(Z)-Y*SIN(Z)
;	NY=X*SIN(Z)+Y*COS(Z)
                move.w  a0,d4           ; SIN(z)
                move.w  a1,d3           ; COS(z)
                move.w  d1,d5           ; y
                move.w  d0,d6           ; x
                muls    d4,d5           ; d5 = y*SIN(z)
                muls    d4,d6           ; d6 = x*SIN(z)
                muls    d3,d1           ; d1 = y*COS(z)
                muls    d0,d3           ; d3 = x*COS(z)
                sub.l   d5,d3           ; d3 = x*COS(z)-y*SIN(z)
                add.l   d6,d1           ; d1 = x*SIN(z)+y*COS(z)
                FP2I14  d3              ; d3 = nx

;	NX=X*COS(Y)-Z*SIN(Y)
                move.w  a2,d4           ; SIN(Y)
                move.w  a3,d0           ; COS(Y)
                muls    d4,d3           ; d3 = X*SIN(Y)
                muls    d2,d0           ; d0 = z*COS(Y)
                sub.l   d3,d0           ; X*COS(Y)-Z*SIN(Y)
                FP2I14  d0              ; d0 = nx

; Write transformed vertex
                asr.l   #6,d1
                add.w   #64,d0
                add.w   #64<<8,d1
                move.w  d0,(a5)+        ; U
                move.w  d1,(a5)+        ; V

                dbf     d7,.normLoop
;-------------------------------------------------------------------------------
.noNorms:

                rts


                endc


********************************************************************************
ObjectVars:
********************************************************************************

; Optimised order for movem
TopY:           dc.w    0
BottomY:        dc.w    0
TopX:           dc.w    0
BottomX1:       dc.w    0

BottomX2:       dc.w    0
BottomU:        dc.w    0
BottomV:        dc.w    0

TopH:           dc.w    0
LongH:          dc.w    0
TopW:           dc.w    0
LongW:          dc.w    0
BottomH:        dc.w    0
BottomW:        dc.w    0

BottomDuDy:     dc.l    0
BottomDvDy:     dc.w    0
BottomDxDy1:    dc.l    0
BottomDxDy2:    dc.l    0

TopU:           dc.w    0
TopV:           dc.w    0
TopDuDy:        dc.l    0
TopDvDy:        dc.w    0


********************************************************************************

                rept    RECIP_RANGE_NEG
                dc.w    -$8000/(RECIP_RANGE_NEG-REPTN+3)
                endr
                dc.w    $8000
RecipTbl:
                dc.w    0
                rept    RECIP_RANGE_POS
                dc.w    $7fff/(REPTN+1)
                endr
