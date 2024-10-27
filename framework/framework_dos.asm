;--------------------------------------------------------------------
; Load, decrunch and run the given part
;
; Searches for the given file name on disk, allocates enough memory
; to load the compressed hunks, decrunches them (maybe in-place)
; relocates the hunks, executes an optional pre-launch hook
; and finally calls the loaded part.
;
; A part may have been preloaded using PreloadPart in which case the
; loading from disk is skipped and only the allocation and decrunching
; happens.
;
; Restores the framework base to the default after execution and
; frees all memory allocated.
;
; In : a0 = filename
; Trashes: probably all registers
;
fw_ExecuteNextPart:
        PUTMSG  10,<10,"%d: *** Preparing to execute next part %s ***">,fw_FrameCounterLong(a6),a0
        bsr     fw_LoadNextPart

        PUSHM   a0
        bsr     fw_CheckPrePartLaunchHook
        POPM

        IF      FW_MUSIC_SUPPORT
        PUTMSG  10,<"%d: *** Executing next part %p at music frame %d">,fw_FrameCounterLong(a6),a0,fw_MusicFrameCount-2(a6)
        ELSE
        PUTMSG  10,<"%d: *** Executing next part %p">,fw_FrameCounterLong(a6),a0
        ENDC
        jsr     (a0)
        IF      FW_MUSIC_SUPPORT
        PUTMSG  10,<"%d: *** Part finished at music frame %d",10>,fw_FrameCounterLong(a6),fw_MusicFrameCount-2(a6)
        ELSE
        PUTMSG  10,<"%d: *** Part finished",10>,fw_FrameCounterLong(a6)
        ENDC

        bsr     fw_RestoreFrameworkBase
        bsr     fw_DropCurrentMemoryAllocations
        rts

;--------------------------------------------------------------------
; Load and decrunch given part
;
; Searches for the given file name on disk, allocates enough memory
; to load the compressed hunks, decrunches them (maybe in-place)
; and relocates the hunks. Part is not executed, stores the loading
; address of first (typically code) hunk in fw_LastLoadedPart(a6).
; Note that this also allocates BSS hunks if there any.
;
; This can be used for background loading the next part.
; See also PreloadPart for an alternative without decrunching.
;
; In : a0 = filename
; Out: a0 = loading address of first hunk
; Trashes: probably all registers
;
fw_LoadNextPart:
        PUTMSG  10,<10,"%d: *** Loading next part %s ***">,fw_FrameCounterLong(a6),a0
        clr.l   fw_LastLoadedPart(a6)
        bsr     fw_DropCurrentMemoryAllocations
        bsr     fw_FindFile
        bsr     fw_LoadAndDecrunchPart
        move.l  a0,fw_LastLoadedPart(a6)
        rts

;--------------------------------------------------------------------
; Wait until next part has been loaded (and decrunched)
;
; Can be used if a background task is used to load the next part to
; to ensure the loading and decrunching has finished.
;
        IF      FW_MULTITASKING_SUPPORT
fw_WaitForPartLoaded:
        tst.l   fw_LastLoadedPart(a6)
        bne.s   .done
        PUTMSG  10,<"%d: Part not yet fully loaded. Waiting.">,fw_FrameCounterLong(a6)
.loop   bsr     fw_Yield
        tst.l   fw_LastLoadedPart(a6)
        beq.s   .loop
.done   rts
        ENDC

;--------------------------------------------------------------------
; Check and execute the pre-part launch hook
;
; Internal function to execute a hook that is supposed to be called
; just before ExecuteNextPart starts the part after loading/decrunching.
;
; Hooks can be installed by writing fw_PrePartLaunchHook(a6).
; If this field is NULL, this function does nothing. 
; fw_PrePartLaunchHook(a6) is cleared prior to executing the hook.
;
fw_CheckPrePartLaunchHook:
        move.l  fw_PrePartLaunchHook(a6),d0
        beq.s   .skip
        clr.l   fw_PrePartLaunchHook(a6)
        move.l  d0,a0
        PUTMSG  10,<"Executing pre-part launch hook at %p">,a0
        jmp     (a0)
