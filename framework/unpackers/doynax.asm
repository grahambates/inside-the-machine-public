;-------------------------------------------------------------------------------
;Lempel-Ziv decompressor by Johan "Doynax" Forslöf. Call doynamitedepack to decode the entire buffer in
;one go.
;
;This is a fork of the 68000 depacker by Michael Hillebrandt (Axis/Oxyron)
;for the 6502 Doynamite format, except with the encoding rearranged to take
;somewhat better advantage of the 68k architecture.
;
;The present version is 210 bytes long including the tables and should fit
;snugly in the 68020+ cache.
;
;Note that the scheme with a split input stream for odd literal bytes requires
;a significant safety buffer for forward in-place decompression (about 3% but
;dependent on the file to be processed)
;
;Parameters:
;a0 = Input buffer to be decompressed. Must be 16-bit aligned!
;a1 = Output buffer. Points to the end of the data at exit
;
;Register legend:
;d0 = 32-bit shift register terminated by a least-significant 1 bit.
;d1 = Run length.
;d2 = Match offset length in bits.
;d3 = Match offset bitmask.
;d4 = Constant offset length bit mask.
;a0 = Bit-stream pointer.
;a1 = Continuous output pointer.
;a2 = Unaligned literal pointer ahead of the bit-stream. Points to the end of
;     the source buffer at exit.
;a3 = Mid-point where the literal buffer meets the bit-stream at EOF
;a4 = Match source pointer.
;-------------------------------------------------------------------------------
        ;Ensure that the shift-register contains at least 16-bits of data by
        ;checking whether the trailing word is zero, and if so filling up with
        ;another word
DOY_REFILL macro
        DOY_REFILL1 .full\@
        DOY_REFILL2
.full\@
        endm

DOY_REFILL1 macro
        tst.w   d0
        bne.s   \1
        endm

DOY_REFILL2 macro                       ;This swaps in the new bits ahead of the
        move.w  (a0)+,d0                ;old, but that's fine as long as the
        swap.w  d0                      ;encoder is in on the scheme
        endm

        ;Entry point. Wind up the decruncher
doynaxdepack:
        PUSHM   d4/a4
        movea.l (a0)+,a2                ;Unaligned literal buffer at the end of
        adda.l  a0,a2                   ;the stream
        move.l  a2,a3
        move.l  (a0)+,d0                ;Seed the shift register
        moveq.l #@10,d4
        bra.s   .literal
.return
        POPM
        rts

        ;******** Copy a literal sequence ********

.lcopy                                  ;Copy two bytes at a time, with the
        move.b  (a0)+,(a1)+             ;deferral of the length LSB helping
        move.b  (a0)+,(a1)+             ;slightly in the unrolling
        dbra    d1,.lcopy

        lsl.l   #2,d0                   ;Copy odd bytes separately in order
        bcc.s   .match                  ;to keep the source aligned
.lsingle
        move.b  (a2)+,(a1)+

        ;******** Process a match ********

        ;Start by refilling the bit-buffer
.match
        DOY_REFILL1 .mprefix
        cmp.l   a0,a3                   ;Take the opportunity to test for the
        bls.s   .return                 ;end of the stream while refilling
.mrefill
        DOY_REFILL2

.mprefix
        ;Fetch the first three bits identifying the match length, and look up
        ;the corresponding table entry
        rol.l   #3+3,d0
        moveq.l #@70,d1
        and.w   d0,d1
        eor.w   d1,d0
        movem.w doy_table(pc,d1.w),d2/d3/a4

        ;Extract the offset bits and compute the relative source address from it
        rol.l   d2,d0                   ;Reduced by 3 to account for 8x offset
        and.w   d0,d3                   ;scaling
        eor.w   d3,d0
        suba.w  d3,a4
        adda.l  a1,a4

        ;Decode the match length
        DOY_REFILL
        and.w   d4,d1                   ;Check the initial length bit from the
        beq.s   .mcopy                  ;type triple

        moveq.l #1,d1                   ;This loops peeks at the next flag
        tst.l   d0                      ;through the sign bit bit while keeping
        bpl.s   .mendlen2               ;the LSB in carry
        lsl.l   #2,d0
        bpl.s   .mendlen1
.mgetlen
        addx.b  d1,d1
        lsl.l   #2,d0
        bmi.s   .mgetlen
.mendlen1
        addx.b  d1,d1
.mendlen2

        ;Copy the match data a word at a time. Note that the minimum length is
        ;two bytes
        lsl.l   #2,d0                   ;The trailing length payload bit is
        bcc.s   .mhalf                  ;stored out-of-order
.mcopy
        move.b  (a4)+,(a1)+
.mhalf
        move.b  (a4)+,(a1)+
        dbra    d1,.mcopy

        ;Fetch a bit flag to see whether what follows is a literal run or
        ;another match
        add.l   d0,d0
        bcc.s   .match

        ;******** Process a run of literal bytes ********

        DOY_REFILL                      ;Replenish the shift-register
.literal
        ;Extract delta-coded run length in the same swizzled format as the
        ;matches above
        moveq   #0,d1
        add.l   d0,d0
        bcc.s   .lsingle                ;Single out the one-byte case
        bpl.s   .lendlen
.lgetlen
        addx.b  d1,d1
        lsl.l   #2,d0
        bmi.s   .lgetlen
.lendlen
        addx.b  d1,d1

        ;Branch off to the main copying loop unless the run length is 256 bytes
        ;or greater, in which case the sixteen guaranteed bits in the buffer
        ;may have run out.
        ;In the latter case simply give up and stuff the payload bits back onto
        ;the stream before fetching a literal 16-bit run length instead
.lcopy_near
        dbvs    d1,.lcopy

        add.l   d0,d0
        eor.w   d1,d0
        ror.l   #7+1,d0                 ;Note that the constant MSB acts as a
        move.w  (a0)+,d1                ;substitute for the unfetched stop bit
        bra.s   .lcopy_near

        ;******** Offset coding tables ********

DOY_OFFSET macro
        dc.w    (\1)-3                  ;Bit count, reduced by three
        dc.w    (1<<(\1))-1             ;Bit mask
        dc.w    -(\2)                   ;Base offset
        endm

doy_table:
        DOY_OFFSET 3,1                  ;Short A
        dc.w    0
        DOY_OFFSET 4,1                  ;Long A
        dc.w    0                       ;(Empty hole)
        DOY_OFFSET 6,1+8                ;Short B
        dc.w    0                       ;(Empty hole)
        DOY_OFFSET 7,1+16               ;Long B
        dc.w    0                       ;(Empty hole)
        DOY_OFFSET 8,1+8+64             ;Short C
        dc.w    0                       ;(Empty hole)
        DOY_OFFSET 10,1+16+128          ;Long C
        dc.w    0                       ;(Empty hole)
        DOY_OFFSET 10,1+8+64+256        ;Short D
        dc.w    0                       ;(Empty hole)
        DOY_OFFSET 13,1+16+128+1024     ;Long D