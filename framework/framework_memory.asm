;--------------------------------------------------------------------
DEBUGMEM MACRO
        IFGE    DEBUG_DETAIL-10
        bsr     fw_DebugMemoryManagement
        ENDC
        ENDM

;--------------------------------------------------------------------
; Initializes the memory stacks for chip- and fast-mem
;
fw_InitMemoryManagement:
        move.l  fw_ChipMemStack(a6),d0
        move.l  fw_ChipMemStackEnd(a6),d1
        move.l  fw_FastMemStack(a6),d2
        move.l  fw_FastMemStackEnd(a6),d3
        PUTMSG  10,<"Chipmem %p - %p, Fastmem %p - %p">,d0,d1,d2,d3

        lea     fw_MemBottomStack(a6),a1
        move.l  d0,cf_ChipMemLevel+mtb_CurrLevelPtr(a1)
        move.l  d0,cf_ChipMemLevel+mtb_MinLevelPtr(a1)
        move.l  d2,cf_FastMemLevel+mtb_CurrLevelPtr(a1)
        move.l  d2,cf_FastMemLevel+mtb_MinLevelPtr(a1)
        ;clr.w   fw_CurrMemBottomLevel(a6)

        lea     fw_MemTopStack(a6),a1
        move.l  d1,cf_ChipMemLevel+mtb_CurrLevelPtr(a1)
        move.l  d1,cf_ChipMemLevel+mtb_MinLevelPtr(a1)
        move.l  d3,cf_FastMemLevel+mtb_CurrLevelPtr(a1)
        move.l  d3,cf_FastMemLevel+mtb_MinLevelPtr(a1)
        ;clr.w   fw_CurrMemTopLevel(a6)

        DEBUGMEM
        rts

;--------------------------------------------------------------------
; Frees all allocated memory
;
; Frees the memory of the current stack and current direction.
; Memory of other allocation direction is unchanged.
;
fw_DropCurrentMemoryAllocations:
        PUTMSG  10,<"%d: DropCurrentMemoryAllocations">,fw_FrameCounterLong(a6)
        IFGE    DEBUG_DETAIL-20
        PUSHM   a0/a1/d0
        ELSE
        PUSHM   a1
        ENDC
        DEBUGMEM
        IF      FW_TOP_BOTTOM_MEM_SECTIONS
        bsr     fw_DetectAllocationDirection
        bne.s   .toptobottom
        ENDC
        PUTMSG  10,<"DOWN: Freeing all">
        lea     fw_MemBottomStack(a6),a1
        adda.w  fw_CurrMemBottomLevel(a6),a1

        IFGE    DEBUG_DETAIL-20
        move.l  cf_ChipMemLevel+mtb_MinLevelPtr(a1),a0
        move.l  cf_ChipMemLevel+mtb_CurrLevelPtr(a1),d0
        sub.l   a0,d0
        bsr     fw_FillWithGarbage

        move.l  cf_FastMemLevel+mtb_MinLevelPtr(a1),a0
        move.l  cf_FastMemLevel+mtb_CurrLevelPtr(a1),d0
        sub.l   a0,d0
        bsr     fw_FillWithGarbage
        ENDC
.cont
        move.l  cf_ChipMemLevel+mtb_MinLevelPtr(a1),cf_ChipMemLevel+mtb_CurrLevelPtr(a1)
        move.l  cf_FastMemLevel+mtb_MinLevelPtr(a1),cf_FastMemLevel+mtb_CurrLevelPtr(a1)

        DEBUGMEM
        POPM
        rts
        IF      FW_TOP_BOTTOM_MEM_SECTIONS
.toptobottom
        PUTMSG  10,<"UP: Freeing all">
        lea     fw_MemTopStack(a6),a1
        adda.w  fw_CurrMemTopLevel(a6),a1

        IFGE    DEBUG_DETAIL-20
        move.l  cf_ChipMemLevel+mtb_CurrLevelPtr(a1),a0
        move.l  cf_ChipMemLevel+mtb_MinLevelPtr(a1),d0
        sub.l   a0,d0
        bsr     fw_FillWithGarbage

        move.l  cf_FastMemLevel+mtb_CurrLevelPtr(a1),a0
        move.l  cf_FastMemLevel+mtb_MinLevelPtr(a1),d0
        sub.l   a0,d0
        bsr     fw_FillWithGarbage
        ENDC
        bra.s   .cont
        ENDC

