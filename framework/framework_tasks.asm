;--------------------------------------------------------------------
; Initialize the multitasking environment.
;
fw_InitTasks:
        lea     fw_Tasks(a6),a1
        NEWLIST a1
        lea     fw_backgroundtask_restore_irq(pc),a0
        move.l  a0,fw_MultitaskingIRQ(a6)
        IF      FW_BLITTERTASK_MT_SUPPORT
        lea     fw_blitter_task_irq(pc),a0
        move.l  a0,fw_BlitterTaskIRQ(a6)
        ENDC
        move.l  #FW_MAX_VPOS_FOR_BG_TASK<<8,fw_MaxVposForTask(a6)
        rts

;--------------------------------------------------------------------
; Adds a task to the list of background tasks.
;
; LN_NAME(a1) can be populated for debugging reasons
; LN_PRI(a1) from -128 (low) to +127 (high) describes the priority
; of the task. Unless a task yields, no lower priority task will be
; processed.
; Exception: For FW_ROUNDROBIN_MT_SUPPORT=1, if LN_PRI is negative,
; low prio tasks will be scheduled round robin, if the task did not yield.
;
; Note that every task will only be scheduled at most once every frame.
; May also be called from subtask.
; Note: All tasks must preserve a5/a6 until exit!
;
; In : a0: start address of routine
;      a1: FrameworkTask structure (with length of ft_SIZEOF)
;      All registers will be initial registers for subtask.
; Out: All registers are unchanged.
;
fw_AddTask:
        PUTMSG  10,<"%d: AddTask(%p,%p,%s)">,fw_FrameCounterLong(a6),a0,a1,LN_NAME(a1)
        tst.l   ft_USP(a1)
        bne     fw_Error
        IF      FW_TOP_BOTTOM_MEM_SECTIONS
        move.w  fw_MainMemDirection(a6),ft_MemDirection(a1)
        ENDC
        move.l  a2,-(sp)
        lea     ft_StackEnd(a1),a2
        exg     a2,sp               ; temporarily swap stack pointers
        move.l  a1,-(sp)            ; keep node for cleanup
        pea     .cleanup(pc)        ; routine to call after RTS from backgroundtask
        move.l  a0,-(sp)            ; background task to jump to
        clr.w   -(sp)               ; initial ccr
        movem.l d0-d7/a0-a6,-(sp)   ; initial register dump from caller
        move.l  sp,ft_USP(a1)
        exg     a2,sp
        move.l  (sp)+,(8+2)*4(a2)   ; restore a2 to stack
        move.l  (8+2)*4(a2),a2      ; restore a2 to register
        lea     fw_Tasks(a6),a0
        DISABLE_INTS
        bsr     fw_EnqueueNode
        ENABLE_INTS
        rts

.cleanup
        ;move.l  fw_BasePtr(pc),a6
        move.l  (sp)+,a1            ; suppress M68kDeadWrite used by REMOVE
        PUTMSG  10,<"%d: background task %p (%s) finished">,fw_FrameCounterLong(a6),a1,LN_NAME(a1)

.waitforsafearea
        move.l  #$1ff00,d0
        and.l   vposr(a5),d0
        cmp.l   fw_MaxVposForTask(a6),d0          ; we are too short before VBL, it's not safe to disable intsmaxvpos
        bgt     .waitforsafearea

        DISABLE_INTS
        clr.l   ft_USP(a1)              ; mark task finished
        REMOVE
        lea     fw_Tasks(a6),a1
        IFEMPTY a1,fw_KillTaskContext   ; wait for doom
        move.l  LN_SUCC(a1),a0          ; hand over to next task
        PUTMSG  40,<"Continuing to task %p (%s)">,a0,LN_NAME(a0)
        move.l  a0,fw_BackgroundTask(a6)
        move.l  ft_USP(a0),sp
        ENABLE_INTS
        movem.l (sp)+,d0-d7/a0-a6
        rtr

;--------------------------------------------------------------------

fw_EnqueueNode:
        move.b  LN_PRI(a1),d1
        move.l  (a0),d0
.next
        move.l  d0,a0
        move.l  (a0),d0
        beq.s   .done
        cmp.b   LN_PRI(a0),d1
        ble.s   .next
