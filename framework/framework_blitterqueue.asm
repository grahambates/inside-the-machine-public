;--------------------------------------------------------------------
; Interrupt-driven Blitter Queue
;
; Blitter queues may not be an optimal solution but they add a tool
; to the various ways of intertwining CPU and blitter activity.
;
; As there may be a rather large penalty for interrupt context
; switches (less so if FW_A5_A6_UNTOUCHED is activated),
; this implementation tries to reduce the overhead to a minimum.
;
; There are four basic ways to use the Blitter Queue:
;
; 1) Create and process blits in the same frame:
;    - [AddToBlitterQueue]*
;    - TerminateBlitterQueue
;    - TriggerBlitterQueue
;    - Do more CPU based stuff
;    - JoinBlitterQueue
;    - VSyncWithTask
;
; 2) Create stuff for the next frame, no queue double buffering:
;    - TriggerBlitterQueue
;    - Do CPU based stuff
;    - JoinBlitterQueue
;    - [AddToBlitterQueue]*
;    - TerminateBlitterQueue
;    - VSyncWithTask
;
; 3) Create stuff for the next frame, double buffered queue:
;    - TriggerBlitterQueue (the last one)
;    - [AddToBlitterQueue]* (the current one)
;    - TerminateBlitterQueue (the current one)
;    - Do more CPU based stuff
;    - JoinBlitterQueue
;    - VSyncWithTask
;
; 4) Create and run stuff in parallel with the current frame:
;    - [AppendToRunningBlitterQueue, do more CPU based stuff]*
;    - TerminateBlitterQueue
;    - JoinBlitterQueue
;    - VSyncWithTask
;
; 5) Create and run stuff in parallel with the current frame (alternate):
;    - [AddToBlitterQueue]* (makes sense if there is not much to prepare)
;    - TriggerBlitterQueue
;    - [AppendToRunningBlitterQueue, do more CPU based stuff]*
;    - TerminateBlitterQueue
;    - JoinBlitterQueue
;    - VSyncWithTask
;
; Each blit is stored in a BlitterQueueNode with consists of a
; linking pointer (singly linked list) and the pointer to routine
; for setting up the next blit.
; Optional parameters should follow after this field and are
; available to the callee via a0.
;
; When called, a5/a6 are filled with standard values ($dff000 and
; framework base address). a0 points to bq_Data,
; a1 holds the address of the routine stored in bq_Routine.
;
; Your routine may trash a0/a1/d0, all other registers must be
; preserved! The Z flag at exit determines whether the blit should
; be executed synchronously (blitter hogging will be activated).
; This makes sense if the blit is very short and a context switch
; is not reasonable. Except for a blit of 1024x1024 pixels,
; setting bltsize as a last instruction before RTS will clear Z
; and make the routine asynchronous. If you want it synchroneously,
; the last instruction before RTS could be a moveq.l #0,d0.
; In this case you must ensure the blitter is NOT running when
; your routine exits (e.g. with a blitter wait).
;
; Usually your routine MUST start the blitter -- the only exception
; is when setting the Z condition code at the exit of the routine.
; This can be used e.g. for common setup (like for line drawing)
; to reduce the amount of work done in a series of blits.
; You can also issue a BLTWAIT as the last "instruction" of your
; routine to make it a synchronous blit (no context switch).
;
; If you are absolutely sure that no routine of your main code loop
; will modify a5 or a6 while the blitter queue is running, you may
; turn on the FW_A5_A6_UNTOUCHED switch, which will reduce the
; context switch time even further by not saving/loading/restoring
; these two registers during the interrupt.
; (Otherwise, disabling interrupts for the periods where you need to
; modify a5/a6 may be an option, if the routines don't take too long)
;
; Amiga effects are supposed to be one-frame :) Your blitter queue
; must start its last blit before the vertical blank. Otherwise,
; havoc will happen.
; If you plan to use blitter queues that span several frames,
; please be aware that you need to call SetBlitterQueueMultiFrame,
; which is slightly slower because it will check which interrupt
; occurred. Otherwise please call SetBlitterQueueSingleFrame once.
;
; Blitter queues may NOT be combined with Blitter tasks for obvious
; reasons, but having background tasks and calling VSyncWithTask
; is perfectly fine, IF you make sure that you have joined the queue
; with JoinBlitterQueue before calling VSyncWithTask.
;
; To start a new blit, it takes around 3/4 of a raster line in ideal
; conditions. Calculate with an overhead of one rasterline per blit.
;
; Advanced use:
; You can modify fw_BlitterQueueReadPtr(a6) within a routine for
; branching and looping etc. by changing the next queue node to be
; executed. If you want to terminate the queue, don't set it to
; zero directly, but point it to a node with bq_Next set to zero
; and an empty (not null!) routine. Note that this only works
; reliably for blitter queues that are not extended while running!

