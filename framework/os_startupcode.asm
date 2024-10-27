        include "exec/memory.i"
        include "dos/dosextens.i"
        include "workbench/startup.i"
        include "graphics/gfxbase.i"
        IF      FW_DO_FANCY_WORKBENCH_STUFF
        include "graphics/view.i"
        ENDC

        include "uae/uaestuff.i"

        IFND    CHIPMEM_SIZE
CHIPMEM_SIZE = 4
        ENDC
        IFND    FASTMEM_SIZE
FASTMEM_SIZE = 4
        ENDC

        bsr     os_AppInit

        IF      FW_LMB_EXIT_SUPPORT
        lea     -4(sp),a0
        move.l  a0,fw_DemoAbortStackPointer(a6)
        ENDC

        PUTMSG  10,<"%d: Entrypoint: %p">,fw_FrameCounterLong(a6),#entrypoint
        bsr     entrypoint
        PUTMSG  10,<"%d: Part terminated">,fw_FrameCounterLong(a6)

        bra     os_AppShutdown

;--------------------------------------------------------------------
;   startup code
;--------------------------------------------------------------------

os_AppInit:
        PUTMSG  10,<"AppInit %ld, %ld">,#CHIPMEM_SIZE,#FASTMEM_SIZE
        IFGT    DEBUG_DETAIL
        UAEExitWarp
        ENDC

        move.l  4.w,a6
        IFEQ    FW_HD_TRACKMO_MODE
        IFD     pd_SIZEOF
        move.l  #pd_SIZEOF,d0
        PUTMSG  10,<"Allocating framework memory (%ld) WITH PART data: %ld bytes">,#fw_SIZEOF,d0
        ELSE
        move.l  #fw_SIZEOF,d0
        PUTMSG  10,<"Allocating framework memory: %ld bytes (NO part data!)">,d0
        ENDC
        move.l  d0,d2
        move.l  #MEMF_PUBLIC|MEMF_CLEAR,d1
        CALL    AllocMem
        move.l  d0,fw_BasePtr
        bne.s   .cont
        moveq.l #ERROR_NO_FREE_STORE,d0
        addq.w  #4,sp
        rts
.cont   move.l  d0,a4
        move.l  d0,fw_OrigBaseMemAllocAddr(a4)
        move.l  d2,fw_OrigBaseMemAllocLength(a4)
        ELSE
        move.l  #fw_SIZEOF+6,d0         ; for InitData LVO
        move.l  d0,d2
        move.l  #MEMF_PUBLIC|MEMF_CLEAR,d1
        CALL    AllocMem
        tst.l   d0
        beq.s   .error
        move.l  d0,a0
        move.w  #%0100111011111001,(a0)+
        move.l  #fw_InitPart,(a0)+
        move.l  a0,fw_BasePtr
        bra.s   .cont
.error
        moveq.l #ERROR_NO_FREE_STORE,d0
        addq.w  #4,sp
        rts
.cont   move.l  a0,a4
        move.l  d0,fw_OrigBaseMemAllocAddr(a4)
        move.l  d2,fw_OrigBaseMemAllocLength(a4)
        ENDC
        move.l  a4,fw_PartFwBase(a4)
        move.l  a4,fw_PrimaryFwBase(a4)

        suba.l  a1,a1
        CALL    FindTask
        move.l  d0,a2
        tst.l   pr_CLI(a2)
        bne.s   .cli
        lea     pr_MsgPort(a2),a0
        CALL    WaitPort
        lea     pr_MsgPort(a2),a0
        CALL    GetMsg
        move.l  d0,fw_WBMessage(a4)