.done
        move.l  LN_PRED(a0),d0
        move.l  a1,LN_PRED(a0)
        move.l  a0,(a1)
        move.l  d0,LN_PRED(a1)
        move.l  d0,a0
        move.l  a1,(a0)
        rts

;--------------------------------------------------------------------

fw_KillTaskContext:
        PUTMSG  50,<"KillTaskContext">
        move.l  fw_VBR(a6),a0
        move.l  fw_DefaultIRQ(a6),$6c(a0)
        clr.l   fw_BackgroundTask(a6)   ; make sure we don't have a stray pointer
        move.l  fw_PrimaryUSP(a6),sp    ; primary USP from before
        clr.l   fw_PrimaryUSP(a6)
        move.w  fw_MainCurrentFrame(a6),d0
        ENABLE_INTS
.loop   cmp.w   fw_FrameCounter(a6),d0
        beq.s   .loop
        rts

;--------------------------------------------------------------------
; Waits for next vertical blank and allows multitasking to happen.
;
; Note: Also checks left mouse button for exit if configured.
;
; In : -
; Out: All registers except for a5 and a6 may be trashed.
;
fw_VSyncWithTask:
        move.l  #$1ff00,d0
        and.l   vposr(a5),d0
        cmp.l   #FW_MAX_VPOS_FOR_BG_TASK<<8,d0  ; if we're too late, don't continue background task
        bgt     fw_VSync

        IF      FW_LMB_EXIT_SUPPORT
        btst    #6,$bfe001
        beq     .abortdemo
.noabort
        ENDC

        lea     fw_Tasks(a6),a1
        IFEMPTY a1,fw_VSync
        SUCC    a1,a1       ; take first task from list
        ; context switch takes a few hundred cycles (with idle DMA)

        move.w  fw_FrameCounter(a6),fw_MainCurrentFrame(a6)
.switch
        PUTMSG  50,<"TaskSwitch %p">,a1
        move.l  sp,fw_PrimaryUSP(a6)    ; store old stackpointer (pointing to RTS address)
        move.l  fw_VBR(a6),a0
        move.l  fw_MultitaskingIRQ(a6),$6c(a0)
        PUTMSG  40,<"Switching to task %p (%s)">,a1,LN_NAME(a1)
        move.l  a1,fw_BackgroundTask(a6)
        move.l  ft_USP(a1),sp
        movem.l (sp)+,d0-d7/a0-a6       ; restore context, 132 cycles (another >132 cycles in interrupt)
        PUTMSG  50,<"RTR %p">,sp
        rtr

        IF      FW_LMB_EXIT_SUPPORT
.abortdemo
        move.l  fw_DemoAbortStackPointer(a6),d0
        beq     .noabort
        move.l  d0,sp
        rts
        ENDC
  

;--------------------------------------------------------------------
; Waits for next copper interrupt and allows multitasking to happen.
; Same as VsynWithTask, but no vposr check
;
; Note: Also checks left mouse button for exit if configured.
;
; In : -
; Out: All registers except for a5 and a6 may be trashed.
;
fw_CopSyncWithTask:
        move.l  #$1ff00,d0
        and.l   vposr(a5),d0
        cmp.l   fw_MaxVposForTask(a6),d0  ; if we're too late, don't continue background task
        bgt     fw_VSync

        IF      FW_LMB_EXIT_SUPPORT
        btst    #6,$bfe001
        beq     .abortdemo
.noabort
        ENDC

        lea     fw_Tasks(a6),a1
        IFEMPTY a1,fw_WaitNextFrame
        SUCC    a1,a1       ; take first task from list
        ; context switch takes a few hundred cycles (with idle DMA)

        move.w  fw_FrameCounter(a6),fw_MainCurrentFrame(a6)
.switch
        PUTMSG  50,<"TaskSwitch %p">,a1
        move.l  sp,fw_PrimaryUSP(a6)    ; store old stackpointer (pointing to RTS address)
        move.l  fw_VBR(a6),a0
        move.l  fw_MultitaskingIRQ(a6),$6c(a0)
        PUTMSG  40,<"Switching to task %p (%s)">,a1,LN_NAME(a1)
        move.l  a1,fw_BackgroundTask(a6)
        move.l  ft_USP(a1),sp
        movem.l (sp)+,d0-d7/a0-a6       ; restore context, 132 cycles (another >132 cycles in interrupt)
        PUTMSG  50,<"RTR %p">,sp
        rtr

        IF      FW_LMB_EXIT_SUPPORT