;--------------------------------------------------------------------
; Pushes the current memory allocation state to the stack
;
; This only pushes the state for the current memory allocation
; direction onto the stack. All allocated memory upto this point
; will be kept safe and will no longer be freed automatically.
;
fw_PushMemoryState:
        PUSHM   a1/d0-d1

        moveq.l #cf_SIZEOF,d0
        IF      FW_TOP_BOTTOM_MEM_SECTIONS
        bsr     fw_DetectAllocationDirection
        bne.s   .toptobottom
        ENDC
        PUTMSG  10,<"UP: ++++++ Pushing mem state ++++++">

        add.w   fw_CurrMemBottomLevel(a6),d0
        move.w  d0,fw_CurrMemBottomLevel(a6)
        lea     fw_MemBottomStack(a6,d0.w),a1
.cont
        move.l  cf_ChipMemLevel+mtb_CurrLevelPtr-cf_SIZEOF(a1),d0
        move.l  cf_FastMemLevel+mtb_CurrLevelPtr-cf_SIZEOF(a1),d1
        move.l  d0,cf_ChipMemLevel+mtb_CurrLevelPtr(a1)
        move.l  d0,cf_ChipMemLevel+mtb_MinLevelPtr(a1)
        move.l  d1,cf_FastMemLevel+mtb_CurrLevelPtr(a1)
        move.l  d1,cf_FastMemLevel+mtb_MinLevelPtr(a1)
        DEBUGMEM
        POPM
        rts
        IF      FW_TOP_BOTTOM_MEM_SECTIONS
.toptobottom
        PUTMSG  10,<"DOWN: ++++++ Pushing mem state ++++++">
        add.w   fw_CurrMemTopLevel(a6),d0
        move.w  d0,fw_CurrMemTopLevel(a6)
        lea     fw_MemTopStack(a6,d0.w),a1
        bra.s   .cont
        ENDC

;--------------------------------------------------------------------
; Restore the last memory state from the memory stack for the current
; allocation direction. All memory from the previous allocation is
; freed.
;
; With debug enabled, freed memory is also overwritten with garbage.
;
; Out: All registers unchanged.
;
fw_PopMemoryState:
        PUSHM   a0/d0
        DEBUGMEM

        IF      FW_TOP_BOTTOM_MEM_SECTIONS
        bsr     fw_DetectAllocationDirection
        bne     .toptobottom
        ENDC
        IFGE    DEBUG_DETAIL-10
        PUTMSG  10,<"UP: ------ Popping mem state ------">
        bsr     fw_DropCurrentMemoryAllocations
        sub.w   #cf_SIZEOF,fw_CurrMemBottomLevel(a6)
        bmi.s   .errorbottom
        ELSE
        sub.w   #cf_SIZEOF,fw_CurrMemBottomLevel(a6)
        ENDC
.cont
        DEBUGMEM
        POPM
        rts
        IFGE    DEBUG_DETAIL-10
.errorbottom
        PUTMSG  10,<"!!! Could not pop bottom memory stack (TOP: %d vs %d)">,fw_CurrMemBottomLevel-2(a6),fw_CurrMemTopLevel-2(a6)
        move.w  #ERROR_MEMORYWRONGPOP,d0
        bra     fw_Error
.errortop
        PUTMSG  10,<"!!! Could not pop top memory stack (TOP: %d vs %d)">,fw_CurrMemBottomLevel-2(a6),fw_CurrMemTopLevel-2(a6)
        move.w  #ERROR_MEMORYWRONGPOP,d0
        bra     fw_Error
        ENDC
        IF      FW_TOP_BOTTOM_MEM_SECTIONS