.cli
        moveq.l #ERROR_NO_FREE_STORE,d7
        move.l  #CHIPMEM_SIZE+(mfw_copperlistend-mfw_copperlist),d0

        addq.l  #7,d0
        and.w   #-8,d0
        move.l  d0,d2
        move.l  d0,fw_OrigChipMemAllocLength(a4)
        move.l  #MEMF_CHIP|MEMF_PUBLIC|MEMF_CLEAR,d1
        CALL    AllocMem
        move.l  d0,fw_OrigChipMemAllocAddr(a4)
        beq     os_AppAbort
        move.l  d0,fw_ChipMemStack(a4)
        add.l   d2,d0
        move.l  d0,fw_ChipMemStackEnd(a4)

        IF      FW_SINETABLE_SUPPORT
        move.l  #FASTMEM_SIZE+(1024+256)*2,d0
        ELSE
        move.l  #FASTMEM_SIZE,d0
        ENDC
        move.l  d0,d2
        move.l  d0,fw_OrigFastMemAllocLength(a4)
        move.l  #MEMF_ANY|MEMF_PUBLIC|MEMF_CLEAR,d1
        CALL    AllocMem
        move.l  d0,fw_OrigFastMemAllocAddr(a4)
        beq     os_AppAbort
        move.l  d0,fw_FastMemStack(a4)
        add.l   d2,d0
        move.l  d0,fw_FastMemStackEnd(a4)

        IF      DEBUG_DETAIL
        move.l  #MEMF_CHIP,d1
        CALL    AvailMem
        PUTMSG  10,<"Chip memory free: %ld bytes">,d0
        move.l  #MEMF_CHIP|MEMF_LARGEST,d1
        CALL    AvailMem
        PUTMSG  10,<"Chip memory largest: %ld bytes">,d0
        move.l  #MEMF_FAST,d1
        CALL    AvailMem
        PUTMSG  10,<"Fast memory free: %ld bytes">,d0
        ENDC
        IF      0
        PUTMSG  10,<"OpenResource">
        move.w  #ERROR_LOCK_COLLISION,d7
        lea     .ciabname(pc),a1
        CALL    OpenResource
        move.l  d0,fw_CiaBResource(a4)
        beq     os_AppAbort
        move.l  a6,a5
        move.l  d0,a6

        PUTMSG  10,<"AddICRVector">
        lea     fw_SysFriendlyInterrupt(a4),a1
        lea     .nopirq(pc),a0
        move.l  a0,IS_CODE(a1)
        moveq.l #CIAICRB_TB,d0
        CALL    AddICRVector
        tst.l   d0
        beq.s   .gottimer
        move.l  a5,a6
        bra     os_AppAbort

        ; No turning back at this point!
.gottimer
        PUTMSG  10,<"AbleICR">
        moveq.l #CIAICRF_TB,d0
        CALL    AbleICR
        ENDC

        lea     $dff000,a5
        exg     a4,a6   ; from now on, a6 is supposed to be our framework pointer, a5 is _custom

        IF      FW_MULTITASKING_SUPPORT
        bsr     fw_InitTasks
        ENDC

        IF      FW_DYNAMIC_MEMORY_SUPPORT
        bsr     fw_InitMemoryManagement

        IF      (FW_STANDALONE_FILE_MODE==0)|FW_HD_TRACKMO_MODE
        IF      FW_MULTITASKING_SUPPORT
        move.l  #ft_SIZEOF,d0
        bsr     fw_AllocFast
        move.l  a0,fw_TrackloaderTask(a6)
        ENDC
        ENDC

        moveq.l #mfw_copperlistend-mfw_copperlist,d0
        bsr     fw_AllocChip
        move.l  a0,a1
        move.l  a0,fw_BaseCopperlist(a6)
        ELSE
        IF      (FW_STANDALONE_FILE_MODE==0)|FW_HD_TRACKMO_MODE
        IF      FW_MULTITASKING_SUPPORT
        move.l  fw_FastMemStack(a6),a0
        move.l  a0,fw_TrackloaderTask(a6)
        lea     ft_SIZEOF(a0),a0
        move.l  a0,fw_FastMemStack(a6)
        ENDC
        ENDC
        move.l  fw_ChipMemStack(a6),a1
        lea     mfw_copperlistend-mfw_copperlist(a1),a0
        move.l  a0,fw_ChipMemStack(a6)
        ENDC

        lea     mfw_copperlist(pc),a0
        moveq.l #(mfw_copperlistend-mfw_copperlist)/4-1,d7
