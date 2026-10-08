import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

os.makedirs("/Users/amodkanthe/key_hide_examples/play_store_assets", exist_ok=True)
OUT_DIR = "/Users/amodkanthe/key_hide_examples/play_store_assets"

FONT_PATH = "/System/Library/Fonts/Supplemental/Arial.ttf"
if not os.path.exists(FONT_PATH):
    FONT_PATH = "/System/Library/Fonts/Helvetica.ttc"

def get_font(size, bold=False):
    try:
        return ImageFont.truetype(FONT_PATH, size)
    except Exception:
        return ImageFont.load_default()

def draw_gradient(draw, width, height, col_top, col_bot):
    for y in range(height):
        r = int(col_top[0] + (col_bot[0] - col_top[0]) * (y / height))
        g = int(col_top[1] + (col_bot[1] - col_top[1]) * (y / height))
        b = int(col_top[2] + (col_bot[2] - col_top[2]) * (y / height))
        draw.line([(0, y), (width, y)], fill=(r, g, b))

def draw_shield(draw, cx, cy, radius, fill_color, outline_color, outline_width=6):
    points = [
        (cx, cy - radius),
        (cx + radius * 0.82, cy - radius * 0.65),
        (cx + radius * 0.80, cy + radius * 0.15),
        (cx, cy + radius),
        (cx - radius * 0.80, cy + radius * 0.15),
        (cx - radius * 0.82, cy - radius * 0.65),
    ]
    draw.polygon(points, fill=fill_color, outline=outline_color)
    if outline_width > 1:
        for w in range(outline_width):
            scaled_pts = []
            scale = 1.0 - (w * 0.015)
            for px, py in points:
                scaled_pts.append((cx + (px - cx) * scale, cy + (py - cy) * scale))
            draw.polygon(scaled_pts, outline=outline_color)

def draw_keyhole(draw, cx, cy, size, color):
    r = size * 0.4
    draw.ellipse([cx - r, cy - size * 0.6, cx + r, cy + size * 0.2], fill=color)
    trap = [
        (cx - size * 0.22, cy),
        (cx + size * 0.22, cy),
        (cx + size * 0.35, cy + size * 0.7),
        (cx - size * 0.35, cy + size * 0.7),
    ]
    draw.polygon(trap, fill=color)

# ==========================================
# 1. APP ICON: 512 x 512
# ==========================================
def generate_icon():
    w, h = 512, 512
    img = Image.new("RGBA", (w, h), (10, 15, 30, 255))
    draw = ImageDraw.Draw(img)
    draw_gradient(draw, w, h, (11, 19, 43), (5, 9, 20))
    
    # Outer subtle rounded glow
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse([80, 80, 432, 432], fill=(6, 182, 212, 45))
    glow = glow.filter(ImageFilter.GaussianBlur(35))
    img.paste(Image.alpha_composite(img.convert("RGBA"), glow))
    draw = ImageDraw.Draw(img)

    # Shield
    draw_shield(draw, 256, 240, 150, (15, 28, 64), (14, 165, 233), outline_width=8)
    draw_shield(draw, 256, 240, 130, (20, 38, 85), (56, 189, 248), outline_width=4)
    draw_keyhole(draw, 256, 235, 60, (241, 245, 249))

    # Bottom text badge
    font_bold = get_font(26)
    draw.text((256, 420), "OBFS DEMO", font=font_bold, fill=(248, 250, 252), anchor="mm")
    font_sub = get_font(15)
    draw.text((256, 445), "VAULT INTEGRITY", font=font_sub, fill=(56, 189, 248), anchor="mm")

    path = os.path.join(OUT_DIR, "icon_512x512.png")
    img.save(path, "PNG")
    print("Saved icon:", path)