.toptobottom
        IFGE    DEBUG_DETAIL-10
        PUTMSG  10,<"DOWN: ------ Popping mem state ------">
        bsr     fw_DropCurrentMemoryAllocations
        sub.w   #cf_SIZEOF,fw_CurrMemTopLevel(a6)
        bmi     .errortop
        ELSE
        sub.w   #cf_SIZEOF,fw_CurrMemTopLevel(a6)
        ENDC
        bra     .cont
        ENDC

;--------------------------------------------------------------------
; Allocates the given amount of fastmem in the current direction of
; memory allocation (bottom->top or top->bottom).
;
; If theres not enough fast-mem, it falls back and returns chip-mem
; instead.
;
; Contents of memory are not cleared!
;
; In : d0: Size in bytes
; Out: a0: Start of memory allocation
;      d0: Rounded size of allocation
;      d1/a1: Trashed.
;
fw_AllocFast:
        PUTMSG  10,<"%d: AllocFast(%ld)">,fw_FrameCounterLong(a6),d0
        addq.l  #3,d0
        and.w   #-4,d0

        lea     fw_MemBottomStack(a6),a0
        adda.w  fw_CurrMemBottomLevel(a6),a0
        lea     fw_MemTopStack(a6),a1
        adda.w  fw_CurrMemTopLevel(a6),a1

        move.l  cf_FastMemLevel+mtb_CurrLevelPtr(a1),d1
        sub.l   cf_FastMemLevel+mtb_CurrLevelPtr(a0),d1
        cmp.l   d0,d1
        blo.s   fw_AllocChip

        moveq.l #cf_FastMemLevel,d1
        bsr     fw_DoAllocation
        PUTMSG  30,<"Fast allocated at %p">,a0
        IFGE    DEBUG_DETAIL-12
        bsr     fw_FillWithGarbage
        ENDC
        DEBUGMEM
        rts

;--------------------------------------------------------------------
; Allocates the given amount of chipmem in the current direction of
; memory allocation (bottom->top or top->bottom).
;
; Contents of memory are not cleared!
;
; In : d0: Size in bytes
; Out: a0: Start of memory allocation
;      d0: Rounded size of allocation
;      d1/a1: Trashed.
;
fw_AllocChip:
        PUTMSG  10,<"%d: AllocChip(%ld)">,fw_FrameCounterLong(a6),d0
        addq.l  #7,d0
        and.w   #-8,d0

        lea     fw_MemBottomStack(a6),a0
        adda.w  fw_CurrMemBottomLevel(a6),a0
        lea     fw_MemTopStack(a6),a1
        adda.w  fw_CurrMemTopLevel(a6),a1

        move.l  cf_ChipMemLevel+mtb_CurrLevelPtr(a1),d1
        sub.l   cf_ChipMemLevel+mtb_CurrLevelPtr(a0),d1
        cmp.l   d0,d1
        blo.s   .error

        moveq.l #cf_ChipMemLevel,d1
        bsr     fw_DoAllocation

        PUTMSG  30,<"Chip allocated at %p">,a0
        IFGE    DEBUG_DETAIL-12
        bsr     fw_FillWithGarbage
        ENDC
        DEBUGMEM
        rts
.error
        PUTMSG  10,<"Out of memory: %ld smaller than %ld">,d1,d0
        DEBUGMEM
        move.w  #ERROR_OUTOFMEMORY,d0
        bra     fw_Error

;--------------------------------------------------------------------
; Allocates the given amount of chipmem within a 64 KB page in the
; current direction of memory allocation.
;
; Memory area returned is guaranteed not to cross a 64 KB page
; boundary for the given size. Depending on the current memory
; situation and size requirements, may waste up to 64 KB of memory
; in the worst case. If you need multiple allocations these
; requirements, make sure to cluster them in a good way.
;
; Contents of memory are not cleared!
;
; In : d0: Size in bytes (less or equal to 64 KB!)
; Out: a0: Start of memory allocation
;      d0: Rounded size of allocation
;      d1/a1: Trashed.
;
        IF      FW_64KB_PAGE_MEMORY_SUPPORT