.skip
        rts


;--------------------------------------------------------------------
; Poor-man's multi disk check
;
; Waits for a disk-change, then re-initializes the loader and reads
; the new directory. This is currently untested and might not work
; well with multiple drives.
;
; In : d0.l = First four bytes of first filename on expected disk.
;
        IFEQ    FW_HD_TRACKMO_MODE
fw_NextDisk:
        move.l  d0,fw_ExpectedFirstFileID(a6)
        bsr     fw_TrackloaderWaitForDiskChange
        ;bra.b  fw_InitDos
        ENDC

;--------------------------------------------------------------------
; Initializes the trackloader and reads the disk directory
fw_InitDos:
        IF      FW_MULTITASKING_SUPPORT
        move.l  fw_TrackloaderTask(a6),a1
        move.b  #-10,LN_PRI(a1) ; FIXME breaks things! Why?
        IFNE    DEBUG_DETAIL
        lea      .loadertask(pc),a0
        move.l  a0,LN_NAME(a1)
        ENDC
        ENDC

        tst.l   fw_DirBuffer(a6)
        bne.s   .hasmem
        move.l  #FW_NUM_DIRECTORY_BLOCKS*512,d0
        bsr     fw_AllocFast
        move.l  a0,fw_DirBuffer(a6)
        IFEQ    FW_HD_TRACKMO_MODE
        move.l  #'Plat',fw_ExpectedFirstFileID(a6)  ; Standard ID for launcher, change ID to detect a second disk
        ENDC
.hasmem
.retry
        IFEQ    FW_HD_TRACKMO_MODE
        bsr     fw_TrackloaderDiskMotorOn
        ENDC
        move.l  fw_DirBuffer(a6),a0
        PUTMSG  10,<"Directory at %p">,a0
        move.l  #FW_DIRECTORY_ENTRIES_OFFSET,d0     ; second block
        move.l  #FW_NUM_DIRECTORY_BLOCKS*512,d1
        bsr     fw_TrackloaderLoad
        IFEQ    FW_HD_TRACKMO_MODE
        move.l  fw_DirBuffer(a6),a0
        move.l  fw_ExpectedFirstFileID(a6),d0
        cmp.l   (a0),d0
        bne.s   .otherdisk
        rts
.otherdisk
        PUTMSG  10,<"Wrong disk %lx">,(a0)
        move.w  fw_CurrentDrive(a6),d0
        addq.w  #1,d0
        move.w  d0,fw_CurrentDrive(a6)
        cmp.w   #4,d0
        bne.s   .retry
        move.w  #ERROR_DISK,d0
        bra     fw_Error
        ELSE
        rts
        ENDC

        IFNE    DEBUG_DETAIL
.loadertask
        dc.b    "Loadertask",0
        even
        ENDC

;--------------------------------------------------------------------
; Locates the DirEntry of a file on disk
;
; The DirEntry contains the meta-data for a file on disk
; (see framework.i).
;
; In : a0 = filename
; Out: a1 = Dir entry structure
;
fw_FindFile:
        PUTMSG  10,<"Searching for %s...">,a0
        move.l  fw_DirBuffer(a6),a1
.restartloop
        moveq.l #0,d0
.loop
        move.b  de_Name(a1,d0.w),d1
        cmp.b   (a0,d0.w),d1
        bne.s   .next
        addq.w  #1,d0
        tst.b   d1
        beq     .foundit
        cmp.w   #16,d0
        beq     .foundit
        bra.s   .loop
.next
        PUTMSG  40,<"%s did not match">,a1
.nextline
        tst.w   de_Flags(a1)
        bpl.s   .nextentry
        PUTMSG  40,<"NL">
        lea     de_NextHunk(a1),a1
        bra.s   .nextline
.nextentry
        lea     de_SIZEOF(a1),a1
        tst.b   de_Name(a1)
        beq.s   .notfound
        PUTMSG  40,<"Next Entry %s">,a1
        bra     .restartloop
