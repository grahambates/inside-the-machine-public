; Framework settings

DEBUG_DETAIL    set     0

FW_STANDALONE_FILE_MODE = 0             ; DO NOT CHANGE (required for trackmo mode)
FW_HD_TRACKMO_MODE = 0                  ; DO NOT CHANGE (required for trackmo mode)

FW_MUSIC_SUPPORT = 1
FW_MUSIC_PLAYER_CHOICE = 2              ; 0 = None, 1 = LSP, 2 = LSP_CIA, 3 = P61A, 4 = Pretracker
FW_LMB_EXIT_SUPPORT = 0                 ; DO NOT CHANGE, allows abortion of intro with LMB
FW_MULTIPART_SUPPORT = 1                ; DO NOT CHANGE (required for trackmo mode)
FW_DYNAMIC_MEMORY_SUPPORT = 1           ; DO NOT CHANGE (required for trackmo mode)
FW_MAX_MEMORY_STATES = 5                ; the amount of memory states (at least 2)
FW_TOP_BOTTOM_MEM_SECTIONS = 1          ; allow allocations from both sides of the memory
FW_64KB_PAGE_MEMORY_SUPPORT = 1         ; allow allocation of chip memory that doesn't cross the 64 KB page boundary
FW_MULTITASKING_SUPPORT = 1             ; enable multitasking
FW_ROUNDROBIN_MT_SUPPORT = 0            ; enable fair scheduling among tasks with same priority
FW_BLITTERTASK_MT_SUPPORT = 0           ; enable single parallel task during large blits
FW_MAX_VPOS_FOR_BG_TASK = 307           ; max vpos that is considered to be worth switching to a background task, if any
FW_MIN_BGTASK_LINES = 12                ; min lines before copper int considered to be worth switching to a background task, if any
FW_SINETABLE_SUPPORT = 1                ; enable creation of 1024 entries sin/cos table
FW_SCRIPTING_SUPPORT = 1                ; enable simple timed scripting functions
FW_PALETTE_LERP_SUPPORT = 1             ; enable basic palette fading functions
FW_YIELD_FROM_MAIN_TOO = 1              ; DO NOT CHANGE (required for background loading)
FW_VBL_IRQ_SUPPORT = 1                  ; enable custom VBL IRQ routine
FW_COPPER_IRQ_SUPPORT = 1               ; enable copper IRQ routine support
FW_AUDIO_IRQ_SUPPORT = 0                ; enable audio IRQ support (unimplemented)
FW_VBL_MUSIC_IRQ = 0                    ; enable calling of VBL based music ticking (disable, if using CIA timing!)
FW_BLITTERQUEUE_SUPPORT = 1             ; enable blitter queue support
FW_A5_A6_UNTOUCHED = 1                  ; speed up blitter queue if registers a5/a6 are never changed in main code

FW_LZ4_SUPPORT = 1                      ; compile in LZ4 decruncher
FW_DOYNAX_SUPPORT = 0                   ; compile in doynax decruncher
FW_ZX0_SUPPORT = 1                      ; compile in ZX0 decruncher

; trackmo options
FW_TD_FREE_MEM_HACK = 1                 ; attempt to free the trackdisk buffers
FW_TRACKMO_LZ4_SUPPORT = 1              ; enable decrunching while loading for LZ4
FW_TRACKMO_LZ4_DLT8_SUPPORT = 0         ; enable decrunching while loading for LZ4 with delta
FW_NUM_DIRECTORY_BLOCKS = 4             ; number of directory blocks used for this trackmo
FW_MAX_DOS_HUNKS = 4                    ; maximum amount of hunks (increase this when a part produces the ERROR_TOOMANYHUNKS)
FW_IN_PLACE_DECR_SAFE_DIST = 1024       ; number of extra bytes to allocate for in-place decompression