fw_AllocChip64KB:
        PUTMSG  10,<"%d: AllocChip64KB(%ld)">,fw_FrameCounterLong(a6),d0
        addq.l  #7,d0
        and.w   #-8,d0

        lea     fw_MemBottomStack(a6),a0
        adda.w  fw_CurrMemBottomLevel(a6),a0
        lea     fw_MemTopStack(a6),a1
        adda.w  fw_CurrMemTopLevel(a6),a1

.retry
        move.l  cf_ChipMemLevel+mtb_CurrLevelPtr(a1),d1
        sub.l   cf_ChipMemLevel+mtb_CurrLevelPtr(a0),d1
        cmp.l   d0,d1
        blo     .error

        IF      FW_TOP_BOTTOM_MEM_SECTIONS
        bsr     fw_DetectAllocationDirection
        bne.s   .toptobottom
        ENDC

        move.l  cf_ChipMemLevel+mtb_CurrLevelPtr(a0),d1
        add.l   d0,d1
        subq.l  #1,d1
        swap    d1
        cmp.w   cf_ChipMemLevel+mtb_CurrLevelPtr(a0),d1
        beq     .doallocation

        addq.w  #1,cf_ChipMemLevel+mtb_CurrLevelPtr(a0)
        IFGE    DEBUG_DETAIL-10
        moveq.l #0,d1
        move.w  cf_ChipMemLevel+mtb_CurrLevelPtr+2(a0),d1
        neg.w   d1
        PUTMSG  10,<"Skipping %ld bytes of memory DOWN (sorry)">,d1
        ENDC
        clr.w   cf_ChipMemLevel+mtb_CurrLevelPtr+2(a0)
        bra.s   .retry

        IF      FW_TOP_BOTTOM_MEM_SECTIONS
.toptobottom
        moveq.l #0,d1
        move.w  cf_ChipMemLevel+mtb_CurrLevelPtr+2(a1),d1
        beq.s   .doallocation
        cmp.l   d0,d1
        bge.s   .doallocation

        PUTMSG  10,<"Skipping %d bytes of memory UP (sorry)">,cf_ChipMemLevel+mtb_CurrLevelPtr(a1)
        clr.w   cf_ChipMemLevel+mtb_CurrLevelPtr+2(a1)
        bra     .retry
        ENDC

.doallocation
        moveq.l #cf_ChipMemLevel,d1
        bsr     fw_DoAllocation

        PUTMSG  30,<"Chip within 64 KB page allocated at %p">,a0
        IFGE    DEBUG_DETAIL-20
        bsr     fw_FillWithGarbage
        ENDC
        DEBUGMEM
        rts
.error
        PUTMSG  10,<"Out of memory: %ld smaller than %ld">,d1,d0
        DEBUGMEM
        move.w  #ERROR_OUTOFMEMORY,d0
        bra     fw_Error
        ENDC

;--------------------------------------------------------------------
; Changes the direction of memory allocation (bottom to top vs top
; to bottom). Also works from subtasks (be a bit careful there).
;
; Out: All registers unchanged.
;
        IF      FW_TOP_BOTTOM_MEM_SECTIONS
fw_FlipAllocationDirection:
        IF      FW_MULTITASKING_SUPPORT
        tst.l   fw_BackgroundTask(a6)
        beq.s   .flipmain
        PUSHM   a0
        move.l  fw_BackgroundTask(a6),a0
        eor.w   #1,ft_MemDirection(a0)
        PUTMSG  10,<"Flipping allocation direction of task %p (%s) to %d">,a0,LN_NAME(a0),ft_MemDirection-2(a0)
        POPM
        rts
        ENDC
.flipmain
        eor.w   #1,fw_MainMemDirection(a6)
        PUTMSG  10,<"Flipping main allocation direction to %d">,fw_MainMemDirection-2(a6)
        rts

;--------------------------------------------------------------------

