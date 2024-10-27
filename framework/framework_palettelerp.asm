;--------------------------------------------------------------------
; Initializes linear interpolation for simple palette fading.
;
; In : a0 = source palette buffer (12 bit)
;      a1 = lerp structures
;      d0 = number of colors
;
fw_InitPaletteLerp:
        PUTMSG  20,<"Init Lerp %p with %p">,a1,a0
        subq.w  #1,d0
        bcc.s   .cont
        rts
.cont   move.w   #$800,d2
.loop
        moveq.l #0,d1
        move.w  d1,cl_Steps(a1)
        move.w  (a0),cl_Color(a1)
        move.w  d1,cl_Red+le_Add(a1)
        move.w  d1,cl_Green+le_Add(a1)
        move.w  d1,cl_Blue+le_Add(a1)

        move.b  (a0)+,d1
        ror.w   #4,d1
        add.w   d2,d1
        move.w  d1,cl_Red+le_Current(a1)
        moveq.l #-16,d1
        and.b   (a0),d1
        addq.b  #8,d1
        move.b  d1,cl_Green+le_Current(a1)
        clr.b   cl_Green+1+le_Current(a1)

        moveq.l #15,d1
        and.b   (a0)+,d1
        ror.w   #4,d1
        add.w   d2,d1
        move.w  d1,cl_Blue+le_Current(a1)
        lea     cl_SIZEOF(a1),a1
        dbra    d0,.loop
        rts

;--------------------------------------------------------------------
; Initializes linear interpolation for simple palette fading to given color
;
; In : a1 = lerp structures
;      d0 = number of colors
;      d1 = color value
;
fw_InitPaletteLerpSameColor:
        PUTMSG  20,<"Init Lerp %p with %x">,a1,d1
        subq.w  #1,d0
        bcc.s   .cont
        rts
.cont   move.w  d1,cl_Color(a1)
        moveq.l #0,d1
        move.w  d1,cl_Steps(a1)
        move.w  d1,cl_Red+le_Add(a1)
        move.w  d1,cl_Green+le_Add(a1)
        move.w  d1,cl_Blue+le_Add(a1)

        move.b  cl_Color(a1),d1
        ror.w   #4,d1
        add.w   #$800,d1
        move.w  d1,cl_Red+le_Current(a1)
        moveq.l #-16,d1
        and.b   cl_Color+1(a1),d1
        addq.b  #8,d1
        move.b  d1,cl_Green+le_Current(a1)
        clr.b   cl_Green+1+le_Current(a1)

        moveq.l #15,d1
        and.b   cl_Color+1(a1),d1
        ror.w   #4,d1
        add.w   #$800,d1
        move.w  d1,cl_Blue+le_Current(a1)
        dbra    d0,.iloop
        rts
.iloop  movem.l (a1),d1-d4
.loop   lea     cl_SIZEOF(a1),a1
        movem.l d1-d4,(a1)
        dbra    d0,.loop
        rts

;--------------------------------------------------------------------
; Initialize fading to the given palette from current state
;
; In : a0 = target palette (12 bit)
;      a1 = lerp structures
;      d0 = number of colors
;      d1 = number of steps (power of two)
;
fw_FadePaletteTo:
        subq.w  #1,d0
        bcc.s   .cont
        rts
.cont
        move.w  d1,d4
        moveq.l #-2,d2
.stepsizeloop
        addq.w  #1,d2
        lsr.w   #1,d1
        bne.s   .stepsizeloop
.loop
        move.w  d4,cl_Steps(a1)
        moveq.l #0,d1
        move.b  (a0)+,d1
        ror.w   #4,d1
        move.w  cl_Red+le_Current(a1),d3
        lsr.w   #1,d1
        add.w   #$80,d1
        lsr.w   #1,d3
        sub.w   d3,d1
        asr.w   d2,d1
        move.w  d1,cl_Red+le_Add(a1)

        moveq.l #-16,d1
        and.b   (a0),d1
        lsl.w   #8,d1
        clr.b   d1
        move.w  cl_Green+le_Current(a1),d3
        lsr.w   #1,d1
        add.w   #$80,d1
        lsr.w   #1,d3
        sub.w   d3,d1
        asr.w   d2,d1
        move.w  d1,cl_Green+le_Add(a1)

        moveq.l #15,d1
        and.b   (a0)+,d1
        ror.w   #4,d1
        move.w  cl_Blue+le_Current(a1),d3
        lsr.w   #1,d1
        add.w   #$80,d1
        lsr.w   #1,d3
        sub.w   d3,d1
        asr.w   d2,d1
        move.w  d1,cl_Blue+le_Add(a1)

        lea     cl_SIZEOF(a1),a1
        dbra    d0,.loop
        rts

;--------------------------------------------------------------------
; Do one step in fading for the pre-initialized
;
; Will do nothing if end-point has been already reached.
;
; In : a1 = lerp structures
;      d0 = number of colors
;
fw_DoFadePaletteStep:
        subq.w  #1,d0
        bcc.s   .cont
.done   rts

.cont   lea     cl_Steps(a1),a0
        tst.w   (a0)
        bmi.s   .done
        moveq.l #0,d4
.loop
        addq.w  #2,a1
        move.w  (a1),d1                     ; cl_Steps
        beq.s   .skip
        moveq.l #1,d4
        subq.w  #1,d1
        move.w  d1,(a1)+                    ; cl_Steps
        move.w  (a1)+,d1                    ; cl_Red+le_Add
        add.w   (a1),d1                     ; cl_Red+le_Current
        move.w  d1,(a1)+                    ; cl_Red+le_Current
        move.w  (a1)+,d2                    ; cl_Green+le_Add
        add.w   d2,(a1)+                    ; cl_Green+le_Current
        move.w  (a1)+,d3                    ; cl_Blue+le_Add
        add.w   (a1),d3                     ; cl_Blue+le_Current
        move.w  d3,(a1)+                    ; cl_Blue+le_Current

        lsr.w   #4,d1
        moveq.l #15,d2
        rol.w   #4,d3
        and.w   d2,d3
        moveq.l #-16,d2
        and.b   cl_Green+le_Current-(cl_Blue+le_Current+2)(a1),d2
        or.b    d3,d2
        move.b  d2,d1
        move.w  d1,-cl_SIZEOF(a1)           ; cl_Color
        dbra    d0,.loop
        rts
.skip
        lea     cl_SIZEOF-2(a1),a1
        dbra    d0,.loop
        tst.w   d4
        bne.s   .noend
        st      (a0)
.noend
        rts