.notfound
        PUTMSG  10,<"File %s not found">,a0
        move.w  #ERROR_FILE_NOT_FOUND,d0
        bra     fw_Error
.foundit
        PUTMSG  10,<"Found %s at %p">,a1,a1
        rts

;--------------------------------------------------------------------
; Allocate and load a file (filename) from disk without decrunching
;
; Allocates sufficient memory and loads the possibly compressed file
; from the directory into this memory. File will be loaded to fast
; memory if crunched, otherwise memory allocation depends on the
; flags. Note that this call is not useful for DOS hunk files.
;
; In : a0 = filename
; Out: a0 = start of loaded file in a0
;      a1 = Dir entry structure of the file
;
fw_LoadFile:
        bsr     fw_FindFile
        move.w  #DEFM_PACKMODE,d0
        and.w   de_Flags(a1),d0
        bne.s   fw_LoadPlainFileEntryToFast

;--------------------------------------------------------------------
; Allocate and load a file via DirEntry from disk without decrunching
;
; Allocates sufficient memory and loads the possibly compressed file
; from the directory into this memory. File will be loaded to the
; type of memory specified in the DirEntry.
; Note that this call is not useful for DOS hunk files.
;
; In : a1 = Dir entry structure
; Out: a0 = start of loaded file in a0
;      a1 = Dir entry structure of the file
;
fw_LoadPlainFileEntry:
        PUTMSG  10,<"%d: Loading plain file from offset %ld, size %ld">,fw_FrameCounterLong(a6),de_DiskOffset(a1),de_DiskLength(a1)
        tst.b   de_Flags+1(a1)
        bpl.s   fw_LoadPlainFileEntryToFast
        move.l  de_DiskLength(a1),d0
        move.l  a1,-(sp)
        bsr     fw_AllocChip
        bra.s   fw_InternalLoadFileEntryToBuffer

;--------------------------------------------------------------------
; Allocate and load a file via DirEntry from disk to fast mem
;
; Allocates sufficient memory and loads the possibly compressed file
; from the directory into this memory. File will be loaded to
; fast memory, if available.
;
; In : a1 = DirEntry
; Out: a0 = start of loaded file in a0
;      a1 = DirEntry of the file
;
fw_LoadPlainFileEntryToFast:
        IFEQ    FW_HD_TRACKMO_MODE
fw_LoadReadOnlyPlainFileEntryToFast:
        ENDC
        move.l  de_DiskLength(a1),d0
        move.l  a1,-(sp)
        bsr     fw_AllocFast
fw_InternalLoadFileEntryToBuffer:
        move.l  (sp)+,a1

        bsr     fw_LoadFileToBuffer

        move.l  de_DiskLength(a1),d0
        rts
        IFNE    FW_HD_TRACKMO_MODE
fw_LoadReadOnlyPlainFileEntryToFast:
        move.l  de_DiskLength(a1),d0
        move.l  fw_TrackBuffer(a6),a0
        adda.l  de_DiskOffset(a1),a0
fw_TrackloaderDiskMotorOff:
        rts
        ENDC

;--------------------------------------------------------------------
; Load a file from disk and decrunch it
;
; Allocates sufficient memory and loads the possibly compressed file
; from the directory into this memory. File will be decompressed to
; chip or fast memory depending on its flags.
; Allocation may be slightly bigger if file is decrunchable in-place,
; but uses no additional memory for the compressed data in this case.
;
; Note that this call is not useful for DOS hunk files.
;
; In : a0: Filename
; Out: a0: Pointer to loaded buffer
;      a1: Dir entry structure
;
fw_LoadAndDecrunchFile:
        bsr     fw_FindFile
        move.w  #DEFM_PACKMODE,d0
        and.w   de_Flags(a1),d0
        beq     fw_LoadPlainFileEntry

        PUTMSG  10,<"File %s is crunched">,a1
        IFEQ    FW_HD_TRACKMO_MODE
        IF      FW_ZX0_SUPPORT
        btst    #DEFB_IN_PLACE,de_Flags(a1)
        bne.s   .inplacedecrunch
        ENDC
        ENDC
        move.l  a1,-(sp)                    ; dir entry

        move.l  de_MemorySize(a1),d0
        tst.b   de_Flags+1(a1)
        bpl.s   .usefast
        bsr     fw_AllocChip
        bra.s   .allocated