.abortdemo
        move.l  fw_DemoAbortStackPointer(a6),d0
        beq     .noabort
        move.l  d0,sp
        rts
        ENDC

fw_WaitNextFrame:
        move.w   fw_FrameCounter(a6),d0
 .l:
        cmp.w   fw_FrameCounter(a6),d0
        beq   .l
        rts

;--------------------------------------------------------------------
; Allows the current task to switch CPU to the next task in queue.
;
; Usually may not be called from tasks, except if FW_YIELD_FROM_MAIN_TOO
; is set (then it will just call VSyncWithTask).
;
; Preserves all registers!
;
fw_Yield:
        IF      FW_YIELD_FROM_MAIN_TOO
        tst.l   fw_PrimaryUSP(a6)
        bne.s   .switch
        ; So we're not in a background task (method should actually not be used this way)
        PUTMSG  50,<"Simple yield %p">,a7
        PUSHM   d0-d7/a0-a4
        bsr     fw_VSyncWithTask
        POPM
        rts
        ENDC

.switch
        PUSHM   d0/a0
        move.l  #$1ff00,d0
        and.l   vposr(a5),d0
        cmp.l   fw_MaxVposForTask(a6),d0  ; it's too close to VBL, we cannot safely disable ints
        ble     .cont
        POPM    NOBUMP
        rts
.cont
        DISABLE_INTS
        move.l  fw_BackgroundTask(a6),a0
        TSTNODE a0,a0
        POPM
        bne.s   .doswitch
        PUTMSG  50,<"No more tasks">
        subq.w  #2,sp       ; ccr can be anything
        movem.l d0-d7/a0-a6,-(sp)
        move.l  fw_BackgroundTask(a6),a0
        move.l  sp,ft_USP(a0)

        bra     fw_KillTaskContext

.doswitch
        ; return address already on stack
        subq.w  #2,sp       ; ccr can be anything
        PUSHM   d0-d7/a0-a6
        move.l  fw_BackgroundTask(a6),a0
        move.l  sp,ft_USP(a0)
        SUCC    a0,a0
        PUTMSG  40,<"Yield to task %p (%s)">,a0,LN_NAME(a0)
        move.l  a0,fw_BackgroundTask(a6)
        move.l  ft_USP(a0),sp
        ENABLE_INTS
        POPM
        rtr

;--------------------------------------------------------------------
; Makes sure the given task is finished.
;
; May only be called from main.
;
; In: a1 = task structure
;
; May trash all registers except a1
;
fw_WaitUntilTaskFinished:
.retry  tst.l   ft_USP(a1)
        bne.s   .wait
        rts
.wait   PUSHM   a1
        bsr     fw_VSyncWithTask
        POPM
        bra.s   .retry

;--------------------------------------------------------------------
; Removes the task from list if it was still running
;
; May only be called from main.
;
; In: a1 = task structure
; Trashes: a0/a1
fw_RemTask:
        tst.l   ft_USP(a1)
        bne.s   .remove
        rts
.remove PUTMSG  10,<"%d: Removing still running task %p (%s)">,
        clr.l   ft_USP(a1)
        REMOVE
        rts

;--------------------------------------------------------------------

