;--------------------------------------------------------------------
; Raspberry Casket Player V1.1 (28-Dec-2022)
; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;
; Provided by Chris 'platon42' Hodges <chrisly@platon42.de>
;
; Latest: https://github.com/chrisly42/PretrackerRaspberryCasket
;
; Rewritten by platon42/Desire based on a resourced, binary identical
; version of the original Pretracker V1.0 replayer binary provided
; by hitchhikr (thanks!), originally written in C by Pink/Abyss.
;
; This version is the hard work of reverse engineering all the
; offsets, removing all the C compiler crud, removing dead and
; surplus code (maybe artefacts from earlier ideas that did nothing),
; optimizing the code where possible. This resulted in both reduced
; size of the replayer, faster sample calculation and speeding the
; tick routine up significantly.
;
; I also added a few optional features that come in handy, such as
; song-end detection and precalc progress support.
;
; It took me more than a month and it was not fun.
;
; Also: Open source. It's 2022, keeping the code closed is just not
; part of the demoscene spirit (anymore?), at least for a replayer.
;
; Also note that this is not the final state of the source code.
; I could go over many places still and try to rework them.
; But I wanted the code to be out in public.
;
; Verification
; ~~~~~~~~~~~~
; The replayer has been verified on about 60 Pretracker tunes to
; create an identical internal state for each tick and identical
; samples (if certain optimizations switches are disabled).
;
; I might have introduced bugs though. If you find some problems,
; please let me know under chrisly@platon42.de. Thank you.
;
; Usage
; ~~~~~
; The new replayer comes as a drop-in binary replacement if you wish.
; In this case you will get faster sample generation (about 12%
; faster on 68000) and about 45% less CPU time spent. However, you
; won't get stuff as song-end detection and precalc progress this way.
; This mode uses the old CPU DMA wait that takes away 8 raster lines.
;
; If you want to get rid of the unnecessary waiting, you can switch
; to a copper driven audio control. If you want to use the top portion
; of the copperlist for this, you probably need to double buffer it.
; Otherwise, you could also position the copperlist at the end of
; the display and use single buffering if you call the tick routine
; during the vertical blank.
;
; Please use the documented sizes for the MySong and MyPlayer data
; structures, which are the symbols sv_SIZEOF and pv_SIZEOF
; respectively (about 2K and 12K with volume table).
;
; The source needs two common include files to compile (custom.i and
; dmabits.i). You should leave assembler optimizations enabled.
;
; (0. If you're using copper list mode, call pre_PrepareCopperlist.)
;
; 1. Call pre_SongInit with
;    - a pointer to MySong (mv_SIZEOF) in a1 and
;    - the music data in a2.
;    It will return the amount of sample memory needed in d0.
;
; 2. Then call pre_PlayerInit with
;    - a pointer to MyPlayer (pv_SIZEOF) in a0
;    - a pointer to chip memory sample buffer in a1
;    - the pointer to MySong in a2
;    - a pointer to a longword for progress information or null in a3
;    This will create the samples, too.
;
; 3. After that, regularly call pre_PlayerTick with MyPlayer in a0
;    and optionally the copperlist in a1 if you're using that mode).
;
; Size
; ~~~~
; The original C compiled code was... just bad. The new binary is
; about 1/3 of the original one.
;
; The code has been also optimized in a way that it compresses better.
; The original code compressed with Blueberry's Shrinkler goes from
; 18052 bytes down to 9023 bytes.
;
; Raspberry Casket, depending on the features compiled in, is about
; 6216 bytes and goes down to ~4348 bytes (in isolation).
;
; So this means that the optimization is not just "on the outside".
;
; Timing
; ~~~~~~
; Sample generation is a bit faster (I guess around 10-15%), but most
; of the time is spent on muls operations, so this is the limiting
; factor.
;
; Raspberry Casket is about twice as fast as the old replayer for playback.
;
; Unfortunately, the replayer is still pretty slow and has high
; jitter compared to other standard music replayers.
; This means it may take up to 32 raster lines (13-18 on average)
; which is significant more than a standard Protracker replayer
; (the original one could take about 60 raster lines worst case and
; about 34 on average!).
;
; Watch out for Presto, the LightSpeedPlayer variant that should
; solve this problem.
;
; Changelog see https://github.com/chrisly42/PretrackerRaspberryCasket#Changelog
;--------------------------------------------------------------------

; Here come the various options for you to configure.
;
; To create an optimized drop-in replacement for the old V1.0 binary:
; PRETRACKER_SUPPORT_V1_5 = 0
; PRETRACKER_PARANOIA_MODE = 0
; PRETRACKER_DUBIOUS_PITCH_SHIFT_FOR_DELAYED_TRACK = 0
; PRETRACKER_KEEP_JUMP_TABLE = 1
; PRETRACKER_SONG_END_DETECTION = 0
; PRETRACKER_PROGRESS_SUPPORT = 0
; PRETRACKER_FASTER_CODE = 1
; PRETRACKER_VOLUME_TABLE = 1
; PRETRACKER_BUGFIX_CODE = 1
; PRETRACKER_DONT_TRASH_REGS = 1
; PRETRACKER_COPPER_OUTPUT = 0


; This player was based on the V1.0 binary of the pretracker replayer
; and thus can only play files created with versions up to V1.0.
; Subsongs and sound effects are not supported. There is usually no
; use for this in an intro anyway.
;
; Enabling this switch will patch the song runtime to make it backward
; compatible with this replayer. Song data will be modified in memory.
; I would encourage you to still use V1.0 as the files saved with
; Pretracker V1.5 are unnecessarily bigger (about 458 bytes) and might
; lose some instrument names it seems.
        IFND    PRETRACKER_SUPPORT_V1_5
PRETRACKER_SUPPORT_V1_5 = 0
        ENDC

; The original binary had a lot of extra checks that I would consider
; paranoia. For example it handled songs without instruments, waves
; or patterns.
; It contains code that I think is unreachable and a relic of
; being used for the actual tracker itself (releasing notes after
; a delay, looping patterns instead of advancing song).
; Or for combinations of song stopping (F00) and note delay in the
; same step, which no sane musician would use.
;
; This switch gets rid of the code. If you find a song that doesn't
; work with this disabled, please let me know.
        IFND    PRETRACKER_PARANOIA_MODE
PRETRACKER_PARANOIA_MODE = 0
        ENDC

; There is some pitch shifting applied during track delay by
; a maximum of one period -- depending on the delay value.
; I guess this might add some phasing to the sound (which would be
; only audible in a mono mix, I would think), but it comes with an
; extra multiplication per channel.
; If you really want that, enable this switch.
        IFND    PRETRACKER_DUBIOUS_PITCH_SHIFT_FOR_DELAYED_TRACK
PRETRACKER_DUBIOUS_PITCH_SHIFT_FOR_DELAYED_TRACK = 0
        ENDC

; The binary comes with a jump table that has three official entry
; points. As you have the source, you could just bsr to the three
; functions (pre_SongInit, pre_PlayerInit, pre_PlayerTick) directly.
; If you want a drop-in (binary) replacement instead, enable this
; switch to get the jump table back.
        IFND    PRETRACKER_KEEP_JUMP_TABLE
PRETRACKER_KEEP_JUMP_TABLE = 0
        ENDC

; The original Pretracker replayer does not come with a song-end
; detection. If you want to have that (e.g. for a music disk), enable
; this switch and check for pv_songend_detected_b (relative to the
; MyPlayer structure) which goes to true when song-end is reached.
        IFND    PRETRACKER_SONG_END_DETECTION
PRETRACKER_SONG_END_DETECTION = 0
        ENDC

; Do you want to have information on the sample generation progress
; during the call to pre_PlayerInit? Then enable this and call w
; pre_PlayerInit with a pointer to a longword in a3.
; Please make sure yourself that the initial value is zero.
; It will be incremented by the number of samples (in bytes)
; for each waveform done. You can get the total number of samples
; from the (previously undocumented) return value of pre_SongInit.
        IFND    PRETRACKER_PROGRESS_SUPPORT
PRETRACKER_PROGRESS_SUPPORT = 0
        ENDC

; Use slightly faster code and smaller for sample generation that
; might be off by 1 (rounding error) compared to the original code.
        IFND    PRETRACKER_FASTER_CODE
PRETRACKER_FASTER_CODE = 1
        ENDC

; Use tables for volume calculation instead of multiplication.
; Is slightly faster on 68000 (about 11%), but probably has no
; benefit for 68020+ and needs about 3.5 KB more RAM (MyPlayer)
; and 40 bytes of code.
        IFND    PRETRACKER_VOLUME_TABLE
PRETRACKER_VOLUME_TABLE = 1
        ENDC

; I found some obvious bugs in the code. This switch enables bugfixes,
; but the sound might not be exactly the same as in the tracker /
; original player (e.g. there is a bug in the volume envelope that
; will cause a pause in the decay curve that is not supposed to
; happen).
        IFND    PRETRACKER_BUGFIX_CODE
PRETRACKER_BUGFIX_CODE = 1
        ENDC

; You want to take care of what registers may be trashed by these
; routines because you have your own ABI? Good!
; Setting this to 0 will remove the register saving/restoring on
; the stack. All registers then may be trashed.
; Otherwise, d2-d7/a2-a6 are preserved as with the AmigaOS standard.
        IFND    PRETRACKER_DONT_TRASH_REGS
PRETRACKER_DONT_TRASH_REGS = 1
        ENDC

; Enable output to copperlist instead of audio registers and DMA wait.
; This gives your slightly more CPU time and less jitter (maybe 7
; rasterlines).
;
; When enabled, provide a pointer to a copperlist in a1 on calling
; pre_PlayerTick. It will update the necessary fields in the
; copperlist. To initially generate a copperlist (or two), use the
; pre_PrepareCopperlist subroutine. It will write out 37 copper
; commands (WAITs and MOVEs) starting for a given rasterline (if
; you're below rasterline 255, make sure you have the necessary
; wait for this case yourself!).
;
; There are two major reasonable ways to use this:
; - Your intro does no fancy copper shenanigans:
;   You can reserve the space of 37 longwords inside your normal
;   copperlist. The position should be after rasterline ~35.
; - You do a lot of copper stuff during the frame:
;   Create the pretracker copperlist to be at the very end of the
;   frame (rasterline 300 is a good spot). Make sure your custom
;   copper code has a static jump to the 37 copper instructions
;   at its end and terminate the copperlist correctly (hint:
;   move.l d1,(a0) after bsr pre_PrepareCopperlist will terminate
;   the copperlist ($fffffffe).
        IFND    PRETRACKER_COPPER_OUTPUT
PRETRACKER_COPPER_OUTPUT = 0 ; 0 = standard CPU wait, 1 = Copperlist
        ENDC

; Pretracker song format description:
;
; $0000  4: PRT<version> ($19 (V0.x), $1b (V1.0), $1e (V1.5))
; $0004  4: File offset to position data (POSD)
; $0008  4: File offset to pattern data (PATT)
; $000C  4: File offset to instruments (INST)
; $0010  4: File offset to waves (WAVE)
; $0014 20: Songname
; $0028 20: Author
; $003C  1: Restart position for song (<=V1.0)
; $003D  1: Number of patterns (<=V1.0)
; $003E  1: Songlength in patterns (<=V1.0)
; $003F  1: Number of steps per pattern (<=V1.0)
; $0040  1: Number of instruments (<=V1.0), $40 for V1.5
; $0041  1: Number of waves
; $0042 24: Wave generation ordering (>=V1.0)
; $005a  1: Number of subsongs (>=V1.5)
; [...]
; Position data (POSD):
; - Per subsong (>=V1.5)
;   - 1: Restart pos
;   - 1: #patterns
;   - 1: #numsteps
;   - 1: songlength
;   - 4: relative pattern offset in pattern data
; - Positions x 4 x [Pattern number (byte), pitch shift (signed byte)]
;
; Pattern data (PATT):
; Each pattern line consists of three bytes:
;   - 1 Bit : Bit 4 of Inst Number
;   - 1 Bit : ARP instead of effect
;   - 6 Bits: Pitch ($01 is C-0, $3d is NOTE OFF)
;
;   - 4 Bits: Bit 0-3 of Inst Number
;   - 4 Bits: Effect command
;   - 8 Bits: Effect data
; - Patterns x steps x 3 bytes
;
; Unknown data after pattern data: (12 10 00 00 00 00)
;
; Instrument definitions (INST):
; - 32 (!) x Null terminated string (or 23 chars max) (for V1.5 this is 64 strings)
; - For each instrument: Instrument Info (ININ)
;   - $00  1: Vibrato Delay
;   - $01  1: Vibrato Depth
;   - $02  1: Vibrato Speed (-1)
;   - $03  1: ADSR Attack
;   - $04  1: ADSR Decay
;   - $05  1: ADSR Sustain
;   - $06  1: ADSR Release
;   - $07  1: Number of Inst Pattern steps
;
; - For each instrument:
;   - 1 Byte: number of steps
;   - 3 Bytes x number of steps: Inst Pattern (IPTT)
;
; Inst pattern data (IPTT):
; Each pattern line consists of three bytes:
;   - 1 Bit  : Next note stitched to this one
;   - 1 Bit  : Fixed Pitch Note
;   - 6 Bits : Pitch ($01 is C-0)
;   - 4 Bits : unused?
;   - 12 Bits: Effect
; - Patterns x steps x 3 bytes
;
; Wave definitions (WAVE):
; - 24 (!) x Null terminated string (or 23 chars max)
; - Optional padding to even address, if necessary
; - For each wave:
;   - 42 Bytes: Wave info structure (see definition below)

; ----------------------------------------
; Some constants for clarity

MAX_VOLUME      = $40
MAX_SPEED       = $2f
MAX_WAVES       = 24
MAX_INSTRUMENTS = 32
MAX_TRACK_DELAY = 32
NOTE_OFF_PITCH  = $3d
NOTES_IN_OCTAVE = 12
NUM_CHANNELS    = 4     ; yes, you can reduce the number of channels if you want

; ----------------------------------------
; Pretracker file structures

; Pattern data (PATT and IPTT)
pdb_pitch_ctrl      = 0
pdb_inst_effect     = 1 ; for normal pattern data
pdb_effect_cmd      = 1 ; for inst pattern
pdb_effect_data     = 2

; Pattern pos data (POSD)
ppd_pat_num         = 0
ppd_pat_shift       = 1

; Instrument Info (ININ)
ii_vibrato_delay    = 0
ii_vibrato_depth    = 1
ii_vibrato_speed    = 2
ii_adsr_attack      = 3
ii_adsr_decay       = 4
ii_adsr_sustain     = 5
ii_adsr_release     = 6
ii_pattern_steps    = 7
ii_SIZEOF           = 8

; Wave Info (WAVE)
wi_loop_start_w    = $00
wi_loop_end_w      = $02
wi_subloop_len_w   = $04
wi_allow_9xx_b     = $06
wi_subloop_wait_b  = $07
wi_subloop_step_w  = $08
wi_chipram_w       = $0a
wi_loop_offset_w   = $0c
wi_chord_note1_b   = $0e
wi_chord_note2_b   = $0f
wi_chord_note3_b   = $10
wi_chord_shift_b   = $11
wi_osc_unknown_b   = $12 ; always $00? (unused in code?)
wi_osc_phase_spd_b = $13
wi_flags_b         = $14 ; bit 0/1: osc type, bit 2: needs extra octaves, bit 3: boost, bit 4: pitch linear, bit 5: vol fast
wi_osc_phase_min_b = $15
wi_osc_phase_max_b = $16
wi_osc_basenote_b  = $17
wi_osc_gain_b      = $18
wi_sam_len_b       = $19 ; in multiples of 128, zero-based (0 == 128)
wi_mix_wave_b      = $1a
wi_vol_attack_b    = $1b
wi_vol_delay_b     = $1c
wi_vol_decay_b     = $1d
wi_vol_sustain_b   = $1e
wi_flt_type_b      = $1f ; 1=lowpass, 2=highpass, 3=bandpass, 4=notch
wi_flt_resonance_b = $20
wi_pitch_ramp_b    = $21
wi_flt_start_b     = $22
wi_flt_min_b       = $23
wi_flt_max_b       = $24
wi_flt_speed_b     = $25
wi_mod_params_l    = $26
wi_mod_wetness_b   = $26
wi_mod_length_b    = $27
wi_mod_predelay_b  = $28
wi_mod_density_b   = $29 ; (1-7), unisono (bits 3/4) and post bit 5
wi_SIZEOF          = $2a

; ----------------------------------------
; Unpacked Instrument Info (addition to player for faster processing)
                    rsreset
uii_vibrato_delay   rs.w    1
uii_vibrato_depth   rs.w    1
uii_vibrato_speed   rs.w    1
uii_adsr_release    rs.b    1
                    rs.b    1 ; dummy
uii_adsr_attack     rs.w    1
uii_adsr_decay      rs.w    1
uii_adsr_sustain    rs.w    1
uii_pattern_steps   rs.b    1
                    rs.b    1 ; padding
uii_SIZEOF          rs.b    0

; ----------------------------------------
; MySong offsets
                        rsreset
sv_waveinfo_table       rs.l    MAX_WAVES ; 24 pointers to wave infos to avoid mulu
sv_inst_patterns_table  rs.l    MAX_INSTRUMENTS ; 32 pointers to pattern data
                        ; --- 127 byte displacement limit ---
sv_wavelength_table     rs.l    MAX_WAVES ; 24 longwords to sample lengths (standard octave) (NEW)
sv_wavetotal_table      rs.l    MAX_WAVES ; 24 longwords to sample lengths for all octaves (NEW)
sv_wavegen_order_table  rs.b    MAX_WAVES ; 24 bytes
sv_num_waves_b          rs.b    1
sv_num_steps_b          rs.b    1
sv_patterns_ptr         rs.l    1
sv_curr_pat_pos_w       rs.w    1 ; only byte used FIXME why is this part of MySong? Should be in Player
sv_pat_pos_len_w        rs.w    1 ; only byte used
sv_pat_restart_pos_w    rs.w    1 ; only byte used
sv_pos_data_adr         rs.l    1
sv_waveinfo_ptr         rs.l    1 ; base pointer of wave info
sv_pattern_table        rs.l    256
sv_inst_infos_table     rs.b    MAX_INSTRUMENTS*uii_SIZEOF
sv_SIZEOF               rs.b    0

; ----------------------------------------
; channel output data (part of pcd structure below)
                rsreset
ocd_sam_ptr     rs.l    1   ; 0
ocd_length      rs.w    1   ; 4
ocd_loop_offset rs.w    1   ; 6
ocd_period      rs.w    1   ; 8
ocd_volume      rs.b    1   ; 10
ocd_trigger     rs.b    1   ; 11 needs to be after volume
ocd_unused      rs.l    1   ; 12 unused, but makes the structure an even 16 bytes
ocd_SIZEOF      rs.b    0

; channel structure (part of pv structure)
                            rsreset
; DO NOT CHANGE ORDER -- OPTIMIZED CLEARING
pcd_pat_portamento_dest_w   rs.w    1 ; portamento destination pitch
pcd_pat_pitch_slide_w       rs.w    1

pcd_pat_vol_ramp_speed_b    rs.b    1
pcd_pat_2nd_inst_num4_b     rs.b    1
pcd_pat_2nd_inst_delay_b    rs.b    1
pcd_wave_offset_b           rs.b    1

pcd_inst_pitch_slide_w      rs.w    1
pcd_inst_sel_arp_note_w     rs.w    1

pcd_inst_note_pitch_w       rs.w    1
pcd_inst_curr_port_pitch_w  rs.w    1

pcd_inst_line_ticks_b       rs.b    1
pcd_inst_pitch_pinned_b     rs.b    1
pcd_inst_vol_slide_b        rs.b    1
pcd_inst_step_pos_b         rs.b    1

pcd_inst_wave_num_w         rs.w    1 ; current wave number (1 based) (lower byte used)

pcd_track_delay_offset_b    rs.b    1 ; $ff = no track delay
pcd_inst_speed_stop_b       rs.b    1 ; speed byte, $ff stops processing
pcd_inst_pitch_w            rs.w    1

pcd_inst_vol_w              rs.w    1
pcd_loaded_inst_vol_b       rs.b    1
pcd_pat_vol_b               rs.b    1 ; Multiplied with volume of instrument.
; DO NOT CHANGE ORDER -- OPTIMIZED CLEARING END

pcd_arp_notes_l             rs.b    0
pcd_arp_note_1_b            rs.b    1
pcd_arp_note_2_b            rs.b    1
pcd_arp_note_3_b            rs.b    1
                            rs.b    1 ; gets cleared

pcd_last_trigger_pos_w      rs.w    1 ; I think this makes sure that we don't retrigger the note on same pos

pcd_pat_portamento_speed_b  rs.b    1
pcd_pat_adsr_rel_delay_b    rs.b    1 ; counts down until adsr release. Seems unused?
pcd_note_off_delay_b        rs.b    1 ; time before note is released ($ff = disabled)
pcd_inst_pattern_steps_b    rs.b    1 ; number of steps in instrument pattern

pcd_note_delay_b            rs.b    1 ; $ff = no note delay
pcd_track_delay_steps_b     rs.b    1 ; $00 = no track delay, $ff = stop track delay (this is for the next channel!)
pcd_track_delay_vol16_b     rs.b    1
pcd_track_init_delay_b      rs.b    1 ; number of frames to ignore the delay

pcd_inst_num4_w             rs.w    1 ; current instrument number * 4
;pcd_inst_new_step_w         rs.w    1 ; seems to be unused
pcd_inst_subloop_wait_w     rs.w    1
pcd_inst_loop_offset_w      rs.w    1
pcd_inst_info_ptr           rs.l    1 ; pointer to currently active instrument

pcd_waveinfo_ptr            rs.l    1 ; pointer to currently active waveinfo
pcd_channel_mask_b          rs.b    1
pcd_channel_num_b           rs.b    1
pcd_adsr_phase_w            rs.w    1 ; 0=attack, 1=decay, 2=sustain, 3=release ! do not change order
pcd_adsr_volume_w           rs.w    1 ; 0 for restart / $400 (word only) ! do not change order
pcd_adsr_phase_speed_b      rs.b    1
pcd_inst_ping_pong_dir_b    rs.b    1 ; direction of ping-pong (-1 == $00 / +1 = $ff)
pcd_adsr_pos_w              rs.w    1 ; pos in adsr curve
pcd_adsr_vol64_w            rs.w    1 ; some adsr volume

pcd_new_inst_num_b          rs.b    1 ; load new instrument (number) ! do not change order
                            rs.b    1 ; gets cleared
pcd_vibrato_pos_w           rs.w    1 ;
pcd_vibrato_delay_w         rs.w    1 ; is a byte value ! do not change order
pcd_vibrato_depth_w         rs.w    1 ; is a byte value ! do not change order
pcd_vibrato_speed_w         rs.w    1 ; is a byte value ! do not change order
pcd_adsr_release_b          rs.b    1 ; is a byte value ! do not change order
                            rs.b    1 ; padding will be overwritten!

pcd_out_base                rs.b    ocd_SIZEOF
pcd_track_delay_buffer      rs.b    MAX_TRACK_DELAY*ocd_SIZEOF
pcd_SIZEOF                  rs.b    0

pcd_out_ptr_l       = pcd_out_base+ocd_sam_ptr
pcd_out_len_w       = pcd_out_base+ocd_length
pcd_out_lof_w       = pcd_out_base+ocd_loop_offset
pcd_out_per_w       = pcd_out_base+ocd_period
pcd_out_vol_b       = pcd_out_base+ocd_volume
pcd_out_trg_b       = pcd_out_base+ocd_trigger
pcd_out_unused_l    = pcd_out_base+ocd_unused          ; copied for track delay, but not used?

                rsreset
owb_saw_waves   rs.b    128
owb_sqr_waves   rs.b    128
owb_tri_waves   rs.b    128
owb_wave_length rs.b    1
owb_SIZEOF      rs.b    0

; ----------------------------------------
; MyPlayer global variables (not bound to channel)
                        rsreset
; DO NOT CHANGE ORDER -- OPTIMIZED INIT
pv_pat_curr_row_b       rs.b    1 ; current step
pv_next_pat_row_b       rs.b    1
pv_next_pat_pos_b       rs.b    1
pv_pat_speed_even_b     rs.b    1 ; even shuffle speed

pv_pat_speed_odd_b      rs.b    1 ; odd shuffle speed
pv_pat_line_ticks_b     rs.b    1
pv_pat_stopped_b        rs.b    1 ; 0 = stop, $ff = run
pv_songend_detected_b   rs.b    1
; DO NOT CHANGE ORDER -- OPTIMIZED INIT END

pv_loop_pattern_b       rs.b    1 ; repeat current pattern, do not advance
                        rs.b    1 ; padding

pv_trigger_mask_w       rs.w    1

pv_my_song              rs.l    1
pv_sample_buffer_ptr    rs.l    1 ; pointer to start of sample buffer
pv_copperlist_ptr       rs.l    1
pv_wave_sample_table    rs.l    MAX_WAVES ; 24 pointers to sample starts
pv_period_table         rs.w    16*NOTES_IN_OCTAVE*3
                        ; --- 127 byte displacement limit ---
pv_channeldata          rs.b    NUM_CHANNELS*pcd_SIZEOF

                        IFNE    PRETRACKER_VOLUME_TABLE
pv_osc_buffers          rs.b    0 ; reuse space of volume_table, which is bigger than NOTES_IN_OCTAVE*owb_SIZEOF
pv_volume_table         rs.b    (MAX_VOLUME+1)*MAX_VOLUME*2
                        ELSE
pv_osc_buffers          rs.b    NOTES_IN_OCTAVE*owb_SIZEOF
                        ENDC

pv_precalc_sample_size  rs.l    1
pv_precalc_progress_ptr rs.l    1
pv_wg_wave_ord_num_w    rs.w    1
                        IFNE    PRETRACKER_PARANOIA_MODE    ; same wave for mixing cannot be selected in Pretracker
pv_wg_curr_wave_num_b   rs.b    1
                        rs.b    1
                        ENDC
pv_wg_curr_sample_ptr   rs.l    1
pv_wg_curr_samend_ptr   rs.l    1
pv_wg_curr_sample_len_w rs.w    1
pv_wg_chord_note_num_b  rs.b    1 ; don't change order
pv_wg_unisono_run_b     rs.b    1 ; don't change order
pv_wg_chord_flag_w      rs.w    1
pv_wg_chord_pitches     rs.l    1
pv_wg_osc_speed_l       rs.l    1
pv_wg_flt_taps          rs.w    4
pv_SIZEOF               rs.b    0

;--------------------------------------------------------------------

        include "../includes/hardware/custom.i"
        include "../includes/hardware/dmabits.i"

CLIPTO8BIT MACRO
        cmpi.w  #-$80,\1
        bge.s   .nominclip\@
        moveq.l #-$80,\1
.nominclip\@
        cmpi.w  #$7F,\1
        ble.s   .nomaxclip\@
        moveq.l #$7F,\1
.nomaxclip\@
        ENDM

CLIPORTRUNC8BIT MACRO
        beq.s   .unboosted\@
        asr.l    #6,\1
        cmpi.w  #-$80,\1
        bge.s   .nominclip\@
        moveq.l #-$80,\1
.nominclip\@
        cmpi.w  #$7F,\1
        ble.s   .nomaxclip\@
        moveq.l #$7F,\1
        bra.s   .nomaxclip\@
.unboosted\@
        asr.l   #8,\1
.nomaxclip\@
        ENDM

CLIPTO8BITAFTERADD MACRO
        bvc.s   .noclip\@
        spl     \1
        eor.b   #$7f,\1
.noclip\@
        ENDM

;--------------------------------------------------------------------
; Code starts here

        IFNE    PRETRACKER_KEEP_JUMP_TABLE
pre_FuncTable
        dc.l     pre_SongInit-pre_FuncTable
        dc.l     pre_PlayerInit-pre_FuncTable
        dc.l     pre_PlayerTick-pre_FuncTable
        ENDC
        ;dc.b     '$VER: Raspberry Casket 1.1',0
        ;even

        IFNE    PRETRACKER_COPPER_OUTPUT
;********************************************************************
;--------------------------------------------------------------------
; pre_PrepareCopperlist - initialize copperlist for replaying
;
; a0.l = copperlist (37 longwords for 4 channels, 5+8*NUM_CHANNELS)
; d0.w = rasterline (<239 or >=256)
; out: a0 = copperlist ptr after init
;********************************************************************
pre_PrepareCopperlist:
        IFNE    PRETRACKER_DONT_TRASH_REGS
        movem.l d2-d3/d6/d7,-(sp)
        ENDC
        moveq.l #-2,d1
        lsl.w   #8,d0
        move.b  #$07,d0
        move.w  d0,(a0)+
        move.w  d1,(a0)+

        move.l  #(dmacon<<16)|DMAF_AUDIO,(a0)+

        add.w   #$500,d0
        move.w  d0,(a0)+
        move.w  d1,(a0)+

        ; writing 5*4 = 20 words
        move.w  #aud0+ac_ptr,d2
        moveq.l #0,d3
        moveq.l #NUM_CHANNELS-1,d7
.chloop moveq.l #5-1,d6
.dloop  move.w  d2,(a0)+
        move.w  d3,(a0)+
        addq.w  #2,d2
        dbra    d6,.dloop
        addq.w  #ac_SIZEOF-ac_dat,d2
        dbra    d7,.chloop

        move.l  #(dmacon<<16)|DMAF_SETCLR,(a0)+

        add.w   #$500,d0
        move.w  d0,(a0)+
        move.w  d1,(a0)+

        ; writing 2*4 = 12 words
        move.w  #aud0+ac_ptr,d2
        moveq.l #NUM_CHANNELS-1,d7
.chloop2
        moveq.l #3-1,d6
.dloop2 move.w  d2,(a0)+
        move.w  d3,(a0)+
        addq.w  #2,d2
        dbra    d6,.dloop2
        add.w   #ac_SIZEOF-ac_per,d2
        dbra    d7,.chloop2
        IFNE    PRETRACKER_DONT_TRASH_REGS
        movem.l (sp)+,d2-d3/d6/d7
        ENDC
        rts

        ENDC

;********************************************************************
;--------------------------------------------------------------------
; SongInit - initialize data structure belonging to a song
;
; In:
; - a0: MyPlayer structure (unused)
; - a1: MySong structure (must be sv_SIZEOF bytes!)
; - a2: Pretracker song data
; Out:
; - d0: chipmemory (bytes) required for samples or 0 on error
;********************************************************************
pre_SongInit:
        IFNE    PRETRACKER_DONT_TRASH_REGS
        movem.l d2/d7/a2-a5,-(sp)
        ENDC
        moveq.l #0,d0
        move.l  $0000(a2),d1
        move.b  d1,d2
        clr.b   d1
        cmpi.l  #$50525400,d1                   ; "PRE"-Text
        bne     .error
        moveq.l #MAX_INSTRUMENTS-1,d7           ; notice there's one extra name (available in 1.5, but not usable)!
        IFNE    PRETRACKER_SUPPORT_V1_5
        cmpi.b  #$1e,d2
        bgt     .error
        bne.s   .nopatchv15
        move.l  $005c(a2),d0                    ; make song backward compatible
        ror.w   #8,d0
        move.l  d0,$003c(a2)
        addq.l  #8,$0004(a2)                    ; skip over first pattern data
        moveq.l #2*MAX_INSTRUMENTS-1,d7         ; v1.5 has 32 slots (the other ones used for sfx)
.nopatchv15
        ELSE
        cmpi.b  #$1b,d2
        bgt     .error
        ENDC

        move.l  a1,a0
        move.w  #sv_SIZEOF,d0
        bsr     pre_MemClr

        move.b  $003c(a2),sv_pat_restart_pos_w+1(a1)   ; song restart pos
        move.b  $003e(a2),sv_pat_pos_len_w+1(a1)       ; songlength in pattern positions
        move.b  $003f(a2),sv_num_steps_b(a1)           ; number of steps!
        move.b  $0041(a2),sv_num_waves_b(a1)           ; number of instruments

        move.l  $0004(a2),d0
        add.l   a2,d0
        move.l  d0,sv_pos_data_adr(a1)          ; address to position data (POSD)

        move.l  $0008(a2),d0
        add.l   a2,d0
        move.l  d0,sv_patterns_ptr(a1)          ; address to pattern data (PATT)

        move.l  $000c(a2),d0                    ; offset into instrument names
        lea     (a2,d0.l),a0                    ; instrument names

.instrnamesloop
        moveq.l #23-1,d0                        ; max 23 chars
.inststrloop
        tst.b   (a0)+
        dbeq    d0,.inststrloop
        dbra    d7,.instrnamesloop

        moveq.l #0,d7
        move.b  $0040(a2),d7                    ; number of instruments
        IFNE    PRETRACKER_PARANOIA_MODE
        beq.s   .noinstsskip
        ENDC
        move.l  d7,d0
        lsl.w   #3,d0
        add.l   a0,d0                           ; skip 8 bytes of info per instrument (ININ)
        lea     sv_inst_patterns_table(a1),a3
        lea     sv_inst_infos_table(a1),a4
        IFNE    PRETRACKER_SUPPORT_V1_5
        cmp.w   #MAX_INSTRUMENTS,d7
        ble.s   .notruncto32
        moveq.l #MAX_INSTRUMENTS,d7
.notruncto32
        ENDC
        subq.w  #1,d7
.instinfoloop
        move.l  d0,(a3)+

        moveq.l #0,d1
        move.b  (a0)+,d1                        ; ii_vibrato_delay
        lea     pre_vib_delay_table(pc),a5
        move.b  (a5,d1.w),d1
        addq.w  #1,d1
        move.w  d1,uii_vibrato_delay(a4)

        moveq.l #0,d1
        move.b  (a0)+,d1                        ; ii_vibrato_depth
        move.b  pre_vib_depth_table-pre_vib_delay_table(a5,d1.w),uii_vibrato_depth+1(a4)

        move.b  (a0)+,d1                        ; ii_vibrato_speed
        move.b  pre_vib_speed_table-pre_vib_delay_table(a5,d1.w),d1
        muls    uii_vibrato_depth(a4),d1        ; bake in this strange vibrato stuff
        asr.w   #4,d1
        move.w  d1,uii_vibrato_speed(a4)

        moveq.l #0,d1
        move.b  (a0)+,d1                        ; ii_adsr_attack
        add.w   d1,d1
        move.w  pre_fast_roll_off_16-pre_vib_delay_table(a5,d1.w),d1
        move.w  d1,uii_adsr_attack(a4)

        moveq.l #0,d1
        move.b  (a0)+,d1                        ; ii_adsr_decay
        move.b  pre_ramp_up_16-pre_vib_delay_table(a5,d1.w),uii_adsr_decay+1(a4)

        move.b  (a0)+,d1                        ; ii_adsr_sustain
        ; what is this? a patch?
        cmp.b   #15,d1
        bne.s   .dont_patch_sustain
        moveq.l #16,d1
.dont_patch_sustain
        lsl.w   #6,d1
        move.w  d1,uii_adsr_sustain(a4)

        moveq.l #0,d1
        move.b  (a0)+,d1                        ; ii_adsr_release
        move.b  pre_ramp_up_16-pre_vib_delay_table(a5,d1.w),uii_adsr_release(a4)

        move.b  (a0)+,d1                        ; ii_pattern_steps
        move.b  d1,uii_pattern_steps(a4)
        add.l   d1,d0
        add.l   d1,d0
        add.l   d1,d0                           ; calc next start address
        lea     uii_SIZEOF(a4),a4
        dbra    d7,.instinfoloop

.noinstsskip
        move.l  $0010(a2),d0                    ; offset into wave names
        lea     (a2,d0.l),a0
        moveq.l #MAX_WAVES-1,d7
.wavenamesloop
        moveq.l #23-1,d0                        ; max 23 chars
.wavestrloop
        tst.b   (a0)+
        dbeq    d0,.wavestrloop
        dbra    d7,.wavenamesloop

        move.l  a0,d0
        lsr.w   #1,d0
        bcc.s   .addressiseven
        addq.l  #1,a0                           ; make address even
.addressiseven
        move.l  a0,sv_waveinfo_ptr(a1)

        lea     sv_wavegen_order_table(a1),a0
        cmpi.b  #$19,d2                         ; check if version is higher than 19
        bhi.s   .haswaveorderinfo

        moveq.l #0,d0                           ; fill 24 bytes with default order of waves?
        moveq.l #MAX_WAVES-1,d7
.fillcount
        move.b  d0,(a0)+
        addq.b  #1,d0
        dbra    d7,.fillcount
        bra.s   .contafterworkaround

.haswaveorderinfo
        moveq.l #(MAX_WAVES/4)-1,d7
        lea     $0042(a2),a2                    ; offset into wave ordering
.memcpyloop
        move.l  (a2)+,(a0)+
        dbra    d7,.memcpyloop

.contafterworkaround
        moveq.l #2,d0                           ; at least empty sample
        moveq.l #0,d7
        move.b  sv_num_waves_b(a1),d7           ; has instruments?
        IFNE    PRETRACKER_PARANOIA_MODE
        beq.s   .hasnoinstruments
        ENDC

        move.l  sv_waveinfo_ptr(a1),a3
        subq.w  #1,d7
.wavetableloop
        moveq.l #0,d1
        move.b  wi_sam_len_b(a3),d1
        addq.w  #1,d1
        lsl.w   #7,d1
        move.l  d1,sv_wavelength_table-sv_waveinfo_table(a1)
        btst    #2,wi_flags_b(a3)
        beq.s   .onlythreeocts
        mulu    #15,d1
        lsr.l   #3,d1           ; * 1.875
.onlythreeocts
        move.l  d1,sv_wavetotal_table-sv_waveinfo_table(a1)
        move.l  a3,(a1)+
        add.l   d1,d0
        lea     wi_SIZEOF(a3),a3
        dbra    d7,.wavetableloop
        ; d0 will contain the size of the samples
.hasnoinstruments
.error
.exit
        IFNE    PRETRACKER_DONT_TRASH_REGS
        movem.l (sp)+,d2/d7/a2-a5
        ENDC
        rts

;********************************************************************
;--------------------------------------------------------------------
; PlayerInit - initialize player and calculate samples
;
; In:
; - a0: MyPlayer (must have size of pv_SIZEOF, will be initialized)
; - a1: sample buffer
; - a2: MySong (must have been filled with SongInit before!)
; - a3: pointer to a longword for the progress of samples bytes generated (or null)
;********************************************************************
pre_PlayerInit:
        IFNE    PRETRACKER_DONT_TRASH_REGS
        movem.l d2-d7/a2-a6,-(sp)
        ENDC
        move.l  a0,a4
        move.l  a2,a6

        move.w  #pv_SIZEOF,d0
        bsr     pre_MemClr     ; keeps a1 unchanged!

; ----------------------------------------
; proposed register assignment:
; a0 = sample output / scratch
; a1 = scratch
; a3 = waveinfo
; a4 = MyPlayer
; a6 = MySong

        move.l  a2,pv_my_song(a4)
        IFNE    PRETRACKER_PROGRESS_SUPPORT
        move.l  a3,pv_precalc_progress_ptr(a4)
        ENDC

        move.l  a1,pv_sample_buffer_ptr(a4)
        IFNE    PRETRACKER_PARANOIA_MODE
        beq.s   .hasnosamplebuffer  ; PARANOIA
        ENDC

        clr.w   (a1)+               ; empty sample
        moveq.l #0,d7
        move.b  sv_num_waves_b(a6),d7
        IFNE    PRETRACKER_PARANOIA_MODE
        beq.s   .hasnosamplebuffer  ; PARANOIA
        ENDC

        lea     pv_wave_sample_table(a4),a0
        lea     sv_wavetotal_table(a6),a3
        subq.w  #1,d7
.samplestartsloop
        move.l  a1,(a0)+               ; write sample start pointer
        adda.l  (a3)+,a1
        dbra    d7,.samplestartsloop
.hasnosamplebuffer

; ----------------------------------------

        lea     pre_period_table(pc),a0
        lea     pv_period_table(a4),a1

.calcperiodtable
        ; fill the missing entries in the period table by interpolating
        moveq.l #3*NOTES_IN_OCTAVE-1,d7
.periodtableloop
        move.w  (a0)+,d0
        move.w  (a0),d1
        sub.w   d0,d1
        swap    d0
        clr.w   d0
        swap    d1
        clr.w   d1
        asr.l   #4,d1

        moveq.l #16-1,d6
.perfineipolloop
        swap    d0
        move.w  d0,(a1)+
        swap    d0
        add.l   d1,d0
        dbra    d6,.perfineipolloop
        dbra    d7,.periodtableloop

; ----------------------------------------

        moveq.l #0,d0
        move.b  sv_num_steps_b(a6),d0
        move.w  d0,d1
        add.w   d0,d0
        add.w   d1,d0           ; *3 bytes per pattern line

        move.l  sv_patterns_ptr(a6),a3
        lea     sv_pattern_table(a6),a0
        move.w  #255-1,d7       ; FIXME we should use the number of patterns instead?
.pattableloop
        move.l  a3,(a0)+
        add.w   d0,a3
        dbra    d7,.pattableloop

; ----------------------------------------

        move.l  #$00ffff06,pv_pat_curr_row_b(a4)    ; pattern frame = 0, line = $ff, pattern pos = $ff, speed_even = 0
        move.l  #$06060100,pv_pat_speed_odd_b(a4)   ; and pv_pat_line_ticks_b, pv_pat_stopped_b, pv_songend_detected_b

        move.l  sv_waveinfo_ptr(a6),a1
        lea     pv_channeldata(a4),a0
        moveq.l #NUM_CHANNELS-1,d7
        moveq.l #0,d0
.chaninitloop2
        move.b  #MAX_VOLUME,pcd_pat_vol_b(a0)
        st      pcd_track_delay_offset_b(a0)
        move.l  a1,pcd_waveinfo_ptr(a0)
        move.w  #3,pcd_adsr_phase_w(a0)

        move.l  pv_sample_buffer_ptr(a4),pcd_out_ptr_l(a0)
        move.w  #2,pcd_out_len_w(a0)
        move.w  #$7B,pcd_out_per_w(a0)
        move.b  d0,pcd_channel_num_b(a0)
        bset    d0,pcd_channel_mask_b(a0)
        addq.b  #1,d0
        lea     pcd_SIZEOF(a0),a0
        dbra    d7,.chaninitloop2

; ----------------------------------------

        lea     pre_log12_table(pc),a0   ; 128, 121, 114, 107, 102, 96, 90, 85, 80, 76, 72, 67
        lea     pv_osc_buffers+owb_sqr_waves(a4),a1
        moveq.l #NOTES_IN_OCTAVE-1,d7
.noteloop
        moveq.l #0,d6
        move.l  d6,a3               ; tabpos
        move.b  (a0)+,d6            ; period
        move.b  d6,owb_wave_length-owb_sqr_waves(a1)

        move.l  #$ff00,d5
        divu    d6,d5               ; frac increment

        move.w  d6,d4
        lsr.w   #1,d4               ; half-period
        move.w  d4,d3
        lsr.w   #1,d3               ; quarter-period

        moveq.l #0,d0               ; acc
        lea     (a1,d6.w),a2
        lea     owb_tri_waves-owb_sqr_waves(a2),a2
        suba.w  d3,a2
.notewaveloop
        move.w  d0,d2
        lsr.w   #8,d2

        moveq.l #$7f,d1
        sub.b   d2,d1
        move.b  d1,owb_saw_waves-owb_sqr_waves(a1,a3.w)

        add.b   d2,d2
        cmp.w   a3,d3               ; tabpos == negquarter
        bne.s   .nowrapback
        suba.w  d6,a2               ; go back to start of period
.nowrapback
        cmp.w   d0,a3
        ble.s   .otherhalf
        moveq.l #$7f,d1
        sub.b   d2,d1
        move.b  d1,(a2)+
        bra.s   .clip80

.otherhalf
        add.b   #$80,d2
        move.b  d2,(a2)+
        moveq.l #$7f,d2
        cmp.w   a3,d4
        bne.s   .noclip80
.clip80 moveq.l #-$80,d2
.noclip80
        move.b  d2,owb_sqr_waves-owb_sqr_waves(a1,a3.w)

        add.w   d5,d0               ; increment acc by frac
        addq.w  #1,a3               ; increment pos

        cmp.w   a3,d6
        bne.s   .notewaveloop

        lea     owb_SIZEOF(a1),a1
        dbra    d7,.noteloop

; ----------------------------------------

.audioinit
        bset    #1,$BFE001          ; filter off

        IFNE    PRETRACKER_PARANOIA_MODE
        tst.b   sv_num_waves_b(a6)
        beq     .earlyexit          ; PARANOIA
        ENDC

; ----------------------------------------
; proposed register assignment:
; a0 = sample output
; a1 = scratch
; a3 = songinfo
; a4 = MyPlayer
; a6 = MySong / waveinfo

.wavegenloop
        ;movea.l  pv_my_song(a4),a6
        lea     sv_wavegen_order_table(a6),a1
        move.w  pv_wg_wave_ord_num_w(a4),d0         ; counter through all 24 waves
        moveq.l #0,d1
        move.b  (a1,d0.w),d1        ; apply wave order redirection
        IFNE    PRETRACKER_PARANOIA_MODE    ; same wave for mixing cannot be selected in Pretracker
        move.b  d1,pv_wg_curr_wave_num_b(a4)
        ENDC
        lsl.w   #2,d1
        move.l  pv_wave_sample_table(a4,d1.w),a0
        move.l  a0,pv_wg_curr_sample_ptr(a4)

        add.w   #sv_wavelength_table,d1
        adda.w  d1,a6
        move.l  sv_wavelength_table-sv_wavelength_table(a6),d0
        move.w  d0,pv_wg_curr_sample_len_w(a4)
        IFNE    PRETRACKER_PROGRESS_SUPPORT
        move.l  sv_wavetotal_table-sv_wavelength_table(a6),pv_precalc_sample_size(a4)
        ENDC
        move.l  sv_waveinfo_table-sv_wavelength_table(a6),a3

        ; clear sample data (a0 and d0 from above)
        bsr     pre_MemClr
        move.l  a0,pv_wg_curr_samend_ptr(a4)

        ; read out chord information
        lea     wi_chord_note1_b(a3),a1
        move.b  (a1)+,d1
        move.b  (a1)+,d2
        move.b  (a1)+,d3

        moveq.l #0,d4
        move.b  d1,d4
        or.b    d2,d4
        or.b    d3,d4
        seq     d4
        neg.b   d4
        move.w  d4,pv_wg_chord_flag_w(a4)   ; has chord flag (0/1)

        move.b  wi_osc_basenote_b(a3),d0
        add.b   d0,d1
        add.b   d0,d2
        add.b   d0,d3
        lea     pv_wg_chord_pitches(a4),a1
        move.b  d0,(a1)+
        move.b  d1,(a1)+
        move.b  d2,(a1)+
        move.b  d3,(a1)+

        suba.l  a5,a5
        clr.w   pv_wg_chord_note_num_b(a4)  ; and pv_wg_chord_note_num_b

.wavegen_chordloop
        lea     pv_wg_chord_pitches(a4),a1
        moveq.l #0,d1
        move.b  pv_wg_chord_note_num_b(a4),d1   ; chord note counter
        move.b  (a1,d1.w),d0    ; get chord note
        ext.w   d0

        tst.w   d1
        beq.s   .base_note_is_never_skipped ; is base note?
        cmp.b   wi_osc_basenote_b(a3),d0
        beq     .wave_gen_tone_done      ; skip chord notes that are same as base note
.base_note_is_never_skipped
        moveq.l #0,d1
        moveq.l #NOTES_IN_OCTAVE,d2
        move.w  d0,d1
        move.w  d0,a2           ; save base note, used later (much later, noise generator)!
        add.w   #NOTES_IN_OCTAVE*NOTES_IN_OCTAVE,d1 ; make sure we don't run into negative modulo
        divu    d2,d1
        swap    d1
        move.w  d1,d0           ; note within octave
        swap    d1
        sub.w   d2,d1           ; restore octave

        mulu    #owb_SIZEOF,d0
        lea     (a4,d0.w),a1

        lea     pv_osc_buffers+owb_saw_waves(a1),a6
        moveq.l #3,d0
        and.b   wi_flags_b(a3),d0
        beq.s   .osc_selected
        lea     owb_tri_waves-owb_saw_waves(a6),a6
        subq.b  #1,d0
        beq.s   .osc_selected
        lea     owb_sqr_waves-owb_tri_waves(a6),a6
        subq.b  #1,d0
        beq.s   .osc_selected
        suba.l  a6,a6           ; noise selected
.osc_selected

        move.l  #$8000,d6
        move.w  d1,d0           ; check octave shift
        bgt.s   .shiftleft
        beq.s   .contshift
;.shiftright
        move.w  d0,d3
        neg.w   d3
        asr.l   d3,d6
        bra.s   .contshift
.shiftleft
        lsl.l   d0,d6
.contshift

; ----------------------------------------
; pitch ramp
        move.b  wi_pitch_ramp_b(a3),d3
        ext.w   d3
        ext.l   d3
        btst    #4,wi_flags_b(a3)   ; pitch linear flag
        beq.s   .pitch_not_linear
        tst.b   d3
        bgt.s   .pitch_ramp_positive

        lsl.l   d0,d3
        add.l   d3,d3
        bra.s   .pitch_ramp_cont

.pitch_not_linear
        tst.b   d3
        ble.s   .pitch_ramp_cont
.pitch_ramp_positive
        muls    d3,d3
.pitch_ramp_cont
        move.l  d3,d2
        lsl.l   #8,d2
        lsl.l   #2,d2

        moveq.l #0,d7
        move.b  pv_osc_buffers+owb_wave_length(a1),d7   ; get period
        moveq.l #15,d5
        lsl.l   d5,d7

        sub.w   d0,d5       ; 15-octave
        lsl.w   #3,d5

        moveq.l #0,d3
        move.b  wi_osc_phase_min_b(a3),d3

        mulu    d5,d3
        lsl.l   #6,d3

        moveq.l #0,d0
        move.b  wi_osc_phase_max_b(a3),d0
        mulu    d5,d0
        lsl.l   #6,d0
        move.l  d0,a5

        moveq.l #0,d5
        move.b  wi_osc_phase_spd_b(a3),d5
        lsl.l   #8,d5
        lsl.l   #3,d5

        cmp.l   d3,d0
        bge.s   .osc_with_positive_phase_speed
        neg.l   d5

        movea.l d3,a5
        bra.s   .osc_continue
.osc_with_positive_phase_speed
        move.l  d3,d0

.osc_continue
        move.l  d0,pv_wg_osc_speed_l(a4)

        ; d0 = d6 * chord_shift * chordnum + d6 * phase_min = d6 * (chord_shift * chordnum + phase_min)

        moveq.l #0,d4
        move.b  wi_chord_shift_b(a3),d4
        move.w  pv_wg_chord_flag_w(a4),d0
        add.b   pv_wg_chord_note_num_b(a4),d0
        mulu    d0,d4
        moveq.l #0,d0
        move.b  wi_osc_phase_min_b(a3),d0
        add.w   d0,d4
        move.l  d6,d0
        lsr.l   #4,d0
        lsl.l   #4,d4
        mulu    d4,d0

        cmp.l   d7,d0
        ble.s   .lbC002516
.lbC002510
        sub.l   d7,d0
        cmp.l   d7,d0
        bgt.s   .lbC002510
.lbC002516
        move.l  a6,d4
        bne     .no_noise

; ----------------------------------------
; d1 = octave
; d5 = osc phase speed
; a2 = base note
.gen_noise
        IFNE    PRETRACKER_PARANOIA_MODE
        tst.w   pv_wg_curr_sample_len_w(a4)
        beq     .wave_gen_tone_done
        ENDC

        move.l  #$8000,d5
        move.l  d5,a5
        tst.w   d1
        bge.s   .gen_noise_positive_octave

.gen_noise_negative_octave
        moveq.l #NOTES_IN_OCTAVE,d1
        move.l  a2,d3
        neg.l   d3
        move.l  d3,d0
        divu    d1,d0
        IFNE    PRETRACKER_PARANOIA_MODE
        bvs.s   .divisionoverflow
        ENDC
        addq.w  #1,d0
        lsr.w   d0,d5
        moveq.l #0,d0
        move.w  d5,d0
        divu    d1,d0
        moveq.l #0,d4
        move.w  d0,d4
        IFNE    PRETRACKER_PARANOIA_MODE
        bra.s   .returnfromoverflow
.divisionoverflow
        move.l  #$AAA,d4        ; some dummy value, I would expect
.returnfromoverflow
        ENDC
        moveq.l #0,d0
        move.w  d3,d0
.cheap_mod12
        sub.w   d1,d0
        bpl.s   .cheap_mod12
        neg.w   d0
        mulu    d4,d0
        add.l   d0,d5

.gen_noise_positive_octave
        moveq.l #0,d0
        move.b  wi_osc_phase_min_b(a3),d0
        moveq.l #0,d1
        move.b  wi_chord_shift_b(a3),d1
        add.w   d1,d0
        addq.w  #1,d0

        movea.l d5,a1
        movea.l pv_wg_curr_sample_ptr(a4),a0
        moveq.l #0,d1
        moveq.l #0,d6
        moveq.l #0,d3
        move.b  wi_osc_gain_b(a3),d3

.gen_noise_outerloop
        move.w  d0,d1           ; random noise generator
        lsl.w   #8,d1
        lsl.w   #5,d1
        eor.w   d1,d0

        move.w  d0,d1
        lsr.w   #8,d1
        lsr.w   #1,d1
        eor.w   d1,d0

        move.w  d0,d1
        lsl.w   #7,d1
        eor.w   d1,d0

        cmpa.l  #$8000,a5       ; if symmetrical
        beq.s   .gen_noise_centered
        ; what does this do? (a5 - $8000) (a5 +$7fff)&$8000
        move.l  a5,d4
        addi.l  #$FFFF8000,d4
        move.l  a5,d1
        addi.l  #$FFFF7FFF,d1
        andi.w  #$8000,d1
        movea.l d4,a5
        suba.l  d1,a5
.gen_noise_centered

        move.b  d0,d1
        ext.w   d1
        move.w  d3,d4
        muls    d1,d4
        move.l  d4,d1
        asr.l   #7,d1
        CLIPTO8BIT d1
        add.b   (a0),d1

.gen_noise_innerloop
        move.b  d1,(a0)+
        adda.l  a1,a5
        tst.l   d2
        beq.s   .lbC002BAC
        add.l   d2,d6
        move.l  d6,d4
        asr.l   #8,d4
        asr.l   #2,d4
        add.l   d5,d4
        movea.l d4,a1

        btst    #4,wi_flags_b(a3)   ; pitch linear flag
        beq.s   .noise_nonlinear_pitch
        move.l  d2,d4
        asr.l   #7,d4
        sub.l   d4,d2
.noise_nonlinear_pitch

        cmpa.w  #$1FF,a1
        bgt.s   .lbC002BAC
        moveq.l #0,d2
        move.l  d2,a5
        ;suba.l   a5,a5
        movea.w #$200,a1
.lbC002BAC
        cmpa.l  pv_wg_curr_samend_ptr(a4),a0
        beq     .wave_gen_tone_done
        cmpa.w  #$7FFF,a5
        ble.s   .gen_noise_innerloop
        bra     .gen_noise_outerloop

.no_noise
        move.l  d6,d1
        tst.b   pv_wg_unisono_run_b(a4)
        beq.s   .is_not_in_unisono

        moveq.l #3<<3,d1
        and.b   wi_mod_density_b(a3),d1
        lsr.b   #3,d1
        moveq.l #9,d4
        sub.b   d1,d4

        move.l  d6,d1
        asr.l   d4,d1
        add.l   d6,d1
.is_not_in_unisono

        IFNE    PRETRACKER_PARANOIA_MODE
        tst.w   pv_wg_curr_sample_len_w(a4)
        beq     .wave_gen_tone_done
        ENDC

; ----------------------------------------
; chord gen
; in: d0/d1/d2/d3/d5/d7
; in: a0
        move.l  d3,a1
        movea.l pv_wg_curr_sample_ptr(a4),a0
        suba.l  a2,a2

.chordtoneloop
        move.l  d0,d4
        sub.l   a1,d4
        bpl.s   .noclip_osc_phase
        moveq.l #0,d4
.noclip_osc_phase
        asr.l   #8,d4
        asr.l   #7,d4
        move.b  (a6,d4.w),d4        ; fetch precalced sample
        ext.w   d4

        moveq.l #0,d3
        move.b  wi_osc_gain_b(a3),d3
        muls    d4,d3
        asr.w   #7,d3

        move.b  (a0),d4
        ext.w   d4
        add.w   d3,d4
        CLIPTO8BIT d4
        move.b  d4,(a0)+

        add.l   d1,d0
        cmp.l   d7,d0
        blt.s   .lbC0025A2
        sub.l   d7,d0
        add.l   d5,a1
        cmp.l   a5,a1
        blt.s   .lbC00259A
        neg.l   d5
        move.l  a5,a1
.lbC00259A
        cmp.l   pv_wg_osc_speed_l(a4),a1
        bgt.s   .lbC0025A2
        neg.l   d5
        move.l  pv_wg_osc_speed_l(a4),a1
.lbC0025A2
        tst.l   d2
        beq.s   .chordtone_done
        adda.l  d2,a2
        move.l  a2,d1
        asr.l   #8,d1
        asr.l   #2,d1
        add.l   d6,d1

        btst    #4,wi_flags_b(a3)   ; pitch linear flag
        beq.s   .no_linear_pitch
        move.l  d2,d4
        asr.l   #7,d4
        sub.l   d4,d2
.no_linear_pitch
        cmp.l   d7,d1
        bcs.s   .chordtone_done
        moveq.l #0,d2
        moveq.l #0,d1
.chordtone_done
        cmpa.l  pv_wg_curr_samend_ptr(a4),a0
        bne.s   .chordtoneloop

.wave_gen_tone_done
        addq.b  #1,pv_wg_chord_note_num_b(a4)
        cmp.b   #4,pv_wg_chord_note_num_b(a4)
        bne     .wavegen_chordloop

        moveq.l #3<<3,d0
        and.b   wi_mod_density_b(a3),d0 ; unisono
        beq.s   .chords_done
        move.l  a6,d1
        beq.s   .chords_done
        tst.b   pv_wg_unisono_run_b(a4)
        bne.s   .chords_done
        move.w  #$0001,pv_wg_chord_note_num_b(a4) ; sets also pv_wg_unisono_run_b
        bra     .wavegen_chordloop

.chords_done
; ----------------------------------------
; filters
; proposed register assignment:
; a0 = sample output
; a1 = end of filter chunk
; a2 = filter func
; d7/a6 = filter start
; a4 = MyPlayer
; a5 = unused
; a3 = waveinfo
; d3/d4/d5/d6 = filter taps
; d0/d1/d7 = scratch

        moveq.l #0,d0
        move.b  wi_flt_type_b(a3),d0
        beq     .filter_done

        IFNE    PRETRACKER_PARANOIA_MODE
        tst.w   pv_wg_curr_sample_len_w(a4)
        beq     .filter_done
        ENDC

        add.w   d0,d0
        lea     .filterfunc_jmptable(pc),a2
        add.w   -1*2(a2,d0.w),a2

        moveq.l #0,d4       ; filter tap values
        moveq.l #0,d5       ; filter tap values
        movem.l d4-d5,pv_wg_flt_taps(a4)

        lea     wi_flt_start_b(a3),a0
        moveq.l #0,d0
        move.b  (a0)+,d0    ; wi_flt_start_b
        lsl.w   #8,d0

        move.b  (a0)+,d4    ; wi_flt_min_b
        lsl.w   #8,d4       ; flt_min*256

        move.b  (a0)+,d5    ; wi_flt_max_b
        lsl.w   #8,d5       ; flt_max*256

        move.b  (a0)+,d3    ; wi_flt_speed_b
        ext.w   d3
        ext.l   d3          ; flt_speed*128
        lsl.l   #7,d3

        movea.l pv_wg_curr_sample_ptr(a4),a0

.entry_to_filter_loop
        move.l  d0,a6
        move.l  d3,d1       ; flt_speed_b*128
        adda.l  d1,a6       ; suppress M68kUnexpectedConditionalInstruction
        bgt.s   .filter_speed_pos

.filter_speed_neg
        move.l  d4,d1       ; flt_min*256
        cmp.l   d1,d0
        blt.s   .lbC002790
        cmp.l   d1,a6
        bgt.s   .lbC002936
        move.l  d1,a6
        cmp.l   d5,d1       ; flt_max*256
        beq.s   .filter_load_min
        neg.l   d3          ; flt_speed_b*128
        bra.s   .filter_load_min

.filterfunc_jmptable
        dc.w    .lowpassfilter-.filterfunc_jmptable
        dc.w    .highpassfilter-.filterfunc_jmptable
        dc.w    .bandpassfilter-.filterfunc_jmptable
        dc.w    .notchfilter-.filterfunc_jmptable

.lbC002790
        tst.l   d0
        blt.s   .lbC002936
        move.l  a6,d7
        bgt.s   .lbC002936
        neg.l   d3          ; flt_speed_b*128
        move.w  #$FF,d2
        move.w  d2,d1
        sub.l   a6,a6
        bra.s   .filter_cont

.filter_speed_pos
        cmp.l   d5,d0       ; flt_max*256
        bgt.s   .lbC002D2A
        cmp.l   d5,a6       ; flt_max*256
        blt.s   .lbC002936
        move.l  d4,d2       ; flt_min*256
        cmp.l   d5,d2       ; flt_max*256
        beq.s   .filter_load_max_no_flip
        neg.l   d3          ; flt_speed_b*128
        move.l  d5,a6       ; flt_max*256
        bra.s   .filter_load_max

.lbC002D2A
        cmpi.l  #$FF00,d0
        bgt.s   .lbC002936
        cmp.l   #$FEFF,a6
        ble.s   .lbC002936
        neg.l   d3          ; flt_speed_b*128
        moveq.l #0,d2
        move.l  #$FF00,a6
        bra.s   .filter_cont

.lbC002936
        move.w  a6,d2
        lsr.w   #8,d2
        not.b   d2
        bra.s   .filter_cont

.filter_load_max_no_flip
        movea.l d2,a6
.filter_load_max
        moveq.l #0,d2
        move.b  wi_flt_max_b(a3),d2
        not.b   d2
        bra.s   .filter_cont

.filter_load_min
        moveq.l #0,d2
        move.b  wi_flt_min_b(a3),d2
        not.b   d2

.filter_cont
        btst    #0,wi_flt_type_b(a3)
        bne.s   .not_notch_or_highpass
.highpass_or_notch          ; entered for 2 or 4
        not.b   d2
.not_notch_or_highpass      ; entered for 1 or 3
        move.w  d2,d0
        add.w   d0,d0

        moveq.l #0,d7
        move.b  wi_flt_resonance_b(a3),d7
        beq.s   .filter_no_resonance
        move.w  d2,d1
        ext.l   d1
        lsl.l   #8,d1

        moveq.l #$B6/2,d0
        sub.w   d7,d0
        add.w   d0,d0

        cmpi.w  #$36,d0
        bge.s   .filter_no_clip_resonance
        moveq.l #$36,d0
.filter_no_clip_resonance
        divu    d0,d1
        move.w  d2,d0
        add.w   d1,d0
.filter_no_resonance
        lea     $40(a0),a1          ; end of sample chunk

        movem.l d3-d5,-(sp)
        movem.w pv_wg_flt_taps(a4),d3-d6

        ; d0/d2 relevant for inner loop
.filter_innerloop
        move.b  (a0),d1
        ext.w   d1

        move.w  d4,d7
        sub.w   d5,d7
        muls    d0,d7
        asr.l   #8,d7
        sub.w   d4,d7

        add.w   d1,d7
        muls    d2,d7
        asr.l   #8,d7
        add.w   d7,d4
        move.w  d4,d7

        sub.w   d5,d7
        muls    d2,d7
        asr.l   #8,d7
        add.w   d7,d5
        move.w  d5,d7

        sub.w   d6,d7
        muls    d2,d7
        asr.l   #8,d7
        add.w   d7,d6
        move.w  d6,d7

        sub.w   d3,d7
        muls    d2,d7
        asr.l   #8,d7
        add.w   d7,d3
        move.w  d3,d7

        jmp     (a2)

.highpassfilter
        sub.w   d1,d7
        bra.s   .filterclipresult

.bandpassfilter
        sub.w   d4,d7
        sub.w   d5,d7
        sub.w   d6,d7
        asr.w   #1,d7
        bra.s   .filterclipresult

.notchfilter
        sub.w   d4,d7
        neg.w   d7

.lowpassfilter
.filterclipresult
        CLIPTO8BIT d7
.filter_outputbyte
        move.b  d7,(a0)+
        cmpa.l  a0,a1
        bne.s   .filter_innerloop

.filterloop_end_test
        movem.w d3-d6,pv_wg_flt_taps(a4)
        movem.l (sp)+,d3-d5

        cmpa.l  pv_wg_curr_samend_ptr(a4),a0
        bhs.s   .filter_done
        move.l  a6,d0
        bra     .entry_to_filter_loop

.filter_done
; ----------------------------------------
; Optional Pre-Modulator
        btst    #5,wi_mod_density_b(a3) ; post bit
        bne.s   .nopremodulator
        bsr     pre_Modulator
.nopremodulator

; ----------------------------------------
; start with volume envelope
; a0 = output sample buffer
; d0 = scratch (e.g. sample)
; d1 = increment for attack phase
; d3 = current volume for attack and decay phases
; d4 = remaining sample length - 1
; a3 = wave info

.vol_do_envelope
        movea.l pv_wg_curr_sample_ptr(a4),a0     ; load buffer pointer
        move.w  pv_wg_curr_sample_len_w(a4),d4     ; load length
        IFNE    PRETRACKER_PARANOIA_MODE
        beq     .vol_envelope_finished ; paranoia
        ENDC
        subq.w  #1,d4           ; we use length-1, <0 is end

        moveq.l #2,d1           ; turns into $20000 through swap
        moveq.l #0,d0
        move.b  wi_vol_attack_b(a3),d0
        bne.s   .has_attack_volume
        cmpi.b  #$FF,wi_vol_sustain_b(a3)
        beq     .vol_envelope_finished
        ; no attack but not full sustain -> go to delay
        ;move.l  #$100<<16,d3
        bra.s   .vol_skip_attack

.vol_avoid_overflow_with_1
        moveq.l #1,d1
        bra.s   .cont_vol_envelope
.has_attack_volume
        moveq.l #0,d3
        cmp.w   #1,d0
        beq.s   .cont_vol_envelope
        cmp.w   #2,d0
        beq.s   .vol_avoid_overflow_with_1
        swap    d1                  ; turn into $20000
        divu    d0,d1
        swap    d1
        clr.w   d1
        ; swap is done below
.cont_vol_envelope
        swap    d1                  ; move to high word (should be max $20000 then)
        btst    #5,wi_flags_b(a3)   ; vol fast flag
        beq.s   .vol_no_fast
        lsl.l   #4,d1               ; multiply speed by 16
.vol_no_fast
        add.l   d1,d3               ; increase volume
        cmpi.l  #$FFFFFF,d3
        ble.s   .vol_do_attack      ; first step overshooting?
.vol_skip_attack
        btst    #3,wi_flags_b(a3)   ; boost flag
        bne.s   .vol_delay_boosted
        bra.s   .vol_delay_normal

.vol_do_attack
        btst    #3,wi_flags_b(a3)   ; boost flag
        bne.s   .vol_attack_boosted

; ----------------------------------------
; attack phase with volume boosted
.vol_attack_normal
.vol_attack_normal_loop
        move.b  (a0),d0
        ext.w   d0
        swap    d3
        muls    d3,d0
        swap    d3
        asr.w   #8,d0
        move.b  d0,(a0)+

        subq.w  #1,d4
        bmi     .vol_envelope_finished
        add.l   d1,d3               ; increase volume
        cmpi.l  #$FFFFFF,d3
        ble.s   .vol_attack_normal_loop

; ----------------------------------------
; delay phase (normal)

.vol_delay_normal   ; moved this label two inst up, didn't make sense there
        moveq.l #0,d0
        move.b  wi_vol_delay_b(a3),d0
        lsl.w   #4,d0

        IFNE    PRETRACKER_FASTER_CODE
        ; skip the delay -- we don't change the volume for this section
        addq.w  #1,d0
        sub.w   d0,d4
        bmi     .vol_envelope_finished
        lea     1(a0,d0.w),a0
        ELSE
        lea     2(a0,d0.w),a1

        move.w  #$FF,d3        ; FIXME I don't think that this is quite right. Shouldn't the max volume NOT change the value?
.vol_delay_normal_loop
        move.b  (a0),d0
        IFNE    1
        ext.w   d0
        muls    d3,d0
        asr.w   #8,d0
        ELSE
        ; this should be the same as above (*(256-1))
        spl     d3
        add.b   d3,d0
        ENDC
        move.b  d0,(a0)+

        cmpa.l  a1,a0
        dbeq    d4,.vol_delay_normal_loop
        bne     .vol_envelope_finished
        ENDC

        bra.s   .vol_delay_end_reached

; ----------------------------------------
; attack with volume boosted

.vol_attack_boosted
.vol_attack_boosted_loop
        move.b  (a0),d0
        ext.w   d0
        swap    d3
        muls    d3,d0
        swap    d3
        asr.w   #6,d0
        CLIPTO8BIT d0
        move.b  d0,(a0)+

        subq.w  #1,d4
        bmi     .vol_envelope_finished
        add.l   d1,d3
        cmpi.l  #$FFFFFF,d3
        ble.s   .vol_attack_boosted_loop

; ----------------------------------------
; delay with max volume boosted

.vol_delay_boosted
        moveq.l #0,d0
        move.b  wi_vol_delay_b(a3),d0
        lsl.w   #4,d0

        lea     2(a0,d0.w),a1

        IFNE    PRETRACKER_FASTER_CODE
.vol_delay_boosted_loop
        move.b  (a0),d0
        add.b   d0,d0
        CLIPTO8BITAFTERADD d0
        add.b   d0,d0
        CLIPTO8BITAFTERADD d0
        ELSE
        move.w  #$FF,d3        ; FIXME I don't think that this is quite right. It should be $100 to boost by full volume
.vol_delay_boosted_loop
        move.b  (a0),d0
        ext.w   d0
        muls    d3,d0
        asr.w   #6,d0
        CLIPTO8BIT d0
        ENDC
        move.b  d0,(a0)+

        cmpa.l  a1,a0
        dbeq    d4,.vol_delay_boosted_loop
        bne     .vol_envelope_finished

.vol_delay_end_reached
        subq.w  #1,d4

; ----------------------------------------
; decay phase
; d0 = scratch
; d1 = current volume decrement
; d2 = table index boundary
; d3 = 16:16 decay pos
; d4 = sample length counter
; d5 = volume
; d6 = scratch
; d7 = decay increment
; a0 = sample pointer
; a1 = (current) roll off table pointer (points to upper bound)
; a2 = lower bound

.vol_do_decay
        moveq.l #0,d3
        move.b  wi_vol_decay_b(a3),d3
        beq     .vol_do_sustain
        move.w  d3,d7
        mulu    d7,d7
        lsr.w   #2,d7
        add.w   d3,d7       ; d7 = (d3^2)/4+d3 (<= 16511)

        btst    #5,wi_flags_b(a3)   ; vol fast flag
        beq.s   .vol_decay_not_fast
        moveq.l #0,d3       ; will cause a5=$400,a2=$200,d2=0, decay value has no effect on the ramp used
.vol_decay_not_fast
        lsl.w   #8,d3
        lsl.l   #4,d3
        move.l  d3,d2
        swap    d2
        lea     pre_roll_off_table(pc),a1
        add.w   d2,d2
        adda.w  d2,a1
        move.w  (a1)+,a2    ; first index in table
        lsr.w   #1,d2       ; update next boundary

        moveq.l #0,d1       ; current volume decrement
        moveq.l #0,d5
        not.w   d5          ; set maximum volume
.vol_decay_normal_loop
        add.l   d7,d3       ; increment position in decay
        swap    d3

        cmp.w   #$8e,d3     ; pos in table where it makes no sense to do lerp anymore
        bhi.s   .vol_keep_voldec
        cmp.w   d2,d3
        bls.s   .vol_do_lerp

.vol_lerp_next_section
        move.w  (a1),a2
        IFNE    PRETRACKER_BUGFIX_CODE
        lea     pre_roll_off_table+2(pc),a1 ; Take the right boundary value
        ELSE
        lea     pre_roll_off_table(pc),a1   ; This will set a wrong boundary and thus plateau the slope decay speed
        ENDC
        add.w   d3,a1
        add.w   d3,a1

        move.w  d3,d2       ; update next boundary

.vol_do_lerp        ; ((lowerbound-upperbound)*(d3<<8))>>8 + upperbound
        move.w  a2,d1
        move.w  (a1),d0
        sub.w   d1,d0               ; delta between lower and upper bound (negative value)
        beq.s   .vol_skip_lerp

        swap    d3
        move.w  d3,d1
        lsr.w   #8,d1
        muls    d0,d1
        asr.l   #8,d1
        add.w   a2,d1
        swap    d3

.vol_keep_voldec
.vol_skip_lerp
        swap    d3
        sub.w   d1,d5
        bls.s   .vol_do_sustain

        move.w  d5,d6
        lsr.w   #8,d6

        cmp.b   wi_vol_sustain_b(a3),d6
        bls.s   .vol_do_sustain

        move.b  (a0),d0
        ext.w   d0
        muls    d6,d0
        btst    #3,wi_flags_b(a3)       ; boost flag
        CLIPORTRUNC8BIT d0
        move.b  d0,(a0)+

        dbra    d4,.vol_decay_normal_loop
        bra.s   .vol_envelope_finished

; ----------------------------------------
; sustain phase
.vol_do_sustain
        moveq.l #0,d3
        move.b  wi_vol_sustain_b(a3),d3
        beq.s   .vol_sustain_silence

        btst    #3,wi_flags_b(a3)       ; boost flag
        beq.s   .vol_sustain_normal
.vol_sustain_boosted
.vol_sustain_boosted_loop
        move.b  (a0),d0
        ext.w   d0
        muls    d3,d0
        asr.w   #6,d0

        CLIPTO8BIT d0
        move.b  d0,(a0)+
        dbra    d4,.vol_sustain_boosted_loop
        bra.s   .vol_envelope_finished

.vol_sustain_silence
        moveq.l #0,d0
.vol_sustain_silence_loop
        move.b  d0,(a0)+
        dbra    d4,.vol_sustain_silence_loop
        bra.s   .vol_envelope_finished

.vol_sustain_normal
        IFNE    PRETRACKER_FASTER_CODE
        cmp.b   #$ff,d3
        beq.s   .vol_envelope_finished
        ENDC

.vol_sustain_normal_loop
        move.b  (a0),d0
        ext.w   d0
        muls    d3,d0
        asr.w   #8,d0
        move.b  d0,(a0)+
        dbra    d4,.vol_sustain_normal_loop

.vol_envelope_finished

; ----------------------------------------
; Optional Post-Modulator

        btst    #5,wi_mod_density_b(a3) ; post bit
        beq.s   .nopostmodulator
        bsr     pre_Modulator
.nopostmodulator

; ----------------------------------------
; wave mixing (removed some code here that was doing nothing as result
; because below higher octaves code would overwrite it anyway).
        movea.l pv_my_song(a4),a6

        moveq.l #0,d0
        move.b  wi_mix_wave_b(a3),d0
        beq.s   .mix_no_wave_mixing         ; no mixing selected
        subq.b  #1,d0
        IFNE    PRETRACKER_PARANOIA_MODE    ; same wave for mixing cannot be selected in Pretracker
        cmp.b   pv_wg_curr_wave_num_b(a4),d0
        beq     .mix_no_wave_mixing         ; same wave number!
        ENDC

        lsl.w   #2,d0
        move.l  pv_wave_sample_table(a4,d0.w),a1
        add.w   #sv_wavelength_table,d0
        move.l  (a6,d0.w),d3

        move.w  pv_wg_curr_sample_len_w(a4),d4 ; length of the sample to mix to
        cmp.w   d3,d4
        ble.s   .mix_picked_shorter
        move.w  d3,d4
.mix_picked_shorter

        move.l  pv_wg_curr_sample_ptr(a4),a0

        subq.w  #1,d4
.mix_mixloop
        move.b  (a0),d0
        add.b   (a1)+,d0
        CLIPTO8BITAFTERADD d0
        move.b  d0,(a0)+
        dbra    d4,.mix_mixloop
.mix_no_wave_mixing

; ----------------------------------------
; create higher octaves (this has been massively shortened)

        btst    #2,wi_flags_b(a3)
        beq.s   .oct_has_no_extra_octaves

        moveq.l #0,d4
        move.b  wi_sam_len_b(a3),d4 ; length of the sample
        IFNE    PRETRACKER_PARANOIA_MODE
        beq.s   .oct_has_no_extra_octaves
        ENDC
        addq.w  #1,d4
        lsl.w   #7,d4

        movea.l pv_wg_curr_sample_ptr(a4),a1
        lea     (a1,d4.l),a0    ; needs to be .l due to 32678 max length

        mulu    #7,d4
        lsr.l   #3,d4           ; * 0.875
        subq.w  #1,d4
.oct_downsample_loop
        move.b  (a1),(a0)+
        addq.l  #2,a1
        dbra    d4,.oct_downsample_loop

.oct_has_no_extra_octaves
; ----------------------------------------
        IFNE    PRETRACKER_PROGRESS_SUPPORT
        move.l  pv_precalc_progress_ptr(a4),d0
        beq.s   .no_progress_out
        move.l  d0,a0
        move.l  pv_precalc_sample_size(a4),d0
        add.l   d0,(a0)
.no_progress_out
        ENDC
        move.b  sv_num_waves_b(a6),d0
        addq.b  #1,pv_wg_wave_ord_num_w+1(a4)
        cmp.b   pv_wg_wave_ord_num_w+1(a4),d0
        bgt     .wavegenloop

; ----------------------------------------
        IFNE    PRETRACKER_VOLUME_TABLE
        lea     pv_volume_table(a4),a0
        moveq.l #(MAX_VOLUME+1)-1,d7
        moveq.l #0,d0
.vol_outerloop
        moveq.l #MAX_VOLUME*2-1,d6
        moveq.l #0,d1
.vol_innerloop
        move.w  d1,d2
        lsr.w   #6,d2
        move.b  d2,(a0)+
        add.w   d0,d1
        dbra    d6,.vol_innerloop
        addq.w  #1,d0
        dbra    d7,.vol_outerloop
        ENDC

; ----------------------------------------
.earlyexit
        IFNE    PRETRACKER_DONT_TRASH_REGS
        movem.l (sp)+,d2-d7/a2-a6
        ENDC
        rts

;--------------------------------------------------------------------
; a3: waveinfo
;
; d6: wetness (word)
; uses all data registers and a0-a2 (a3 unchanged)
pre_Modulator:
        tst.b   wi_mod_wetness_b(a3)
        beq.s   .earlyexit
        moveq.l #7,d0
        and.b   wi_mod_density_b(a3),d0
        bne.s   .has_density
.earlyexit
        rts
.has_density
        move.l  pv_wg_curr_sample_ptr(a4),a0
        move.w  pv_wg_curr_sample_len_w(a4),d4
        IFNE    PRETRACKER_PARANOIA_MODE
        bne.s   .not_zero
        rts
.not_zero
        ENDC
        moveq.l #0,d6
        move.b  wi_mod_wetness_b(a3),d6

        moveq.l #0,d7

        lea     pre_modulator_ramp_8(pc),a1
        lea     pre_ramp_up_down_32(pc),a2
.loop   moveq.l #0,d5
        move.b  wi_mod_length_b(a3),d5
        mulu    (a1)+,d5            ; result is a long value

        moveq.l #0,d1
        move.b  wi_mod_predelay_b(a3),d1

        btst    #5,wi_mod_density_b(a3) ; post-modulator?
        bne.s   .factor1_256
        ; factor 1/4 and 64
        lsr.l   #2,d5
        lsl.l   #6,d1
        bra.s   .cont

.factor1_256
        lsl.w   #8,d1
.cont   add.l   d1,d5               ; sum up length and predelay

        moveq.l #0,d2
        moveq.l #0,d3

.innerloop
        add.w   d7,d3
        addq.w  #8,d3
        moveq.l #0,d1
        move.w  d3,d1
        lsr.w   #8,d1
        lsr.w   #3,d1
        add.w   d1,d1
        move.w  (a2,d1.w),d1        ; 4 bit value
        add.l   d5,d1
        lsr.l   #6,d1

        move.w  d2,d0
        sub.w   d1,d0
        bmi.s   .isneg

        move.b  (a0,d0.w),d1
        ext.w   d1
        btst    #0,d7
        beq.s   .keep_dc
        neg.w   d1
.keep_dc

        muls    d6,d1
        asr.w   #8,d1
        add.b   (a0,d2.w),d1

        CLIPTO8BITAFTERADD d1
        move.b  d1,(a0,d2.w)
.isneg
        addq.w  #1,d2
        cmp.w   d4,d2
        bcs.s   .innerloop

.restartloop
        addq.w  #1,d7
        moveq.l #7,d0
        and.b   wi_mod_density_b(a3),d0
        cmp.w   d0,d7
        bcs.s   .loop
        rts

;--------------------------------------------------------------------

pre_MemClr
        lsr.w   #1,d0
        subq.w  #1,d0
        bmi.s   .skipmemclr
        moveq.l #0,d1
.fillmemloop
        move.w  d1,(a0)+
        dbra    d0,.fillmemloop
.skipmemclr
        rts

;********************************************************************
;--------------------------------------------------------------------
; PlayerTick - Play one frame of music (called every VBL)
;
; In:
; - a0: MyPlayer
; - a1: copperlist (if enabled)
;********************************************************************
pre_PlayerTick:
        IFNE    PRETRACKER_DONT_TRASH_REGS
        movem.l d2-d7/a2-a6,-(sp)
        ENDC
        move.l  a0,a4
        IFNE    PRETRACKER_COPPER_OUTPUT
        move.l  a1,pv_copperlist_ptr(a4)
        ENDC
        movea.l pv_my_song(a4),a6
        tst.b   pv_pat_stopped_b(a4)
        beq     .inst_pattern_processing    ; don't process if music has been stopped

; ----------------------------------------
; processes the current pattern position
; registers used:
; d0: pitch shift (lower part)
; d1: scratch
; d2: effect cmd
; d3: pitch_ctrl
; d4: inst number
; d5: effect cmd
; d6: unused (flag later)
; d7: pitch
; a0: pattern data pointer
; a1: short-term scratch
; a2: unused
; a3: unused
; a4: pv
; a5: channel struct
; a6: mysong struct
.process_pattern
        lea     pv_channeldata(a4),a5   ; start with first channel
.pre_pat_chan_loop
        IFNE    PRETRACKER_PARANOIA_MODE
        ; I think this is something leftover from the tracker itself.
        ; Nothing sets pcd_pat_adsr_rel_delay_b from inside the player.
        ; It is used as a counter to release a note (ADSR) after a given time.
        ; It's not the same as the instrument ADSR release (see pcd_note_off_delay_b)
        move.b  pcd_pat_adsr_rel_delay_b(a5),d1
        ble.s   .handle_2nd_instrument
        subq.b  #1,d1
        move.b  d1,pcd_pat_adsr_rel_delay_b(a5)
        bne.s   .handle_2nd_instrument

        move.w  pcd_adsr_volume_w(a5),d3
        lsr.w   #6,d3
        move.w  d3,pcd_adsr_vol64_w(a5)
        moveq.l #16,d4
        move.w  d4,pcd_adsr_pos_w(a5)
        sub.w   d3,d4
        lsr.w   #1,d4
        add.b   pcd_adsr_release_b(a5),d4
        move.b  d4,pcd_adsr_phase_speed_b(a5)
        move.w  #3,pcd_adsr_phase_w(a5)
        ENDC

; ----------------------------------------
.handle_2nd_instrument
        moveq.l #0,d1
        move.b  pcd_pat_2nd_inst_num4_b(a5),d1
        beq.s   .handle_current_instrument

        move.b  pcd_pat_2nd_inst_delay_b(a5),d3
        beq.s   .trigger_2nd_instrument
        subq.b  #1,d3
        move.b  d3,pcd_pat_2nd_inst_delay_b(a5)
        bra.s   .handle_current_instrument

.trigger_2nd_instrument
        move.b  d1,pcd_new_inst_num_b(a5)
        move.w  d1,pcd_inst_num4_w(a5)
        add.w   d1,d1
        add.w   d1,d1
        lea     sv_inst_infos_table-uii_SIZEOF(a6),a1
        add.w   d1,a1
        move.l  a1,pcd_inst_info_ptr(a5)    ; loads 2nd instrument
        move.b  uii_pattern_steps(a1),pcd_inst_pattern_steps_b(a5)

        moveq.l #0,d1
        move.l  a5,a1
        move.l  d1,(a1)+    ; pcd_pat_portamento_dest_w and pcd_pat_pitch_slide_w
        move.l  d1,(a1)+    ; pcd_pat_vol_ramp_speed_b, pcd_pat_2nd_inst_num4_b, pcd_pat_2nd_inst_delay_b, pcd_wave_offset_b
        move.l  d1,(a1)+    ; pcd_inst_pitch_slide_w and pcd_inst_sel_arp_note_w
        move.w  d1,(a1)+    ; pcd_inst_note_pitch_w
        addq.w  #2,a1

        move.l  d1,(a1)+    ; pcd_inst_line_ticks_b, pcd_inst_pitch_pinned_b, pcd_inst_vol_slide_b, pcd_inst_step_pos_b

        subq.b  #1,d1
        move.w  d1,(a1)+    ; pcd_inst_wave_num_w

        move.l  #$ff010010,(a1)+    ; pcd_track_delay_offset_b, pcd_inst_speed_stop_b, pcd_inst_pitch_w
        move.l  #(MAX_VOLUME<<16)|(MAX_VOLUME<<8)|MAX_VOLUME,(a1)+  ; pcd_inst_vol_w / pcd_loaded_inst_vol_b / pcd_pat_vol_b

        bra.s   .continue_with_inst

; ----------------------------------------
.handle_current_instrument

; ----------------------------------------
; handle portamento
        move.w  pcd_pat_portamento_dest_w(a5),d3
        beq.s   .no_portamento_active
        move.w  pcd_inst_curr_port_pitch_w(a5),d2
        moveq.l #0,d1
        move.b  pcd_pat_portamento_speed_b(a5),d1
        cmp.w   d3,d2
        bge.s   .do_portamento_down
        add.w   d1,d2
        cmp.w   d3,d2
        bgt.s   .portamento_note_reached
        bra.s   .update_portamento_value

.do_portamento_down
        sub.w   d1,d2
        cmp.w   d3,d2
        bge.s   .update_portamento_value

.portamento_note_reached
        clr.w   pcd_pat_portamento_dest_w(a5)
        move.w  d3,d2
.update_portamento_value
        move.w  d2,pcd_inst_curr_port_pitch_w(a5)
.no_portamento_active

; ----------------------------------------
; handle volume ramping
        move.b  pcd_pat_vol_ramp_speed_b(a5),d1
        beq.s   .no_vol_ramping_active
        add.b   pcd_pat_vol_b(a5),d1
        bpl.s   .noclip_pat_vol_min
        moveq.l #0,d1
.noclip_pat_vol_min
        cmpi.b  #MAX_VOLUME,d1
        ble.s   .noclip_pat_vol_max
        moveq.l #MAX_VOLUME,d1
.noclip_pat_vol_max
        move.b  d1,pcd_pat_vol_b(a5)
.no_vol_ramping_active

; ----------------------------------------
; enters with channel number in d0

.continue_with_inst
        ; handle delayed note and note off first
        moveq.l #0,d4
        move.b  pcd_note_delay_b(a5),d4
        blt     .pat_play_cont
        beq.s   .no_note_delay
        subq.b  #1,d4
        beq.s   .note_delay_end_reached

        move.b  d4,pcd_note_delay_b(a5)     ; note still delayed
        IFNE    PRETRACKER_BUGFIX_CODE
        bra     .pat_play_cont              ; I believe that with activated track delay, we must jump here
        ELSE
        bra     .pat_channels_loop_test
        ENDC

.note_delay_end_reached
        st       pcd_note_delay_b(a5)       ; release note delay
.no_note_delay
        moveq.l #0,d5
        move.b  pcd_channel_num_b(a5),d5
        move.w  sv_curr_pat_pos_w(a6),d2
        add.w   d2,d2
        add.w   d2,d2          ; *4
        add.w   d5,d2
        add.w   d2,d2          ; 8*pos+2*chan
        movea.l sv_pos_data_adr(a6),a1
        adda.w  d2,a1
        ;move.l  a1,d2
        ;cmpa.w  #0,a1
        ;beq     .pat_play_other ; this is probably never happening!
        moveq.l #0,d2
        move.b  pv_pat_curr_row_b(a4),d2
        cmp.b   sv_num_steps_b(a6),d2
        bcc     .pat_play_cont

        move.b  ppd_pat_num(a1),d5
        beq     .pat_play_cont
        add.w   d5,d5
        add.w   d5,d5
        add.w   #sv_pattern_table,d5
        move.l  -4(a6,d5.w),a0
        IFNE    PRETRACKER_PARANOIA_MODE
        move.l  a0,d5   ; move to data register due to cc's
        beq     .pat_play_cont
        ENDC

        move.b  ppd_pat_shift(a1),d0        ; pattern pitch shift (signed)
        ext.w   d0

        add.w   d2,a0
        add.w   d2,d2
        add.w   d2,a0                       ; pattern data

        moveq.l #15,d2
        move.b  pdb_inst_effect(a0),d4      ; instrument and command byte
        and.w   d4,d2
        lsr.w   #4,d4                       ; instrument nr bits 0-4

        moveq.l #0,d5
        move.b  pdb_effect_data(a0),d5

        cmpi.b  #$e,d2
        bne.s   .pat_exy_cmd_cont
        ; handle $exy commands
        tst.b   pcd_note_delay_b(a5)
        bne.s   .pat_exy_cmd_cont           ; ignore if already running note delay
        move.l  d5,d3
        moveq.l #15,d1
        and.w   d3,d1
        lsr.w   #4,d3
        sub.w   #$d,d3
        bne.s   .pat_is_not_ed_cmd
        ; note delay in x sub steps
        IFNE    PRETRACKER_PARANOIA_MODE    ; who does this kind of stuff?
        tst.b   pv_pat_speed_even_b(a4)
        beq.s   .pat_exy_cmd_cont
        ENDC
        move.b  d1,pcd_note_delay_b(a5)
        IFNE    PRETRACKER_BUGFIX_CODE
        bra     .pat_play_cont             ; I believe that with activated track delay, we must jump here
        ELSE
        bra     .pat_channels_loop_test
        ENDC

.pat_is_not_ed_cmd
        addq.b  #$d-$a,d3
        bne.s   .pat_exy_cmd_cont
        ; note off in x sub steps
        move.b  d1,pcd_note_off_delay_b(a5)

.pat_exy_cmd_cont
        st      pcd_note_delay_b(a5)

; ----------------------------------------
; read out pattern editor data

        moveq.l #0,d6                   ; clear arp flag
        move.b  pdb_pitch_ctrl(a0),d3   ; pitch and control byte
        bpl.s   .noselinst16plus
        add.w   #16,d4                  ; add high bit of instrument number
.noselinst16plus
        moveq.l #$3f,d7
        and.w   d3,d7                   ; pitch
        add.w   d4,d4
        add.w   d4,d4
        beq.s   .no_new_note            ; if no instrument
        tst.w   d7
        bne.s   .no_new_note            ; if it has pitch

        ; only change of instrument, not pitch
        move.b  pcd_loaded_inst_vol_b(a5),pcd_pat_vol_b(a5)

        cmp.w   pcd_inst_num4_w(a5),d4
        bne.s   .no_new_note
        ; attack!
        move.l   d6,pcd_adsr_phase_w(a5)   ; and pcd_adsr_volume_w
        ;clr.w   pcd_adsr_volume_w(a5)
        ;move.b  #1,pcd_adsr_trigger_b(a5) ; never read

.no_new_note

; d2 = effect cmd, d3 = pitch_ctrl, d4 = inst number, d5 = effect data, d7 = pitch

        andi.b  #$40,d3     ; ARP bit
        bne.s   .has_arp_note
.no_arp_note
        tst.b   d2
        bne.s   .arp_processing_done
        ; 0xx: play second instrument
        tst.b   d5
        beq.s   .no_effect
        moveq.l #15,d1      ; FIXME seems like it only supports the lower 15 instruments
        and.b   d5,d1
        add.w   d1,d1
        add.w   d1,d1

        tst.b   d7
        bne.s   .play_2nd_inst_without_trigger

.play_2nd_inst_with_no_pitch
        addq.w  #1,d0       ; pattern pitch shift
        lsl.w   #4,d0

        tst.b   d1
        beq.s   .clear_note_arp

        moveq.l #0,d2
        move.w  d4,d3
        move.w  d1,d4
        bra.s   .trigger_new_instrument

.play_2nd_inst_without_trigger
        move.w  d4,d3       ; 1st instrument num
        move.w  d1,d4       ; 2nd instrument num
        bra.s   .arp_processing_done

.clear_note_arp
        clr.l   pcd_arp_notes_l(a5)
        move.b  d7,d2
        move.b  d4,d3
        bra     .clear_portamento

.has_arp_note
        move.b  d2,d3
        or.b    d5,d3
        beq.s   .all_arp_notes_zero     ; if we go there, d3 MUST be 0 already

        move.b  d2,pcd_arp_note_1_b(a5)

        move.b  d5,d2
        lsr.b   #4,d2
        move.b  d2,pcd_arp_note_2_b(a5)

        moveq.l #15,d2
        and.b   d5,d2
        move.b  d2,pcd_arp_note_3_b(a5)

.all_arp_notes_zero
        moveq.l #1,d6
.no_effect
        moveq.l #0,d2   ; make sure we don't get a random command here
        moveq.l #0,d3

; ----------------------------------------
; d2 = effect cmd, d3 = alt inst number (or 0), d4 = inst number, d5 = effect cmd, d6 = ARP flag, d7 = pitch

.arp_processing_done
        cmpi.b  #NOTE_OFF_PITCH,d7
        bne.s   .has_no_note_off

.release_note
        ; release note
        ; FIXME we have the identical code (different regs) three times (one is inactive)
        move.w  pcd_adsr_volume_w(a5),d4
        asr.w   #6,d4
        move.w  d4,pcd_adsr_vol64_w(a5)
        moveq.l #16,d7
        move.w  d7,pcd_adsr_pos_w(a5)
        sub.w   d4,d7
        lsr.w   #1,d7
        add.b   pcd_adsr_release_b(a5),d7
        move.b  d7,pcd_adsr_phase_speed_b(a5)
        move.w  #3,pcd_adsr_phase_w(a5)
        bra     .start_patt_effect_handling

.has_inst_number
        add.w   d7,d0       ; pattern pitch shift?
        lsl.w   #4,d0

        cmpi.b  #3,d2       ; is command portamento?
        beq.s   .pat_set_portamento

.trigger_new_instrument
        move.w  d4,d1

        move.b  d1,pcd_new_inst_num_b(a5)
        move.w  d1,pcd_inst_num4_w(a5)
        add.w   d1,d1
        add.w   d1,d1
        lea     sv_inst_infos_table-uii_SIZEOF(a6),a1
        add.w   d1,a1
        move.l  a1,pcd_inst_info_ptr(a5)
        move.b  uii_pattern_steps(a1),pcd_inst_pattern_steps_b(a5)

        moveq.l #0,d1
        move.l  a5,a1
        move.l  d1,(a1)+    ; pcd_pat_portamento_dest_w and pcd_pat_pitch_slide_w
        move.l  d1,(a1)+    ; pcd_pat_vol_ramp_speed_b, pcd_pat_2nd_inst_num4_b, pcd_pat_2nd_inst_delay_b, pcd_wave_offset_b
        move.l  d1,(a1)+    ; pcd_inst_pitch_slide_w and pcd_inst_sel_arp_note_w
        move.l  d1,(a1)+    ; pcd_inst_note_pitch_w and pcd_inst_curr_port_pitch_w

        move.l  d1,(a1)+    ; pcd_inst_line_ticks_b, pcd_inst_pitch_pinned_b, pcd_inst_vol_slide_b, pcd_inst_step_pos_b

        subq.b  #1,d1
        move.w  d1,(a1)+    ; pcd_inst_wave_num_w

        move.l  #$ff010010,(a1)+    ; pcd_track_delay_offset_b, pcd_inst_speed_stop_b, pcd_inst_pitch_w
        move.l  #(MAX_VOLUME<<16)|(MAX_VOLUME<<8)|MAX_VOLUME,(a1)+  ; pcd_inst_vol_w / pcd_loaded_inst_vol_b / pcd_pat_vol_b

        bra.s   .cont_after_inst_trigger

.has_no_note_off
        tst.b   d7
        beq.s   .start_patt_effect_handling
        tst.b   d4
        bne.s   .has_inst_number

        add.w   d7,d0               ; pattern pitch shift
        lsl.w   #4,d0

.cont_after_inst_trigger
        tst.b   d6                  ; has ARP?
        bne.s   .lbC001852
        bra.s   .lbC00193C

.pat_set_portamento
        tst.b   d6
        bne.s   .pat_new_portamento
.lbC00193C
        clr.l   pcd_arp_notes_l(a5)
        moveq.l #0,d6

.lbC001852
        cmpi.b  #3,d2               ; is command portamento?
        beq.s   .pat_new_portamento

.clear_portamento
        move.w  #$10,pcd_inst_pitch_w(a5)
        move.w  d0,pcd_inst_curr_port_pitch_w(a5)
        clr.w   pcd_pat_portamento_dest_w(a5)
        bra.s   .start_patt_effect_handling

.pat_new_portamento
        add.w   #$10,d0             ; pattern pitch shift
        move.w  d0,pcd_pat_portamento_dest_w(a5)

        move.w  pcd_inst_pitch_w(a5),d1
        add.w   d1,pcd_inst_curr_port_pitch_w(a5)
        clr.w   pcd_inst_pitch_w(a5)
        tst.b   d5
        beq.s   .pat_keep_old_portamento
        move.b  d5,pcd_pat_portamento_speed_b(a5)
.pat_keep_old_portamento

; ----------------------------------------
.start_patt_effect_handling
        ; FIXME can we move this code to avoid blocking the two registers d3/d5
        tst.b   d3
        beq.s   .has_no_second_inst
        move.b  d3,pcd_pat_2nd_inst_num4_b(a5)
        move.b  d5,d3
        lsr.b   #4,d3
        move.b  d3,pcd_pat_2nd_inst_delay_b(a5)

.has_no_second_inst
        clr.b   pcd_pat_vol_ramp_speed_b(a5)
        clr.w   pcd_pat_pitch_slide_w(a5)
        tst.b   d6
        bne     .pat_play_cont
        add.w   d2,d2
        move.w  .pattern_command_jmptable(pc,d2.w),d2
        jmp     .pattern_command_jmptable(pc,d2.w)

.pattern_command_jmptable
        dc.w    .pat_play_nop-.pattern_command_jmptable
        dc.w    .pat_slide_up-.pattern_command_jmptable
        dc.w    .pat_slide_down-.pattern_command_jmptable
        dc.w    .pat_play_nop-.pattern_command_jmptable
        dc.w    .pat_set_vibrato-.pattern_command_jmptable
        dc.w    .pat_set_track_delay-.pattern_command_jmptable
        dc.w    .pat_play_nop-.pattern_command_jmptable
        dc.w    .pat_play_nop-.pattern_command_jmptable
        dc.w    .pat_play_nop-.pattern_command_jmptable
        dc.w    .pat_set_wave_offset-.pattern_command_jmptable
        dc.w    .pat_volume_ramp-.pattern_command_jmptable
        dc.w    .pat_pos_jump-.pattern_command_jmptable
        dc.w    .pat_set_volume-.pattern_command_jmptable
        dc.w    .pat_pat_break-.pattern_command_jmptable
        dc.w    .pat_play_nop-.pattern_command_jmptable
        dc.w    .pat_set_speed-.pattern_command_jmptable

; d5 = command parameter data
; ----------------------------------------
.pat_set_speed
        lea     pv_pat_speed_even_b(a4),a1
        cmpi.b  #MAX_SPEED,d5
        bhs.s   .pat_set_speed_shuffle
        move.b  d5,(a1)+            ; pv_pat_speed_even_b
        move.b  d5,(a1)+            ; pv_pat_speed_odd_b
        move.b  d5,(a1)+            ; pv_pat_line_ticks_b
        sne     (a1)+               ; pv_pat_stopped_b
        IFNE    PRETRACKER_SONG_END_DETECTION
        seq     (a1)+               ; pv_songend_detected_b
        ENDC
        bra     .pat_play_cont
.pat_set_speed_shuffle
        moveq.l #15,d2
        and.w   d5,d2               ; odd speed
        lsr.w   #4,d5               ; even speed
        move.b  d5,(a1)+            ; pv_pat_speed_even_b
        move.b  d2,(a1)+            ; pv_pat_speed_odd_b
        btst    #0,pv_pat_curr_row_b(a4)
        beq.s   .pat_shuffle_on_even
        move.b  d2,d5               ; toggle speed to odd row
.pat_shuffle_on_even
        move.b  d5,(a1)+            ; pv_pat_line_ticks_b
        bra     .pat_play_cont

; ----------------------------------------
.pat_set_vibrato
        clr.w   pcd_vibrato_pos_w(a5)
        move.w  #1,pcd_vibrato_delay_w(a5)
        moveq.l #15,d2
        and.w   d5,d2

        lea     pre_vib_depth_table(pc),a1
        move.b  (a1,d2.w),pcd_vibrato_depth_w+1(a5)
        lsr.b   #4,d5
        move.b  pre_vib_speed_table-pre_vib_depth_table(a1,d5.w),d2
        muls    pcd_vibrato_depth_w(a5),d2
        asr.w   #4,d2
        move.w  d2,pcd_vibrato_speed_w(a5)
        bra.s   .pat_play_cont

; ----------------------------------------
.pat_set_track_delay
        cmp.b   #NUM_CHANNELS-1,pcd_channel_num_b(a5)
        beq.s   .pat_play_cont  ; we are at channel 3 -- track delay not available here

        lea     pcd_SIZEOF+pcd_track_delay_buffer+ocd_volume(a5),a1
        moveq.l #MAX_TRACK_DELAY-1,d2
.clr_track_delay_buffer_loop
        clr.b   (a1)            ; ocd_volume
        lea     ocd_SIZEOF(a1),a1
        dbra    d2,.clr_track_delay_buffer_loop

        tst.b   d5
        bne.s   .pat_track_delay_set
        st      pcd_track_delay_steps_b(a5)
        bra.s   .handle_track_delay

; ----------------------------------------
.pat_volume_ramp
        tst.b   d5
        beq.s   .pat_play_cont
        moveq.l #15,d3
        and.b   d5,d3
        beq.s   .pat_vol_ramp_up
        ; NOTE: Changed behaviour: using d3 instead of d5
        ; if both lower and upper were specified, this
        ; probably led to a drastic decrease of volume.
        neg.b   d3
        move.b  d3,pcd_pat_vol_ramp_speed_b(a5)
        bra.s   .pat_play_cont
.pat_vol_ramp_up
        lsr.b   #4,d5
        move.b  d5,pcd_pat_vol_ramp_speed_b(a5)
        bra.s   .pat_play_cont

.pat_track_delay_set
        moveq.l #15,d2
        and.b   d5,d2
        add.b   d2,d2
        move.b  d2,pcd_track_delay_steps_b(a5)
;        subq.b  #1,d2
;        move.b  d2,pcd_SIZEOF+pcd_track_init_delay_b(a5)
        lsr.b   #4,d5
        move.b  d5,pcd_track_delay_vol16_b(a5)
        bra.s   .pat_play_cont

; ----------------------------------------
.pat_slide_down
        neg.w   d5
.pat_slide_up
        move.w  d5,pcd_pat_pitch_slide_w(a5)
        bra.s   .pat_play_cont

; ----------------------------------------
.pat_set_wave_offset
        move.b  d5,pcd_wave_offset_b(a5)
        bra.s   .pat_play_cont

; ----------------------------------------
.pat_pos_jump
        move.b  d5,pv_next_pat_pos_b(a4)
        bra.s   .pat_play_cont

; ----------------------------------------
.pat_pat_break
        move.b  d5,pv_next_pat_row_b(a4)
        bra.s   .pat_play_cont

; ----------------------------------------
.pat_set_volume
        cmpi.b  #MAX_VOLUME,d5
        bls.s   .pat_set_volume_nomax
        moveq.l #MAX_VOLUME,d5
.pat_set_volume_nomax
        move.b  d5,pcd_pat_vol_b(a5)

; ----------------------------------------

.pat_play_nop
.pat_play_cont
        move.b  pcd_track_delay_steps_b(a5),d2      ; FIXME this is a mess
        beq.s   .pat_channels_loop_test

.handle_track_delay
        lea     pcd_SIZEOF(a5),a5
        cmp.b   #NUM_CHANNELS-2,pcd_channel_num_b-pcd_SIZEOF(a5) ; FIXME find out why we need this
        bge.s   .pat_channels_loop_end

.pat_channels_loop_test
        lea     pcd_SIZEOF(a5),a5
        cmp.b   #NUM_CHANNELS-1,pcd_channel_num_b-pcd_SIZEOF(a5)
        bne     .pre_pat_chan_loop
.pat_channels_loop_end

; end of pattern loop

; ----------------------------------------
; Pattern advancing and pattern break and jump handling. Song looping and song-end detection.
.pattern_advancing
        subq.b  #1,pv_pat_line_ticks_b(a4)
        bne     .no_pattern_advance

        ; clear note delay info
        moveq.l #0,d0
        REPT    NUM_CHANNELS
        move.b  d0,pv_channeldata+pcd_note_delay_b+REPTN*pcd_SIZEOF(a4)
        ENDR

        move.b  sv_num_steps_b(a6),d1       ; number of steps in pattern

        move.b  pv_pat_curr_row_b(a4),d0
        addq.b  #1,d0                       ; normal step increment

        move.w  sv_curr_pat_pos_w(a6),d3    ; current song position

        move.b  pv_next_pat_row_b(a4),d2    ; $ff means no pattern break
        bmi.s   .no_pattern_break
        st      pv_next_pat_row_b(a4)       ; processed break, set to $ff
        move.b  d2,d0
        IFNE    0 ; PRETRACKER_BUGFIX_CODE  ; currently disabled to keep old behaviour
        moveq.l #0,d2                       ; clear mask
        ENDC
        cmp.b   d1,d0
        blo.s   .has_legal_break_pos
        move.b  d1,d0                       ; limit to last step
        subq.b  #1,d0
        bra.s   .has_legal_break_pos

.no_pattern_break
        cmp.b   d1,d0
        blo.s   .pattern_end_not_reached
        moveq.l #0,d0
        IFNE    PRETRACKER_PARANOIA_MODE
        move.b  pv_loop_pattern_b(a4),d0    ; keep same pattern rolling?
        bne.s   .pattern_end_not_reached
        ENDC
.has_legal_break_pos
        addq.w  #1,d3                       ; pattern break will increment song pos -- if there is no new pattern position

.pattern_end_not_reached
        move.b  pv_next_pat_pos_b(a4),d4
        bmi.s   .no_new_position            ; has a new pattern position
        st      pv_next_pat_pos_b(a4)
        IFNE    PRETRACKER_SONG_END_DETECTION
        cmp.b   d4,d3
        bgt.s   .no_backjump
        st      pv_songend_detected_b(a4)   ; detect jumping back
.no_backjump
        ENDC
        move.b  d4,d3                       ; load new position
        IFNE    0 ; PRETRACKER_BUGFIX_CODE  ; currently disabled to keep old behaviour
        not.b   d2
        and.b   d2,d0                       ; if we had NO pattern break, we will clear d0
        ELSE
        moveq.l #0,d0
        ENDC
.no_new_position

        cmp.w   sv_pat_pos_len_w(a6),d3
        blt.s   .no_restart_song
        move.w  sv_pat_restart_pos_w(a6),d3
        IFNE    PRETRACKER_SONG_END_DETECTION
        st      pv_songend_detected_b(a4)
        ENDC
.no_restart_song
        move.b  d0,pv_pat_curr_row_b(a4)
        move.w  d3,sv_curr_pat_pos_w(a6)

        move.b  pv_pat_speed_even_b(a4),d1
        lsr.b   #1,d0
        bcc.s   .set_speed_even
        move.b  pv_pat_speed_odd_b(a4),d1
.set_speed_even
        move.b  d1,pv_pat_line_ticks_b(a4)
.no_pattern_advance

; ----------------------------------------
; processes the instrument pattern for each running instrument
; registers used:
; d0: pitch
; d1: volume
; d2: inst num
; d3: scratch
; a0: pattern data pointer
; a1: scratch
; a2: instrument info
; a3: wave info
; a4: pv
; a5: channel struct
; a6: mysong struct

.inst_pattern_processing
        lea     pv_channeldata(a4),a5

.inst_chan_loop
        move.l  pcd_waveinfo_ptr(a5),a3

        move.l  pcd_inst_info_ptr(a5),a2
        move.l  a2,d3
        beq     .inst_no_inst_active

        ; calculate pitch -- funny that there is no min check (seems to happen later though)
        move.w  pcd_inst_pitch_slide_w(a5),d0
        add.w   pcd_pat_pitch_slide_w(a5),d0
        beq.s   .inst_no_pitch_slides_active
        add.w   pcd_inst_pitch_w(a5),d0
        cmp.w   #(3*NOTES_IN_OCTAVE)<<4,d0
        ble.s   .inst_noclip_pitch_max
        move.w  #(3*NOTES_IN_OCTAVE)<<4,d0
.inst_noclip_pitch_max
        move.w  d0,pcd_inst_pitch_w(a5)
.inst_no_pitch_slides_active

        move.b  pcd_inst_vol_slide_b(a5),d1
        beq.s   .inst_no_vol_slide_active
        add.b   pcd_inst_vol_w+1(a5),d1
        bpl.s   .inst_noclip_vol_zero
        moveq.l #0,d1
.inst_noclip_vol_zero
        cmp.b   #MAX_VOLUME,d1
        ble.s   .inst_noclip_vol_max
        moveq.l #MAX_VOLUME,d1
.inst_noclip_vol_max
        move.b  d1,pcd_inst_vol_w+1(a5)

.inst_no_vol_slide_active
        move.b  pcd_inst_line_ticks_b(a5),d2
        bne     .inst_still_ticking

        moveq.l #0,d0
        move.w  d0,pcd_inst_pitch_slide_w(a5)
        move.b  d0,pcd_inst_vol_slide_b(a5)

;        IFNE    PRETRACKER_PARANOIA_MODE ; new step is never written
;        move.w  pcd_inst_new_step_w(a5),d1
;        blt.s   .inst_no_new_step_pos
;        cmpi.w  #$20,d1
;        ble.s   .inst_good_new_step_pos
;        moveq.l #$20,d1
;.inst_good_new_step_pos
;        move.b  d1,pcd_inst_step_pos_b(a5)
;        move.w  #$ffff,pcd_inst_new_step_w(a5)
;.inst_no_new_step_pos
;        ENDC
        move.b  pcd_inst_step_pos_b(a5),d0
        cmp.b   pcd_inst_pattern_steps_b(a5),d0
        bhs     .inst_pat_loop_exit

        moveq.l #-1,d4
        moveq.l #0,d7
        moveq.l #0,d3       ; flag for stitching -- if set, must not trigger new note
        ; enters with d4 = -1, meaning no first note pos yet

        move.w  pcd_inst_num4_w(a5),d1
        movea.l sv_inst_patterns_table-4(a6,d1.w),a0

        add.w   d0,a0
        add.w   d0,a0
        add.w   d0,a0

.inst_pat_loop
        IFNE    PRETRACKER_PARANOIA_MODE
        moveq.l #0,d2               ; default to not stitched
        move.b  (a0)+,d1            ; pdb_pitch_ctrl get pitch byte
        move.b  d1,d6
        bpl.s   .inst_note_is_not_stitched  ; means that note is stitched

        tst.w   d4
        bpl.s   .inst_no_update_first_note
        move.w  d0,d4               ; position of first note before stitching
.inst_no_update_first_note
        moveq.l #1,d2               ; next note will be fetched immediately
.inst_note_is_not_stitched
        ELSE
        move.b  (a0)+,d1            ; pdb_pitch_ctrl get pitch byte
        move.b  d1,d6
        smi     d2                  ; note stitched?
        ;neg.b   d2
        ENDC

        tst.b   d3
        bne.s   .skippitchloading
        andi.w  #$3F,d1
        beq.s   .skippitchloading   ; no new note
        subq.w  #1,d1
        lsl.w   #4,d1
        move.w  d1,pcd_inst_note_pitch_w(a5)
        and.w   #1<<6,d6
        sne     pcd_inst_pitch_pinned_b(a5)
        IFEQ    PRETRACKER_FASTER_CODE
        neg.b   pcd_inst_pitch_pinned_b(a5) ; only to be state binary compatible
        ENDC
.skippitchloading
        moveq.l #15,d6
        and.b   (a0)+,d6        ; pdb_effect_cmd command number
        add.w   d6,d6
        moveq.l #0,d5
        move.b  (a0)+,d5        ; pdb_effect_data command parameter byte
        move.w  .inst_command_jmptable(pc,d6.w),d3
        jmp     .inst_command_jmptable(pc,d3.w)

.inst_command_jmptable
        dc.w    .inst_select_wave-.inst_command_jmptable
        dc.w    .inst_slide_up-.inst_command_jmptable
        dc.w    .inst_slide_down-.inst_command_jmptable
        dc.w    .inst_adsr-.inst_command_jmptable
        dc.w    .inst_select_wave-.inst_command_jmptable
        dc.w    .inst_nop-.inst_command_jmptable
        dc.w    .inst_nop-.inst_command_jmptable
        dc.w    .inst_nop-.inst_command_jmptable
        dc.w    .inst_nop-.inst_command_jmptable
        dc.w    .inst_nop-.inst_command_jmptable
        dc.w    .inst_vol_slide-.inst_command_jmptable
        dc.w    .inst_jump_to_step-.inst_command_jmptable
        dc.w    .inst_set_volume-.inst_command_jmptable
        dc.w    .inst_nop-.inst_command_jmptable
        dc.w    .inst_use_pat_arp-.inst_command_jmptable
        dc.w    .inst_set_speed-.inst_command_jmptable

; d0 = current step / next step
; d5 = command parameter data / scratch
; d2 = note stitched flag
; d6 = scratch
; ----------------------------------------
.inst_select_wave
        subq.w  #1,d5
        cmp.w   #MAX_WAVES,d5
        bhs     .inst_cmd_cont_next
        add.w   d5,d5
        add.w   d5,d5
        cmp.w   pcd_inst_wave_num_w(a5),d5
        beq     .inst_cmd_cont_next
        move.w  d5,pcd_inst_wave_num_w(a5)
        move.l  sv_waveinfo_table(a6,d5.w),a3
        move.l  a3,pcd_waveinfo_ptr(a5)

        move.b  pcd_channel_mask_b(a5),d3
        move.b  d3,pcd_out_trg_b(a5)
        or.b    d3,pv_trigger_mask_w+1(a4)

        move.l  pv_wave_sample_table(a4,d5.w),a1
        tst.w   d6
        bne.s   .inst_select_wave_nosync

        moveq.l #0,d3
        move.w  wi_loop_offset_w(a3),d6     ; is unlikely 32768
        move.w  wi_subloop_len_w(a3),d5
        bne.s   .inst_set_wave_has_subloop

        adda.w  d6,a1                       ; add loop offset

        move.w  wi_chipram_w(a3),d5
        sub.w   d6,d5
        ;cmp.w   #1,d5 ; not necessary as increases in steps of 2
        bhi.s   .inst_set_wave_has_min_length
        moveq.l #2,d5
.inst_set_wave_has_min_length
        move.w  d5,pcd_out_len_w(a5)

        moveq.l #-1,d3
.inst_set_wave_has_subloop
        move.w  d3,pcd_out_lof_w(a5)
        move.l  a1,pcd_out_ptr_l(a5)

        st      pcd_inst_ping_pong_dir_b(a5)
        moveq.l #0,d5
        move.b  wi_subloop_wait_b(a3),d5
        addq.w  #1,d5
        move.w  d5,pcd_inst_subloop_wait_w(a5)

        move.w  d6,pcd_inst_loop_offset_w(a5)
        bra     .inst_cmd_cont_next

; ----------------------------------------
.inst_select_wave_nosync
        move.w  wi_chipram_w(a3),d5
        moveq.l #0,d3
        tst.w   wi_subloop_len_w(a3)
        bne.s   .inst_set_wave_ns_has_subloop

        move.w  wi_loop_offset_w(a3),d6
        adda.w  d6,a1

        sub.w   d6,d5
        ;cmp.w   #1,d5 ; not necessary as increases in steps of 2
        bhi.s   .inst_set_wave_ns_has_min_length
        moveq.l #2,d5
.inst_set_wave_ns_has_min_length
        move.w  d5,pcd_out_len_w(a5)

        moveq.l #-1,d3
.inst_set_wave_ns_has_subloop
        move.w  d3,pcd_out_lof_w(a5)
        move.l  a1,pcd_out_ptr_l(a5)

        move.w  pcd_inst_loop_offset_w(a5),d6
        cmp.w   d6,d5
        bhs.s   .inst_set_wave_ns_keep_pp
        st      pcd_inst_ping_pong_dir_b(a5)
.inst_set_wave_ns_keep_pp
        moveq.l #0,d5
        move.w  d5,pcd_inst_subloop_wait_w(a5)

        sub.w   wi_subloop_step_w(a3),d6
        move.w  d6,pcd_inst_loop_offset_w(a5)
        bra     .inst_cmd_cont_next

; ----------------------------------------
.inst_slide_down
        neg.w   d5
.inst_slide_up
        move.w  d5,pcd_inst_pitch_slide_w(a5)
        bra     .inst_cmd_cont_next

; ----------------------------------------
.inst_adsr
        subq.w  #1,d5
        beq.s   .inst_adsr_release
        subq.w  #1,d5
        bne     .inst_cmd_cont_next
        ; d5.l is zero
        move.w  d5,pcd_adsr_phase_w(a5)
        move.w  d5,pcd_adsr_volume_w(a5)
        bra     .inst_cmd_cont_next

.inst_adsr_release
        move.w  pcd_adsr_volume_w(a5),d5
        asr.w   #6,d5
        move.w  d5,pcd_adsr_vol64_w(a5)
        moveq.l #16,d6
        move.w  d6,pcd_adsr_pos_w(a5)
        sub.w   d5,d6
        lsr.w   #1,d6
        add.b   pcd_adsr_release_b(a5),d6
        move.b  d6,pcd_adsr_phase_speed_b(a5)
        move.w  #3,pcd_adsr_phase_w(a5)
        bra.s   .inst_cmd_cont_next

; ----------------------------------------
.inst_vol_slide
        moveq.l #15,d3
        and.w   d5,d3
        beq.s   .inst_vol_slide_up
        ; NOTE: Changed behaviour: using d3 instead of d5
        ; if both lower and upper were specified, this
        ; probably led to a drastic decrease of volume.
        neg.w   d3
        move.b  d3,pcd_inst_vol_slide_b(a5)
        bra.s   .inst_cmd_cont_next

.inst_vol_slide_up
        lsr.b   #4,d5
        move.b  d5,pcd_inst_vol_slide_b(a5)
        bra.s   .inst_cmd_cont_next

; ----------------------------------------
.inst_jump_to_step
        cmp.w   d0,d5
        bge.s   .inst_cmd_cont_next         ; only backward jumps allowed (?)
        IFNE    PRETRACKER_PARANOIA_MODE
        ; this stuff is PARANOIA
        tst.b   d4
        bmi.s   .inst_jump_to_step_doit     ; we did not have a stitched note before
        cmp.b   d3,d4
        ble     .inst_cmd_cont_next         ; we are jumping back to the stitched note, ignore
.inst_jump_to_step_doit
        ENDC
        move.w  d5,d0
        tst.b   d7                          ; check if we had jumped before
        bne.s   .inst_we_were_stitched
        IFNE    PRETRACKER_PARANOIA_MODE
        moveq.l #-1,d4                      ; mark as no first stitch pos
        ENDC

        move.w  pcd_inst_num4_w(a5),d1
        movea.l sv_inst_patterns_table-4(a6,d1.w),a0

        add.w   d5,a0
        add.w   d5,d5
        add.w   d5,a0

        bra.s   .inst_fetch_next
.inst_we_were_stitched
        move.b  pcd_inst_speed_stop_b(a5),d2
        bra.s   .inst_cont_from_nasty_double_jump

; ----------------------------------------
.inst_set_volume
        cmp.w   #MAX_VOLUME,d5
        ble.s   .inst_set_volume_nomax
        moveq.l #MAX_VOLUME,d5
.inst_set_volume_nomax
        move.w  d5,pcd_inst_vol_w(a5)
        bra.s   .inst_cmd_cont_next

; ----------------------------------------
.inst_use_pat_arp
        moveq.l #3,d3
        and.w   d5,d3
        beq.s   .inst_use_pat_arp_play_base
        lsr.w   #4,d5
        beq.s   .inst_use_pat_arp_skip_empty
        subq.w  #1,d5
        bne.s   .inst_cmd_cont_next     ; illegal high nibble (only 0/1 allowed)

        ; pick arp note
        move.b  pcd_arp_notes_l-1(a5,d3.w),d3

        ; play base note
.inst_use_pat_arp_set
        lsl.w   #4,d3
.inst_use_pat_arp_play_base
        move.w  d3,pcd_inst_sel_arp_note_w(a5)
        bra.s   .inst_cmd_cont_next

.inst_use_pat_arp_skip_empty
        ; pick arp note, if it's 0, skip it
        move.b  pcd_arp_notes_l-1(a5,d3.w),d3
        bne.s   .inst_use_pat_arp_set

        addq.w  #1,d0
        bra.s   .inst_fetch_next

; ----------------------------------------
.inst_set_speed
        tst.w   d5
        bne.s   .inst_set_speed_nostop
        st      d5
.inst_set_speed_nostop
        move.b  d5,pcd_inst_speed_stop_b(a5)

; ----------------------------------------
.inst_nop
.inst_cmd_cont_next
        addq.w  #1,d0
        tst.b   d2
        beq.s   .inst_pat_loop_exit2
        ; d2 != 0 in this case, hence d3 will be set
.inst_fetch_next
        moveq.l #1,d7                       ; mark that we are in at least next iteration
        move.b  d2,d3                       ; mark stitching
        cmp.b   pcd_inst_pattern_steps_b(a5),d0
        blo     .inst_pat_loop

.inst_pat_loop_exit
        st      d2
.inst_pat_loop_exit2
        add.b   pcd_inst_speed_stop_b(a5),d2
.inst_cont_from_nasty_double_jump
        move.b  d2,pcd_inst_line_ticks_b(a5)
        move.b  d0,pcd_inst_step_pos_b(a5)  ; update inst step pos

.inst_still_ticking
        tst.b   pcd_inst_wave_num_w+1(a5)
        bpl.s   .inst_wave_selected

.inst_no_wave_selected
        moveq.l #0,d3
        move.w  d3,pcd_inst_wave_num_w(a5)  ; FIXME why set to wave 0? just asking, because this is zero based
        move.l  sv_waveinfo_ptr(a6),a3
        move.l  a3,pcd_waveinfo_ptr(a5)

        move.b  pcd_channel_mask_b(a5),d0
        move.b  d0,pcd_out_trg_b(a5)
        or.b    d0,pv_trigger_mask_w+1(a4)

        tst.w   wi_subloop_len_w(a3)
        bne.s   .inst_nowave_has_subloop

        move.w  wi_loop_offset_w(a3),d5
        move.l  pv_wave_sample_table(a4),a1
        adda.w  d5,a1
        move.l  a1,pcd_out_ptr_l(a5)

        move.w  wi_chipram_w(a3),d0
        move.w  d0,d6
        subq.w  #1,d6
        cmp.w   d4,d6
        ble.s   .lbC00118E
        sub.w   d5,d0
        bra.s   .lbC000F48
.lbC00118E
        moveq.l #2,d0
.lbC000F48
        move.w  d0,pcd_out_len_w(a5)
        subq.w  #1,d3
        bra.s   .inst_set_no_lof

.inst_nowave_has_subloop
        move.l  pv_wave_sample_table(a4),pcd_out_ptr_l(a5)

        move.w  wi_loop_offset_w(a3),d4
.inst_set_no_lof
        move.w  d3,pcd_out_lof_w(a5)
        moveq.l #0,d0
        move.b  wi_subloop_wait_b(a3),d0
        addq.w  #1,d0
        move.w  d0,pcd_inst_subloop_wait_w(a5)

        move.w  d4,pcd_inst_loop_offset_w(a5)
        st      pcd_inst_ping_pong_dir_b(a5)

.inst_wave_selected
        cmpi.b  #$FF,d2
        beq.s   .inst_pat_loop_exit3
        subq.b  #1,d2
        move.b  d2,pcd_inst_line_ticks_b(a5)

.inst_no_inst_active
.inst_pat_loop_exit3

; ----------------------------------------

; expects d2 = inst num
; a5 = channel
        move.w  pcd_inst_vol_w(a5),d1
        tst.b   pcd_new_inst_num_b(a5)
        bne.s   .load_instrument

.dont_load_instrument
        move.w  pcd_adsr_volume_w(a5),d2
        move.w  pcd_adsr_phase_w(a5),d4
        beq.s   .adsr_attack
        subq.w  #1,d4
        move.w  d4,d3
        beq.s   .adsr_decay_and_release ; we destinguish via d3 == 0 -> decay
        subq.w  #1,d4
        beq     .adsr_sustain

.adsr_release
        move.w  pcd_adsr_pos_w(a5),d4
        add.w   pcd_adsr_vol64_w(a5),d4
        move.w  d4,pcd_adsr_pos_w(a5)
        sub.w   #16,d4
        blt.s   .adsr_done
        move.w  d4,pcd_adsr_pos_w(a5)

        ; same code for both release and decay
.adsr_decay_and_release
        moveq.l #0,d4
        move.b  pcd_adsr_phase_speed_b(a5),d4
        cmpi.b  #$8f,d4
        bhs.s   .adsr_absurd_slow_release
        move.b  d4,d5
        addq.b  #1,d5
        add.w   d4,d4
        lea     pre_roll_off_table(pc),a1
        move.w  (a1,d4.w),d4
        bra.s   .adsr_release_cont

.adsr_absurd_slow_release
        moveq.l #2,d4           ; FIXME I guess this should be 1, if I look at the roll-off table
        moveq.l #-$71,d5        ; same as $8f, we only need the byte
.adsr_release_cont
        move.b  d5,pcd_adsr_phase_speed_b(a5)

        tst.w   d3
        beq.s   .adsr_is_actually_decay

        sub.w   d4,d2
        bpl.s   .adsr_done
        moveq.l #0,d2
        bra.s   .adsr_done

.adsr_is_actually_decay
        sub.w   d4,d2

        cmp.w   uii_adsr_sustain(a2),d2
        bgt.s   .adsr_done
.adsr_enter_sustain
        move.w  #2,pcd_adsr_phase_w(a5)
        move.w  uii_adsr_sustain(a2),d2
        bra.s   .adsr_done

.load_instrument
        move.b  d1,pcd_loaded_inst_vol_b(a5)
        move.l  uii_vibrato_delay(a2),pcd_vibrato_delay_w(a5)  ; and uii_vibrato_depth
        ;move.w  uii_vibrato_delay(a2),pcd_vibrato_delay_w(a5)
        ;move.w  uii_vibrato_depth(a2),pcd_vibrato_depth_w(a5)

        move.l  uii_vibrato_speed(a2),pcd_vibrato_speed_w(a5)  ; and uii_adsr_release
        ;move.w  uii_vibrato_speed(a2),pcd_vibrato_speed_w(a5)
        ;move.b  uii_adsr_release(a2),pcd_adsr_release_b(a5)

        moveq.l #0,d2
        move.l  d2,pcd_adsr_phase_w(a5)     ; and pcd_adsr_volume_w
        ;move.w  d2,pcd_adsr_phase_w(a5)
        ;move.w  d2,pcd_adsr_volume_w(a5)

        move.l  d2,pcd_new_inst_num_b(a5)   ; and pcd_vibrato_pos_w

.adsr_attack
        add.w   uii_adsr_attack(a2),d2
        cmpi.w  #MAX_VOLUME<<4,d2
        blt.s   .adsr_done

.adsr_do_decay
        move.w  #MAX_VOLUME<<4,d2
        move.w  #1,pcd_adsr_phase_w(a5)
        move.b  uii_adsr_decay+1(a2),pcd_adsr_phase_speed_b(a5)

.adsr_sustain

.adsr_done
        move.w  d2,pcd_adsr_volume_w(a5)

        ; handle note cut-off command (EAx command)
        move.b  pcd_note_off_delay_b(a5),d4
        beq.s   .dont_release_note
        subq.b  #1,d4
        move.b  d4,pcd_note_off_delay_b(a5)
        bne.s   .dont_release_note
        ; cut off note
        clr.w   pcd_adsr_volume_w(a5)
        move.w  #3,pcd_adsr_phase_w(a5)

.dont_release_note

; ----------------------------------------
; calculate final volume output = inst_vol * ADSR volume * pattern volume

        IFNE    PRETRACKER_VOLUME_TABLE
        lea     pv_volume_table(a4),a1
        lsl.w   #3,d2
        and.w   #127<<7,d2
        or.b    d1,d2
        move.b  (a1,d2.w),d1
        lsl.w   #7,d1
        or.b    pcd_pat_vol_b(a5),d1
        move.b  (a1,d1.w),pcd_out_vol_b(a5)
        ELSE
        lsr.w   #4,d2
        mulu    d2,d1
        lsr.w   #6,d1

        moveq.l #0,d2
        move.b  pcd_pat_vol_b(a5),d2
        mulu    d1,d2
        lsr.w   #6,d2
        move.b  d2,pcd_out_vol_b(a5)
        ENDC

; ----------------------------------------
; wave loop pos advancing and pattern wave offset command handling

        move.w  wi_subloop_len_w(a3),d3
        beq     .wave_has_no_subloop
        move.w  d3,pcd_out_len_w(a5)        ; FIXME can we move this to wave loading?

        move.w  wi_subloop_step_w(a3),d2
        moveq.l #0,d1
        move.b  pcd_wave_offset_b(a5),d1
        beq.s   .wave_with_subloop_but_no_wave_offset
        tst.b   wi_allow_9xx_b(a3)
        beq.s   .wave_with_subloop_but_no_wave_offset

        ; update loop offset from pattern
        lsl.w   #7,d1

        clr.b   pcd_wave_offset_b(a5)

        ; keep current direction of ping-pong unchanged
        move.b  pcd_inst_ping_pong_dir_b(a5),d4
        bpl.s   .wave_move_one_step_ahead
        sub.w   d2,d1       ; go in reverse direction one step?
        bra.s   .wave_submove_cont
.wave_move_one_step_ahead
        add.w   d2,d1       ; go in reverse direction one step?
        bra.s   .wave_submove_cont

.wave_with_subloop_but_no_wave_offset
        subq.w  #1,pcd_inst_subloop_wait_w(a5)
        bgt.s   .wave_subloop_wait

        ; subloop moves!
        move.b  pcd_inst_ping_pong_dir_b(a5),d4
        move.w  pcd_inst_loop_offset_w(a5),d1
.wave_submove_cont
        ; reset subloop wait
        moveq.l #0,d5
        move.b  wi_subloop_wait_b(a3),d5        ; FIXME why is this not increased by one here?
        move.w  d5,pcd_inst_subloop_wait_w(a5)

        tst.b   d4
        bpl.s   .wave_is_moving_backwards
        add.w   d2,d1                   ; increment offset in forward direction one step

        move.w  d1,d4
        add.w   d3,d4                   ; calculate next start of loop (curr start)

        move.w  wi_loop_end_w(a3),d2
        cmp.w   d1,d2
        bhs.s   .is_not_past_loop_end   ; are we starting playback past the end of the loop
        move.w  wi_chipram_w(a3),d2     ; use sample end
.is_not_past_loop_end
        sub.w   d4,d2                   ; space left = (max(loop end, sample end) - curr start)
        bhi.s   .wave_new_loop_pos_fits ; max(loop end, sample end) > curr start?

        add.w   d2,d1                   ; place offset at last possible place (loop_end - loop size)

        clr.b   pcd_inst_ping_pong_dir_b(a5) ; mark going backwards
        bra.s   .wave_loop_dir_changed

.wave_is_moving_backwards
        sub.w   d2,d1                   ; decrement offset in backward direction one step

        move.w  wi_loop_start_w(a3),d4

        move.w  d4,d2
        sub.w   d1,d2                   ; calc how many bytes we are part front
        bmi.s   .wave_new_loop_pos_fits

.wave_hit_front_of_loop
        move.w  d4,d1
        st      pcd_inst_ping_pong_dir_b(a5)

.wave_loop_dir_changed
        tst.w   d2
        bne.s   .wave_new_loop_pos_fits ; perfect fit for last loop

        ; partial fit only
        subq.w  #1,pcd_inst_subloop_wait_w(a5)  ; why, oh why?

.wave_new_loop_pos_fits
        move.w  d1,d4
        move.w  d4,pcd_inst_loop_offset_w(a5)
        bra.s   .done_lof_calc

.wave_subloop_wait
        move.w  pcd_inst_loop_offset_w(a5),d4
.done_lof_calc
        move.w  d4,pcd_out_lof_w(a5)

        move.w  pcd_inst_wave_num_w(a5),d1  ; FIXME can we move this to wave loading?
        move.l  pv_wave_sample_table(a4,d1.w),pcd_out_ptr_l(a5)
        bra.s   .loop_handling_done

.wave_has_no_subloop
        move.b  pcd_wave_offset_b(a5),d1
        beq.s   .loop_handling_done
        tst.b   wi_allow_9xx_b(a3)
        beq.s   .loop_handling_done

        ; apply offset from pattern for sample without subloop
        lsl.w   #8,d1   ; clear upper byte
        lsr.w   #1,d1

        clr.b   pcd_wave_offset_b(a5)

        move.b  pcd_channel_mask_b(a5),d2   ; trigger output
        move.b  d2,pcd_out_trg_b(a5)
        or.b    d2,pv_trigger_mask_w+1(a4)

        move.w  wi_chipram_w(a3),d2
        sub.w   d1,d2
        bgt.s   .waveoffset_is_not_past_end
        moveq.l #2,d2
        IFNE    PRETRACKER_BUGFIX_CODE
        ; FIXME actually we should set the start address to the empty sample
        ; FIXME (or at least to the beginning of the sample?) to avoid an audible glitch
        moveq.l #0,d1
        ENDC
.waveoffset_is_not_past_end
        move.w  d2,pcd_out_len_w(a5)

        move.w  pcd_inst_wave_num_w(a5),d2
        add.l   pv_wave_sample_table(a4,d2.w),d1
        move.l  d1,pcd_out_ptr_l(a5)

        ;move.w  #$FFFF,pcd_out_lof_w(a5)   ; this is already set to -1, no need to set it again
.loop_handling_done

; ----------------------------------------
; pitch handling
        move.w  pcd_inst_pitch_w(a5),d0
        sub.w   #$10,d0
        tst.b   pcd_inst_pitch_pinned_b(a5)
        bne.s   .pitch_pinned
.pitch_not_pinned
        add.w   pcd_inst_sel_arp_note_w(a5),d0
        add.w   pcd_inst_curr_port_pitch_w(a5),d0
        sub.w   #$10,d0
.pitch_pinned
        add.w   pcd_inst_note_pitch_w(a5),d0

; ----------------------------------------
; vibrato processing
        move.b  pcd_vibrato_delay_w+1(a5),d1
        beq.s   .vibrato_already_active
        subq.b  #1,d1
        move.b  d1,pcd_vibrato_delay_w+1(a5)
        bne.s   .vibrato_still_delayed

.vibrato_already_active
        move.w  pcd_vibrato_speed_w(a5),d2
        beq.s   .vibrato_disabled      ; no speed -- skip stuff
        move.w  pcd_vibrato_depth_w(a5),d4
        move.w  d2,d1
        add.w   pcd_vibrato_pos_w(a5),d1
        cmp.w   d1,d4
        blt.s   .vibrato_flipit
        neg.w   d4
        cmp.w   d1,d4
        ble.s   .vibrato_cont
.vibrato_flipit
        neg.w   d2
        move.w  d2,pcd_vibrato_speed_w(a5)
        move.w  d4,d1
.vibrato_cont
        move.w  d1,pcd_vibrato_pos_w(a5)

        asr.w   #3,d1
        add.w   d1,d0
.vibrato_disabled
.vibrato_still_delayed

; ----------------------------------------
; select right sample corresponding to current pitch

        move.w  pcd_out_len_w(a5),d3
        cmpi.w  #$219,d0
        ble     .noclippitchhigh
        move.w  #$231,d6                    ; That's probably B-3+1, mapping to period $71 (although $7c is the last safe value)
        btst    #2,wi_flags_b(a3)
        beq     .noclippitchlow2

        ; select high pitch version of the sample
        moveq.l #0,d2
        move.w  wi_chipram_w(a3),d2
        move.w  d0,d5
        sub.w   #$219,d5
        lsr.w   #6,d5
        lea     pre_octave_select_table(pc),a1
        moveq.l #0,d1
        move.b  (a1,d5.w),d1
        move.w  pcd_out_lof_w(a5),d7
        addq.w  #1,d7   ; compare to $ffff
        beq.s   .has_no_loop_offset
        subq.w  #1,d7
        lsr.w   d1,d7
        move.w  d7,pcd_out_lof_w(a5)
        lsr.w   d1,d3
        move.w  d3,pcd_out_len_w(a5)
        bra.s   .lbC0005C0

.has_no_loop_offset
        tst.b   pcd_out_trg_b(a5)
        beq.s   .no_retrigger_new

        move.w  pcd_inst_wave_num_w(a5),d7
        movea.l pv_wave_sample_table(a4,d7.w),a3

        move.l  pcd_out_ptr_l(a5),d4
        sub.l   a3,d4
        move.w  d3,d6
        add.w   d4,d6

        move.w  d2,d7
        sub.w   d6,d7
        cmp.w   d7,d3
        bcc.s   .fix_sample_loop
        moveq.l #2,d3
        bra.s   .cont_after_one_shot

.fix_sample_loop
        add.w   d6,d3
        sub.w   d2,d3
        lsr.w   d1,d3

.cont_after_one_shot
        move.w  d3,pcd_out_len_w(a5)

        lsr.w   d1,d4
        add.l   a3,d4
        move.l  d4,pcd_out_ptr_l(a5)

.lbC0005C0
        subq.b  #1,d1
        bmi.s   .is_normal_octave
        ; find offset in sample buffer for the right octave
        moveq.l #0,d4
.movetoloopposloop
        add.l   d2,d4
        lsr.w   #1,d2
        dbra    d1,.movetoloopposloop
        add.l   d4,pcd_out_ptr_l(a5)

.no_retrigger_new
.is_normal_octave
        moveq.l #0,d1
        move.b  pre_octave_note_offset_table-pre_octave_select_table(a1,d5.w),d1
        add.w   d1,d1
        add.w   d1,d1
        sub.w   d1,d0
        cmpi.w  #$231,d0
        ble.s   .noclippitchhigh
        move.w  #$231,d0
.noclippitchhigh
        tst.w   d0
        bge.s   .noclippitchlow
        moveq.l #0,d0
.noclippitchlow
        move.w  d0,d6
.noclippitchlow2
        tst.b   pcd_out_trg_b(a5)
        beq.s   .wasnottriggered
        moveq.l #0,d0
        move.w  pcd_out_lof_w(a5),d0
        addq.w  #1,d0       ; compare to $ffff
        beq.s   .hasnoloop2
        subq.w  #1,d0
        add.l   d0,pcd_out_ptr_l(a5)
        clr.w   pcd_out_lof_w(a5)
.wasnottriggered
.hasnoloop2
        cmp.w   pcd_last_trigger_pos_w(a5),d3
        beq.s   .hassamesampos
        move.w  d3,pcd_last_trigger_pos_w(a5)
        move.b  pcd_channel_mask_b(a5),d3
        move.b  d3,pcd_out_trg_b(a5)
        or.b    d3,pv_trigger_mask_w+1(a4)
.hassamesampos
        add.w   d6,d6
        move.w  pv_period_table(a4,d6.w),pcd_out_per_w(a5)

; ----------------------------------------
; track delay handling

        move.b  pcd_track_delay_steps_b(a5),d3
        beq     .incrementchannel       ; no track delay

        cmp.b   #NUM_CHANNELS-1,pcd_channel_num_b(a5)   ; last channel processed?
        beq     .updatechannels         ; no track delay for last channel

        moveq.l #MAX_TRACK_DELAY-1,d0   ; load from last buffer

        ; handle track delay
        cmpi.b  #$FF,d3
        beq.s   .clear_track_delay

        ; advance and wrap offset
        move.b  pcd_SIZEOF+pcd_track_delay_offset_b(a5),d1
        addq.b  #1,d1
        and.w   d0,d1
        move.b  d1,pcd_SIZEOF+pcd_track_delay_offset_b(a5)

        move.w  d1,d2
        lea     pcd_SIZEOF(a5),a3
        lsl.w   #4,d2
        lea     pcd_track_delay_buffer(a3,d2.w),a3
        lea     pcd_out_base(a5),a1
        move.l  (a1)+,(a3)+             ; ocd_sam_ptr
        move.l  (a1)+,(a3)+             ; ocd_length/ocd_loop_offset
        move.l  (a1)+,(a3)+             ; ocd_period/ocd_volume/ocd_trigger
        ;move.l  (a1)+,(a3)+             ; this is never used

        move.b  -(a3),d2
        add.b   d2,d2               ; increment channel
        bne.s   .copy_trigger_for_delayed_channel
        tst.b   pcd_SIZEOF+pcd_track_delay_steps_b(a5)
        bne.s   .dont_trigger_track_delay_first_note
        move.b  d2,(a3)            ; trigger note (ocd_trigger)
.copy_trigger_for_delayed_channel
        or.b    d2,pv_trigger_mask_w+1(a4)
.dont_trigger_track_delay_first_note

        IFNE    PRETRACKER_VOLUME_TABLE
        lea     pv_volume_table(a4),a1
        move.b  pcd_track_delay_vol16_b(a5),-(sp)
        move.w  (sp)+,d4
        clr.b   d4
        add.w   d4,d4
        move.b  -(a3),d4            ; ocd_volume
        move.b  (a1,d4.w),(a3)+
        ELSE
        moveq.l #0,d4
        move.b  -(a3),d4            ; ocd_volume
        move.b  pcd_track_delay_vol16_b(a5),d2
        ext.w   d2
        mulu    d4,d2               ; apply track delay volume
        lsr.w   #4,d2
        move.b  d2,(a3)+            ; fix volume
        ENDC

        move.b  d3,pcd_SIZEOF+pcd_track_delay_steps_b(a5)

        sub.b   d3,d1
        and.w   d1,d0

        IFNE    PRETRACKER_DUBIOUS_PITCH_SHIFT_FOR_DELAYED_TRACK
        moveq.l #7,d4
        and.w   d4,d1
        lea     pre_minus4plus4_table(pc),a1
        move.b  (a1,d1.w),d1
        ext.w   d1
        ENDC
        bra.s   .load_track_data_from_buffer

.clear_track_delay
        moveq.l #0,d1
        move.b  d1,pcd_track_delay_steps_b(a5)
        move.b  d1,pcd_SIZEOF+pcd_pat_vol_b(a5)
        move.b  d1,pcd_SIZEOF+pcd_track_delay_steps_b(a5)
        st      pcd_SIZEOF+pcd_track_delay_offset_b(a5)

.load_track_data_from_buffer
        lea     pcd_SIZEOF(a5),a5       ; skip the channel we applied track delay to
        lsl.w   #4,d0
        lea     pcd_track_delay_buffer(a5,d0.w),a1
        lea     pcd_out_base(a5),a3
        move.l  (a1)+,(a3)+             ; ocd_sam_ptr
        move.l  (a1)+,(a3)+             ; ocd_length/ocd_loop_offset
        move.l  (a1)+,(a3)+             ; ocd_period/ocd_volume/ocd_trigger
        ;move.l   (a1)+,(a3)+            ; this is never used

        ;clr.b   ocd_volume-ocd_unused(a1) ; does not seem to bother

        IFNE     PRETRACKER_DUBIOUS_PITCH_SHIFT_FOR_DELAYED_TRACK
        ; FIXME this seems odd! Why modulate the period by the distance?
        move.w  pcd_out_base+ocd_period(a5),d2
        move.w  d1,d0
        muls    d2,d0
        lsl.l   #4,d0
        swap    d0
        add.w   d0,d2
        move.w  d2,pcd_out_base+ocd_period(a5)
        ENDC

.incrementchannel
        lea     pcd_SIZEOF(a5),a5
        cmp.b   #NUM_CHANNELS-1,pcd_channel_num_b-pcd_SIZEOF(a5)
        bne     .inst_chan_loop

; ----------------------------------------
.updatechannels
        ; so this changed a lot from the original routine
        move.w  pv_trigger_mask_w(a4),d2

        IFNE    PRETRACKER_COPPER_OUTPUT
        move.l  pv_copperlist_ptr(a4),d0
        beq     .skipcopperlist
        move.l  d0,a5
        move.b  d2,1*4+3(a5)    ; dmacon
        move.b  d2,(1+1+1+5*NUM_CHANNELS)*4+3(a5)       ; dmacon after wait, dmacon, wait, 20 writes

        lea     pv_channeldata+pcd_out_base(a4),a0
        move.l  pv_sample_buffer_ptr(a4),d3
        moveq.l #0,d5
        move.w  d5,pv_trigger_mask_w(a4)
        moveq.l #-1,d1
        lea     3*4+2(a5),a1
        lea     (1+1+1+5*NUM_CHANNELS+1+1)*4+2(a5),a2   ; wait, dmacon, wait, 20 writes, dmacon, wait
        moveq.l #NUM_CHANNELS-1,d7
.checkchan
        moveq.l #0,d2
        move.w  ocd_loop_offset(a0),d2
        cmp.w   d1,d2
        bne.s   .is_looping_sample
        tst.b   ocd_trigger(a0)
        beq.s   .one_shot_clear_loop
        move.b  d5,ocd_trigger(a0)
        move.l  ocd_sam_ptr(a0),d0
        move.l  d3,d6                       ; set loop start
        move.w  ocd_length(a0),d4
        lsr.w   #1,d4
        move.w  d4,2*4(a1)  ; ac_len
        moveq.l #1,d4
        bra.s   .setptrvolper
.one_shot_clear_loop
        move.l  d3,d6
        move.l  d3,d0
        moveq.l #1,d4
        move.w  d4,2*4(a1)  ; ac_len
        bra.s   .setptrvolper

.is_looping_sample
        move.l  ocd_sam_ptr(a0),d0
        add.l   d2,d0
        move.l  d0,d6

        move.w  ocd_length(a0),d4
        lsr.w   #1,d4
        move.w  d4,2*4(a1)  ; ac_len
        tst.b   ocd_trigger(a0)
        beq.s   .setptrvolper
        move.b  d5,ocd_trigger(a0)
        sub.l   d2,d6
.setptrvolper
        move.w  d0,1*4(a1)  ; ac_ptr (lo)
        swap    d0
        move.w  d0,(a1)     ; ac_ptr (hi)
        move.w  ocd_period(a0),3*4(a1)
        move.b  ocd_volume(a0),4*4+1(a1)
        move.w  d6,1*4(a2)  ; ac_ptr (lo)
        swap    d6
        move.w  d6,(a2)     ; ac_ptr (hi)
        move.w  d4,2*4(a2)  ; ac_len

        lea     pcd_SIZEOF(a0),a0
        lea     5*4(a1),a1
        lea     3*4(a2),a2
        dbra    d7,.checkchan

.skipcopperlist
        ELSE
        lea     $dff000,a5

        ; turn channels off and remember raster position
        move.w  d2,dmacon(a5)       ; turn dma channels off
        move.w  vhposr(a5),d5       ; I know this only works for the lower 256 rasterlines...
        add.w   #4<<8,d5            ; target rasterpos

        ; in the meanwhile we can update both channels that
        ; - need triggering by setting the new start and length
        ; - need updating of loop offset only
        ; update volume and period in any case
        lea     pv_channeldata+pcd_out_base(a4),a0
        lea     aud0(a5),a1
        move.l  pv_sample_buffer_ptr(a4),d3
        moveq.l #0,d6
        move.w  d6,pv_trigger_mask_w(a4)
        moveq.l #-1,d1
        moveq.l #NUM_CHANNELS-1,d7
.checkchan
        tst.b   ocd_trigger(a0)
        beq.s   .updateloop
        move.b  d6,ocd_trigger(a0)
        ; set start and length of the new sample
        move.w  ocd_length(a0),d0
        lsr.w   #1,d0
        move.w  d0,ac_len(a1)
        move.l  ocd_sam_ptr(a0),ac_ptr(a1)
        bra.s   .setvolperchan
.updateloop
        ; just update loop offset if looping
        moveq.l #0,d0
        move.w  ocd_loop_offset(a0),d0
        cmp.w   d1,d0
        beq.s   .setvolperchan
        add.l   ocd_sam_ptr(a0),d0
        move.l  d0,ac_ptr(a1)
.setvolperchan
        move.b  ocd_volume(a0),ac_vol+1(a1)
        move.w  ocd_period(a0),ac_per(a1)
        lea     pcd_SIZEOF(a0),a0
        lea     ac_SIZEOF(a1),a1
        dbra    d7,.checkchan

        tst.w   d2
        beq.s   .skiprasterwait ; if no channel needed triggering, we are done!

        or.w    #DMAF_SETCLR,d2
.rasterwait1
        cmp.w   vhposr(a5),d5
        bgt.s   .rasterwait1

        move.w  d2,dmacon(a5)   ; enable triggered channels
        add.w   #4<<8,d5        ; target rasterpos

.rasterwait2
        cmp.w   vhposr(a5),d5
        bgt.s   .rasterwait2

        lea     pv_channeldata+pcd_out_base(a4),a0
        lea     aud(a5),a1
.chanloop
        lsr.b   #1,d2
        bcc.s   .nosetloopchan
        moveq.l #0,d0
        move.w  ocd_loop_offset(a0),d0
        cmp.w   d1,d0
        beq.s   .setchan_no_loop2
        add.l   ocd_sam_ptr(a0),d0
        bra.s   .keepchanrunning2
.setchan_no_loop2
        move.l  d3,d0
        move.w  #1,ac_len(a1)
.keepchanrunning2
        move.l  d0,ac_ptr(a1)
.nosetloopchan
        lea     pcd_SIZEOF(a0),a0
        lea     ac_SIZEOF(a1),a1
        tst.b   d2
        bne.s   .chanloop

.skiprasterwait
        ENDC

        IFNE    PRETRACKER_DONT_TRASH_REGS
        movem.l (sp)+,d2-d7/a2-a6
        ENDC
        rts

;--------------------------------------------------------------------
; table data currently about 594 bytes

; I assume this is a log table for freq distances within an octave
pre_log12_table:
        dc.b    $400000/$8000,$400000/$871D,$400000/$8F2F,$400000/$97B7,$400000/$9FC4,$400000/$A9DE
        dc.b    $400000/$B505,$400000/$BF49,$400000/$CB31,$400000/$D645,$400000/$E215,$400000/$F1A0

; linear then steep quadratic slope
pre_vib_speed_table:
        dc.b    2,3,4,5,6,7,8,9,10,11,12,13,14,20,40,80

; linear (a bit wonky), then a bit quadratic, then steep
pre_vib_depth_table:
        dc.b    0,8,9,10,11,12,13,14,18,20,28,40,50,70,160,255

; linear then almost quadratic
pre_vib_delay_table:
        dc.b    0,4,8,10,12,14,16,18,20,24,32,40,56,96,150,255

pre_ramp_up_16:
        dc.b    0,1,3,6,7,9,10,11,12,13,14,16,19,35,55,143

pre_fast_roll_off_16:
        dc.w    $400,$200,$80,$64,$50,$40,$30,$20,$10,14,12,10,8
        dc.w    4,2,1

pre_roll_off_table:
        dc.w    $400,$200,$180,$140,$100,$C0,$A0,$80,$78,$74,$6E
        dc.w    $69,$64,$5A,$46,$40,$38,$30,$28,$20,$1F,$1E,$1D
        dc.w    $1C,$1B,$1A,$19,$18,$17,$16,$15,$14,$13,$12,$11
        dc.w    $10,15,14,13,13,12,12,11,11,10,10,9,9,8,8,8,8,7,7
        dc.w    7,7,6,6,6,6,5,5,5,5,4,4,4,4,4,4,4,4,4,4,3,4,4,3,4
        dc.w    4,3,4,3,4,3,4,3,4,3,3,3,3,3,3,3,3,3,2,3,3,3,2,3,3
        dc.w    2,3,3,2,3,3,2,3,2,3,2,3,2,3,2,3,2,2,2,2,2,2,2,2,1
        dc.w    2,1,2,1,2,1,2,1,1,2,1,1,1,2,1

pre_octave_note_offset_table:
        dc.b    1*NOTES_IN_OCTAVE*4,1*NOTES_IN_OCTAVE*4,1*NOTES_IN_OCTAVE*4
        dc.b    2*NOTES_IN_OCTAVE*4,2*NOTES_IN_OCTAVE*4,2*NOTES_IN_OCTAVE*4
        dc.b    3*NOTES_IN_OCTAVE*4,3*NOTES_IN_OCTAVE*4,3*NOTES_IN_OCTAVE*4
        dc.b    3*NOTES_IN_OCTAVE*4,3*NOTES_IN_OCTAVE*4,3*NOTES_IN_OCTAVE*4
        dc.b    3*NOTES_IN_OCTAVE*4,3*NOTES_IN_OCTAVE*4,3*NOTES_IN_OCTAVE*4
        IFNE    PRETRACKER_PARANOIA_MODE
        dc.b    3*NOTES_IN_OCTAVE*4,3*NOTES_IN_OCTAVE*4,3*NOTES_IN_OCTAVE*4
        dc.b    3*NOTES_IN_OCTAVE*4,3*NOTES_IN_OCTAVE*4,3*NOTES_IN_OCTAVE*4
        dc.b    3*NOTES_IN_OCTAVE*4,3*NOTES_IN_OCTAVE*4,3*NOTES_IN_OCTAVE*4
        ELSE
        dc.b    3*NOTES_IN_OCTAVE*4
        ENDC
        even

        ; based on pitch $219 (537), covers up to pitch 0x819 (2073).
        ; In practice, I was unable to get higher than $5ff
pre_octave_select_table:
        dc.b    1,1,1
        dc.b    2,2,2
        dc.b    3,3,3
        dc.b    3,3,3
        dc.b    3,3,3
        dc.b    3,3,3
        IFNE    PRETRACKER_PARANOIA_MODE
        dc.b    3,3,3
        dc.b    3,3,3
        ELSE
        dc.b    3
        ENDC
        even

        IFNE     PRETRACKER_DUBIOUS_PITCH_SHIFT_FOR_DELAYED_TRACK
        ; -4,-3,-1,1,2,3,4,0
pre_minus4plus4_table:
        dc.b     $FC,$FB,$FF,1,2,3,4,0
        ENDC

pre_ramp_up_down_32:
        dc.w     0*32,1*32,2*32,3*32,4*32,5*32,6*32,7*32,8*32,9*32,10*32,11*32,12*32,13*32,14*32,15*32
        dc.w     15*32,14*32,13*32,12*32,11*32,10*32,9*32,8*32,7*32,6*32,5*32,4*32,3*32,2*32,1*32,0*32

pre_modulator_ramp_8:
        ;dc.w     77,293,539,1079,1337,1877,2431,3031 ; the 1079 value is strange (938 better?)
        dc.w     $4D,$125,$21B,$437,$539,$755,$96D,$BD7

pre_period_table:
        dc.w     $350,$320,$2F2,$2C8,$2A0,$279,$256,$236,$216,$1F8,$1DC,$1C0
        dc.w     $1A8,$190,$179,$164,$151,$13E,$12C,$11B,$10B,$FC,$EE,$E0
        dc.w     $D4,$C8,$BD,$B2,$A8,$9F,$96,$8D,$86,$7E,$78,$71
        dc.w     $71
