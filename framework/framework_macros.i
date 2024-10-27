        IFND    FRAMEWORK_MACROS_I
FRAMEWORK_MACROS_I     SET     1

        IFD     FW_DEMO_PART
CALLFW  MACRO
        jsr     _LVOFrameWork\1(a6)
        ENDM
        ELSE
CALLFW  MACRO
        bsr     fw_\1
        ENDM
        ENDC

DEFFWFUNC MACRO
        IF      FWGENLVOTABLE
        dc.w    fw_\1-*
        ELSE
FWLVOPOS SET FWLVOPOS-6
        IFND    _LVOFrameWork\1
_LVOFrameWork\1 = FWLVOPOS
        ENDC
        ENDC
        ENDM

DISABLE_INTS MACRO
        ; do this twice so to be sure that it has propagated to IPL and we really don't get an interrupt
        move.w  #INTF_INTEN,intena(a5)
        move.w  #INTF_INTEN,intena(a5)
        ENDM

ENABLE_INTS MACRO
        move.w  #INTF_SETCLR|INTF_INTEN,intena(a5)
        ENDM

;Blitter logic macros
;& (bitwise and)
;^ (bitwise exclusive-or)
;| (bitwise inclusive-or)
;~ (bitwise not)
;                                                   idle cycles for normal operation (not line or fill!)
BLTEN_A     = $0800                                 ; 1 idle cycle
BLTEN_B     = $0400                                 ; 2 idle cycles
BLTEN_C     = $0200                                 ; 1 idle cycle
BLTEN_D     = $0100                                 ; 1 idle cycle
BLTEN_AD    = (BLTEN_A|BLTEN_D)                     ; NO idle cycle
BLTEN_BD    = (BLTEN_B|BLTEN_D)                     ; 1 idle cycle
BLTEN_CD    = (BLTEN_C|BLTEN_D)                     ; 1 idle cycle
BLTEN_ABD   = (BLTEN_A|BLTEN_B|BLTEN_D)             ; NO idle cycle
BLTEN_ACD   = (BLTEN_A|BLTEN_C|BLTEN_D)             ; NO idle cycle
BLTEN_BCD   = (BLTEN_B|BLTEN_C|BLTEN_D)             ; 1 idle cycle
BLTEN_ABCD  = (BLTEN_A|BLTEN_B|BLTEN_C|BLTEN_D)     ; NO idle cycle
BLTEN_AB    = (BLTEN_A|BLTEN_B)                     ; 1 idle cycle
BLTEN_AC    = (BLTEN_A|BLTEN_C)                     ; NO idle cycle
BLTEN_BC    = (BLTEN_B|BLTEN_C)                     ; 1 idle cycle
BLTEN_ABC   = (BLTEN_A|BLTEN_B|BLTEN_C)             ; NO idle cycle

BLT_A   = %11110000
BLT_B   = %11001100
BLT_C   = %10101010

BLTHOGON MACRO
        move.w  #DMAF_SETCLR|DMAF_BLITHOG,dmacon(a5)
        ENDM
BLTHOGOFF MACRO
        move.w  #DMAF_BLITHOG,dmacon(a5)
        ENDM

BLTWAIT MACRO
.bw\@
        btst    #DMAB_BLTDONE-8,dmaconr(a5)
        bne.s   .bw\@
        ENDM

;--------------------------------------------------------------------

; channels, minterm, shift a, shift b, (optional: target)
BLTCON_SET     MACRO
        ; write both bltcon0/bltcon1
        IFNC	'\5',''
        move.l  #(((BLTEN_\1+((\2)&$ff))|(\3<<12))<<16)|(\4<<12),\5
        ELSE
        move.l  #(((BLTEN_\1+((\2)&$ff))|(\3<<12))<<16)|(\4<<12),bltcon0(a5)
        ENDC
        ENDM

; channels, minterm, shift a, (optional: target)
BLTCON0_SET     MACRO
        ; write only bltcon0
        IFNC	'\4',''
        move.w  #((BLTEN_\1+((\2)&$ff))|(\3<<12)),\4
        ELSE
        move.w  #((BLTEN_\1+((\2)&$ff))|(\3<<12)),bltcon0(a5)
        ENDC
        ENDM