;--------------------------------------------------------------------
; Adds a node to blitter queue
;
; This call will not start (trigger) the queue!
; If the queue is already being processed, it should append the
; node for later execution -- however, due to race conditions
; it is better to use AppendToBlitterQueue, which will also
; again trigger the queue if it ran out of blits.
;
; Each BlitterQueueNode should be entered with an empty bq_Next
; field (bq_Next may be random if at least the LAST node has it
; set to zero and the queue is not yet running!) and
; a bq_Routine pointer to a routine to be called.
;
; Note: there is also a macro ADD_TO_BLITTER_QUEUE to inline the
;       adding for even more speed, but in this case the queue
;       must not be empty!
;
; In: a0 = BlitterQueueNode
; Trashes: a1
;
fw_AddToBlitterQueue:
        lea     fw_BlitterQueueWritePtr(a6),a1
        tst.l   (a1)
        beq.s   .first
        move.l  (a1),a1
        PUTMSG  50,<"Add BQ Next %p after %p">,a0,a1
        move.l  a0,(a1)     ; bq_Next
        move.l  a0,fw_BlitterQueueWritePtr(a6)
        rts
.first  PUTMSG  50,<"Add BQ Init %p First">,a0
        move.l  a0,(a1)+    ; fw_BlitterQueueWritePtr
        move.l  a0,(a1)+    ; fw_BlitterQueueHeadPtr
        rts

;--------------------------------------------------------------------
; Appends a blitter node to a previously triggered queue
;
; Given a running blitter queue, this call will attempt to add a node
; to it.
; If the queue has run out of stuff to do, it will retrigger the
; queue automatically.
; If the last blit was still running, it will resume interrupt driven
; blitting (in fact, this also works with running blits that were not
; started from a blitter queue!).
;
; This call is slightly more complex than AddToBlitterQueue, so
; choose wisely.

; In: a0 = BlitterQueueNode
; Trashes: a0/a1/d0
;
fw_AppendToRunningBlitterQueue:
        PUTMSG  50,<"Append Head/Write/Read %p %p %p">,fw_BlitterQueueHeadPtr(a6),fw_BlitterQueueWritePtr(a6),fw_BlitterQueueReadPtr(a6)
        pea     .restints(pc)
        DISABLE_INTS
        tst.l   fw_BlitterQueueHeadPtr(a6)
        bne.s   fw_AddToBlitterQueue
        tst.l   fw_BlitterQueueReadPtr(a6)
        bne.s   fw_AddToBlitterQueue
        bsr.s   fw_AddToBlitterQueue
        btst    #DMAB_BLTDONE-8,dmaconr(a5)
        beq.s   fw_TriggerBlitterQueue
        PUTMSG  50,<"Install IRQ %p %p %p">,fw_BlitterQueueHeadPtr(a6),fw_BlitterQueueWritePtr(a6),fw_BlitterQueueReadPtr(a6)
        move.w  #INTF_BLIT,intreq(a5)    ; clear pending blitter int

        move.l  fw_VBR(a6),a1
        move.l  fw_BlitterQueueIRQ(a6),$6c(a1)
        move.w  #INTF_SETCLR|INTF_BLIT,intena(a5)    ; enable blitter int
        lea     fw_BlitterQueueHeadPtr(a6),a1
        move.l  (a1)+,(a1)  ; fw_BlitterQueueHeadPtr -> fw_BlitterQueueReadPtr
        clr.l   -(a1)       ; fw_BlitterQueueHeadPtr
        addq.w  #4,sp
        btst    #DMAB_BLTDONE-8,dmaconr(a5)
        bne.s   .restints
        move.w  #INTF_SETCLR|INTF_BLIT,intreq(a5)    ; set pending blitter int to avoid race condition
