********************************************************************************
; Decrunch and start preloaed task
;-------------------------------------------------------------------------------
; \1 - Part name
; \2 - Next part to load (optional)
;-------------------------------------------------------------------------------
EXEC_PART       macro
                move.l  fw_TrackloaderTask(a6),a1
                bsr     fw_WaitUntilTaskFinished

                ifnc    "\2",""
                bsr     fw_FlipAllocationDirection
                bsr     fw_DropCurrentMemoryAllocations
                bsr     fw_FlipAllocationDirection
                lea     \2(pc),a0
                move.l  fw_TrackloaderTask(a6),a1
                bsr     fw_AddTask
                endc

                lea     \1(pc),a0
                clr.l   fw_PrePartLaunchHook(a6)
                bsr     fw_ExecuteNextPart
                endm

********************************************************************************
; Start fully loaded part
;-------------------------------------------------------------------------------
; \1 - Next part to load (optional)
;-------------------------------------------------------------------------------
EXEC_LOADED_PART macro
                move.l  fw_TrackloaderTask(a6),a1
                bsr     fw_WaitUntilTaskFinished

                bsr     fw_FlipAllocationDirection

                ifnc    "\1",""
                bsr     fw_FlipAllocationDirection
                bsr     fw_DropCurrentMemoryAllocations
                bsr     fw_FlipAllocationDirection
                lea     \1(pc),a0
                move.l  fw_TrackloaderTask(a6),a1
                bsr     fw_AddTask
                endc

                move.l  fw_LastLoadedPart(a6),a0
                jsr     (a0)
                PUTMSG  10,<"%d: *** Part finished",10>,fw_FrameCounterLong(a6)
                bsr     fw_RestoreFrameworkBase
                bsr     fw_DropCurrentMemoryAllocations
                endm

********************************************************************************
; Exec a part with precalc (for testing)
;-------------------------------------------------------------------------------
; \1 - Part name
; \2 - Next part to load (optional)
;-------------------------------------------------------------------------------
EXEC_PRECALC_PART macro
                move.l  fw_TrackloaderTask(a6),a1
                bsr     fw_WaitUntilTaskFinished

                ifnc    "\2",""
                bsr     fw_FlipAllocationDirection
                bsr     fw_DropCurrentMemoryAllocations
                bsr     fw_FlipAllocationDirection
                lea     \2(pc),a0
                move.l  fw_TrackloaderTask(a6),a1
                bsr     fw_AddTask
                endc

                lea     \1(pc),a0
                bsr     fw_LoadNextPart
                PUSHM   a0
                jsr     2(a0)
                POPM
                jsr     (a0)
                bsr     fw_RestoreFrameworkBase
                bsr     fw_DropCurrentMemoryAllocations
                endm

********************************************************************************
PRELOAD_TASK    macro
.preload_\1:
                bsr     fw_FlipAllocationDirection
                lea     .\1(pc),a0
                bsr     fw_PreloadPart
                bra     fw_TrackloaderDiskMotorOff
                ; rts
                endm

********************************************************************************
LOAD_TASK       macro
.load_\1:
                bsr     fw_FlipAllocationDirection
                lea     .\1(pc),a0
                bsr     fw_LoadNextPart
                bra     fw_TrackloaderDiskMotorOff
                ; rts
                endm

********************************************************************************
LOAD_PRECALC_TASK macro
.load_\1:
                bsr     fw_FlipAllocationDirection
                lea     .\1(pc),a0
                bsr     fw_LoadNextPart
                bsr     fw_TrackloaderDiskMotorOff
                jmp     2(a0)           ; call precalc from jump table
                ; rts
                endm

********************************************************************************
FILENAME        macro
.\1:            dc.b    "\2",0
                endm

