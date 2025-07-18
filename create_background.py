from PIL import Image, ImageDraw, ImageFont
import os

# Rozměry DMG okna
width, height = 600, 400
bg_color = (245, 245, 245)  # Světle šedá
text_color = (100, 100, 100)
arrow_color = (0, 122, 255)  # Modrá Apple

# Vytvoření obrázku
img = Image.new('RGB', (width, height), bg_color)
draw = ImageDraw.Draw(img)

# Pozice ikon (musí odpovídat AppleScript)
app_x, app_y = 150, 180
folder_x, folder_y = 450, 180

# Kreslení šipky mezi ikonami
arrow_start_x = app_x + 80
arrow_end_x = folder_x - 80
arrow_y = app_y + 50

# Šipka
draw.line((arrow_start_x, arrow_y, arrow_end_x, arrow_y), fill=arrow_color, width=4)
# Šipka hlavička
draw.polygon([
    (arrow_end_x, arrow_y),
    (arrow_end_x - 15, arrow_y - 8),
    (arrow_end_x - 15, arrow_y + 8)
], fill=arrow_color)

# Text instrukce
instruction = "Drag the app to the Applications folder"
try:
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 18)
except:
    font = ImageFont.load_default()

# Vycentrování textu
bbox = draw.textbbox((0, 0), instruction, font=font)
text_width = bbox[2] - bbox[0]
text_x = (width - text_width) // 2
text_y = height - 50

draw.text((text_x, text_y), instruction, fill=text_color, font=font)

# Uložení
img.save('dmg-background.png')
print("✅ Background created")
