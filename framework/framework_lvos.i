FWLVOPOS    SET     0

        DEFFWFUNC InitPart
        DEFFWFUNC RestoreFrameworkBase
        DEFFWFUNC Error
        DEFFWFUNC FlushCaches
        DEFFWFUNC SetBaseCopper
        DEFFWFUNC SetCopper
        DEFFWFUNC VSync
        DEFFWFUNC WaitForFrame

        IF      FW_DYNAMIC_MEMORY_SUPPORT
        DEFFWFUNC PushMemoryState
        DEFFWFUNC PopMemoryState
        DEFFWFUNC AllocChip
        IF      FW_64KB_PAGE_MEMORY_SUPPORT
        DEFFWFUNC AllocChip64KB
        ENDC
        DEFFWFUNC AllocFast
        DEFFWFUNC DropCurrentMemoryAllocations
        IF      FW_TOP_BOTTOM_MEM_SECTIONS
        DEFFWFUNC FlipAllocationDirection
        ENDC
        ENDC

        IF      (FW_STANDALONE_FILE_MODE==0)|FW_HD_TRACKMO_MODE
        DEFFWFUNC FindFile
        DEFFWFUNC LoadFile
        DEFFWFUNC LoadAndDecrunchFile
        DEFFWFUNC LoadFileToBuffer
        DEFFWFUNC DecrunchToBuffer
        DEFFWFUNC TrackmoLoadAndDecrunchToBuffer
        DEFFWFUNC TrackloaderDiskMotorOff
        ENDC

        IF      FW_MUSIC_SUPPORT
        DEFFWFUNC StartMusic
        DEFFWFUNC StopMusic
        ENDC

        IF      FW_MULTITASKING_SUPPORT
        DEFFWFUNC AddTask
        DEFFWFUNC RemTask
        DEFFWFUNC VSyncWithTask
        DEFFWFUNC Yield
        DEFFWFUNC WaitUntilTaskFinished

        IF      FW_BLITTERTASK_MT_SUPPORT
        DEFFWFUNC AddAndRunBlitterTask
        DEFFWFUNC YieldToBlitterTask
        DEFFWFUNC FinishBlitterTask
        ENDC
        ELSE
        IFEQ    FWGENLVOTABLE
_LVOFrameWorkVSyncWithTask = _LVOFrameWorkVSync
        ENDC
        ENDC

        IF      FW_PALETTE_LERP_SUPPORT
        DEFFWFUNC InitPaletteLerp
        DEFFWFUNC InitPaletteLerpSameColor
        DEFFWFUNC FadePaletteTo
        DEFFWFUNC DoFadePaletteStep
        ENDC

        IF      FW_SCRIPTING_SUPPORT
        DEFFWFUNC InstallScript
        DEFFWFUNC CheckScript
        IF      FW_MUSIC_SUPPORT
        DEFFWFUNC InstallMusicScript
        DEFFWFUNC CheckMusicScript
        ENDC
        ENDC

        IF      FW_BLITTERQUEUE_SUPPORT
        DEFFWFUNC AddToBlitterQueue
        DEFFWFUNC SetBlitterQueueMultiFrame
        DEFFWFUNC SetBlitterQueueSingleFrame
        DEFFWFUNC TriggerBlitterQueue
        DEFFWFUNC TriggerCustomBlitterQueue
        DEFFWFUNC JoinBlitterQueue
        DEFFWFUNC TerminateBlitterQueue
        ENDC

        IF      FW_LZ4_SUPPORT
        DEFFWFUNC DecompressLZ4
        ENDC
        IF      FW_ZX0_SUPPORT
        DEFFWFUNC DecompressZX0
        ENDC
        IF      FW_DOYNAX_SUPPORT
        DEFFWFUNC DecompressDoynax
        ENDC

        DEFFWFUNC EnableCopperSync
        DEFFWFUNC DisableCopperSync
        DEFFWFUNC CopSyncWithTask
        