fw_backgroundtask_restore_irq:
        PUTMSG  50,<"MTINT %lx">,$dff000+intenar
        IF      FW_COPPER_IRQ_SUPPORT
        btst    #INTB_COPER,$dff000+intreqr+1
        bne     fw_copper_irq
        ENDC
        move.l  a6,-(sp)                ; save a6, we need a spare register
        move.l  usp,a6                  ; get USP
        PUTMSG  50,<"USP %p">,a6
        move.l  4+2(sp),-(a6)           ; store PC
        move.w  4(sp),-(a6)             ; store SR
        move.l  (sp)+,-(a6)             ; store a6 in stack frame
        movem.l d0-d7/a0-a5,-(a6)       ; store the rest of the registers
        move.l  a6,a0

        move.l  fw_BasePtr(pc),a6
        move.l  fw_BackgroundTask(a6),a1
        move.l  a0,ft_USP(a1)           ; save USP for background task
        IF      FW_ROUNDROBIN_MT_SUPPORT
        tst.b   LN_PRI(a1)
        bpl.s   .tasklocked
        move.l  a1,a2

        ; REMOVE
        move.l  (a2)+,a0
        move.l  (a2),a2 ; LN_PRED
        move.l  a0,(a2)
        move.l  a2,LN_PRED(a0)

        lea     fw_Tasks+LN_PRED(a6),a0
        ; ADDTAIL
        move.l  LN_PRED(a0),d0
        move.l  a1,LN_PRED(a0)
        exg     d0,a0
        movem.l d0/a0,(a1)
        move.l  a1,(a0)
.tasklocked
        ENDC

        clr.l   fw_BackgroundTask(a6)

        move.l  fw_PrimaryUSP(a6),a0    ; primary USP from before
        move.l  (a0)+,2(sp)             ; store return PC to exception frame (keep SR unchanged)
        move.l  a0,usp                  ; restore primary USP (now at position before calling the vblank wait)
        clr.l   fw_PrimaryUSP(a6)

        PUTMSG  50,<"Restoring USP %p">,a0
        move.l  fw_VBR(a6),a0
        move.l  fw_DefaultIRQ(a6),$6c(a0)

        lea     $dff000,a5
        move.w  #INTF_VERTB,intreq(a5)   ; acknowledge the vbl-irq.
        move.w  #INTF_VERTB,intreq(a5)   ; acknowledge the vbl-irq.
        addq.w  #1,fw_FrameCounter(a6)

        IF      (FW_MUSIC_SUPPORT&FW_VBL_MUSIC_IRQ)
        tst.w   fw_MusicEnabled(a6)
        beq.s   .skipmus
        bsr     fw_MusicPlay
.skipmus
        ENDC

        IF      FW_VBL_IRQ_SUPPORT
        move.l  fw_VBlankIRQ(a6),d0
        beq.s   .novbl1
        move.l  d0,a0
        ; IRQ may destroy everything here (except a5/a6)
        jsr     (a0)
.novbl1
        ENDC
        nop
        rte

;--------------------------------------------------------------------

fw_coppersync_backgroundtask_restore_irq:
        PUTMSG  50,<"MTINT %lx">,$dff000+intenar
        move.l  a6,-(sp)                ; save a6, we need a spare register
        move.l  usp,a6                  ; get USP
        PUTMSG  50,<"USP %p">,a6
        move.l  4+2(sp),-(a6)           ; store PC
        move.w  4(sp),-(a6)             ; store SR
        move.l  (sp)+,-(a6)             ; store a6 in stack frame
        movem.l d0-d7/a0-a5,-(a6)       ; store the rest of the registers
        move.l  a6,a0

        move.l  fw_BasePtr(pc),a6
        move.l  fw_BackgroundTask(a6),a1
        move.l  a0,ft_USP(a1)           ; save USP for background task
        IF      FW_ROUNDROBIN_MT_SUPPORT
        tst.b   LN_PRI(a1)
        bpl.s   .tasklocked
        move.l  a1,a2

        ; REMOVE
        move.l  (a2)+,a0
        move.l  (a2),a2 ; LN_PRED
        move.l  a0,(a2)
        move.l  a2,LN_PRED(a0)

        lea     fw_Tasks+LN_PRED(a6),a0
        ; ADDTAIL
        move.l  LN_PRED(a0),d0
        move.l  a1,LN_PRED(a0)
        exg     d0,a0
        movem.l d0/a0,(a1)
        move.l  a1,(a0)