.restints
        ENABLE_INTS
        rts

;--------------------------------------------------------------------
; Terminates the blitter queue list
;
; Makes sure that the adding new nodes to will not contribute to a
; running blitter queue. Must be called before starting a new queue.
;
fw_TerminateBlitterQueue:
        clr.l  fw_BlitterQueueWritePtr(a6)
        rts

;--------------------------------------------------------------------
; Setup the blitter queue for multiple frames
;
; Selects the slightly slower interrupt routine that allows spilling
; of interrupt driven blits across a VBL.
;
; Either this function or SetBlitterQueueSingleFrame must be called
; at least once!
;
; NOTE: Even if you have a multi-frame blitter queue set up, you may
; NOT use VSyncWithTask unless you made sure the queue has been
; processed by calling JoinBlitterQueue. You still can call VSync
; of course.
;
; Trashes: a0
;
fw_SetBlitterQueueMultiFrame:
        lea     fw_blitter_queue_multiframe_irq(pc),a0
        move.l  a0,fw_BlitterQueueIRQ(a6)
        rts

;--------------------------------------------------------------------
; Setup the blitter queue for multiple frames
;
; Selects the slightly faster interrupt routine that does not care
; about a vertical blank interrupt and may crash or do fancy stuff
; if the blit before the last spills into the next frame.
;
; Either this function or SetBlitterQueueMultiFrame must be called
; at least once!
;
; Trashes: a0
;
fw_SetBlitterQueueSingleFrame:
        lea     fw_blitter_queue_irq(pc),a0
        move.l  a0,fw_BlitterQueueIRQ(a6)
        rts

;--------------------------------------------------------------------
; Triggers execution of the blitter queue.
;
; Starts the current queue if it is not empty.
; Warning: You MUST make sure the blitter is NOT busy when calling
; this. It is up to you if you want to start the blitter with
; hogging or not (you can control this in your routines as well,
; of course!). Blitter hogging on makes only sense if you will have
; blits with IDLE frames!
;
; NOTE! You MUST join the blitter queue before waiting for the next
; vertical blank because a running interrupt driven blitter queue
; is not compatible with multitasking!
;
; Trashes: a0/a1/d0
;
fw_TriggerBlitterQueue:
        PUTMSG  50,<"Trigger Head/Write/Read %p %p %p">,fw_BlitterQueueHeadPtr(a6),fw_BlitterQueueWritePtr(a6),fw_BlitterQueueReadPtr(a6)
        move.l  fw_BlitterQueueHeadPtr(a6),d0
        bne.s   .cont
        PUTMSG  50,<"BQ empty">
        rts
.cont
        clr.l   fw_BlitterQueueHeadPtr(a6)
        move.l  d0,a0
fw_TriggerCustomBlitterQueue:
        PUTMSG  50,<"Exe BQ %p">,a0
        move.l  (a0)+,fw_BlitterQueueReadPtr(a6)
        beq.s   .onlyone

        move.w  #INTF_BLIT,intena(a5)    ; disable blitter int
        move.w  #INTF_BLIT,intena(a5)    ; disable blitter int

.allsyncloop
        move.w  #INTF_BLIT,intreq(a5)    ; clear pending blitter int

        move.l  (a0)+,a1
        jsr     (a1)
        bne.s   .activate
        move.l  fw_BlitterQueueReadPtr(a6),a0
        move.l  (a0)+,fw_BlitterQueueReadPtr(a6)
        bne.s   .allsyncloop
.lastwasalsosync
.onlyone
        cmp.l   fw_BlitterQueueWritePtr(a6),d0
        bne.s   .noconflict
        PUTMSG  50,<"Trigger caught up">
        clr.l   fw_BlitterQueueWritePtr(a6)
