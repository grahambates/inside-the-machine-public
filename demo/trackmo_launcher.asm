                opt     p+,o+
                include "trackmo_settings.i"
                include "global_bonus.i"

                include "../framework/framework.i"

                bsr     trackmo_AppInit

                include "trackmo_script.asm"

                bsr     trackmo_AppShutdown

.loop:          bra.s   .loop

                include "../framework/framework.asm"
