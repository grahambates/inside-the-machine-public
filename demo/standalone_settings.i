; Framework settings

FW_STANDALONE_FILE_MODE = 1             ; enable standalone (part testing)
FW_HD_TRACKMO_MODE = 0                  ; DO NOT CHANGE (not supported for standalone mode)

FW_MUSIC_SUPPORT = 1
FW_MUSIC_PLAYER_CHOICE = 2              ; 0 = None, 1 = LSP, 2 = LSP_CIA, 3 = P61A, 4 = Pretracker (CPU DMA wait), 5 = Pretracker Turbo (Copper wait)
FW_LMB_EXIT_SUPPORT = 1                 ; allows abortion of intro with LMB
FW_MULTIPART_SUPPORT = 0                ; DO NOT CHANGE (not supported for standalone mode)
FW_DYNAMIC_MEMORY_SUPPORT = 1           ; enable dynamic memory allocation. Otherwise, use fw_ChipMemStack/End etc fields.
FW_MAX_MEMORY_STATES = 4                ; the amount of memory states
FW_TOP_BOTTOM_MEM_SECTIONS = 0          ; allow allocations from both sides of the memory
FW_64KB_PAGE_MEMORY_SUPPORT = 0         ; allow allocation of chip memory that doesn't cross the 64 KB page boundary
FW_MULTITASKING_SUPPORT = 1             ; enable multitasking
FW_ROUNDROBIN_MT_SUPPORT = 0            ; enable fair scheduling among tasks with same priority
FW_BLITTERTASK_MT_SUPPORT = 0           ; enable single parallel task during large blits
FW_MAX_VPOS_FOR_BG_TASK = 307           ; max vpos that is considered to be worth switching to a background task, if any
FW_MIN_BGTASK_LINES = 8                 ; min lines before copper int considered to be worth switching to a background task, if any
FW_SINETABLE_SUPPORT = 1                ; enable creation of 1024 entries sin/cos table
FW_SCRIPTING_SUPPORT = 1                ; enable simple timed scripting functions
FW_PALETTE_LERP_SUPPORT = 1             ; enable basic palette fading functions
FW_YIELD_FROM_MAIN_TOO = 0              ; adds additional code that copes with Yield being called from main code instead of task
FW_VBL_IRQ_SUPPORT = 1                  ; enable custom VBL IRQ routine
FW_COPPER_IRQ_SUPPORT = 1               ; enable copper IRQ routine support
FW_AUDIO_IRQ_SUPPORT = 0                ; enable audio IRQ support (unimplemented)
FW_VBL_MUSIC_IRQ = 0                    ; enable calling of VBL based music ticking (disable, if using CIA timing!)
FW_BLITTERQUEUE_SUPPORT = 0             ; enable blitter queue support
FW_A5_A6_UNTOUCHED = 0                  ; speed up blitter queue if registers a5/a6 are never changed in main code

FW_LZ4_SUPPORT = 0                      ; compile in LZ4 decruncher
FW_DOYNAX_SUPPORT = 0                   ; compile in doynax decruncher
FW_ZX0_SUPPORT = 0                      ; compile in ZX0 decruncher

FW_DO_FANCY_WORKBENCH_STUFF = 0         ; enable pre- and post-hook (os startup only)