# ==========================================
# 2. FEATURE GRAPHIC: 1024 x 500
# ==========================================
def generate_feature_graphic():
    w, h = 1024, 500
    img = Image.new("RGBA", (w, h), (10, 15, 30, 255))
    draw = ImageDraw.Draw(img)
    draw_gradient(draw, w, h, (10, 17, 40), (4, 8, 18))

    # Subtle cyan radial glow on right side
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse([650, 50, 1050, 450], fill=(14, 165, 233, 40))
    gdraw.ellipse([100, 100, 450, 450], fill=(99, 102, 241, 25))
    glow = glow.filter(ImageFilter.GaussianBlur(50))
    img.paste(Image.alpha_composite(img.convert("RGBA"), glow))
    draw = ImageDraw.Draw(img)

    # Accent decorative lines
    for i in range(5):
        y = 80 + i * 80
        draw.line([(60, y), (500, y)], fill=(30, 41, 59, 120), width=1)

    # Left content: Titles and Badges
    badge_bg = [60, 90, 240, 122]
    draw.rounded_rectangle(badge_bg, radius=8, fill=(30, 58, 138), outline=(56, 189, 248), width=2)
    font_badge = get_font(14)
    draw.text((150, 106), "PLAY INTEGRITY SECURE", font=font_badge, fill=(224, 242, 254), anchor="mm")

    font_title = get_font(46)
    draw.text((60, 150), "Obfs Demo Vault", font=font_title, fill=(255, 255, 255))

    font_sub = get_font(21)
    draw.text((60, 220), "Signature-Bound Cryptographic Key Shield", font=font_sub, fill=(56, 189, 248))

    font_desc = get_font(16)
    draw.text((60, 265), "• Runtime App Signature verification (SHA-256)", font=font_desc, fill=(148, 163, 184))
    draw.text((60, 295), "• AES-256-GCM zero-trust key unlocking", font=font_desc, fill=(148, 163, 184))
    draw.text((60, 325), "• Compatible with Google Play App Signing", font=font_desc, fill=(148, 163, 184))

    # Metric tags
    tag1 = [60, 380, 220, 425]
    draw.rounded_rectangle(tag1, radius=6, fill=(15, 23, 42), outline=(51, 65, 85), width=1)
    draw.text((140, 402), "SHA-256 VAULT", font=get_font(13), fill=(125, 211, 252), anchor="mm")

    tag2 = [235, 380, 415, 425]
    draw.rounded_rectangle(tag2, radius=6, fill=(15, 23, 42), outline=(51, 65, 85), width=1)
    draw.text((325, 402), "OBFUSCATION READY", font=get_font(13), fill=(167, 139, 250), anchor="mm")

    # Right side: Shield Graphics
    draw_shield(draw, 780, 245, 140, (17, 34, 77), (14, 165, 233), outline_width=8)
    draw_shield(draw, 780, 245, 115, (23, 46, 102), (56, 189, 248), outline_width=4)
    draw_keyhole(draw, 780, 240, 55, (255, 255, 255))

    path = os.path.join(OUT_DIR, "feature_graphic_1024x500.png")
    img.save(path, "PNG")
    print("Saved feature graphic:", path)