; channels, minterm, shift a, shift b, bltcon1 flags, (optional: target)
BLTCON_SET_X   MACRO
        ; write both bltcon0/bltcon1
        IFNC	'\6',''
        move.l  #(((BLTEN_\1+((\2)&$ff))|(\3<<12))<<16)|(\4<<12)|(\5),\6
        ELSE
        move.l  #(((BLTEN_\1+((\2)&$ff))|(\3<<12))<<16)|(\4<<12)|(\5),bltcon0(a5)
        ENDC
        ENDM

; issue blitter wait to copper list (in a0)
COPBLITWAIT MACRO
        move.l  #COP_WAITBLIT_DATA,(a0)+
        move.l  #COP_WAITBLIT_DATA,(a0)+    ; avoid OCS hardware bug
        ENDM

; issue immediate write of register to copper list (in a0)
COPIMOVE MACRO
        move.l  #((\2)<<16)|((\1)&$ffff),(a0)+
        ENDM

; issue register (or ea) write of register to copper list (in a0)
COPRMOVE MACRO
        move.w  #\2,(a0)+
        move.w  \1,(a0)+
        ENDM

; write 32 bit pointer to register pair to copper list (in a0) using temp data register
COPPTMOVE MACRO
        move.l  \1,\3
        swap    \3
        move.w  #\2,(a0)+
        move.w  \3,(a0)+
        move.w  #(\2)+2,(a0)+
        move.w  \1,(a0)+
        ENDM

; reuse temp register of COPPTMOVE to write the same pointer to more register pairs
COPPTMOVEMORE MACRO
        move.w  #\2,(a0)+
        move.w  \3,(a0)+
        move.w  #(\2)+2,(a0)+
        move.w  \1,(a0)+
        ENDM

; write 32 bit pointer in data register to register pair to copper list (in a0)
COPDPTMOVE MACRO
        swap    \1
        move.w  #\2,(a0)+
        move.w  \1,(a0)+
        swap    \1
        move.w  #(\2)+2,(a0)+
        move.w  \1,(a0)+
        ENDM

        IF      FW_BLITTERQUEUE_SUPPORT
; shortcut macro for AddToBlitterQueue (queue must NOT be empty!)
; first parameter: node
; second parameter: scratch address register
ADD_TO_BLITTER_QUEUE MACRO
        move.l  fw_BlitterQueueWritePtr(a6),\2
        move.l  \1,(\2)
        move.l  \1,fw_BlitterQueueWritePtr(a6)
        ENDM

; the following macros are for a series of blits,
; shortcut macro for AddToBlitterQueue (queue must NOT be empty!)
; parameter: register that is used for storing the previous node pointer
PREP_ADD_TO_BLITTER_QUEUE MACRO
        move.l  fw_BlitterQueueWritePtr(a6),\1
        ENDM

; shortcut macro for AddToBlitterQueue (queue MUST be empty!), replaces PREP_ADD_TO_BLITTER_QUEUE
; first parameter: node
; second parameter: register that is used for storing the previous node pointer
FIRST_ADD_TO_BLITTER_QUEUE MACRO
        move.l  \1,\2
        ENDM

; shortcut macro for AddToBlitterQueue (queue must NOT be empty!)
; first parameter: node
; second parameter: register that is used for storing the previous node pointer
FAST_ADD_TO_BLITTER_QUEUE MACRO
        move.l  \1,(\2)
        move.l  \1,\2
        ENDM

; shortcut macro for AddToBlitterQueue (queue MAY be empty!)
; first parameter: node
; second parameter: register that is used for storing the previous node pointer
SAFE_ADD_TO_BLITTER_QUEUE MACRO
        tst.l   fw_BlitterQueueWritePtr(a6)
        beq.s   .isfirst\@
        move.l  fw_BlitterQueueWritePtr(a6),\2
        move.l  \1,(\2)
.isfirst\@
        move.l  \1,\2
        ENDM

; shortcut macro for AddToBlitterQueue (queue must NOT be empty!)
; first parameter: node
; second parameter: register that is used for storing the previous node pointer
LAST_ADD_TO_BLITTER_QUEUE MACRO
        move.l  \1,(\2)
        move.l  \1,fw_BlitterQueueWritePtr(a6)
        ENDM

; shortcut macro for AddToBlitterQueue
; parameter: register that is used for storing the previous node pointer
TERM_ADD_TO_BLITTER_QUEUE MACRO
        move.l  \1,fw_BlitterQueueWritePtr(a6)
        ENDM

TERMINATE_BLITTER_QUEUE MACRO
        clr.l   fw_BlitterQueueWritePtr(a6)
        ENDM
        ENDC

        ENDC ; FRAMEWORK_MACROS_I