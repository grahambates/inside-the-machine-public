                incdir  ../../includes/
                incdir  ../../common/

                ifnd    FW_DEMO_PART
                ; Standalone
                ifnd    DEBUG_DETAIL
DEBUG_DETAIL    set     10
                endc
                ifnd    NEWAGE_DEBUG
NEWAGE_DEBUG = 1
                endc
                include "../demo/standalone_settings.i"
                else
                ifd     FW_HD_DEMO_PART
                ; HD trackmo
                include "../demo/hdtrackmo_settings.i"
                else
                ; Trackmo
                include "../demo/trackmo_settings.i"
                endc
                endc

                include "../demo/global_bonus.i"
                include "../demo/timings.i"

                ; Common includes
                include "../framework/framework.i"
                include hw.i
                include macros.i
