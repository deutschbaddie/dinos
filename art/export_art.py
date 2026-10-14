"""Export approved generated art and deterministic typography from selection.json."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parent
FONT = '/System/Library/Fonts/Supplemental/Arial Black.ttf'
CREAM = '#FFF3CF'
INK = '#122032'
ORANGE = '#EF8129'
RAINBOW = ['#FF665B', '#FFAA38', '#FFE45B', '#72E277', '#59CFFF', '#C58BFF']
NAMES = {'ICON':'icon','ICON_ALT':'icon_alt','T1':'thumb_1_chase','T2':'thumb_2_eggs','T3':'thumb_3_secret','T4':'thumb_4_boss','T5':'thumb_5_island'}
TITLES = {'T1':['OUTRUN','THE T. REX!'],'T2':['STEAL','THE EGGS!'],'T3':['HATCH A','SECRET DINO!'],'T4':['BEAT','THE BOSS!'],'T5':['BUILD YOUR','DINO ISLAND']}

def fitted(source, size):
    im = Image.open(source).convert('RGB')
    return ImageOps.fit(im, size, method=Image.Resampling.LANCZOS, centering=(.5,.5)).filter(ImageFilter.UnsharpMask(radius=.65, percent=65, threshold=3))

def headline(id):
    layer = Image.new('RGBA',(1920,1080))
    if id not in TITLES: return layer
    lines = TITLES[id]
    maxwidth = 820 if id != 'T5' else 940
    size = 132
    while max(ImageFont.truetype(FONT,size).getlength(s) for s in lines) > maxwidth: size-=1
    font = ImageFont.truetype(FONT,size)
    block = Image.new('RGBA',(1100,360)); d=ImageDraw.Draw(block)
    for i,line in enumerate(lines):
        x,y=24,18+i*(size+9)
        d.text((x+9,y+12),line,font=font,fill=ORANGE,stroke_width=12,stroke_fill=INK,anchor='lt')
        d.text((x,y),line,font=font,fill=CREAM,stroke_width=8,stroke_fill=INK,anchor='lt')
        if id=='T3' and line.startswith('SECRET'):
            for n,char in enumerate('SECRET'):
                xx=x+font.getlength(line[:n])
                d.text((xx,y),char,font=font,fill=RAINBOW[n],anchor='lt')
    block=block.crop(block.getbbox()).rotate(2,resample=Image.Resampling.BICUBIC,expand=True)
    layer.alpha_composite(block,(58,54))
    if id=='T2':
        f=ImageFont.truetype(FONT,74);d=ImageDraw.Draw(layer)
        d.text((1110,323),'!?',font=f,fill=CREAM,stroke_width=6,stroke_fill=INK,anchor='mm')
    if id=='T5':
        d=ImageDraw.Draw(layer);f=ImageFont.truetype(FONT,35)
        s='PLAY WITH FRIENDS';w=int(f.getlength(s))+54;y=315
        d.rounded_rectangle((65,y,65+w,y+66),radius=30,fill=INK,outline='#FFD447',width=3)
        d.text((65+w/2,y+33),s,font=f,fill=CREAM,anchor='mm')
    return layer

def export():
    config=json.loads((ROOT/'selection.json').read_text())
    for folder in ['final','final/art_only','final/text_layers','runner_ups']:(ROOT/folder).mkdir(exist_ok=True,parents=True)
    dimensions={}
    for id,entry in config.items():
        size=(512,512) if id.startswith('ICON') else (1920,1080)
        base=fitted(ROOT/entry['source'],size)
        base.save(ROOT/'final/art_only'/f'{NAMES[id]}.png')
        if id.startswith('ICON'): final=base
        else:
            layer=headline(id);layer.save(ROOT/'final/text_layers'/f'{NAMES[id]}_text.png')
            final=Image.alpha_composite(base.convert('RGBA'),layer).convert('RGB')
        final.save(ROOT/'final'/f'{NAMES[id]}.png')
        dimensions[NAMES[id]]=list(final.size)
        if id=='T4':
            named=final.copy();d=ImageDraw.Draw(named);f=ImageFont.truetype(FONT,32)
            d.text((1490,91),'TYRANT KING',font=f,fill=CREAM,stroke_width=3,stroke_fill=INK,anchor='mm')
            named.save(ROOT/'final/thumb_4_boss_tyrant_king.png')
        for n,runner in enumerate(entry['runners'],1):
            fitted(ROOT/runner,size).save(ROOT/'runner_ups'/f'{id}_runner_{n}.png')
    (ROOT/'final/dimensions.json').write_text(json.dumps(dimensions,indent=2)+'\n')
    preview=Image.new('RGB',(1240,1470),'#121212');d=ImageDraw.Draw(preview)
    f=ImageFont.truetype(FONT,22)
    for i,id in enumerate(['ICON','ICON_ALT']):
        im=Image.open(ROOT/'final'/f'{NAMES[id]}.png');im.thumbnail((260,260));x=20+i*310
        preview.paste(im,(x,45));d.text((x,12),id,font=f,fill='white')
    for i,id in enumerate(['T1','T2','T3','T4','T5']):
        x=20+(i%2)*610;y=335+(i//2)*370
        im=Image.open(ROOT/'final'/f'{NAMES[id]}.png');im.thumbnail((590,332));preview.paste(im,(x,y+25));d.text((x,y),id,font=f,fill='white')
    preview.save(ROOT/'final/contact_sheet.jpg',quality=94)
    print(json.dumps(dimensions,indent=2))

if __name__=='__main__':export()
