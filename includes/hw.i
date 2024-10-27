                ifnd    _HW_I
_HW_I           set     1

                include "hardware/adkbits.i"
                include "hardware/blit.i"
                include "hardware/cia.i"
                include "hardware/custom.i"
                include "hardware/dmabits.i"
                include "hardware/intbits.i"

custom = $dff000
ciaa = $bfe001
ciab = $bfd000
execbase = $4

; potgor = $16

dskpth = $20
dskptl = $22

bltcpth = $48
bltcptl = $4a
bltbpth = $4c
bltbptl = $4e
bltapth = $50
bltaptl = $52
bltdpth = $54
bltdptl = $56

cop1lch = $80
cop1lcl = $82
cop2lch = $84
cop2lcl = $86

aud0lch = $a0
aud0lcl = $a2
aud0len = $a4
aud0per = $a6
aud0vol = $a8
aud0dat = $aa
aud1lch = $b0
aud1lcl = $b2
aud1len = $b4
aud1per = $b6
aud1vol = $b8
aud1dat = $ba
aud2lch = $c0
aud2lcl = $c2
aud2len = $c4
aud2per = $c6
aud2vol = $c8
aud2dat = $ca
aud3lch = $d0
aud3lcl = $d2
aud3len = $d4
aud3per = $d6
aud3vol = $d8
aud3dat = $da

bpl0pt = $e0
bpl0ptl = $e2
bpl1pt = $e4
bpl1ptl = $e6
bpl2pt = $e8
bpl2ptl = $ea
bpl3pt = $ec
bpl3ptl = $ee
bpl4pt = $f0
bpl4ptl = $f2
bpl5pt = $f4
bpl5ptl = $f6
bpl6pt = $f8
bpl6ptl = $fa
bpl7pt = $fc
bpl7ptl = $fe

spr0pth = $120
spr0ptl = $122
spr1pth = $124
spr1ptl = $126
spr2pth = $128
spr2ptl = $12a
spr3pth = $12c
spr3ptl = $12e
spr4pth = $130
spr4ptl = $132
spr5pth = $134
spr5ptl = $136
spr6pth = $138
spr6ptl = $13a
spr7pth = $13c
spr7ptl = $13e

spr0pos = $140
spr0ctl = $142
spr0data = $144
spr0datb = $146
spr1pos = $148
spr1ctl = $14a
spr1data = $14c
spr1datb = $14e
spr2pos = $150
spr2ctl = $152
spr2data = $154
spr2datb = $156
spr3pos = $158
spr3ctl = $15a
spr3data = $15c
spr3datb = $15e
spr4pos = $160
spr4ctl = $162
spr4data = $164
spr4datb = $166
spr5pos = $168
spr5ctl = $16a
spr5data = $16c
spr5datb = $16e
spr6pos = $170
spr6ctl = $172
spr6data = $174
spr6datb = $176
spr7pos = $178
spr7ctl = $17a
spr7data = $17c
spr7datb = $17e

color00 = $180
color01 = $182
color02 = $184
color03 = $186
color04 = $188
color05 = $18a
color06 = $18c
color07 = $18e
color08 = $190
color09 = $192
color10 = $194
color11 = $196
color12 = $198
color13 = $19a
color14 = $19c
color15 = $19e
color16 = $1a0
color17 = $1a2
color18 = $1a4
color19 = $1a6
color20 = $1a8
color21 = $1aa
color22 = $1ac
color23 = $1ae
color24 = $1b0
color25 = $1b2
color26 = $1b4
color27 = $1b6
color28 = $1b8
color29 = $1ba
color30 = $1bc
color31 = $1be

; ecs / aa
sprhdat = $078
bplhdat = $07a
lisaid = $07c
bplhmod = $1e6
sprhpth = $1e8
sprhptl = $1ea
bplhpth = $1ec
bplhptl = $1ee

                endc
