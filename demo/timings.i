BPM = 175
T_BEAT = 1*3000/BPM
T_BAR = 4*3000/BPM
T_PATTERN = 16*3000/BPM

MUSIC_START = 737

TM              SET     0

********************************************************************************
; \1 - Part name
; \2 - Duration (to next part)
; \3 - Padding (return early to allow decrunch/precalc time on next part)
;-------------------------------------------------------------------------------
PART_TIME       macro
\1_START = TM
\1_DURATION = (\2)-(\3)
\1_END = TM+(\2)-(\3)
                ifd     FW_DEMO_PART
TM              SET     TM+(\2)
                endc
                endm

;-------------------------------------------------------------------------------

                PART_TIME MOTHERBOARD,T_PATTERN+MUSIC_START,T_BAR-10
                PART_TIME AMIGA,2*T_PATTERN,T_BEAT*2
                PART_TIME TITLE,3*T_PATTERN,0
                PART_TIME TUNNEL_2D,2*T_PATTERN,0
                PART_TIME FACELIGHTS,2*T_PATTERN,T_BEAT
                PART_TIME ROTO,2*T_PATTERN,0
                PART_TIME CIRCUIT_G,2*T_PATTERN,0
                PART_TIME COMBO,2*T_PATTERN,0
                PART_TIME CIRCUIT_M,2*T_PATTERN,T_BEAT*2
                PART_TIME TMAP,2*T_PATTERN,T_BEAT*2
                PART_TIME CIRCUIT_P,2*T_PATTERN,0
                PART_TIME TUNNEL_S,2*T_PATTERN,T_BEAT*3
                PART_TIME TUNNEL_M,2*T_PATTERN,0
                PART_TIME CIRCUIT_S,2*T_PATTERN,0
                PART_TIME TUNNEL_G,2*T_PATTERN-T_BEAT*11,0
                PART_TIME TEXT1,T_BEAT*11,0
                PART_TIME TUNNEL_P,2*T_PATTERN-T_BEAT*11,0
                PART_TIME TEXT2,T_BEAT*11,0
                PART_TIME TUNNEL_X4,2*T_PATTERN-T_BEAT*11,0
                PART_TIME TEXT3,T_BEAT*11,0
                PART_TIME TUNNEL_R,2*T_PATTERN,T_BEAT*6
                PART_TIME CREDITS,8*T_PATTERN,0
                PART_TIME ENDPART,8*T_PATTERN,0
