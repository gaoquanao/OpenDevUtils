#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os
import math

def hex_to_rgb(hex_color):
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

def create_continuous_corner_mask(size, radius):
    """Create Apple-style continuous corner (superellipse) mask"""
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    # Apple uses a continuous corner radius of ~22.37%
    draw.rounded_rectangle([0, 0, size-1, size-1], radius=radius, fill=255)
    return mask

def create_app_icon():
    size = 1024
    
    # Color palette
    NIGHT = hex_to_rgb('#0D1B2A')
    FOREST = hex_to_rgb('#1B4332')
    MINT = hex_to_rgb('#2DD4A8')
    LIME = hex_to_rgb('#73FFB8')
    
    # Apple's continuous corner radius (~22.37% of icon size)
    corner_radius = int(size * 0.2237)
    
    # Step 1: Create the content on a transparent layer
    content = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    content_draw = ImageDraw.Draw(content)
    
    # Background gradient: NIGHT -> FOREST (diagonal)
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * size)
            r = int(NIGHT[0] + (FOREST[0] - NIGHT[0]) * t)
            g = int(NIGHT[1] + (FOREST[1] - NIGHT[1]) * t)
            b = int(NIGHT[2] + (FOREST[2] - NIGHT[2]) * t)
            content_draw.point((x, y), fill=(r, g, b, 255))
    
    # Add subtle radial glow in center
    cx, cy = size // 2, size // 2 - 40
    glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    for radius in range(350, 0, -3):
        alpha = int(25 * (1 - radius / 350))
        glow_draw.ellipse([cx-radius, cy-radius, cx+radius, cy+radius],
                         fill=(MINT[0], MINT[1], MINT[2], alpha))
    content = Image.alpha_composite(content, glow)
    content_draw = ImageDraw.Draw(content)
    
    # Load font
    try:
        font_large = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 320)
        font_small = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 80)
    except:
        font_large = ImageFont.load_default()
        font_small = ImageFont.load_default()
    
    # Draw < / > symbols - measure and center
    bbox_lt = content_draw.textbbox((0, 0), "<", font=font_large)
    bbox_slash = content_draw.textbbox((0, 0), "/", font=font_large)
    bbox_gt = content_draw.textbbox((0, 0), ">", font=font_large)
    
    w_lt = bbox_lt[2] - bbox_lt[0]
    w_slash = bbox_slash[2] - bbox_slash[0]
    w_gt = bbox_gt[2] - bbox_gt[0]
    
    spacing = 40
    total_w = w_lt + spacing + w_slash + spacing + w_gt
    start_x = (size - total_w) // 2
    
    y_sym = 220
    content_draw.text((start_x, y_sym), "<", fill=(*MINT, 255), font=font_large)
    content_draw.text((start_x + w_lt + spacing, y_sym), "/", fill=(*LIME, 255), font=font_large)
    content_draw.text((start_x + w_lt + spacing + w_slash + spacing, y_sym), ">", fill=(*MINT, 255), font=font_large)
    
    # "OpenDevUtils" text
    text_color = (*hex_to_rgb('#F0F5FA'), 230)
    bbox = content_draw.textbbox((0, 0), "OpenDevUtils", font=font_small)
    tw = bbox[2] - bbox[0]
    content_draw.text(((size - tw) // 2, 800), "OpenDevUtils", fill=text_color, font=font_small)
    
    # Step 2: Create the rounded corner mask
    corner_mask = create_continuous_corner_mask(size, corner_radius)
    
    # Step 3: Create the final opaque image with NIGHT background
    final = Image.new('RGB', (size, size), NIGHT)
    
    # Paste content using the corner mask (only inside the rounded rect)
    final.paste(Image.composite(
        content.convert('RGB'),
        Image.new('RGB', (size, size), NIGHT),
        content.split()[3]
    ), mask=corner_mask)
    
    # Save directly to icon.iconset
    iconset_dir = os.path.join(os.path.dirname(__file__), "devUtils", "Assets.xcassets", "icon.iconset")
    os.makedirs(iconset_dir, exist_ok=True)
    
    sizes = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    
    for name, sz in sizes.items():
        resized = final.resize((sz, sz), Image.LANCZOS)
        resized.save(os.path.join(iconset_dir, name))
        print(f"Generated {name} ({sz}x{sz})")
    
    final.save(os.path.join(iconset_dir, "icon_full.png"))
    print(f"Done! icon.iconset ready at {iconset_dir}")

if __name__ == "__main__":
    create_app_icon()
