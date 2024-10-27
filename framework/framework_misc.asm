;--------------------------------------------------------------------
; Endlessly loops and indicate an error
;
; In : d0.w - errorcode
; Out: never returns
;
fw_Error:
                ext.l   d0
                PUTMSG  10,<"Error %x (%d)">,d0,d0
.l0:            move.w  d0,color(a5)
                bra.s   .l0

;--------------------------------------------------------------------
; Sets the base copperlist and irq (empty screen).
;
; Background colour is unchanged, sprites and display are disabled. 
;
; Out: Trashes d0/a0
;
fw_SetBaseCopper:
                PUTMSG  10,<"%d: SetBaseCopper">,fw_FrameCounterLong(a6)
                moveq.l #0,d0
                IF      FW_VBL_IRQ_SUPPORT
                move.l  d0,fw_VBlankIRQ(a6)
                ENDC
                IF      FW_COPPER_IRQ_SUPPORT
                move.l  d0,fw_CopperIRQ(a6)
                ENDC
                move.w  #DMAF_SPRITE|DMAF_RASTER|DMAF_COPPER,dmacon(a5) ; Disable sprite- and copper DMA to avoid race conditions overwriting cop1lc
                bsr.s   .clrspr
                move.w  #$0200,bplcon0(a5)

                move.l  fw_BaseCopperlist(a6),a0
                move.l  a0,cop1lc(a5)

                bsr     fw_DisableCopperSync

                move.l  fw_VBR(a6),a0
                move.l  fw_DefaultIRQ(a6),$6c(a0)

                move.w  #INTF_BLIT,intena(a5) ; disable blitter interrupt
                move.w  #INTF_BLIT|INTF_COPER,intreq(a5)
                IF      FW_COPPER_IRQ_SUPPORT
                move.w  #INTF_SETCLR|INTF_INTEN|INTF_COPER|INTF_VERTB,intena(a5) ; enable vblank & copper interrupts
                ELSE
                move.w  #INTF_SETCLR|INTF_INTEN|INTF_VERTB,intena(a5) ; enable vblank interrupt
                ENDC
                bsr.s   fw_VSync
                move.w  #DMAF_SETCLR|DMAF_MASTER|DMAF_BLITTER|DMAF_RASTER|DMAF_COPPER,dmacon(a5)
.clrspr:
                moveq.l #0,d0
                move.w  d0,spr+0*8+sd_ctl(a5)
                move.w  d0,spr+1*8+sd_ctl(a5)
                move.w  d0,spr+2*8+sd_ctl(a5)
                move.w  d0,spr+3*8+sd_ctl(a5)
                move.w  d0,spr+4*8+sd_ctl(a5)
                move.w  d0,spr+5*8+sd_ctl(a5)
                move.w  d0,spr+6*8+sd_ctl(a5)
                move.w  d0,spr+7*8+sd_ctl(a5)
                rts

;--------------------------------------------------------------------
; Sets a new copperlist (and waits for VBL)
;
; In: a0 = the new copperlist
;
fw_SetCopper:
                move.l  a0,cop1lc(a5)
                IF      FW_MULTITASKING_SUPPORT
                bra     fw_VSyncWithTask
                ELSE
;bra.s   fw_VSync
; fall through
                ENDC

;--------------------------------------------------------------------
; Waits for the next vertical blank.
;
; This version does not allow other tasks to run in the background!
;
; Note: Also checks left mouse button for exit if configured.
;
; In : -
; Out: d0 is trashed
;
                IFEQ    FW_MULTITASKING_SUPPORT
fw_VSyncWithTask:
                ENDC
fw_VSync:
                IF      FW_LMB_EXIT_SUPPORT
                btst    #6,$bfe001
                beq     .abortdemo
                ENDC
.noabort:
                IF      1
                move.w  fw_FrameCounter(a6),d0
                BLTHOGON
.loop:          cmp.w   fw_FrameCounter(a6),d0
                beq.s   .loop
                ELSE
;btst   #DMAB_BLTDONE-8,dmaconr(a5)
;beq.s   .vs1
                BLTHOGON
.vs1:           btst    #0,vposr+1(a5)
                beq.s   .vs1
.vs0:           btst    #0,vposr+1(a5)
                bne.s   .vs0
                ENDC
                rts

                IF      FW_LMB_EXIT_SUPPORT
.abortdemo:
                move.l  fw_DemoAbortStackPointer(a6),d0
                beq.s   .noabort
                move.l  d0,sp
                rts
                ENDC

;--------------------------------------------------------------------
; Waits until the global framecounter reaches the given frame
;
; In : d0.w - frame to wait for
; Out: May trash all registers!
;
fw_WaitForFrame:
                PUTMSG  10,<"%d: Waiting for frame %d">,fw_FrameCounterLong(a6),d0
.loop:
                cmp.w   fw_FrameCounter(a6),d0
                bmi.s   .endwait
                PUSHM   d0
                IF      FW_MULTITASKING_SUPPORT
                CALLFW  VSyncWithTask
                ELSE
                CALLFW  VSync
                ENDC
                POPM
                bra.s   .loop
.endwait:
                PUTMSG  10,<"%d: Waiting done">,fw_FrameCounterLong(a6)
                rts

