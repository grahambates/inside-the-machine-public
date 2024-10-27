		ifnd	_3D_I
_3D_I		set	1

OBJTYPE_QUAD_B = 0
OBJTYPE_NORM_B = 1
OBJTYPE_SHADE_B = 2

OBJTYPE_QUAD = 1<<OBJTYPE_QUAD_B
OBJTYPE_NORM = 1<<OBJTYPE_NORM_B
OBJTYPE_SHADE = 1<<OBJTYPE_SHADE_B

		rsreset
Obj_Verts	rs.w	1
Obj_Norms	rs.w	1
Obj_Faces	rs.w	1
Obj_Type	rs.w	1

;-------------------------------------------------------------------------------
; Vertex:
		rsreset
Vec2_X		rs.w	1
Vec2_Y		rs.w	1
Vec2_SIZEOF	rs.b	0

VEC2		macro
		dc.w	\1,\2
		endm

		rsreset
Vec3_X		rs.w	1
Vec3_Y		rs.w	1
Vec3_Z		rs.w	1
Vec3_SIZEOF	rs.b	0

VEC3		macro
		dc.w	\1,\2,\3
		endm

;-------------------------------------------------------------------------------
; Textured vertex:
		rsreset
TV_U		rs.w	1
TV_V		rs.w	1
TV_VertOffs	rs.w	1
TV_SIZEOF	rs.b	0

;-------------------------------------------------------------------------------
; Normal vertex:
		rsreset
NV_VertOffs	rs.w	1
NV_NormOffs	rs.w	1
NV_SIZEOF	rs.b	0

TV		macro
		dc.w	\2,\3<<8,\1*Vec2_SIZEOF
		endm
NV		macro
		dc.w	\1*Vec2_SIZEOF,\2*Vec2_SIZEOF
		endm
COUNT		macro
		dc.w	\1-1
		endm
FACE		macro
		dc.w	\1-1
		endm

		endc