.tasklocked
        ENDC

        clr.l   fw_BackgroundTask(a6)

        move.l  fw_PrimaryUSP(a6),a0    ; primary USP from before
        move.l  (a0)+,2(sp)             ; store return PC to exception frame (keep SR unchanged)
        move.l  a0,usp                  ; restore primary USP (now at position before calling the vblank wait)
        clr.l   fw_PrimaryUSP(a6)

        PUTMSG  50,<"Restoring USP %p">,a0
        move.l  fw_VBR(a6),a0
        move.l  fw_DefaultIRQ(a6),$6c(a0)

        lea     $dff000,a5
        move.w  #INTF_COPER,intreq(a5)   ; acknowledge the vbl-irq.
        move.w  #INTF_COPER,intreq(a5)   ; acknowledge the vbl-irq.
        addq.w  #1,fw_FrameCounter(a6)

        IF      (FW_MUSIC_SUPPORT&FW_VBL_MUSIC_IRQ)
        tst.w   fw_MusicEnabled(a6)
        beq.s   .skipmus
        bsr     fw_MusicPlay
.skipmus
        ENDC

        IF      FW_VBL_IRQ_SUPPORT
        move.l  fw_VBlankIRQ(a6),d0
        beq.s   .novbl1
        move.l  d0,a0
        ; IRQ may destroy everything here (except a5/a6)
        jsr     (a0)
.novbl1
        ENDC
        nop
        rte

;--------------------------------------------------------------------
; Allows to run a specific task in parallel to the blitter.
;
; Make sure the blitter has been started and will not terminate within
; a few cycles (otherwise it might lose the interrupt).
;
; Due to the overhead, this routine is best used for
; - larger blits with idle cycles
; - larger blits with no idle cycles, but with blitter hogging off and
;   slow CPU operations such as multiplications or division.
;
; Returns from this call, if either a blitter interrupt or VBL has
; occurred or the task finished execution. Thus you will still need to
; make sure that the blitter has finished before starting another blit.
; The task may be continued during another running blitter operation
; using YieldToBlitterTask. The task can be also finished ("joined")
; synchroneously using FinishBlitterTask.
;
; Compared to a blitter queue or normal background task, this allows more
; fine grained control over the operations to perform during specific blits.
; It also has little complexity overhead, works well when combining large
; (with bg task) and small (without separate task) blits.
;
; Although it might be possible to use this across VBL, it is not recommended.
; A VBL will interrupt the blitter task early even if the blitter is still
; running for some more time.
;
; Note: The task must preserve a5/a6 until exit! This task may not Yield!
; May only be called from the main task!
;
; Trashes all registers except for a5/a6
;
        IF      FW_BLITTERTASK_MT_SUPPORT
fw_AddAndRunBlitterTask:
        DISABLE_INTS
        move.w  #INTF_BLIT,intreq(a5)    ; clear the blitter-irq.
        move.l  a1,fw_BackgroundTask(a6)

.switch
        move.l  sp,fw_PrimaryUSP(a6)    ; store old stackpointer (pointing to RTS address)
        PUTMSG  50,<"Blitter TaskSwitch %p">,a1
        lea     ft_StackEnd(a1),sp
        clr.l   -(sp)               ; a little space for the task stackpointer
        pea     .cleanup(pc)        ; routine to call after RTS from backgroundtask
        move.l  a0,-(sp)            ; background task to jump to

        move.l  fw_VBR(a6),a0
        move.l  fw_BlitterTaskIRQ(a6),$6c(a0)
        move.w  #INTF_SETCLR|INTF_INTEN|INTF_BLIT,intena(a5)    ; enable interrupts, including blitter int
        rts

.cleanup
        move.w  #INTF_INTEN|INTF_BLIT,intena(a5)    ; disable interrupts, including blitter int
        move.w  #INTF_INTEN|INTF_BLIT,intena(a5)    ; disable interrupts, including blitter int
        ; FIXME do we have a race condition here? What happens if the blitter finishes right before this instruction?
        ;move.l  fw_BasePtr(pc),a6
        move.l  fw_PrimaryUSP(a6),d0
        bne.s   .irqcleanup
        move.l  (sp)+,sp                ; we're coming from FinishBlitterTask
        ENABLE_INTS
        rts
.irqcleanup
        PUTMSG  30,<"%d: blitter task finished">,fw_FrameCounterLong(a6)
        move.l  fw_VBR(a6),a0
        move.l  fw_DefaultIRQ(a6),$6c(a0)
        clr.l   fw_BackgroundTask(a6)   ; make sure we don't have a stray pointer
        move.l  d0,sp                   ; switch to primary task
        clr.l   fw_PrimaryUSP(a6)
        move.w  #INTF_BLIT,intena(a5)   ; disable blitter int again
        ENABLE_INTS
        rts