.cpyloop
        move.l  (a0)+,(a1)+
        dbra    d7,.cpyloop

        subq.l  #4,a1
        move.l  a1,fw_EmptySprite(a6)

        lea     fw_vblank_standard_irq(pc),a0
        move.l  a0,fw_DefaultIRQ(a6)

        IF      FW_SINETABLE_SUPPORT
        bsr     fw_InitSineTable
        ENDC

        IF      FW_HD_TRACKMO_MODE
        move.l  #diskimage,fw_TrackBuffer(a6)

        bsr     fw_InitDos

        IF      FW_DYNAMIC_MEMORY_SUPPORT
        IF      FW_MUSIC_SUPPORT
        IF      (FW_MUSIC_PLAYER_CHOICE==4)||(FW_MUSIC_PLAYER_CHOICE==5)
        bsr     fw_MusicAlloc
        ENDC
        ENDC
        bsr     fw_PushMemoryState
        ENDC

        ELSE ; FW_DYNAMIC_MEMORY_SUPPORT

        IF      FW_MUSIC_SUPPORT
        IF      (FW_MUSIC_PLAYER_CHOICE==4)||(FW_MUSIC_PLAYER_CHOICE==5)
        bsr     fw_MusicAlloc
        bsr     fw_PushMemoryState
        ENDC
        ENDC
        ENDC ; FW_DYNAMIC_MEMORY_SUPPORT

        move.w  vposr(a5),d0
        btst    #9,d0
        beq.s   .noaga
        move.w  #-1,fw_AgaChipset(a6)
.noaga

        exg     a4,a6                       ; from now on, a4 is our framework pointer, a6 is exec
        move.l  a6,a5
        PUTMSG  10,<"LoadView">
        movea.l IVBLIT+IV_DATA(a5),a6       ; graphics.library
        move.l  a6,fw_GfxBase(a4)
        move.l  gb_ActiView(a6),fw_OldGfxView(a4)

        IF      FW_DO_FANCY_WORKBENCH_STUFF
        CALL    OwnBlitter
        move.l  a5,a6

        ;CALL    Forbid
        lea     fw_SysFriendlyInterrupt(a4),a1
        lea     os_SysFriendlyVbl(pc),a0
        move.l  a0,IS_CODE(a1)
        move.l  a4,IS_DATA(a1)
        moveq.l #INTB_VERTB,d0
        CALL    AddIntServer

        PUSHM   a4-a6
        lea     $dff000,a5
        exg     a4,a6
        bsr     preentrypoint
        POPM

        lea     fw_SysFriendlyInterrupt(a4),a1
        moveq.l #INTB_VERTB,d0
        CALL    RemIntServer
        clr.l   fw_VBlankIRQ(a4)

        ;CALL    Permit

        move.l  fw_GfxBase(a4),a6
        CALL    DisownBlitter
        suba.l  a1,a1
        CALL    LoadView
        CALL    WaitTOF
        ELSE
        suba.l  a1,a1
        CALL    LoadView
        CALL    WaitTOF
        ENDC

        CALL    OwnBlitter
        move.l  a5,a6

        CALL    Forbid
        CALL    Disable

        PUTMSG  10,<"OS off">

        bsr     os_GetVbr

        lea     $dff000,a5
        exg     a4,a6   ; from now on, a6 is supposed to be our framework pointer, a5 is _custom
        move.l  a0,fw_VBR(a6)
        move.l  $6c(a0),fw_OldSystemVBlankIRQ(a6)

        move.w  #$7fff,d4
        move.w  intenar(a5),d0
        move.w  d4,intena(a5)
        move.w  d4,intena(a5)
        or.w    #INTF_SETCLR,d0
        move.w  intreqr(a5),d1
        move.w  d4,intreq(a5)
        move.w  d4,intreq(a5)
        or.w    #INTF_SETCLR,d1
        move.w  dmaconr(a5),d2
        move.w  #DMAF_MASTER|DMAF_ALL,dmacon(a5)
        or.w    #DMAF_SETCLR,d2
        move.w  adkconr(a5),d3
        move.w  d4,adkcon(a5)
        or.w    #ADKF_SETCLR,d3
        movem.w d0-d3,fw_OldControls(a6)

        bsr     fw_SetBaseCopper
        movem.l fw_EmptyRegs(a6),d0-d7/a0-a4
        rts

        IF      0
