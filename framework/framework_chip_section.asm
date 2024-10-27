mfw_copperlist:
        COP_MOVE diwstrt,$2c81  ; window start
        COP_MOVE diwstop,$2cc1  ; window stop
        COP_MOVE ddfstrt,$0038  ; bitplane start
        COP_MOVE ddfstop,$00d0  ; bitplane stop

        COP_MOVE bplcon0,$0200  ; turn off all bitplanes
        COP_END
mfw_emptysprite:
        dc.w    0,0
mfw_copperlistend:
