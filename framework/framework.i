        IFND    FRAMEWORK_I
FRAMEWORK_I     SET     1

        include "../includes/hardware/custom.i"
        include "../includes/hardware/copper.i"
        include "../includes/hardware/cia.i"
        include "../includes/hardware/intbits.i"
        include "../includes/hardware/dmabits.i"
        include "../includes/hardware/adkbits.i"
        include "../includes/hardware/blitbits.i"
        include "../includes/exec/types.i"
        include "../includes/exec/nodes.i"
        include "../includes/exec/lists.i"
        include "../includes/exec/macros.i"
        include "../includes/exec/execbase.i"
        include "../includes/dos/doshunks.i"
        include "../includes/lvo/lvo.i"
        include "../framework/framework_macros.i"

FWGENLVOTABLE   SET     0
        include "../framework/framework_lvos.i"

; error color codes
ERROR_OUTOFMEMORY       = $0f00         ; one of the memory stacks ran out of memory
ERROR_MEMORYWRONGPOP    = $0f80         ; nothing to pop the current direction
ERROR_INVALID_PARAMS    = $0ff0         ; one of the api functions was called with invalid parameters
ERROR_TOOMANYHUNKS      = $00f0         ; the executable has too many hunks. see: MAX_HUNKS
ERROR_HUNKBROKEN        = $000f         ; one of the executables hunks is broken (e.g. header or compressed hunk).
ERROR_DISK              = $00ff         ; error loading via trackloader
ERROR_FILE_NOT_FOUND    = $0088         ; expected file not found

DEFB_MORE_HUNKS = 15                    ; must be sign bit
DEFF_MORE_HUNKS = (1<<DEFB_MORE_HUNKS)
DEFB_CHIPMEM    = 7                     ; must be sign bit
DEFF_CHIPMEM    = (1<<DEFB_CHIPMEM)

DEFS_TYPE       = 0
DEFM_TYPE       = (7<<DEFS_TYPE)
DEFF_DATAFILE   = (0<<DEFS_TYPE)
DEFF_HUNK_CODE  = (1<<DEFS_TYPE)
DEFF_HUNK_DATA  = (2<<DEFS_TYPE)
DEFF_HUNK_BSS   = (3<<DEFS_TYPE)
DEFF_HUNK_RELOC = (4<<DEFS_TYPE)

DEFS_PACKMODE   = 4
DEFM_PACKMODE   = (7<<DEFS_PACKMODE)
DEFF_UNPACKED   = (0<<DEFS_PACKMODE)
DEFF_LZ4        = (1<<DEFS_PACKMODE)    ; allows parallel loading/decrunching
DEFF_DOYNAX     = (2<<DEFS_PACKMODE)    ; needs to be loaded to fastmem
DEFF_ZX0        = (3<<DEFS_PACKMODE)    ; needs to be loaded to fastmem
DEFF_ZSTANDARD  = (4<<DEFS_PACKMODE)    ; not implemented

DEFS_DELTAMODE  = 8
DEFM_DELTAMODE  = (3<<DEFS_DELTAMODE)
DEFF_NODELTA    = (0<<DEFS_DELTAMODE)
DEFF_DELTA8     = (1<<DEFS_DELTAMODE)
DEFF_DELTA16    = (2<<DEFS_DELTAMODE)    ; not implemented
DEFF_DELTA32    = (3<<DEFS_DELTAMODE)    ; not implemented

DEFB_IN_PLACE   = 11
DEFF_IN_PLACE   = (1<<DEFB_IN_PLACE)

        IF      (FW_STANDALONE_FILE_MODE==0)|FW_HD_TRACKMO_MODE