.nopirq
        move.w  #$f00,$dff180
        rts

.ciabname
        dc.b    'ciab.resource',0
        even
        ENDC

        IF      FW_DO_FANCY_WORKBENCH_STUFF
os_SysFriendlyVbl:
        addq.w  #1,fw_FrameCounter(a1)
        move.l  fw_VBlankIRQ(a1),d0
        beq.s   .skip
        PUSHM   a2-a4/d2-d7
        move.l  a1,a6
        lea     $dff000,a5
        move.l  d0,a0
        jsr     (a0)
        POPM
        move.l  a5,a0
        moveq.l #0,d0
.skip   rts
        ENDC

os_GetVbr:
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

;--------------------------------------------------------------------

os_AppAbort:
        addq.l  #4,sp
        move.l  4.w,a6
        move.l  fw_BasePtr(pc),a4
        bra     os_CleanUp

os_AppShutdown:
        PUTMSG  10,<"AppShutdown">
        IF      FW_MUSIC_SUPPORT
        bsr     fw_StopMusic
        ENDC
        BLTWAIT
        bsr     fw_SetBaseCopper

        move.w  #$7fff,d0
        move.w  d0,intena(a5)
        move.w  d0,intena(a5)
        move.w  d0,intreq(a5)
        move.w  d0,intreq(a5)
        move.w  #DMAF_MASTER|DMAF_ALL,dmacon(a5)
        move.w  d0,adkcon(a5)

        move.l  fw_VBR(a6),a0
        move.l  fw_OldSystemVBlankIRQ(a6),$6c(a0)

        movea.l fw_GfxBase(a6),a0       ; graphics.library
        move.l  $26(a0),cop1lc(a5)
        move.l  $26(a0),cop2lc(a5)
        move.w  d0,copjmp1(a5)
        movem.w fw_OldControls(a6),d0-d3
        move.w  d3,adkcon(a5)
        move.w  d2,dmacon(a5)
        move.w  d1,intreq(a5)
        move.w  d0,intena(a5)

        move.l  a6,a4
        move.l  4.w,a6
        CALL    Enable
        CALL    Permit

        move.l  a6,a5
        movea.l fw_GfxBase(a4),a6       ; graphics.library
        CALL    DisownBlitter
        move.l  fw_OldGfxView(a4),a1
        CALL    LoadView

        IF      0
        move.l  fw_CiaBResource(a4),a6
        move.l  fw_SysFriendlyInterrupt(a4),a1
        moveq.l #CIAICRB_TB,d0
        CALL    RemICRVector
        ENDC

        move.l  a5,a6
        PUTMSG  10,<"OS on">
        IF      FW_DO_FANCY_WORKBENCH_STUFF
        PUSHM   a4-a6
        exg     a4,a6
        bsr     postentrypoint
        POPM
        ENDC
        moveq.l #0,d7

os_CleanUp:
        move.l  fw_OrigFastMemAllocAddr(a4),d0
        beq.s   .nofreefast
        move.l  d0,a1
        move.l  fw_OrigFastMemAllocLength(a4),d0
        CALL    FreeMem

.nofreefast
        move.l  fw_OrigChipMemAllocAddr(a4),d0
        beq.s   .nofreechip
        move.l  d0,a1
        move.l  fw_OrigChipMemAllocLength(a4),d0
        CALL    FreeMem

.nofreechip
        move.l  fw_WBMessage(a4),d2
        move.l  fw_OrigBaseMemAllocAddr(a4),a1
        move.l  fw_OrigBaseMemAllocLength(a4),d0
        CALL    FreeMem

        tst.l   d2
        beq.s   .nowb
        CALL    Forbid
        move.l  d2,a1
        CALL    ReplyMsg
.nowb

        PUTMSG  10,<"Done with code %d">,d7
        move.w  d7,d0
        ext.l   d0
        rts
