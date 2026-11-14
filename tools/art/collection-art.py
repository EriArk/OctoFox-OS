"""Original editable collection emblems. GPL-3.0-or-later.
Run with CairoSVG installed. Retains the persisted qrc:/.../*.png identities;
SVG sources are the editable masters, PNGs are offline exports for Qt.
"""
from pathlib import Path
import shutil
import cairosvg
ROOT=Path(__file__).resolve().parents[2]
INK='#294b50';GOLD='#e6b662';PAPER='#f6e5bc';TEAL='#568780';RED='#c77965'
def path(d,c,stroke='',sw=4):return f'<path d="{d}" fill="{c}"'+(f' stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round" stroke-linecap="round"' if stroke else '')+'/>'
def circle(x,y,r,c):return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{c}"/>'
def rect(x,y,w,h,c,r=0):return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{c}"/>'
def star(x,y,r,c):return path(f'M{x} {y-r} L{x+r*.3} {y-r*.3} L{x+r} {y} L{x+r*.3} {y+r*.3} L{x} {y+r} L{x-r*.3} {y+r*.3} L{x-r} {y} L{x-r*.3} {y-r*.3}Z',c)
def gem(x=128,y=120):return path(f'M{x} {y-66} L{x+39} {y-26} L{x+28} {y+43} L{x} {y+65} L{x-28} {y+43} L{x-39} {y-26}Z','#75b5bc')+path(f'M{x} {y-66} L{x} {y+65} L{x-28} {y+43} L{x-39} {y-26}Z','#c9e1da')+path(f'M{x} {y-66} L{x+39} {y-26} L{x} {y-14} L{x-39} {y-26}Z',PAPER)+path(f'M{x} {y-14} L{x+28} {y+43} L{x} {y+65}Z',TEAL)
def sword():return path('M126 38 L144 59 L144 141 L128 160 L111 141 L111 59Z',PAPER)+path('M128 45 L144 59 L144 141 L128 160Z','#a1beb5')+path('M88 138 L168 138 L174 151 L83 151Z',GOLD)+rect(119,151,18,37,INK,4)+circle(128,191,13,GOLD)
def orb():return circle(128,124,61,INK)+circle(125,120,52,TEAL)+path('M85 90 Q111 58 146 77 Q108 80 102 115Z','#99beb2')+path('M73 146 Q131 184 189 102', 'none',GOLD,12)
def boot():return path('M77 72 L135 72 L142 131 L184 148 Q203 154 199 179 L65 179 L65 145 L79 122Z',RED)+path('M78 91 L135 91 L138 112 L77 112Z',PAPER)+path('M65 179 L199 179 L199 192 L63 192Z',INK)+path('M143 144 L156 136 M156 152 L169 144','none',PAPER,6)
def tank():return rect(54,146,150,44,INK,21)+''.join(circle(x,168,13,'#91aaa1') for x in (78,109,140,171))+path('M65 143 L80 113 L165 113 L192 145Z',TEAL)+path('M94 111 L101 82 L153 82 L165 111Z','#90a689')+rect(146,89,64,11,INK,3)+star(119,126,13,PAPER)
GENRES={
 'fighting':('#e6b7aa','#f4d7c3',path('M67 157 L64 107 Q63 84 84 80 L107 80 L107 68 Q107 58 119 58 L142 59 Q153 60 154 74 L155 96 L177 101 Q194 107 191 128 L184 157 L153 178 L89 178Z',RED,INK,5)+path('M82 105 L82 126 M104 98 L104 123 M126 95 L126 120','none',PAPER,5)+rect(87,167,72,29,INK,6)+rect(99,173,48,10,GOLD,3)),
 'brawlers':('#d8be9e','#ecdbc0',path('M61 94 L114 68 L131 114 L150 96 L188 116 L178 164 L122 192 L78 162Z',TEAL,INK,5)+path('M64 95 L83 135 L129 115 M145 101 L130 136 L177 158','none',PAPER,6)+star(183,64,22,GOLD)),
 'shooters':('#b6c5ce','#d3e1df',path('M128 47 L160 113 L202 162 L153 153 L128 181 L103 153 L54 162 L96 113Z',PAPER,INK,4)+path('M128 47 L128 181 L153 153 L160 113Z',TEAL)+path('M116 117 L128 92 L140 117 L128 139Z',GOLD)+path('M110 177 L110 199 M146 177 L146 199','none',RED,8)),
 'sports':('#bdd0ab','#dce6c4',circle(128,125,64,PAPER)+path('M128 100 L152 116 L143 144 L113 144 L104 116Z',INK)+path('M128 61 L128 100 M67 106 L104 116 M87 176 L113 144 M169 176 L143 144 M189 106 L152 116','none',INK,6)+path('M128 61 L108 65 L128 78 L148 65Z M66 112 L69 133 L81 113 L72 94Z M85 173 L104 185 L99 164Z M169 173 L152 185 L155 164Z M190 110 L185 134 L176 112 L184 94Z',INK)),
 'platform':('#c3d3ab','#e5e7c6',boot()+rect(51,191,153,12,TEAL,3)+circle(180,75,20,GOLD)+circle(180,75,12,PAPER)+path('M164 112 L177 112 M48 123 L62 123','none',INK,5)),
 'puzzle':('#c6bfd6','#e4deea',path('M69 74 H111 Q97 43 125 43 Q153 43 139 74 H184 V116 Q213 102 213 130 Q213 158 184 144 V184 H140 Q154 213 126 213 Q98 213 112 184 H69 V144 Q39 157 39 130 Q39 103 69 116Z',TEAL)+path('M69 74 H111 Q97 43 125 43 Q153 43 139 74 H184 V91 H80 V151 L69 144 Q39 157 39 130 Q39 103 69 116Z','#8fb4aa')+circle(128,129,25,GOLD)+circle(128,129,13,PAPER)),
 'party':('#e5c3b8','#f2dfc4',path('M62 189 L100 91 L160 151Z',RED,INK,4)+path('M76 155 L124 172 M88 125 L145 159','none',GOLD,10)+path('M124 87 Q157 60 175 82 M160 120 Q183 110 194 122 M101 61 L108 74','none',TEAL,7)+star(184,62,17,GOLD)+circle(196,157,8,TEAL)+rect(140,50,10,13,RED,2)),
 'adventure':('#bacdb4','#dae4cd',path('M66 196 V124 Q66 57 128 57 Q190 57 190 124 V196 H165 V125 Q165 83 128 83 Q91 83 91 125 V196Z',TEAL)+path('M91 196 V125 Q91 83 128 83 Q165 83 165 125 V196Z',INK)+path('M100 197 L128 154 L156 197Z',GOLD)+path('M76 117 H90 M166 117 H182 M70 154 H89 M167 154 H185','none','#9fbbb0',5)+star(128,117,23,PAPER)),
 'music':('#cabbd8','#e8dced',path('M96 170 V70 L183 53 V151 H169 V89 L110 101 V170Z',TEAL,INK,4)+path('M110 80 L169 68 V79 L110 91Z',GOLD)+path('M96 153 Q69 146 65 166 Q63 188 86 188 Q111 187 110 166Z',INK)+path('M169 134 Q142 127 138 147 Q136 169 159 169 Q184 168 183 147Z',INK)+star(61,91,18,GOLD)),
}
SERIES={
 'pokemon':('#d0d3ad','#e9e7cc',rect(74,60,107,136,TEAL,12)+rect(86,70,83,112,PAPER,5)+path('M86 113 H169 M86 149 H169','none','#b4c5a7',3)+circle(127,124,30,GOLD)+path('M127 100 L139 124 L127 148 L115 124Z',RED)+rect(64,78,17,12,INK,3)+rect(64,154,17,12,INK,3)+path('M149 64 L149 92 L160 83 L170 91 V64Z',RED)),
 'mario':('#dfb6a2','#f1d4b8',boot()+circle(178,72,20,GOLD)+circle(178,72,12,PAPER)+rect(174,63,7,18,GOLD,3)),
 'zelda':('#b5cbb0','#dbe7c8',sword()+path('M100 175 Q48 153 58 116 Q104 125 100 175Z',TEAL)+path('M153 169 Q201 145 196 106 Q153 113 153 169Z',TEAL)),
 'sonic':('#adcbd9','#d0e2e8',path('M63 120 L121 102 L139 130 L191 139 L204 169 L65 181 L50 162Z',RED,INK,4)+path('M89 114 L108 155 L132 151 L117 106Z',PAPER)+path('M59 169 L201 157 L207 175 L66 191Z',PAPER,INK,4)+path('M52 125 H31 M65 101 H42 M77 77 H55','none',TEAL,6)+star(184,75,23,GOLD)),
 'final-fantasy':('#c6bfd9','#e6ddec',gem()+star(186,66,16,GOLD)+circle(70,153,12,GOLD)),
 'metroid':('#adc2bf','#d0dfd5',path('M59 157 V113 Q59 61 126 61 Q197 61 197 120 V156 L167 184 H89Z',TEAL,INK,5)+path('M71 115 L125 101 L185 115 L170 145 H87Z',INK)+path('M84 117 L125 109 L173 119 L163 132 H94Z',GOLD)+path('M97 160 H158','none',PAPER,6)+path('M125 62 V88','none',PAPER,5)),
 'castlevania':('#c4b3ca','#dfd1df',path('M71 194 V95 L128 45 L185 95 V194Z',INK)+path('M87 181 V102 L128 65 L169 102 V181Z',RED)+path('M128 66 V181 M88 124 H169','none',GOLD,6)+path('M57 111 Q79 95 99 115 L115 103 L128 116 L141 103 L156 115 Q179 95 199 111 L181 142 L157 133 L128 151 L100 133 L75 142Z',INK)),
 'kirby':('#e4bdcc','#f0d9df',path('M125 58 L142 99 L188 102 L152 131 L164 175 L125 149 L86 175 L98 131 L62 102 L108 99Z',GOLD,INK,4)+path('M125 71 L125 139 L151 157 L142 128 L168 109 L136 107Z',PAPER)+star(190,68,13,TEAL)+star(64,179,12,TEAL)),
 'metal-slug':('#c1c9a8','#e2e4c6',tank()),
 'multiverse':('#b8c7d6','#d6e0e6',orb()+star(68,65,18,GOLD)+star(192,168,14,PAPER)),
}
for category,entries in [('genres',GENRES),('series',SERIES)]:
 for name,(bg,halo,body) in entries.items():
  svg=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256"><!-- OctoFox original geometry; GPL-3.0-or-later. -->{rect(0,0,256,256,bg)}{circle(128,117,89,halo)}<ellipse cx="128" cy="206" rx="70" ry="10" fill="{INK}" opacity=".14"/>{body}</svg>\n'
  (ROOT/'assets'/category/(name+'.svg')).write_text(svg)
for name in ('rpg','racing','strategy'):
 shutil.copyfile(ROOT/'docs/design/art-direction-267/collections'/f'{name}.svg',ROOT/'assets/genres'/f'{name}.svg')
for category in ('genres','series'):
 for svg in (ROOT/'assets'/category).glob('*.svg'):
  cairosvg.svg2png(url=str(svg),write_to=str(svg.with_suffix('.png')),output_width=384,output_height=384)