;--------------------------------------------------------------------
; Allows the current task to switch CPU to the current blitter task.
;
; Returns from this call immediately if the task was already finished.
; May return later if either a blitter interrupt or VBL has
; occurred or the task finished execution.
; The task can be also finished synchroneously using FinishBlitterTask.
;
; May only be called from the main task!
;
; In: a0 = task
; Trashes all registers except for a5/a6
;
fw_YieldToBlitterTask:
        move.l  fw_BackgroundTask(a6),d0
        beq.s   .noswitch
        DISABLE_INTS
        move.w  #INTF_BLIT,intreq(a5)   ; clear the blitter-irq.
        move.l  sp,fw_PrimaryUSP(a6)    ; store old stackpointer (pointing to RTS address)
        move.l  d0,a0
        move.l  ft_USP(a0),sp
        PUTMSG  40,<"Yielding to Blitter task %p (%s)">,a0,LN_NAME(a0)
        move.l  fw_VBR(a6),a0
        move.l  fw_BlitterTaskIRQ(a6),$6c(a0)
        movem.l (sp)+,d0-d7/a0-a6
        move.w  #INTF_SETCLR|INTF_INTEN|INTF_BLIT,intena(a5)    ; enable interrupts, including blitter int
        rtr
.noswitch
        PUTMSG  50,<"Blitter task not available">
        rts

;--------------------------------------------------------------------
; Finish Blitter parallel task outside of blitter action.
;
; Returns from this call, immediately if the task was already finished.
; Otherwise, runs the task until the end.
;
; May only be called from the main task!
;
; Trashes all registers except for a5/a6
;
fw_FinishBlitterTask:
        DISABLE_INTS
        move.l  fw_BackgroundTask(a6),d0
        bne.s   .doswitch
        PUTMSG  50,<"Blitter task not available">
        ENABLE_INTS
        rts

.doswitch
        move.l  d0,a0
        PUTMSG  50,<"Restoring Blitter Task %p">,a0
        clr.l   fw_BackgroundTask(a6)
        move.l  sp,ft_StackEnd-4(a0)
        move.l  ft_USP(a0),sp
        ENABLE_INTS
        movem.l (sp)+,d0-d7/a0-a6
        rtr

;--------------------------------------------------------------------

fw_blitter_task_irq:
        PUTMSG  50,<"BLINT %lx">,$dff000+intenar
        IF      FW_COPPER_IRQ_SUPPORT
        btst    #INTB_COPER,$dff000+intreqr+1
        bne     fw_copper_irq
        ENDC
        move.l  a6,-(sp)                ; save a6, we need a spare register
        move.l  usp,a6                  ; get USP
        PUTMSG  50,<"USP %p">,a6
        move.l  4+2(sp),-(a6)           ; store PC
        move.w  4(sp),-(a6)             ; store SR
        move.l  (sp)+,-(a6)             ; store a6 in stack frame
        movem.l d0-d7/a0-a5,-(a6)       ; store the rest of the registers
        move.l  a6,a0

        move.l  fw_BasePtr(pc),a6
        move.l  fw_BackgroundTask(a6),a1
        move.l  a0,ft_USP(a1)           ; save USP for background task

        move.l  fw_PrimaryUSP(a6),a0    ; primary USP from before
        move.l  (a0)+,2(sp)             ; store return PC to exception frame (keep SR unchanged)
        move.l  a0,usp                  ; restore primary USP (now at position before calling the vblank wait)
        clr.l   fw_PrimaryUSP(a6)

        lea     $dff000,a5
        move.w  #INTF_BLIT,intreq(a5)    ; acknowledge the blitter irq.
        move.w  #INTF_BLIT,intena(a5)    ; disable the blitter irq

        PUTMSG  50,<"Restoring USP %p">,a0
        move.l  fw_VBR(a6),a0
        move.l  fw_DefaultIRQ(a6),$6c(a0)

        nop
        rte

        ENDC
