        include "exec/libraries.i"
        include "exec/memory.i"

;--------------------------------------------------------------------
;   startup code
;--------------------------------------------------------------------

        IF      FW_LMB_EXIT_SUPPORT
        fail    "FW_LMB_EXIT_SUPPORT cannot be provided"
        ENDC

trackmo_AppInit:
        lea     fw_Base(pc),a4
        lea     fw_BasePtr(pc),a0
        move.l  a4,(a0)
        PUTMSG  10,<"*** FW Base %p, FW BasePtr %p">,a4,a0

        move.l  4.w,a6
        IF      FW_TD_FREE_MEM_HACK
        ; try to free trackdisk buffers. These are attached to the task structure of the trackdisk.device tasks.
        ; The trackdisk.device does not support expunge, so this is the best hack I can think of.
        ; (This will only return a small non-continuous block of chip mem, about 17 KB for each drive).
        CALL    Forbid
.tdloop
        lea     .trackdiskname(pc),a1
        CALL    FindTask
        tst.l   d0
        beq.s   .notd
        move.l  d0,a1
        PUTMSG  10,<"Removing trackdisk.device task %p">,a1
        CALL    RemTask
        bra.s   .tdloop
.notd   CALL    Permit
        ENDC

        cmp.l   MaxLocMem(a6),a6
        blt.s   .nofast                     ; exec is NOT is fast memory -> not safe to claim whole chipmem
        ; claim available fast mem
        move.l  #(MEMF_LARGEST|MEMF_FAST),d1
        CALL    AvailMem
        move.l  d0,d2
        beq.s   .nofast
        move.l  #MEMF_FAST|MEMF_CLEAR,d1
        CALL    AllocMem
        move.l  d0,fw_FastMemStack(a4)
        bne.s   .goodmem
.memerr
        move.w  #$800,$dff180
        bra.s   .memerr
.nofast
        move.l  #(MEMF_LARGEST|MEMF_CHIP),d1
        CALL    AvailMem
        move.l  d0,d2
        move.l  #(MEMF_CHIP|MEMF_CLEAR),d1
        CALL    AllocMem
        move.l  d0,fw_ChipMemStack(a4)
        add.l   d2,d0
        move.l  d0,fw_ChipMemStackEnd(a4)

        move.l  #(MEMF_LARGEST|MEMF_ANY),d1
        CALL    AvailMem
        move.l  d0,d2
        move.l  #MEMF_CLEAR,d1
        CALL    AllocMem
        move.l  d0,fw_FastMemStack(a4)
        add.l   d2,d0
        move.l  d0,fw_FastMemStackEnd(a4)
        bra.s   .altmem
.goodmem
        add.l   d2,d0
        move.l  d0,fw_FastMemStackEnd(a4)

        ; since our stuff is probably all in fast mem right now, we can take over the complete chipmem
        lea     $400.w,a0
        move.l  a0,fw_ChipMemStack(a4)
        move.l  MaxLocMem(a6),fw_ChipMemStackEnd(a4)
.altmem

        bsr     trackmo_GetVbr
        move.l  a0,fw_VBR(a4)
        ;move.l $6c(a0),fw_OldSystemVBlankIRQ(a4)

        lea     $dff000,a5

        move.w  vposr(a5),d0
        btst    #9,d0
        beq.s   .noaga
        move.w  #-1,fw_AgaChipset(a4)
.noaga

        move.w  #$7fff,d0
        move.w  d0,intena(a5)
        move.w  d0,intena(a5)
        move.w  d0,intreq(a5)
        move.w  d0,intreq(a5)
        move.w  #DMAF_MASTER|DMAF_ALL,dmacon(a5)
        move.w  d0,adkcon(a5)
        move.w  #%0000111100000000,potgo(a5)

        move.l  a4,fw_PartFwBase(a4)
        move.l  a4,fw_PrimaryFwBase(a4)
        move.l  a4,a6   ; from now on, a6 is supposed to be our framework pointer, a5 is _custom

        bsr     fw_InitMemoryManagement

        IF      FW_MULTITASKING_SUPPORT
        bsr     fw_InitTasks
        move.l  #ft_SIZEOF,d0
        bsr     fw_AllocFast
        move.l  a0,fw_TrackloaderTask(a6)
        ENDC

        moveq.l #mfw_copperlistend-mfw_copperlist,d0
        bsr     fw_AllocChip
        move.l  a0,d0
        move.l  d0,fw_BaseCopperlist(a6)
        move.l  d0,a1

        lea     mfw_copperlist(pc),a0
        moveq.l #(mfw_copperlistend-mfw_copperlist)/4-1,d7
.cpyloop
        move.l  (a0)+,(a1)+
        dbra    d7,.cpyloop

        subq.l  #4,a1
        move.l  a1,fw_EmptySprite(a6)

        lea     fw_vblank_standard_irq(pc),a0
        move.l  a0,fw_DefaultIRQ(a6)

        bsr     fw_SetBaseCopper

        IF      FW_SINETABLE_SUPPORT
        bsr     fw_InitSineTable
        ENDC

        bsr     fw_InitTrackLoader
        bsr     fw_InitDos

        IF      FW_MUSIC_SUPPORT
        IF      (FW_MUSIC_PLAYER_CHOICE==4)||(FW_MUSIC_PLAYER_CHOICE==5)
        bsr     fw_MusicAlloc
        ENDC
        ENDC

        bsr     fw_PushMemoryState

        movem.l fw_EmptyRegs(a6),d0-d7/a0-a4
        rts

        IF      FW_TD_FREE_MEM_HACK
.trackdiskname
        dc.b    'trackdisk.device',0
        even

trackmo_GetVbr:
        suba.l  a0,a0
        move.w  AttnFlags(a6),d0
        btst    #AFB_68010,d0
        beq.s   .novbr
        lea     .getvbr(pc),a5
        CALL    Supervisor
.novbr  rts

        machine mc68010
.getvbr
        movec.l vbr,a0
        rte
        machine mc68000
        ENDC

;--------------------------------------------------------------------

trackmo_AppShutdown:
        bsr     fw_SetBaseCopper
        bsr     fw_TrackloaderDiskMotorOff
        rts