.usefast
        bsr     fw_AllocFast
.allocated
        move.l  a0,-(sp)                    ; target buffer

        IFEQ    FW_HD_TRACKMO_MODE
        bsr     fw_PushMemoryState
        move.l  de_DiskLength(a1),d0
        bsr     fw_AllocFast

        move.l  4(sp),a1                    ; dir entry

        bsr     fw_LoadFileToBuffer

        move.l  (sp),a2                     ; target buffer
        bsr     fw_DecrunchToBuffer
        move.l  de_MemorySize(a1),d0
        bsr     fw_PopMemoryState
        ELSE
        move.l  a0,a2
        move.l  4(sp),a1
        move.l  fw_TrackBuffer(a6),a0
        adda.l  de_DiskOffset(a1),a0
        bsr     fw_DecrunchToBuffer
        move.l  de_MemorySize(a1),d0
        ENDC
        move.l  (sp)+,a0                    ; target buffer
        move.l  (sp)+,a1                    ; dir entry
        rts

        IFEQ    FW_HD_TRACKMO_MODE
        IF      FW_ZX0_SUPPORT
.inplacedecrunch
        bsr.s   fw_AllocInPlaceDecrunchBuffer
        PUSHM   a0
        bsr.s   fw_LoadAndInPlaceDecrunchToBuffer
        POPM
        rts
        ENDC
        ENDC

;--------------------------------------------------------------------
; Allocate buffer big enough to hold decrunched data + safety distance
;
; In : a1 = dir entry (preserved)
; Out: a0 = buffer
;
fw_AllocInPlaceDecrunchBuffer:
        PUSHM   a1
        move.l  de_MemorySize(a1),d0
        addq.l  #1,d0
        and.w   #-2,d0
        add.l   #FW_IN_PLACE_DECR_SAFE_DIST,d0
        tst.b   de_Flags+1(a1)
        bpl.s   .usefast2
        bsr     fw_AllocChip
        bra.s   .allocated2
.usefast2
        bsr     fw_AllocFast
.allocated2
        POPM
        rts

;--------------------------------------------------------------------
; Loads a crunched file to the end of a pre-allocated buffer and decrunches it in-place
;
; In : a0 = target buffer (memory size of decrunched + safety distance)
;      a1 = dir entry (preserved)
; Out: a0 = end of decrunched buffer
;
fw_LoadAndInPlaceDecrunchToBuffer:
        move.l  a0,-(sp)
        move.l  de_DiskLength(a1),d0
        addq.l  #1,d0
        and.w   #-2,d0
        lea     FW_IN_PLACE_DECR_SAFE_DIST(a0),a0
        move.l  de_MemorySize(a1),d1
        addq.l  #1,d1
        and.w   #-2,d1
        adda.l  d1,a0
        suba.l  d0,a0

        bsr     fw_LoadFileToBuffer

        move.l  (sp)+,a2                    ; target buffer
        ;bra.s   fw_DecrunchToBuffer

;--------------------------------------------------------------------
; Decrunches the given file to the target buffer
;
; In : a0 = source buffer
;      a1 = Dir entry structure
;      a2 = target buffer 
; Out: a0 = END of the buffer written 
;      a1 = Dir entry structure
;
fw_DecrunchToBuffer:
        PUSHM   a1/a2
        move.w  #DEFM_PACKMODE,d0
        and.w   de_Flags(a1),d0
        IF      FW_DOYNAX_SUPPORT
        cmp.w   #DEFF_DOYNAX,d0
        bne.s   .nodoynax
        PUTMSG  10,<"%d: DoynaxDecrunch from %p (%ld) to %p (%ld)">,fw_FrameCounterLong(a6),a0,de_DiskLength(a1),a2,de_MemorySize(a1)
        move.l  a2,a1
        bsr     doynaxdepack
        bra     .decdone
