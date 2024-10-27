;*****************************************************************
;
;   Light Speed Player v1.11
;   Fastest Amiga MOD player ever :)
;   Written By Arnaud Carré (aka Leonard / OXYGENE)
;   Adapted to demo framework (and optimized) by platon42.
;
;   https://github.com/arnaud-carre/LSPlayer
;   twitter: @leonard_coder
;
;   "small & fast" player version ( average time: 1 scanline )
;   Less than 512 bytes of code!
;   You can also use generated "insane" player code for even more half scanline replayer (-insane option)
;
;   LSP_MusicInit       Initialize a LSP driver + relocate score&bank music data
;   LSP_MusicPlayTick   Play a LSP music (call it per frame)
;   LSP_MusicGetPos     Get mod seq pos (see -setpos option in LSPConvert)
;   LSP_MusicSetPos     Set mod seq pos (see -getpos option in LSPConvert)
;
;*****************************************************************

;------------------------------------------------------------------
;
;   LSP_MusicPlayTick
;
;       In: a5: should be $dff000
;           Scratched regs: d0-d2/a0-a4
;       Out:None
;
;------------------------------------------------------------------
LSP_MusicPlayTick:
                addq.w  #1,fw_MusicFrameCount(a6)
                lea     fw_LspByteStream(a6),a3
                move.l  (a3),a0         ; fw_LspByteStream, byte stream
                move.l  fw_LspCodeTableAddr(a6),a2 ; code table

.process:
                moveq.l #0,d0
                move.b  (a0)+,d0
                beq.s   .cextended
                add.w   d0,d0
                move.w  (a2,d0.w),d0    ; code
                bne.s   .cmdExec
.noInstBS:
                move.l  a0,(a3)         ; fw_LspByteStream, store byte stream if coming from early out
                rts

.cextended:
                add.w   #$0100,d0
                move.b  (a0)+,d0
                beq.s   .cextended
                add.w   d0,d0
                move.w  (a2,d0.w),d0    ; code
                lea     fw_LspEscCodeRewind(a6),a1
                cmp.w   (a1)+,d0        ; fw_LspEscCodeRewind
                beq.s   .r_rewind
                cmp.w   (a1)+,d0        ; fw_LspEscCodeSetBpm
                beq.s   .r_chgBpm
                cmp.w   (a1)+,d0        ; fw_LspEscCodeGetPos
                bne.s   .cmdExec

.r_setPos:
                move.b  (a0)+,fw_LspCurrentSeq+1(a6)
                bra.s   .process

.r_rewind:
                move.l  fw_LspByteStreamLoop(a6),a0
                move.l  fw_LspWordStreamLoop(a6),fw_LspWordStream(a6)
                bra.s   .process

.r_chgBpm:
                move.b  (a0)+,fw_LspCurrentBpm+1(a6) ; BPM
                bra.s   .process

.cmdExec:
                add.b   d0,d0
                bcc.s   .noVd
                move.b  (a0)+,aud3+ac_vol+1(a5)
.noVd:          add.b   d0,d0
                bcc.s   .noVc
                move.b  (a0)+,aud2+ac_vol+1(a5)
.noVc:          add.b   d0,d0
                bcc.s   .noVb
                move.b  (a0)+,aud1+ac_vol+1(a5)
.noVb:          add.b   d0,d0
                bcc.s   .noVa
                move.b  (a0)+,aud0+ac_vol+1(a5)
.noVa:
                move.l  a0,(a3)+        ; fw_LspByteStream, store byte stream ptr
                move.l  (a3),a0         ; fw_LspWordStream, word stream

                tst.b   d0
                beq.s   .noPa

                add.b   d0,d0
                bcc.s   .noPd
                move.w  (a0)+,aud3+ac_per(a5)
.noPd:          add.b   d0,d0
                bcc.s   .noPc
                move.w  (a0)+,aud2+ac_per(a5)
.noPc:          add.b   d0,d0
                bcc.s   .noPb
                move.w  (a0)+,aud1+ac_per(a5)
.noPb:          add.b   d0,d0
                bcc.s   .noPa
                move.w  (a0)+,aud0+ac_per(a5)
.noPa:
                tst.w   d0
                beq.s   .noInstWS

                moveq.l #0,d1
                move.l  fw_LspInstruments(a6),a2 ; instrument table
                lea     fw_LspResetv+4*4(a6),a4

                lea     aud+3*ac_SIZEOF(a5),a1
                moveq.l #4-1,d2
.vloop:         add.w   d0,d0
                bcs.s   .setIns
                add.w   d0,d0
; suppress M68kUnexpectedConditionalInstruction
                move.l  -(a4),a3        ; take loop data
                bcc.s   .skip
                move.l  (a3)+,ac_ptr(a1) ; and update pointer/len with it
                move.w  (a3)+,ac_len(a1) ; (usually triggered from previous frame)
                bra.s   .skip
.setIns:
                add.w   (a0)+,a2
                add.w   d0,d0
                bcc.s   .noReset
                bset    d2,d1
                move.w  d1,dmacon(a5)