;--------------------------------------------------------------------
; Flushes the cache on Kick 2.0 or higher to avoid problems with SMC.
; (also after loading code).
;
fw_FlushCaches:
                PUSHM   a6
                move.l  4.w,a6
                cmp.w   #37,LIB_VERSION(a6)
                blo.s   .lameos
                CALL    CacheClearU
.lameos:
                POPM
                rts

;--------------------------------------------------------------------

                IF      FW_COPPER_IRQ_SUPPORT
fw_copper_irq:
                PUSHM   d0/a0/a5/a6
                lea     $dff000,a5
                move.w  #INTF_COPER,intreq(a5) ;acknowledge the copper-irq.
                move.w  #INTF_COPER,intreq(a5) ;acknowledge the copper-irq.
                move.l  fw_BasePtr(pc),a6
                move.l  fw_CopperIRQ(a6),d0
                beq.s   .nocop
                move.l  d0,a0
                jsr     (a0)
.nocop:         POPM
                nop
                rte
                ENDC

;--------------------------------------------------------------------

fw_vblank_standard_irq:
                IF      FW_COPPER_IRQ_SUPPORT
                btst    #INTB_COPER,$dff000+intreqr+1
                bne.s   fw_copper_irq
                ENDC
                IF      FW_VBL_IRQ_SUPPORT|(FW_MUSIC_SUPPORT&FW_VBL_MUSIC_IRQ)
                PUSHM   d0-d3/a0-a3/a5/a6
                ELSE
                PUSHM   a5/a6
                ENDC
                lea     $dff000,a5
                move.w  #INTF_VERTB,intreq(a5) ;acknowledge the VBL-irq.
                move.w  #INTF_VERTB,intreq(a5) ;acknowledge the VBL-irq.

                move.l  fw_BasePtr(pc),a6
                addq.w  #1,fw_FrameCounter(a6)
                IF      (FW_MUSIC_SUPPORT&FW_VBL_MUSIC_IRQ)
                tst.w   fw_MusicEnabled(a6)
                beq.s   .skipmus
                bsr     fw_MusicPlay
.skipmus:
                ENDC
                IF      FW_VBL_IRQ_SUPPORT
                move.l  fw_VBlankIRQ(a6),d0
                beq.s   .novbl
                move.l  d0,a0
                jsr     (a0)            ; IRQ must maintain d4-d7/a4
.novbl:
                ENDC
                POPM
                nop
                rte

;--------------------------------------------------------------------
; Calls vbl routinesa on copper interrupt instead, to allow syncing 
; with a specific raster line, rather than TOF

fw_coppersync_standard_irq:
                IF      FW_VBL_IRQ_SUPPORT|(FW_MUSIC_SUPPORT&FW_VBL_MUSIC_IRQ)
                PUSHM   d0-d3/a0-a3/a5/a6
                ELSE
                PUSHM   a5/a6
                ENDC
                lea     $dff000,a5
                move.w  #INTF_COPER,intreq(a5) ;acknowledge the COPER-irq.
                move.w  #INTF_COPER,intreq(a5)

                move.l  fw_BasePtr(pc),a6
                addq.w  #1,fw_FrameCounter(a6)
                IF      (FW_MUSIC_SUPPORT&FW_VBL_MUSIC_IRQ)
                tst.w   fw_MusicEnabled(a6)
                beq.s   .skipmus
                bsr     fw_MusicPlay
.skipmus:
                ENDC
                IF      FW_VBL_IRQ_SUPPORT
                move.l  fw_VBlankIRQ(a6),d0
                beq.s   .novbl
                move.l  d0,a0
                jsr     (a0)            ; IRQ must maintain d4-d7/a4
.novbl:
                ENDC
                POPM
                nop
                rte

                IF      FW_MULTITASKING_SUPPORT

;--------------------------------------------------------------------
; In : d0.w - interrupt vpos line

fw_EnableCopperSync:
                move.w  #INTF_VERTB,intena(a5) ; Disable vbi
                move.w  #INTF_VERTB,intena(a5)

                sub.w   #FW_MIN_BGTASK_LINES,d0 ; Set max vpos based on interrupt line
                ext.l   d0
                lsl.l   #8,d0
                move.l  d0,fw_MaxVposForTask(a6)

                lea     fw_coppersync_standard_irq(pc),a0
                move.l  a0,fw_DefaultIRQ(a6)
                move.l  fw_VBR(a6),a1
                move.l  a0,$6c(a1)
                lea     fw_coppersync_backgroundtask_restore_irq(pc),a0
                move.l  a0,fw_MultitaskingIRQ(a6)

                move.w  #INTF_SETCLR!INTF_COPER,intena(a5) ; enable copper interrupt
                rts

;--------------------------------------------------------------------

fw_DisableCopperSync:
                lea     fw_vblank_standard_irq(pc),a0
                move.l  a0,fw_DefaultIRQ(a6)
                move.l  fw_VBR(a6),a1
                move.l  a0,$6c(a1)
                lea     fw_backgroundtask_restore_irq(pc),a0
                move.l  a0,fw_MultitaskingIRQ(a6)

                move.l  #FW_MAX_VPOS_FOR_BG_TASK<<8,fw_MaxVposForTask(a6) ; Restore default max vpos

                move.w  #INTF_SETCLR!INTF_VERTB,intena(a5) ; re-enable vbi
                rts

                ENDC
