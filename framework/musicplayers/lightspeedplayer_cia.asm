;*****************************************************************
;
;   Light Speed Player v1.11
;   Fastest Amiga MOD player ever :)
;   Written By Arnaud Carré (aka Leonard / OXYGENE)
;   Slightly modified by platon42 for demo framework.
;
;   https://github.com/arnaud-carre/LSPlayer
;   twitter: @leonard_coder
;
;   "cia" player version ( or "less effort" )
;
;   Warnings:
;   a)  this file is provided for "easy of use". But if you're working
;       on a cycle-optimizated demo effect, please call LightSpeedPlayer from your
;       own existing interrupt and use copper to set DMACON 11 raster lines later
;
;   b)  this code doesn't restore any amiga OS stuff.
;       ( are you a cycle-optimizer or what? :) )
;
;   --------How to use---------
;
;   bsr LSP_MusicDriver_CIA_Start : Init LSP player code and install CIA interrupt
;       a0: LSP music data(any memory)
;       a1: LSP sound bank(chip memory)
;       a2: VBR (CPU Vector Base Register) ( use 0 if 68000 )
;       d0: 0=PAL, 1=NTSC
;
;   bsr LSP_MusicDriver_CIA_Stop : Stop LSP music replay
;
;*****************************************************************

LSP_MusicDriver_CIA_Stop:
        move.b  #$7f,$bfd000+ciaicr
        move.w  #INTF_EXTER,intena(a5)
        move.w  #INTF_EXTER,intreq(a5)
        move.w  #DMAF_AUDIO,dmacon(a5)
        rts

LSP_MusicDriver_CIA_Start:
        move.w  d0,-(sp)
        lea     .dmaCon+1(pc),a2    ; DMACON byte patch address
        clr.b   (a2)
        move.l  a2,fw_LspDmaConPatch(a6)
        bsr     LSP_MusicInit       ; init the LSP player ( whatever fast or insane version )

        move.w  fw_LspCurrentBpm(a6),d0
        move.w  d0,fw_LspLastCiaBpm(a6)
        moveq   #1,d1
        and.w   (sp)+,d1

; d0: music BPM
; d1: PAL(0) or NTSC(1)
.LSP_IrqInstall
        move.w  #INTF_EXTER,intena(a5)      ; disable CIA interrupt
        lea     .LSP_MainIrq(pc),a0
        move.l  fw_VBR(a6),a2
        move.l  a0,$78(a2)

        lea     $bfd000,a0
        move.b  #$7f,ciaicr(a0)
        move.b  #CIACRAF_LOAD,ciacra(a0)
        move.b  #CIACRBF_LOAD,ciacrb(a0)
        lsl.w   #2,d1
        move.l  .palClocks(pc,d1.w),d1      ; PAL or NTSC clock
        move.l  d1,fw_LspCiaClock(a6)
        divu.w  d0,d1
        move.b  d1,ciatalo(a0)
        lsr.w   #8,d1
        move.b  d1,ciatahi(a0)
        move.b  #CIAICRF_SETCLR|CIAICRF_TA|CIAICRF_TB,ciaicr(a0)
        move.b  #CIACRAF_START|CIACRAF_LOAD,ciacra(a0)

        move.b  #496&$ff,ciatblo(a0)        ; set timer b to 496 ( to set DMACON )
        move.b  #496>>8,ciatbhi(a0)

        move.w  #INTF_EXTER,intreq(a5)      ; clear any req CIA
        move.w  #INTF_SETCLR|INTF_EXTER,intena(a5)          ; CIA interrupt enabled
        rts

.palClocks
        dc.l    1773447,1789773
.dmaCon
        dc.w    $8000 ; we won't put this into the framework variables to the avoid need for relocation

.LSP_MainIrq
        btst.b  #CIAICRB_TA,$bfd000+ciaicr
        beq.s   .skipa

        PUSHM   d0-d2/a0-a6

        ; call player tick
        lea     $dff000,a5
        move.l  fw_BasePtr(pc),a6
        bsr     LSP_MusicPlayTick   ; LSP main music driver tick

        ; check if BMP changed in the middle of the music
        lea     $bfd000,a4
        move.w  fw_LspCurrentBpm(a6),d0 ; current music BPM
        cmp.w   fw_LspLastCiaBpm(a6),d0
        beq.s   .noChg
        move.w  d0,fw_LspLastCiaBpm(a6) ; current BPM
        move.l  fw_LspCiaClock(a6),d1
        divu.w  d0,d1
        move.b  d1,ciatalo(a4)
        lsr.w   #8,d1
        move.b  d1,ciatahi(a4)

.noChg  lea     .LSP_DmaconIrq(pc),a0
        move.l  fw_VBR(a6),a1
        move.l  a0,$78(a1)
        move.b  #CIACRBF_START|CIACRBF_RUNMODE|CIACRBF_LOAD,ciacrb(a4)          ; start timerB, one shot

        POPM
.skipa
        move.w  #INTF_EXTER,$dff000+intreq
        move.w  #INTF_EXTER,$dff000+intreq
        nop
        rte

.LSP_DmaconIrq
        btst.b  #CIAICRB_TB,$bfd000+ciaicr
        beq.s   .skipb
        PUSHM   a0/a1
        move.w  .dmaCon(pc),$dff000+dmacon
        move.l  fw_BasePtr(pc),a1
        lea     .LSP_MainIrq(pc),a0
        move.l  fw_VBR(a1),a1
        move.l  a0,$78(a1)
        POPM
.skipb
        move.w  #INTF_EXTER,$dff000+intreq
        move.w  #INTF_EXTER,$dff000+intreq
        nop
        rte