.nodoynax
        ENDC

        IF      FW_ZX0_SUPPORT
        cmp.w   #DEFF_ZX0,d0
        bne.s   .nozx0
        PUTMSG  10,<"%d: ZX0Decrunch from %p (%ld) to %p (%ld)">,fw_FrameCounterLong(a6),a0,de_DiskLength(a1),a2,de_MemorySize(a1)
        move.l  a2,a1
        bsr     zx0_decompress
        bra.s   .decdone
.nozx0
        ENDC

        IF      FW_LZ4_SUPPORT
        cmp.w   #DEFF_LZ4,d0
        bne.s   .nolz4
        move.l  de_DiskLength(a1),d0
        PUTMSG  10,<"%d: LZ4Decrunch from %p (%ld) to %p (%ld)">,fw_FrameCounterLong(a6),a0,d0,a2,de_MemorySize(a1)
        move.l  a2,a1
        bsr     lz4_depack
        bra.s   .decdone
.nolz4
        ENDC

        move.w  #ERROR_INVALID_PARAMS,d0
        bra     fw_Error

.decdone
        move.l  a1,a0
        POPM

        move.w  #DEFM_DELTAMODE,d0
        and.w   de_Flags(a1),d0
        beq.s   .nodelta
        cmp.w   #DEFF_DELTA8,d0
        beq.s   .delta8
        move.w  #ERROR_INVALID_PARAMS,d0
        bra     fw_Error
.delta8
        PUSHM   a2
        move.l  de_MemorySize(a1),d0
        beq.s   .d8done
        PUTMSG  10,<"%d: Delta8 decoding %p %ld bytes">,fw_FrameCounterLong(a6),a2,d0
        moveq.l #0,d1
        subq.l  #1,d0
.d8loop
        add.b   (a2),d1
        move.b  d1,(a2)+
        dbra    d0,.d8loop
        swap    d0
        subq.w  #1,d0
        bcs.s   .d8done
        swap    d0
        bra.s   .d8loop
.d8done
        POPM
.nodelta
        PUTMSG  10,<"%d: Decrunching done">,fw_FrameCounterLong(a6)
        rts

;--------------------------------------------------------------------
; Loads the file into the given buffer
;
; In : a0 = buffer (preserved)
;      a1 = Dir entry structure (preserved)
;
fw_LoadFileToBuffer:
        PUSHM   a0-a3
        move.l  de_DiskOffset(a1),d0
        move.l  de_DiskLength(a1),d1
        PUTMSG  10,<"%d: Loading file %p to buffer %p (%ld)">,fw_FrameCounterLong(a6),a1,a0,d1
        bsr     fw_TrackloaderLoad
        POPM
        rts

;--------------------------------------------------------------------
; Loads and uncompresses the (LZ4) file into the given buffer
;
; Loads and decrunches the given LZ4 or LZ4 delta compressed file while
; loading it from disk -- needs no extra memory.
;
; In : a0 = target buffer
;      a1 = Dir entry structure
; Out: a1 = end of decrunching pointer
;
fw_TrackmoLoadAndDecrunchToBuffer:
        PUTMSG  10,<"%d: Trackmo Loading and Decrunching %p">,fw_FrameCounterLong(a6),a1
        move.w  #DEFM_PACKMODE,d0
        and.w   de_Flags(a1),d0
        IF      FW_TRACKMO_LZ4_SUPPORT|FW_TRACKMO_LZ4_DLT8_SUPPORT
        cmp.w   #DEFF_LZ4,d0
        bne.s   .nolz4
        move.l  de_DiskOffset(a1),d0
        move.l  de_DiskLength(a1),d1
        move.w  #DEFM_DELTAMODE,d2
        and.w   de_Flags(a1),d2

        IF      FW_TRACKMO_LZ4_SUPPORT
        cmp.w   #DEFF_NODELTA,d2
        beq     fw_TrackloaderLoadAndDecrunchLZ4
        ENDC

        IF      FW_TRACKMO_LZ4_DLT8_SUPPORT
        cmp.w   #DEFF_DELTA8,d2
        beq     fw_TrackloaderLoadAndDecrunchLZ4Delta8
        ENDC