FW_DIRECTORY_ENTRIES_OFFSET = 512

    STRUCTURE   DirEntry,0
        STRUCT  de_Name,16
        LABEL   de_NextHunk
        UWORD   de_Flags                ; see above
        UBYTE   de_HunkNum
        UBYTE   de_NumHunks             ; >0 -> LoadSeg, otherwise simple data file
        ULONG   de_MemorySize           ; memory needed
        ULONG   de_DiskOffset           ; offset on disk (or 0 if BSS)
        ULONG   de_DiskLength           ; load size
        LABEL   de_SIZEOF               ; 32 -> up to 16 files per block
        ENDC

        IF      FW_BLITTERQUEUE_SUPPORT
    STRUCTURE   BlitterQueueNode,0
        APTR    bq_Next
        APTR    bq_Routine
        LABEL   bq_Data
        LABEL   bq_SIZEOF
        ENDC

        IF      FW_MULTITASKING_SUPPORT
    STRUCTURE   FrameworkTask,LN_SIZE
        APTR    ft_USP
        IF      FW_TOP_BOTTOM_MEM_SECTIONS
        UWORD   ft_MemDirection
        ENDC
        LABEL   ft_StackStart
        STRUCT  ft_Stack,512-ft_StackStart
        LABEL   ft_StackEnd
        LABEL   ft_SIZEOF
        ENDC

        IF      FW_DYNAMIC_MEMORY_SUPPORT
    STRUCTURE   MemTopBottom,0
        APTR    mtb_CurrLevelPtr        ; Top (from $80000 down) or Bottom (from $400 up) pointer
        APTR    mtb_MinLevelPtr         ; Min Top or Bottom pointer on free all
        LABEL   mtb_SIZEOF

    STRUCTURE   ChipFastMemState,0
        STRUCT  cf_ChipMemLevel,mtb_SIZEOF
        STRUCT  cf_FastMemLevel,mtb_SIZEOF
        LABEL   cf_SIZEOF
        ENDC

        IF      FW_PALETTE_LERP_SUPPORT
    STRUCTURE   Lerp,0      ; don't change order!
        WORD    le_Add
        UWORD   le_Current
        LABEL   le_SIZEOF

    STRUCTURE   ColorLerp,0 ; don't change order!
        UWORD   cl_Color
        WORD    cl_Steps    ; negative in first entry means fading done
        STRUCT  cl_Red,le_SIZEOF
        STRUCT  cl_Green,le_SIZEOF
        STRUCT  cl_Blue,le_SIZEOF
        LABEL   cl_SIZEOF
        ENDC

    STRUCTURE   FrameWork,0
        UWORD   fw_FrameCounterLong
        UWORD   fw_FrameCounter

        APTR    fw_PartFwBase
        APTR    fw_PrimaryFwBase
        ULONG   fw_PartDataSize
        APTR    fw_GlobalUserData       ; you can use this for your custom trackloading global data area

        IF      FW_DYNAMIC_MEMORY_SUPPORT
        IF      FW_TOP_BOTTOM_MEM_SECTIONS
        UWORD   fw_MainMemDirection
        ENDC
        STRUCT  fw_MemBottomStack,cf_SIZEOF*FW_MAX_MEMORY_STATES
        STRUCT  fw_MemTopStack,cf_SIZEOF*FW_MAX_MEMORY_STATES
        ULONG   fw_MaxChipUsed
        ULONG   fw_MaxFastUsed
        UWORD   fw_CurrMemBottomLevel
        UWORD   fw_CurrMemTopLevel
        ENDC

        APTR    fw_ChipMemStack
        APTR    fw_ChipMemStackEnd
        APTR    fw_FastMemStack
        APTR    fw_FastMemStackEnd

        APTR    fw_EmptySprite
        APTR    fw_BaseCopperlist

        APTR    fw_VBR
        APTR    fw_DemoAbortStackPointer
        BOOL    fw_AgaChipset
        IF      FW_STANDALONE_FILE_MODE
        APTR    fw_OrigBaseMemAllocAddr
        ULONG   fw_OrigBaseMemAllocLength
        APTR    fw_OrigChipMemAllocAddr
        ULONG   fw_OrigChipMemAllocLength
        APTR    fw_OrigFastMemAllocAddr
        ULONG   fw_OrigFastMemAllocLength
        APTR    fw_WBMessage
        APTR    fw_OldGfxView
        APTR    fw_DosBase
        APTR    fw_GfxBase
        STRUCT  fw_OldControls,2*4 ; intena, intreq, dmacon, adkcon
        APTR    fw_OldSystemVBlankIRQ
        APTR    fw_OldCiaIRQ
        APTR    fw_CiaBResource
        STRUCT  fw_SysFriendlyInterrupt,IS_SIZE
        ENDC

        STRUCT  fw_EmptyRegs,4*16

        IF      (FW_STANDALONE_FILE_MODE==0)|FW_HD_TRACKMO_MODE
        APTR    fw_DirBuffer
        APTR    fw_TrackBuffer
        IF      FW_MULTITASKING_SUPPORT
        APTR    fw_TrackloaderTask
        ENDC
        ENDC
        IFEQ    FW_STANDALONE_FILE_MODE
        ULONG   fw_ExpectedFirstFileID
        APTR    fw_MfmTrackBuffer
        UWORD   fw_CurrentCylinder
        UWORD   fw_CurrentHead
        UWORD   fw_CurrentDrive
        UWORD   fw_LastMfmTrack
        UWORD   fw_LastTrack
        UWORD   fw_MfmDoPrefetch
        BOOL    fw_MfmReadingTriggered
        BOOL    fw_MfmReadingDone
        BOOL    fw_DriveMotorOn
        ULONG   fw_DriveSettleTime
        ULONG   fw_TrackChecksum
        UWORD   fw_TrackloaderIdle
        IF      FW_TRACKMO_LZ4_SUPPORT|FW_TRACKMO_LZ4_DLT8_SUPPORT
        UWORD   fw_TrackLz4State
        UWORD   fw_TrackLz4LiteralLength    ; if we have literals >64 KB, we're f*cked anyway
        UWORD   fw_TrackLz4MatchLength      ; duplicating >64 KB is also very improbable
        ULONG   fw_TrackLz4Offset
        UBYTE   fw_TrackLz4Delta8Value
        ALIGNWORD
        ENDC
        ENDC

        APTR    fw_DefaultIRQ
        IF      FW_VBL_IRQ_SUPPORT
        APTR    fw_VBlankIRQ
        ENDC
        IF      FW_COPPER_IRQ_SUPPORT
        APTR    fw_CopperIRQ
        ENDC
        IF      FW_MULTITASKING_SUPPORT
        STRUCT  fw_Tasks,MLH_SIZE
        UWORD   fw_MainCurrentFrame
        APTR    fw_BackgroundTask
        APTR    fw_MultitaskingIRQ
        APTR    fw_BlitterTaskIRQ
        APTR    fw_PrimaryUSP
        APTR    fw_BackgroundTaskUSP
        ENDC

        IF      FW_BLITTERQUEUE_SUPPORT
        APTR    fw_BlitterQueueIRQ
        APTR    fw_BlitterQueueWritePtr ; don't change order
        APTR    fw_BlitterQueueHeadPtr  ; don't change order
        APTR    fw_BlitterQueueReadPtr  ; don't change order
        ENDC

        IF      (FW_STANDALONE_FILE_MODE==0)|FW_HD_TRACKMO_MODE
        STRUCT  fw_HunkPointers,4*FW_MAX_DOS_HUNKS
        STRUCT  fw_PreloadHunkPointers,4*FW_MAX_DOS_HUNKS
        STRUCT  fw_PreloadRelocHunkPointers,4*FW_MAX_DOS_HUNKS

        APTR    fw_LastLoadedPart
        APTR    fw_PrePartLaunchHook
        APTR    fw_PrepNextPartHook
        ENDC

        IF      FW_SINETABLE_SUPPORT
        APTR    fw_SinTable
        APTR    fw_CosTable
        ENDC

        IF      FW_SCRIPTING_SUPPORT
        APTR    fw_ScriptPointer
        UWORD   fw_ScriptFrameOffset
        IF      FW_MUSIC_SUPPORT
        APTR    fw_MusicScriptPointer
        ENDC
        ENDC

        IF      FW_MUSIC_SUPPORT
        BOOL    fw_MusicEnabled
        APTR    fw_MusicData
        APTR    fw_MusicSamples

        UWORD   fw_MusicFrameCount
        UWORD   fw_MusicPatternRow
        BOOL    fw_MusicPatternNewRow

        IF      (FW_MUSIC_PLAYER_CHOICE==1)|(FW_MUSIC_PLAYER_CHOICE==2)
        APTR    fw_LspDmaConPatch       ; patch address
        APTR    fw_LspCodeTableAddr     ; code table addr
        ; do not reorder!
        UWORD   fw_LspCurrentBpm        ; current BPM
        APTR    fw_LspInstruments       ; LSP instruments table addr
        UWORD   fw_LspEscCodeRewind
        UWORD   fw_LspEscCodeSetBpm
        UWORD   fw_LspEscCodeGetPos
        ULONG   fw_LspMusicLength       ; music len in frame ticks
        UWORD   fw_LspSeqCount
        APTR    fw_LspSeqTable
        UWORD   fw_LspCurrentSeq
        APTR    fw_LspStreamBase        ; start of stream info
        APTR    fw_LspByteStream        ; byte stream
        APTR    fw_LspWordStream        ; word stream
        APTR    fw_LspByteStreamLoop    ; byte stream loop point
        APTR    fw_LspWordStreamLoop    ; word stream loop point
        ; END of fixed ordering
        STRUCT  fw_LspResetv,4*4        ; Loop loading data ptr
        IF      FW_MUSIC_PLAYER_CHOICE==2
        UWORD   fw_LspLastCiaBpm
        ULONG   fw_LspCiaClock
        ENDC
        ENDC

        IF      (FW_MUSIC_PLAYER_CHOICE==4)||(FW_MUSIC_PLAYER_CHOICE==5)
        APTR    fw_PretrackerMyPlayer
        APTR    fw_PretrackerMySong
        ULONG   fw_PretrackerProgress
        APTR    fw_PretrackerCopperlist
        ENDC
        ENDC

        ULONG   fw_MaxVposForTask

        IFD     gbd_SIZEOF
        STRUCT  fw_GlobalBonusData,gbd_SIZEOF
        ENDC
        ALIGNLONG
        LABEL   fw_SIZEOF

        ENDC ; FRAMEWORK_I