.noconflict
        PUTMSG  50,<"BQ Trigger Last!">
        move.l  (a0)+,a1
        jmp     (a1)
.activate
        PUTMSG  50,<"Activate!">
        move.l  fw_VBR(a6),a0
        move.l  fw_BlitterQueueIRQ(a6),$6c(a0)
        move.w  #INTF_SETCLR|INTF_BLIT,intena(a5)    ; enable blitter int
        rts

;--------------------------------------------------------------------
; Makes the blitter queue synchronous again -- no longer causes
; interrupts and will restore normal multitasking operation.
;
; The last blit might still be running when this function returns!
;
; Trashes: a0/a1/d0
;
fw_JoinBlitterQueue:
        PUTMSG  50,<"Join Head/Write/Read %p %p %p">,fw_BlitterQueueHeadPtr(a6),fw_BlitterQueueWritePtr(a6),fw_BlitterQueueReadPtr(a6)
        move.w  #INTF_INTEN|INTF_BLIT,intena(a5)    ; disable main and blitter int
        move.w  #INTF_INTEN|INTF_BLIT,intena(a5)    ; disable main and blitter int
        tst.l   fw_BlitterQueueReadPtr(a6)
        beq.s   .done
        PUTMSG  50,<"Joining blitter queue">
        move.l  fw_VBR(a6),a0
        move.l  fw_DefaultIRQ(a6),$6c(a0)
        ENABLE_INTS
.retry
        move.l  fw_BlitterQueueReadPtr(a6),a0
        PUTMSG  50,<"BQ Next %p">,a0
        move.l  (a0)+,fw_BlitterQueueReadPtr(a6)
        beq.s   .last
        pea     .retry(pc)
.last
        move.l  (a0)+,a1                ; bq_Routine
        BLTHOGON
        BLTWAIT
        BLTHOGOFF
        jmp     (a1)
.done
        ENABLE_INTS
        rts

;--------------------------------------------------------------------

fw_blitter_queue_multiframe_irq:
        btst    #INTB_VERTB,$dff000+intreqr+1
        bne     fw_vblank_standard_irq
fw_blitter_queue_irq:
        PUTMSG  50,<"BQINT %lx">,$dff000+intenar
        IF      FW_COPPER_IRQ_SUPPORT
        btst    #INTB_COPER,$dff000+intreqr+1
        bne     fw_copper_irq
        ENDC
        IF      FW_A5_A6_UNTOUCHED
        PUSHM   d0/a0/a1
        ELSE
        PUSHM   d0/a0/a1/a5/a6
        lea     $dff000,a5
        move.l  fw_BasePtr(pc),a6
        ENDC
.retry
        move.w  #INTF_BLIT,intreq(a5)   ; acknowledge the blitter irq.
        move.l  fw_BlitterQueueReadPtr(a6),a0
        PUTMSG  50,<"BQ Next Head/Write/Read %p %p %p">,fw_BlitterQueueHeadPtr(a6),fw_BlitterQueueWritePtr(a6),a0
        move.l  (a0)+,fw_BlitterQueueReadPtr(a6)
        beq.s   .last
        move.l  (a0)+,a1                ; bq_Routine
        jsr     (a1)
        beq.s   .retry
        ; this has some issues regarding starvation e.g. if you're spamming
        ; lots of hogging zero-idle blits across VBL, e.g. music code will not execute in time.
        ;btst    #DMAB_BLTDONE-8,dmaconr(a5)
        ;beq.s   .retry
.finished
        POPM    NOBUMP
        nop
        rte
.last
        PUTMSG  50,<"BQ Last!">
        move.w  #INTF_BLIT,intena(a5)   ; disable blitter int
        lea     -4(a0),a1
        cmp.l   fw_BlitterQueueWritePtr(a6),a1
        bne.s   .noconflict
        PUTMSG  50,<"Caught up">
        clr.l   fw_BlitterQueueWritePtr(a6)
.noconflict
        move.l  (a0)+,a1                ; bq_Routine
        jsr     (a1)
        move.l  fw_VBR(a6),a0
        move.l  fw_DefaultIRQ(a6),$6c(a0)
        POPM
        nop
        rte