fw_DetectAllocationDirection:
        IF      FW_MULTITASKING_SUPPORT
        tst.l   fw_BackgroundTask(a6)
        beq.s   .flipmain
        PUSHM   a0/d0 ; avoid optimizing the movem to move so that the CCs remain intact
        move.l  fw_BackgroundTask(a6),a0
        tst.w   ft_MemDirection(a0)
        POPM
        rts
        ENDC
.flipmain
        tst.w   fw_MainMemDirection(a6)
        rts
        ENDC

;--------------------------------------------------------------------

fw_DoAllocation:
        PUSHM   a1/d0/d1
        IF      FW_TOP_BOTTOM_MEM_SECTIONS
        bsr     fw_DetectAllocationDirection
        bne.s   .toptobottom
        ENDC
        ; allocate from bottom
        lea     fw_MemBottomStack(a6),a1
        adda.w  fw_CurrMemBottomLevel(a6),a1
        move.l  mtb_CurrLevelPtr(a1,d1.w),a0
        PUTMSG  10,<"UP: Allocating %ld bytes from bottom at %p">,d0,a0
        add.l   a0,d0
        move.l  d0,mtb_CurrLevelPtr(a1,d1.w)
.cont
        POPM
        rts
        IF      FW_TOP_BOTTOM_MEM_SECTIONS
.toptobottom
        ; allocate from top
        lea     fw_MemTopStack(a6),a1
        adda.w  fw_CurrMemTopLevel(a6),a1
        move.l  mtb_CurrLevelPtr(a1,d1.w),a0
        sub.l   d0,a0
        PUTMSG  10,<"DOWN: Allocating %ld bytes from top at %p">,d0,a0
        move.l  a0,mtb_CurrLevelPtr(a1,d1.w)
        bra.s   .cont
        ENDC

;--------------------------------------------------------------------

        IFGE    DEBUG_DETAIL-12
fw_FillWithGarbage:
        PUTMSG  10,<"Filling with garbage %p (%ld)">,a0,d0
        PUSHM   a0/d0/d1
        lsr.l   #2,d0
        beq.s   .skipfill
        subq.w  #1,d0
        move.l  #$DEADBE00,d1
.fillloop
        move.l  d1,(a0)+
        addq.l  #1,d1
        dbra    d0,.fillloop
        swap    d0
        subq.w  #1,d0
        bcs.s   .skipfill
        swap    d0
        bra.s   .fillloop
.skipfill
        POPM
        rts
        ENDC

;--------------------------------------------------------------------

        IFGE    DEBUG_DETAIL-10
