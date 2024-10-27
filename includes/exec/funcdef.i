		incdir	"include_std"
		include	"exec/libraries.i"

		macro	FUNCDEF
_LVO\1		equ	FUNC_CNT
FUNC_CNT	set	FUNC_CNT-LIB_VECTSIZE
		endm

FUNC_CNT	set	LIB_USERDEF