.nolz4
        ENDC
.error
        move.w  #ERROR_INVALID_PARAMS,d0
        bra     fw_Error

;--------------------------------------------------------------------
; Load and decrunch a part
;
; Reads, allocates, decrunches and relocates all hunks for the given 
; directory entry.
;
; In : a1 = Dir entry structure
; Out: a0 = launch address of first hunk
;
fw_LoadAndDecrunchPart:
        move.l  d7,-(sp)
        PUTMSG  10,<"%d: Loading and Decrunching %p">,fw_FrameCounterLong(a6),a1

        tst.b   de_NumHunks(a1)
        bne.s   .cont
.b0rked
        move.w  #ERROR_HUNKBROKEN,d0
        bra     fw_Error

.cont
        move.l  a1,a2       ; backup top of the dir entries
        lea     fw_HunkPointers(a6),a3
.hunkallocloop
        moveq.l #0,d7
        move.b  de_HunkNum(a1),d7
        lsl.w   #2,d7

        PUTMSG  30,<"HunkSize %lx">,de_MemorySize(a1)
        move.l  de_MemorySize(a1),d0
        beq.s   .skipthat

        btst    #DEFB_IN_PLACE,de_Flags(a1)
        beq.s   .noinplace
        add.l   #FW_IN_PLACE_DECR_SAFE_DIST,d0
.noinplace
        ; allocate hunk
        PUSHM   a1-a3
        tst.b   de_Flags+1(a1)
        bpl.s   .nochipmem
        bsr     fw_AllocChip
        bra.s   .gotmem
.nochipmem
        bsr     fw_AllocFast
.gotmem
        POPM
        move.l  a0,(a3,d7.w)
.skipthat
        tst.w   de_Flags(a1)
        bpl.s   .hunksallocated
        lea     de_NextHunk(a1),a1
        bra.s   .hunkallocloop

.hunksallocated
        move.l  a2,a1       ; start over

.hunkloadloop
        moveq.l #0,d7
        move.b  de_HunkNum(a1),d7
        PUTMSG  10,<"Hunk num %d">,d7
        lsl.w   #2,d7
        moveq.l #DEFM_TYPE,d0
        and.w   de_Flags(a1),d0
        cmp.w   #DEFF_HUNK_CODE,d0
        beq.s   .codedata
        cmp.w   #DEFF_HUNK_DATA,d0
        beq.s   .codedata
        cmp.w   #DEFF_HUNK_BSS,d0
        beq     .justclear
        cmp.w   #DEFF_HUNK_RELOC,d0
        beq     .reloc
        bra     .b0rked
.codedata
        move.w  #DEFM_PACKMODE,d0
        and.w   de_Flags(a1),d0
        beq     .unpacked
        move.l  fw_PreloadHunkPointers-fw_HunkPointers(a3,d7.w),d1
        beq.s   .loadpacked
        PUSHM   a2-a3
        move.l  (a3,d7.w),a2
        move.l  d1,a0
        clr.l   fw_PreloadHunkPointers-fw_HunkPointers(a3,d7.w)
        PUTMSG  10,<"Decrunching packed data from preload buffer %p to %p">,a0,a2
        bsr     fw_DecrunchToBuffer
        POPM
        bra     .clearmem