fw_DebugMemoryManagement:
        PUSHM   d0-d7/a0/a1
        lea     fw_MemBottomStack(a6),a0
        adda.w  fw_CurrMemBottomLevel(a6),a0
        lea     fw_MemTopStack(a6),a1
        adda.w  fw_CurrMemTopLevel(a6),a1

        move.l  cf_ChipMemLevel+mtb_CurrLevelPtr(a1),d0 ; current free chip: chip top - bottom
        sub.l   cf_ChipMemLevel+mtb_CurrLevelPtr(a0),d0
        lsr.l   #8,d0
        lsr.w   #2,d0

        move.l  fw_MemTopStack+cf_ChipMemLevel+mtb_MinLevelPtr(a6),d1  ; max free chip within this frame
        sub.l   cf_ChipMemLevel+mtb_MinLevelPtr(a0),d1
        lsr.l   #8,d1
        lsr.w   #2,d1

        move.l  cf_ChipMemLevel+mtb_CurrLevelPtr(a0),d2 ; bottom chip allocated in stack
        sub.l   cf_ChipMemLevel+mtb_MinLevelPtr(a0),d2
        lsr.l   #8,d2
        lsr.w   #2,d2

        move.l  cf_ChipMemLevel+mtb_MinLevelPtr(a1),d3 ; top chip allocated in stack
        sub.l   cf_ChipMemLevel+mtb_CurrLevelPtr(a1),d3
        lsr.l   #8,d3
        lsr.w   #2,d3

        move.l  cf_FastMemLevel+mtb_CurrLevelPtr(a1),d4 ; current free fast: fast top - bottom
        sub.l   cf_FastMemLevel+mtb_CurrLevelPtr(a0),d4
        lsr.l   #8,d4
        lsr.w   #2,d4

        move.l  cf_FastMemLevel+mtb_MinLevelPtr(a1),d5  ; max free fast within this frame
        sub.l   fw_MemBottomStack+cf_FastMemLevel+mtb_MinLevelPtr(a6),d5
        lsr.l   #8,d5
        lsr.w   #2,d5

        move.l  cf_FastMemLevel+mtb_CurrLevelPtr(a0),d6 ; bottom fast allocated in stack
        sub.l   cf_FastMemLevel+mtb_MinLevelPtr(a0),d6
        lsr.l   #8,d6
        lsr.w   #2,d6

        move.l  cf_FastMemLevel+mtb_MinLevelPtr(a1),d7 ; top fast allocated in stack
        sub.l   cf_FastMemLevel+mtb_CurrLevelPtr(a1),d7
        lsr.l   #8,d7
        lsr.w   #2,d7

        PUTMSG  10,<"Mem Free: Chip: %ld of %ld KB (%ld/%ld KB) | Fast: %ld of %ld KB (%ld/%ld KB)">,d0,d1,d2,d3,d4,d5,d6,d7

        move.l  cf_ChipMemLevel+mtb_CurrLevelPtr(a0),d0 ; bottom chip allocated total
        sub.l   fw_MemBottomStack+cf_ChipMemLevel+mtb_MinLevelPtr(a6),d0
        add.l   fw_MemTopStack+cf_ChipMemLevel+mtb_MinLevelPtr(a6),d0 ; top chip allocated total
        sub.l   cf_ChipMemLevel+mtb_CurrLevelPtr(a1),d0
        lsr.l   #8,d0
        lsr.w   #2,d0
        cmp.l   fw_MaxChipUsed(a6),d0
        blt.s   .lesschip
        move.l  d0,fw_MaxChipUsed(a6)
.lesschip

        move.l  fw_MemTopStack+cf_ChipMemLevel+mtb_MinLevelPtr(a6),d1  ; max free chip total
        sub.l   fw_MemBottomStack+cf_ChipMemLevel+mtb_MinLevelPtr(a6),d1
        lsr.l   #8,d1
        lsr.w   #2,d1

        move.l  cf_FastMemLevel+mtb_CurrLevelPtr(a0),d2 ; bottom fast allocated total
        sub.l   fw_MemBottomStack+cf_FastMemLevel+mtb_MinLevelPtr(a6),d2
        add.l   fw_MemTopStack+cf_FastMemLevel+mtb_MinLevelPtr(a6),d2 ; top fast allocated total
        sub.l   cf_FastMemLevel+mtb_CurrLevelPtr(a1),d2
        lsr.l   #8,d2
        lsr.w   #2,d2
        cmp.l   fw_MaxFastUsed(a6),d2
        blt.s   .lessfast
        move.l  d2,fw_MaxFastUsed(a6)
.lessfast

        move.l  fw_MemTopStack+cf_FastMemLevel+mtb_MinLevelPtr(a6),d3  ; max free fast total
        sub.l   fw_MemBottomStack+cf_FastMemLevel+mtb_MinLevelPtr(a6),d3
        lsr.l   #8,d3
        lsr.w   #2,d3

        PUTMSG  10,<"Mem Used: Chip: %ld of %ld KB (max. %ld KB) | Fast: %ld of %ld KB (max. %ld KB)">,d0,d1,fw_MaxChipUsed(a6),d2,d3,fw_MaxFastUsed(a6)

        PUTMSG  20,<"Chip Bottom: %p, Chip Top %p, Fast Bottom: %p, Fast Top: %p">,cf_ChipMemLevel+mtb_CurrLevelPtr(a0),cf_ChipMemLevel+mtb_CurrLevelPtr(a1),cf_FastMemLevel+mtb_CurrLevelPtr(a0),cf_FastMemLevel+mtb_CurrLevelPtr(a1)
        POPM
        rts
        ENDC