# ==========================================
# 3. PHONE SCREENSHOT 1: 1080 x 2400
# ==========================================
def generate_screenshot_1():
    w, h = 1080, 2400
    img = Image.new("RGBA", (w, h), (10, 15, 30, 255))
    draw = ImageDraw.Draw(img)
    draw_gradient(draw, w, h, (10, 18, 42), (4, 8, 18))

    # Top banner header
    draw.text((w // 2, 160), "SIGNATURE-BOUND SECURITY", font=get_font(38), fill=(56, 189, 248), anchor="mm")
    draw.text((w // 2, 235), "Runtime SHA-256 Anti-Tamper Verification", font=get_font(52), fill=(255, 255, 255), anchor="mm")
    draw.text((w // 2, 305), "Keys unlock ONLY when executed with verified Play Store certificate", font=get_font(28), fill=(148, 163, 184), anchor="mm")

    # Phone Frame
    px, py, pw, ph = 120, 390, 840, 1880
    draw.rounded_rectangle([px, py, px + pw, py + ph], radius=50, fill=(15, 23, 42), outline=(56, 189, 248), width=6)
    # Notch/speaker
    draw.rounded_rectangle([px + pw // 2 - 90, py + 20, px + pw // 2 + 90, py + 42], radius=11, fill=(30, 41, 59))

    # Inside App Screen
    # App Bar
    draw.rectangle([px + 8, py + 60, px + pw - 8, py + 180], fill=(30, 41, 59))
    draw.text((px + 50, py + 120), "Obfs Demo — Key Vault", font=get_font(34), fill=(255, 255, 255), anchor="lm")
    draw_shield(draw, px + pw - 70, py + 120, 28, (14, 165, 233), (255, 255, 255), outline_width=2)

    # Card 1: Vault Status
    c1_y = py + 230
    draw.rounded_rectangle([px + 40, c1_y, px + pw - 40, c1_y + 360], radius=24, fill=(22, 101, 52, 60), outline=(34, 197, 94), width=3)
    draw.text((px + 70, c1_y + 60), "VAULT STATUS: ACTIVE & UNLOCKED", font=get_font(28), fill=(74, 222, 128))
    draw.text((px + 70, c1_y + 120), "Algorithm: AES-256-GCM + PBKDF2 (100k iter)", font=get_font(24), fill=(226, 232, 240))
    draw.text((px + 70, c1_y + 170), "Secret ID: STRIPE_API_LIVE_KEY", font=get_font(24), fill=(203, 213, 225))
    draw.text((px + 70, c1_y + 220), "Protected Payload: [Decrypted In-Memory Only]", font=get_font(24), fill=(56, 189, 248))
    draw.text((px + 70, c1_y + 280), "State: Verified Matching Release Fingerprint", font=get_font(22), fill=(148, 163, 184))

    # Card 2: Live Diagnostic Panel
    c2_y = c1_y + 400
    draw.rounded_rectangle([px + 40, c2_y, px + pw - 40, c2_y + 700], radius=24, fill=(15, 23, 42), outline=(51, 65, 85), width=2)
    draw.text((px + 70, c2_y + 50), "RUNTIME CERTIFICATE DIAGNOSTICS", font=get_font(28), fill=(56, 189, 248))
    draw.line([(px + 70, c2_y + 85), (px + pw - 70, c2_y + 85)], fill=(51, 65, 85), width=2)

    lines = [
        ("Package Name:", "com.demo.obfs_demo"),
        ("Source:", "MethodChannel: getCertFingerprint"),
        ("Active Fingerprint (SHA-256):", ""),
        ("1F:E0:6A:E6:09:6D:D8:78:40:A0:6A:09...", "(Play Store / Upload Key)"),
        ("Certificate Subject:", "CN=ObfsDemo, OU=Dev, O=Demo, C=IN"),
        ("Play App Signing Mode:", "DUAL-MODE SECURE"),
        ("APK Tamper Check:", "PASSED (Original Signing Chain)"),
    ]
    curr_y = c2_y + 120
    for title, val in lines:
        draw.text((px + 70, curr_y), title, font=get_font(22), fill=(148, 163, 184))
        if val:
            draw.text((px + 70, curr_y + 35), val, font=get_font(22), fill=(241, 245, 249))
            curr_y += 75
        else:
            curr_y += 40

    # Card 3: Action Buttons
    c3_y = c2_y + 740
    btn1 = [px + 50, c3_y, px + (pw // 2) - 15, c3_y + 90]
    draw.rounded_rectangle(btn1, radius=18, fill=(14, 165, 233))
    draw.text((px + (pw // 4) + 15, c3_y + 45), "RE-VERIFY SHA", font=get_font(22), fill=(255, 255, 255), anchor="mm")

    btn2 = [px + (pw // 2) + 15, c3_y, px + pw - 50, c3_y + 90]
    draw.rounded_rectangle(btn2, radius=18, fill=(30, 41, 59), outline=(71, 85, 105), width=2)
    draw.text((px + (3 * pw // 4) - 15, c3_y + 45), "COPY DIAGNOSTICS", font=get_font(22), fill=(226, 232, 240), anchor="mm")

    path = os.path.join(OUT_DIR, "screenshot_phone_1.png")
    img.save(path, "PNG")
    print("Saved screenshot 1:", path)

# ==========================================
# 4. PHONE SCREENSHOT 2: 1080 x 2400
# ==========================================
def generate_screenshot_2():
    w, h = 1080, 2400
    img = Image.new("RGBA", (w, h), (10, 15, 30, 255))
    draw = ImageDraw.Draw(img)
    draw_gradient(draw, w, h, (10, 18, 42), (4, 8, 18))

    # Top banner header
    draw.text((w // 2, 160), "ZERO-TRUST SECRET MANAGEMENT", font=get_font(38), fill=(168, 85, 247), anchor="mm")
    draw.text((w // 2, 235), "Dual-Mode Play App Signing Architecture", font=get_font(52), fill=(255, 255, 255), anchor="mm")
    draw.text((w // 2, 305), "Protects both Debug testing and Play Store distributed builds", font=get_font(28), fill=(148, 163, 184), anchor="mm")

    # Phone Frame
    px, py, pw, ph = 120, 390, 840, 1880
    draw.rounded_rectangle([px, py, px + pw, py + ph], radius=50, fill=(15, 23, 42), outline=(168, 85, 247), width=6)
    draw.rounded_rectangle([px + pw // 2 - 90, py + 20, px + pw // 2 + 90, py + 42], radius=11, fill=(30, 41, 59))

    # Inside App Screen
    # App Bar
    draw.rectangle([px + 8, py + 60, px + pw - 8, py + 180], fill=(30, 41, 59))
    draw.text((px + 50, py + 120), "Security Inspection Log", font=get_font(34), fill=(255, 255, 255), anchor="lm")

    # Architecture Diagram Card
    c1_y = py + 220
    draw.rounded_rectangle([px + 40, c1_y, px + pw - 40, c1_y + 440], radius=24, fill=(24, 24, 27), outline=(82, 82, 91), width=2)
    draw.text((px + 70, c1_y + 50), "DUAL KEY SECURITY MODEL", font=get_font(26), fill=(192, 132, 252))

    # Step 1
    draw.rounded_rectangle([px + 70, c1_y + 90, px + pw - 70, c1_y + 180], radius=14, fill=(39, 39, 42))
    draw.text((px + 100, c1_y + 120), "1. Development (Debug SHA)", font=get_font(22), fill=(244, 244, 245))
    draw.text((px + 100, c1_y + 152), "Unlocks using local debug certificate for developers", font=get_font(18), fill=(161, 161, 170))

    # Step 2
    draw.rounded_rectangle([px + 70, c1_y + 200, px + pw - 70, c1_y + 290], radius=14, fill=(39, 39, 42))
    draw.text((px + 100, c1_y + 230), "2. Play Store (App Signing SHA)", font=get_font(22), fill=(56, 189, 248))
    draw.text((px + 100, c1_y + 262), "Unlocks using Google-managed app signing key on users' devices", font=get_font(18), fill=(161, 161, 170))

    # Step 3
    draw.rounded_rectangle([px + 70, c1_y + 310, px + pw - 70, c1_y + 400], radius=14, fill=(69, 10, 10, 120), outline=(239, 68, 68), width=1)
    draw.text((px + 100, c1_y + 340), "3. Tampered / Re-signed APK", font=get_font(22), fill=(248, 113, 113))
    draw.text((px + 100, c1_y + 372), "Decryption fails. Ciphertext cannot be extracted by attackers", font=get_font(18), fill=(254, 202, 202))

    # Log Card
    c2_y = c1_y + 480
    draw.rounded_rectangle([px + 40, c2_y, px + pw - 40, c2_y + 700], radius=24, fill=(9, 9, 11), outline=(39, 39, 42), width=2)
    draw.text((px + 70, c2_y + 50), "LOGCAT LIVE VERIFICATION", font=get_font(26), fill=(74, 222, 128))
    draw.line([(px + 70, c2_y + 85), (px + pw - 70, c2_y + 85)], fill=(39, 39, 42), width=2)

    log_entries = [
        "[INFO] SignatureVault Initialized",
        "[INFO] Calling MethodChannel getCertFingerprint",
        "[DEBUG] SigningInfo mode: POST-P signingChain",
        "[DEBUG] Fingerprint extracted: 1F:E0:6A:E6...",
        "[DEBUG] KDF: Derived 256-bit AES key via PBKDF2",
        "[SUCCESS] Vault decrypted payload in 12ms",
        "[AUDIT] Integrity verified: Production Certified",
    ]
    ly = c2_y + 120
    for l in log_entries:
        col = (74, 222, 128) if "SUCCESS" in l else ((56, 189, 248) if "INFO" in l else (212, 212, 216))
        draw.text((px + 70, ly), l, font=get_font(20), fill=col)
        ly += 65

    path = os.path.join(OUT_DIR, "screenshot_phone_2.png")
    img.save(path, "PNG")
    print("Saved screenshot 2:", path)

# ==========================================
# 5. TABLET SCREENSHOTS (7-inch: 1200x1920, 10-inch: 1600x2560)
# ==========================================
def generate_tablet_screenshots():
    # 7-inch
    w, h = 1200, 1920
    img = Image.new("RGBA", (w, h), (10, 15, 30, 255))
    draw = ImageDraw.Draw(img)
    draw_gradient(draw, w, h, (10, 18, 42), (4, 8, 18))
    draw.text((w // 2, 140), "TABLET SECURITY AUDIT DASHBOARD", font=get_font(42), fill=(56, 189, 248), anchor="mm")
    draw.text((w // 2, 205), "Comprehensive Signature & Cryptographic Vault Testing", font=get_font(26), fill=(226, 232, 240), anchor="mm")
    
    # Tablet Frame
    draw.rounded_rectangle([100, 280, 1100, 1780], radius=36, fill=(15, 23, 42), outline=(56, 189, 248), width=5)
    draw.text((w // 2, 350), "Obfs Demo Tablet Suite", font=get_font(32), fill=(255, 255, 255), anchor="mm")
    draw_shield(draw, w // 2, 540, 110, (20, 38, 85), (56, 189, 248), outline_width=6)
    draw_keyhole(draw, w // 2, 535, 45, (255, 255, 255))
    
    # Details card
    draw.rounded_rectangle([160, 720, 1040, 1680], radius=20, fill=(24, 24, 27), outline=(63, 63, 70), width=2)
    draw.text((200, 780), "• Dual-Mode Certificate Signing Protection", font=get_font(26), fill=(244, 244, 245))
    draw.text((200, 850), "• Android 15 & API 28+ SigningInfo Multi-Cert Support", font=get_font(26), fill=(244, 244, 245))
    draw.text((200, 920), "• Google Play App Signing Re-Signature Resilience", font=get_font(26), fill=(244, 244, 245))
    draw.text((200, 990), "• Zero Hardcoded Plaintext Secrets in APK Binary", font=get_font(26), fill=(74, 222, 128))
    
    p7 = os.path.join(OUT_DIR, "screenshot_tablet_7in.png")
    img.save(p7, "PNG")
    print("Saved 7-in tablet screenshot:", p7)

    # 10-inch
    w10, h10 = 1600, 2560
    img10 = img.resize((w10, h10), Image.Resampling.LANCZOS)
    p10 = os.path.join(OUT_DIR, "screenshot_tablet_10in.png")
    img10.save(p10, "PNG")
    print("Saved 10-in tablet screenshot:", p10)

generate_icon()
generate_feature_graphic()
generate_screenshot_1()
generate_screenshot_2()
generate_tablet_screenshots()