.loadpacked
        IF      FW_ZX0_SUPPORT
        btst    #DEFB_IN_PLACE,de_Flags(a1)
        bne.s   .inplacedecrunch
        ENDC
        IF      FW_LZ4_SUPPORT
        IF      FW_TRACKMO_LZ4_SUPPORT
        cmp.w   #DEFF_LZ4,d0
        beq     .trackloadlz4
        ELSE
        cmp.w   #DEFF_LZ4,d0
        beq.s   .genericdecrunch
        ENDC
        ENDC

        IF      FW_ZX0_SUPPORT
        cmp.w   #DEFF_ZX0,d0
        beq.s   .genericdecrunch
        ENDC

        IF      FW_DOYNAX_SUPPORT
        cmp.w   #DEFF_DOYNAX,d0
        beq.s   .genericdecrunch
        ENDC
        bra     .b0rked

        IF      FW_ZX0_SUPPORT|FW_DOYNAX_SUPPORT|(FW_LZ4_SUPPORT&!FW_TRACKMO_LZ4_SUPPORT)
.genericdecrunch
        bsr     fw_PushMemoryState
        PUSHM   a1-a3
        bsr     fw_LoadPlainFileEntryToFast
        POPM
        PUSHM   a1-a3
        move.l  (a3,d7.w),a2     ; target buffer
        bsr     fw_DecrunchToBuffer
        POPM
        bsr     fw_PopMemoryState
        bra     .clearmem
        ENDC

        IF      FW_ZX0_SUPPORT
.inplacedecrunch
        PUTMSG  10,<"%d: In-place loading and decrunching %ld bytes to %p (%d)">,fw_FrameCounterLong(a6),de_DiskLength(a1),a0,d7
        PUSHM   a1-a3
        move.l  (a3,d7.w),a0
        bsr     fw_LoadAndInPlaceDecrunchToBuffer
        POPM
        bra     .clearmem
        ENDC

        IF      FW_TRACKMO_LZ4_SUPPORT
.trackloadlz4
        move.l  (a3,d7.w),a0
        PUSHM   a1-a3
        PUTMSG  10,<"%d: LZ4 loading and decrunching %ld bytes to %p (%d)">,fw_FrameCounterLong(a6),de_DiskLength(a1),a0,d7
        bsr     fw_TrackmoLoadAndDecrunchToBuffer
        move.l  a1,a0
        POPM
        bra     .clearmem
        ENDC

.unpacked
        move.l  fw_PreloadHunkPointers-fw_HunkPointers(a3,d7.w),d0
        beq.s   .loadunpacked
        move.l  d0,a0
        clr.l   fw_PreloadHunkPointers-fw_HunkPointers(a3,d7.w)
        PUTMSG  10,<"Copying unpacked data from preload buffer %p">,a0
        move.l  de_DiskLength(a1),d0
        subq.l  #1,d0
        bmi.s   .clearunpacked
        lsr.w   #2,d0
        move.l  (a3,d7.w),a2
.upcopyloop
        move.l  (a0)+,(a2)+
        dbra    d0,.upcopyloop
        bra.s   .clearunpacked

.loadunpacked
        move.l  (a3,d7.w),a0
        bsr     fw_LoadFileToBuffer
.clearunpacked
        move.l  de_MemorySize(a1),d0
        move.l  de_DiskLength(a1),d1
        sub.l   d1,d0
        move.l  (a3,d7.w),a0
        adda.l  d1,a0
        bra     .clearit

.justclear
        move.l  (a3,d7.w),a0
        move.l  de_MemorySize(a1),d0
        bra     .clearit

.clearmem
        move.l  (a3,d7.w),d0
        add.l   de_MemorySize(a1),d0
        PUTMSG  10,<"%d: End of buffer %p, expected %p, memory size %ld">,fw_FrameCounterLong(a6),a0,d0,de_MemorySize(a1)
        sub.l   a0,d0           ; bytes to clear

.clearit
        tst.l   d0
        bmi     fw_Error
        lsr.l   #2,d0
        beq.s   .checknexthunk
        PUTMSG  10,<"Clearing %d longs at end of buffer %p">,d0,a0
        subq.w  #1,d0
        moveq.l #0,d1
.clearloop
        move.l  d1,(a0)+
        dbra    d0,.clearloop

.checknexthunk
        tst.b   de_Flags(a1)
        bpl     .hunksloaded
        lea     de_NextHunk(a1),a1
        bra     .hunkloadloop

