; Bootblock by Chris 'platon42' Hodges.

        opt     p+,o+

DEBUG_DETAIL    set 0

FW_DIRECTORY_ENTRIES_OFFSET = 512

        include "exec/execbase.i"
        include "exec/io.i"
        include "exec/memory.i"
        include "exec/macros.i"

        include "hardware/adkbits.i"
        include "hardware/cia.i"
        include "hardware/custom.i"
        include "hardware/dmabits.i"
        include "hardware/intbits.i"

        include "lvo/lvo.i"

_start:
        dc.b    'D','O','S',0 ; disk type
        dc.l    0           ; checksum 'PLAT'
        dc.b    'ON42'      ; root block 'ON42'

_entrypoint:
        ; Because this is a bootblock, we will have ExecBase in a6 here
        ; a1 is IO-Request
        PUSHM   d2/a2-a3                ; keep registers safe, otherwise bootstrap will crash
        move.l  a1,a3
        lea     _start+FW_DIRECTORY_ENTRIES_OFFSET+20(pc),a2    ; de_MemorySize
        move.l  (a2)+,d0
        PUTMSG  10,<"Alloc %ld bytes">,d0
        moveq.l #MEMF_ANY,d1
        CALL    AllocMem
        move.l  d0,-(sp)
        beq.s   .error

        move.l  (a2)+,IO_OFFSET(a3)     ; de_DiskOffset
        move.l  (a2)+,d0                ; de_DiskLength
        add.w   #511,d0
        and.w   #-512,d0                ; round to 512 block size
        move.l  d0,IO_LENGTH(a3)

        moveq.l #MEMF_CHIP,d1
        CALL    AllocMem
        move.l  d0,-(sp)
        bne.s   .good
.error  move.w  #$f00,$dff180
        bra.s   .error
.good
        PUTMSG  10,<"Loading %ld from offset %ld to %p">,IO_LENGTH(a3),IO_OFFSET(a3),d0
        move.l  d0,IO_DATA(a3)

        move.l  a3,a1
        CALL    DoIO
        tst.l   d0
        bne.s   .error

        move.l  (sp)+,a0
        move.l  (sp),a1
        PUTMSG  10,<"Decrunching %p to %p">,a0,a1
        bsr.s   zx0_decompress  ; a3 not trashed

        PUTMSG  10,<"FreeMem %p">,a1
        move.l  IO_DATA(a3),a1
        move.l  IO_LENGTH(a3),d0
        CALL    FreeMem

        cmp.w   #37,LIB_VERSION(a6)
        blo.s   .lameos
        CALL    CacheClearU
.lameos

.execute
        move.l  (sp)+,a0            ; execute this!
        PUTMSG  10,<"Returning %p for execution">,a0
        POPM
        moveq.l #0,d0               ; no error
        rts

        include "unpackers/zx0.asm"