.noReset:
                move.l  (a2)+,ac_ptr(a1)
                move.w  (a2)+,ac_len(a1)
                move.l  a2,-(a4)        ; set reset values for next iteration to contain loop data
.skip:          lea     -ac_SIZEOF(a1),a1
                dbra    d2,.vloop

                move.l  fw_LspDmaConPatch(a6),a1 ; dmacon patch
                move.b  d1,(a1)         ; dmacon

.noInstWS:
                move.l  a0,fw_LspWordStream(a6) ; store word stream
                rts

;------------------------------------------------------------------
;
;   LSP_MusicInit
;
;       In: a0: LSP music data (any memory)
;           a1: LSP sound bank (chip memory)
;
;------------------------------------------------------------------
LSP_DataError:
                illegal
LSP_MusicInit:
                cmp.l   #"LSP1",(a0)+
                bne.s   LSP_DataError
                move.l  (a0)+,d0        ; unique id
                cmp.l   (a1),d0         ; check that sample bank is this one
                bne.s   LSP_DataError

                cmp.w   #$010b,(a0)+    ; v1.11 minimal major & minor version of latest compatible
                blt.s   LSP_DataError
                moveq.l #0,d1
                bset    d1,(a0)         ; test and mark this music score as "relocated"
                bne.s   .noRelocate
                move.l  a1,d1
.noRelocate:
                addq.w  #2,a0           ; skip relocation flag
                lea     fw_LspCurrentBpm(a6),a3
                move.w  (a0)+,(a3)+     ; fw_LspCurrentBpm
                move.l  a0,(a3)+        ; fw_LspInstruments, LSP data has -12 offset on instrument tab (to win 2 cycles in fast player :))
                move.w  (a0)+,(a3)+     ; fw_LspEscCodeRewind
                move.l  (a0)+,(a3)+     ; fw_LspEscCodeSetBpm/fw_LspEscCodeGetPos
                move.l  (a0)+,(a3)+     ; fw_LspMusicLength

                move.w  (a0)+,d0        ; instrument count
                add.w   d0,d0
                subq.w  #1,d0
.relocLoop:
                add.l   d1,(a0)+
                addq.l  #2,a0
                dbra    d0,.relocLoop

                move.w  (a0)+,d0        ; codes table size
                move.l  a0,fw_LspCodeTableAddr(a6) ; code table
                add.w   d0,d0
                add.w   d0,a0

; read sequence timing infos (if any)
                move.w  (a0)+,d0
                move.w  d0,(a3)+        ; fw_LspSeqCount
                move.l  a0,(a3)+        ; fw_LspSeqTable
                clr.w   (a3)+           ; fw_LspCurrentSeq
                move.w  d0,d1
                lsl.w   #3,d1           ; 8 bytes per entry
                adda.w  d1,a0

                movem.l (a0)+,d0/d1/d2  ; word stream size/byte stream loop point/word stream loop point
                move.l  a0,(a3)+        ; fw_LspStreamBase
                lea     (a0,d0.l),a1    ; byte stream
                move.l  a1,(a3)+        ; fw_LspByteStream
                move.l  a0,(a3)+        ; fw_LspWordStream
                add.l   d1,a1
                add.l   d2,a0
                move.l  a1,(a3)+        ; fw_LspByteStreamLoop
                move.l  a0,(a3)+        ; fw_LspWordStreamLoop
                bset    #1,$bfe001      ; disabling this fucking Low pass filter!!
                rts

;------------------------------------------------------------------
;
;   LSP_MusicSetPos
;
;       In: d0: seq position (from 0 to last seq of the song)
;       Out:None
;
;   Force the replay pointer to a seq position. If music wasn't converted
;   using -setpos option, this func does nothing
;
;------------------------------------------------------------------
LSP_MusicSetPos:
                lea     fw_LspSeqCount(a6),a1
                cmp.w   (a1)+,d0        ; fw_LspSeqCount
                bge.s   .noTimingInfo
                move.l  (a1)+,a0        ; fw_LspSeqTable
                move.w  d0,(a1)+        ; fw_LspCurrentSeq
                lsl.w   #3,d0
                lea     8(a0,d0.w),a0
                move.l  (a1)+,d0        ; fw_LspStreamBase
                move.l  -(a0),d1
                add.l   d0,d1
                move.l  d1,(a1)+        ; fw_LspByteStream
                move.l  -(a0),d1
                add.l   d0,d1
                move.l  d1,(a1)+        ; fw_LspWordStream
.noTimingInfo:
                rts

                if      0
;------------------------------------------------------------------
;
;   LSP_MusicGetPos
;
;       In: None
;       Out: d0:  seq position (from 0 to last seq of the song)
;
;   Get the current seq position. If music wasn't converted with
;   -getpos option, this func just returns 0
;
;------------------------------------------------------------------
LSP_MusicGetPos:
                move.w  fw_LspCurrentSeq(a6),d0
                rts
                endc