.reloc
        move.l  fw_PreloadRelocHunkPointers-fw_HunkPointers(a3,d7.w),d0
        beq.s   .loadreloc
        move.l  d0,a0
        clr.l   fw_PreloadRelocHunkPointers-fw_HunkPointers(a3,d7.w)
        PUTMSG  10,<"Doing Reloc from preloaded data %p">,a0
        PUSHM   a1
        bsr     .doreloc
        POPM
        bra.s   .checknexthunk
.loadreloc
        bsr     fw_PushMemoryState

        PUSHM   a1-a3
        move.l  a3,-(sp)
        bsr     fw_LoadReadOnlyPlainFileEntryToFast
        move.l  (sp)+,a3
        bsr     .doreloc
        POPM
        bsr     fw_PopMemoryState
        bra     .checknexthunk

.hunksloaded
        bsr     fw_FlushCaches

        move.l  (sp)+,d7
        move.l  fw_HunkPointers(a6),a0
        rts

.doreloc
        move.l  (a3,d7.w),a1    ; target-hunk

        PUTMSG  40,<"Relocating for target hunk %p (%d)">,a1,d7

.hunkrelloop
        move.w  (a0)+,d0
        beq.s   .hunkrelocend
        move.w  (a0)+,d1        ; source-hunk
        PUTMSG  50,<"%d offsets for hunk %d">,a0,d1
        subq.w  #1,d0
        lsl.w   #2,d1
        move.l  (a3,d1.w),d2    ; source_hunk offset
.offsetsloop
        moveq.l #0,d1
        move.w  (a0)+,d1        ; offset
        add.l   d1,d1
        add.l   d2,(a1,d1.l)    ; patch offset into target-hunk
        dbra    d0,.offsetsloop
        bra.s   .hunkrelloop
.hunkrelocend
        rts

;--------------------------------------------------------------------
; Loads the next part into memory without decrunching or executing it
;
; Preloads a part that will be almost instantly executed when calling
; ExecuteNextPart (because only the decrunching will be done).
;
; This function is usually called from a background task with memory
; allocation direction flipped. Note that the filename given here and
; later to ExecuteNextPart must match exactly, otherwise, bad things
; will happen.
;
; In : a0 = filename
;
fw_PreloadPart:
        IFEQ    FW_HD_TRACKMO_MODE
        bsr     fw_FindFile
        move.l  d7,-(sp)
        PUTMSG  10,<"%d: Preparing loading and decrunching of %p">,fw_FrameCounterLong(a6),a1

        tst.b   de_NumHunks(a1)
        bne.s   .cont
.b0rked
        move.w  #ERROR_HUNKBROKEN,d0
        bra     fw_Error

.cont
        lea     fw_PreloadHunkPointers(a6),a2
        lea     fw_PreloadRelocHunkPointers(a6),a3
.hunkloadloop
        moveq.l #0,d7
        move.b  de_HunkNum(a1),d7
        PUTMSG  10,<"Hunk num %d">,d7
        lsl.w   #2,d7
        moveq.l #DEFM_TYPE,d0
        and.w   de_Flags(a1),d0
        cmp.w   #DEFF_HUNK_CODE,d0
        beq.s   .codedata
        cmp.w   #DEFF_HUNK_DATA,d0
        beq.s   .codedata
        cmp.w   #DEFF_HUNK_BSS,d0
        beq.s   .ignorehunk
        cmp.w   #DEFF_HUNK_RELOC,d0
        bne     .b0rked
        PUSHM   a1-a3
        bsr     fw_LoadPlainFileEntryToFast
        POPM
        move.l  a0,(a3,d7.w)
        bra.s   .loaded
.codedata
        PUSHM   a1-a3
        bsr     fw_LoadPlainFileEntryToFast
        POPM
        move.l  a0,(a2,d7.w)
.loaded
.ignorehunk
        tst.b   de_Flags(a1)
        bpl     .hunksloaded
        lea     de_NextHunk(a1),a1
        bra     .hunkloadloop

.hunksloaded
        move.l  (sp)+,d7
        ENDC
        rts
