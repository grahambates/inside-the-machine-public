MEMPF_READ  = $0001
MEMPF_WRITE = $0002
MEMPF_DMAREAD   = $0004
MEMPF_DMAWRITE  = $0008
MEMPF_ALL   = MEMPF_READ | MEMPF_WRITE | MEMPF_DMAREAD | MEMPF_DMAWRITE

        IF      NEWAGE_DEBUG

UAEExitWarp     MACRO
        pea     1.w
        pea     .ob\@(pc)
        clr.l   -(sp)
        pea     .wm\@(pc)
        pea     -1.w
        pea     82.w
        jsr     $f0ff60
        lea     .bc\@(pc),a0
        move.l  a0,8(sp)
        jsr     $f0ff60
        lea     6*4(sp),sp
        bra.s   .s\@
.ob\@   dc.l    0
.wm\@   dc.b    "warp false",0
.bc\@   dc.b    "cycle_exact true",0
        cnop    0,2
.s\@
        ENDM

UAEExit MACRO
        move.l  #13,-(sp)
        jmp     $f0ff60
        ENDM

; UAEMemProtect address,size,bits

UAEMemProtect   MACRO
        move.l  #\3,-(sp)
        move.l  #\2,-(sp)
        pea     \1
        jsr     $f0ff54
        lea.l   12(sp),sp
        ENDM

WinUAEBreakpoint MACRO  ;to stop here in WinUAE, enter "w 4 4 4 w" in the debugger window (shift+f12) to place the breakpoint, and enter "w 4" to remove it
        move.l  4.w,4.w
        ENDM

; The UAE debugger doesn‘t know about any symbols your program might have defined,
; so setting a breakpoint to some address is no big help.
; The trick is to use the fi (find instruction) command to break at a specific opcode.
; You cannot use any common opcode, of course, otherwise the debugger will constantly
; stop in all kinds of processes. Use an opcode which doesn‘t appear anywhere else and
; which, preferably, has no effect. Something like EXG A7,A7 ($cf4f).

; Insert this opcode into your code at the position you want to start debugging.
; Then enter fi cf4f into the debugger. Start your program and begin tracing your program flow.
; t executes a single instruction, z executes code over subroutines, m does memory dumps.

        ELSE

UAEExitWarp     MACRO
        ENDM

UAEMemProtect   MACRO
        ENDM

UAEExit         MACRO
        ENDM

WinUAEBreakpoint MACRO
        ENDM

        ENDC
