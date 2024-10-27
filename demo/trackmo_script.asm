                include trackmo_script.i

********************************************************************************
trackmo:
                clr.w   $dff180

                move.l  a6,-(sp)
; switch off cache using system call if ROM > 37
                move.l  $4.w,a6
                move.w  14+6(a6),d0
                cmp.w   #37,d0          ; LIB_VERSION should be at least 37
                blt.s   .noCache		
                moveq   #0,d0
                moveq   #-1,d1
                jsr     -648(a6)
.noCache:
                move.l  (sp)+,a6

                ; bsr     fw_FlipAllocationDirection
                EXEC_PART .motherboard,.preload_music_and_amiga
                EXEC_PART .amiga,.preload_title
                EXEC_PART .title,.load_tunnel_2d
                EXEC_LOADED_PART .load_facelights
                EXEC_LOADED_PART .load_roto
                EXEC_LOADED_PART .load_circuit_g
                EXEC_LOADED_PART .load_combo
                EXEC_LOADED_PART .load_circuit_m
                EXEC_LOADED_PART .load_tmap
                EXEC_LOADED_PART
                EXEC_PART .circuit_p,.load_tunnel_s
                EXEC_LOADED_PART .preload_tunnel_m
                EXEC_PART .tunnel_m,.load_circuit_s
                EXEC_LOADED_PART .load_tunnel_g
                EXEC_LOADED_PART .load_text1
                EXEC_LOADED_PART .load_tunnel_p
                EXEC_LOADED_PART .load_text2
                EXEC_LOADED_PART .load_tunnel_x4
                EXEC_LOADED_PART .load_text3
                EXEC_LOADED_PART .load_tunnel_r
                EXEC_LOADED_PART .preload_credits
                EXEC_PART .credits,.load_endpart
                EXEC_LOADED_PART
                
;--------------------------------------------------------------------
; Tasks

                PRELOAD_TASK motherboard
                PRELOAD_TASK title
                LOAD_TASK tunnel_2d
                LOAD_PRECALC_TASK facelights
                LOAD_TASK roto
                LOAD_TASK circuit_g
                LOAD_PRECALC_TASK combo
                LOAD_TASK circuit_m
                LOAD_TASK tmap
                ; PRELOAD_TASK circuit_p
                LOAD_PRECALC_TASK tunnel_s
                PRELOAD_TASK tunnel_m
                LOAD_TASK circuit_s
                LOAD_PRECALC_TASK tunnel_g
                LOAD_TASK text1
                LOAD_PRECALC_TASK tunnel_p
                LOAD_TASK text2
                LOAD_PRECALC_TASK tunnel_x4
                LOAD_TASK text3
                LOAD_PRECALC_TASK tunnel_r
                PRELOAD_TASK credits
                LOAD_TASK endpart


.preload_music_and_amiga:
                bsr     fw_FlipAllocationDirection

                ; Load music
                lea     .music_data(pc),a0
                bsr     fw_LoadAndDecrunchFile
                move.l  a0,fw_MusicData(a6)
                lea     .music_samples(pc),a0
                bsr     fw_LoadAndDecrunchFile
                move.l  a0,fw_MusicSamples(a6)
                bsr     fw_PushMemoryState ; this memory should not go away!

                ; Preload Amiga part
                lea     .amiga(pc),a0
                bsr     fw_PreloadPart
                bsr     fw_TrackloaderDiskMotorOff

                rts


;-------------------------------------------------------------------------------
; Filename dir entries
                FILENAME motherboard,Motherboard
                FILENAME music_data,tune.lsmus
                FILENAME music_samples,tune.lsbnk
                FILENAME amiga,Amiga 
                FILENAME title,Title
                FILENAME tunnel_2d,Tunnel2D 
                FILENAME facelights,FaceLights 
                FILENAME roto,Roto 
                FILENAME combo,Combo 
                FILENAME tmap,Tmap 
                FILENAME circuit_g,CircuitG 
                FILENAME circuit_p,CircuitP
                FILENAME circuit_m,CircuitM 
                FILENAME circuit_s,CircuitS 
                FILENAME tunnel_g,TunnelG 
                FILENAME text1,Text1 
                FILENAME text2,Text2
                FILENAME text3,Text3
                FILENAME tunnel_p,TunnelP
                FILENAME tunnel_m,TunnelM 
                FILENAME tunnel_s,TunnelS 
                FILENAME tunnel_x4,TunnelX4 
                FILENAME tunnel_r,TunnelR 
                FILENAME credits,Credits 
                FILENAME endpart,End 


                even

;--------------------------------------------------------------------
.end:
