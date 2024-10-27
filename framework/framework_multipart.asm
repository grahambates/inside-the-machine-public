;--------------------------------------------------------------------
; Multipart support for trackmos
;
; In my former demo system I used a6 as a base pointer to the demo
; framework and a4 as a pointer to my demo part variables. That
; seemed a bit wasteful and so the new system uses one pointer for
; both framework AND part variables for the current part. This,
; however, means that the framework base needs to be relocated
; depending on the part because, of course, the size of the
; local variables may vary.
;
; You must start your local variable space with
;
;    STRUCTURE   PartData,fw_SIZEOF
;
; and end it with
;
;        LABEL   pd_SIZEOF
;
;--------------------------------------------------------------------
; Allocate the part variables
;
; The first thing each demo part needs to do is to call InitPart.
; I repeat: Start your code with:
;        IFD     FW_DEMO_PART
;        move.l  #pd_SIZEOF,d0
;        CALLFW  InitPart
;        ENDC
;
; Otherwise, no part variables are available via a6 and no other
; framework calls can be made (the jumping table is not available).
;
; After this call, a6 will be pointing to the new framework base
; with all your variable space cleared.
;
; Make sure that you don't free the memory allocated here until
; the end of your part! The demo framework will call 
; RestoreFrameworkBase automatically at exit of your part.
;
; Flushes the caches (if available), too.
;
; In : d0 = pd_SIZEOF (part data structure size including fw_SIZEOF)
; Out: a6 = new base pointer
; Trashes: everything except a5/a6
;
fw_InitPart:
        PUTMSG  10,<"%d: InitPart(%ld)">,fw_FrameCounterLong(a6),d0
        PUSHM   d0
        bsr     fw_RestoreFrameworkBase
        POPM

        DISABLE_INTS
        move.l  fw_PartFwBase(a6),a0
        move.l  d0,fw_PartDataSize(a6)
        add.l   #-FWLVOPOS,d0
        bsr     fw_AllocFast
        lea     -FWLVOPOS(a0),a1
        PUTMSG  40,<"LVOs from %p to %p">,a1,a0
        move.l  a6,a0
        move.l  a6,a3
        move.l  a1,a6
        move.w  #(fw_SIZEOF/4)-1,d7
        PUTMSG  40,<"Copying %d LW from %p to %p">,d7,a0,a1
.copynew
        move.l  (a0)+,(a1)+
        dbra    d7,.copynew

        move.l  a6,fw_PartFwBase(a6)
        move.l  fw_PartDataSize(a6),d7
        sub.l   #fw_SIZEOF,d7
        addq.w  #3,d7
        lsr.w   #2,d7
        beq.s   .skipclr
        subq.w  #1,d7
        moveq.l #0,d0
.clrnew
        move.l  d0,(a1)+
        dbra    d7,.clrnew
.skipclr
        move.l  a6,a0
        lea     fw_lvo_offsets(pc),a1
.lvoloop
        move.w  (a1)+,d0
        beq.s   .lvodone
        lea     -2(a1,d0.w),a2
        move.l  a2,-(a0)
        move.w  #%0100111011111001,-(a0) ; $4ef9 jmp x.L
        bra.s   .lvoloop
.lvodone

        IF      FW_MULTITASKING_SUPPORT
        ; The task list header is now broken after copying! We need to fix it.
        lea     fw_Tasks(a6),a1
        bsr     fw_RelocateList
        bsr     fw_FixA6BaseInTaskStacks
        ENDC

        lea     fw_BasePtr(pc),a0
        move.l  a6,(a0)
        bsr     fw_FlushCaches
        ENABLE_INTS
        PUTMSG  20,<"%d: InitPart done %p">,fw_FrameCounterLong(a6),a6
        rts

;--------------------------------------------------------------------
; Restore global framework base
;
; Removes the custom framework variable space and makes the global
; one active again.
;
; Out: a6 = new base pointer
; Trashes: everything except a5/a6
;
fw_RestoreFrameworkBase:
        PUTMSG  10,<"%d: RestoreFrameworkBase(%p)">,fw_FrameCounterLong(a6),a6
        DISABLE_INTS
        move.l  fw_PartFwBase(a6),a0
        move.l  fw_PrimaryFwBase(a6),a1
        PUTMSG  40,<"Part %p, Primary %p">,a0,a1
        cmp.l   a1,a0
        beq.s   .noold
        move.l  a0,a3
        PUTMSG  40,<"Restore from %p to %p">,a0,a1
        move.l  a1,a6
        move.w  #(fw_SIZEOF/4)-1,d7
.copyold
        move.l  (a0)+,(a1)+
        dbra    d7,.copyold

        IF      FW_MULTITASKING_SUPPORT
        bsr     fw_FixA6BaseInTaskStacks
        ENDC

        move.l  a6,fw_PartFwBase(a6)
        clr.l   fw_PartDataSize(a6)

        IF      FW_MULTITASKING_SUPPORT
        ; The task list header is now broken after copying! We need to fix it.
        lea     fw_Tasks(a6),a1
        bsr.s   fw_RelocateList
        ENDC

        lea     fw_BasePtr(pc),a0
        move.l  a6,(a0)
.noold
        ENABLE_INTS
        rts

;--------------------------------------------------------------------
; Helper function to relocate a doubly-linked list
;
; When relocating the framework base structure, we need to fix the
; contents of lists, otherwise BadThings(TM) will happen.
; This function goes through the relocated list and fixes the linkage.
;
; In: a1 = ListHead
; Trashes: a0/a1
;
        IF      FW_MULTITASKING_SUPPORT
fw_RelocateList:
        move.l  LH_HEAD(a1),a0
        subq.l  #4,a0
        cmp.l   LH_TAILPRED(a1),a0
        bne.s   .nonewlist
        PUTMSG  10,<"Fixup empty list %p">,a1
        move.l  a1,LH_TAILPRED(a1)  ; fix empty list
        addq.l  #4,a1
        move.l  a1,-(a1)
        bra.s   .listfixed
.nonewlist
        PUTMSG  10,<"Fixup existing list %p">,a1
        move.l  a1,4+LN_PRED(a0)        ; fixup LN_PRED of first node (points to LH_HEAD)
        move.l  LH_TAILPRED(a1),a0  ; get last node
        addq.l  #4,a1           ; now points to LH_TAIL
        move.l  a1,LN_SUCC(a0)  ; fixup LN_SUCC of last node (pointing to LH_TAIL)
.listfixed
        rts
        ENDC

;--------------------------------------------------------------------
; Running tasks will have the old framework base stored in their
; register context. We need to fix these occurrences. Note that
; this is not completely fool-proof, but should work for 99% of the
; cases (there shouldn't be framework-relative things).
;
; In: a3 = old base
;     a6 = new base
fw_FixA6BaseInTaskStacks:
        lea     fw_Tasks(a3),a1
.loop
        TSTNODE a1,a1
        beq.s   .done
        move.l  ft_USP(a1),a0
        lea     ft_StackEnd(a1),a2
.findloop
        cmp.l   a0,a2
        beq.s   .loop
        cmp.l   (a0),a3
        bne.s   .notmatched
        PUTMSG  10,<"Replacing base at %p">,a0
        move.l  a6,(a0)
.notmatched
        addq.l  #2,a0
        bra.s   .findloop
.done   rts


fw_lvo_offsets:
FWGENLVOTABLE SET 1
        include "../framework/framework_lvos.i"
        dc.w    0
FWGENLVOTABLE SET 0
