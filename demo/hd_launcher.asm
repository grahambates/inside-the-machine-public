                opt     p+,o+
                include "hdtrackmo_settings.i"

NEWAGE_DEBUG = 0                        ; enable for UAE warp exit on start with debug detail enabled

CHIPMEM_SIZE = 496*1024                 ; maximum chip memory use for whole demo
FASTMEM_SIZE = 458*1024                 ; maximum fast memory use for whole demo

                include "../framework/framework.i"
                include "../framework/framework.asm"

entrypoint:
                include "trackmo_script.asm"

                section "diskimage",data

diskimage:
                incbin  "hddemo.adf"
