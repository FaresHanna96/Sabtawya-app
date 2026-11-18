"""Builds a short how-to-update video (Arabic, phone sized) for the servants.

    python demo/build_update_video.py     # writes demo/sabtawya-update.mp4

Plain slides, no login or data needed.
"""
import base64
import shutil
import subprocess
from pathlib import Path

import imageio_ffmpeg
from playwright.sync_api import sync_playwright

HERE = Path(__file__).parent
LOGO = base64.b64encode((HERE.parent / "assets/images/logo.png").read_bytes()).decode()
RAW = HERE / "raw_update"
OUT = HERE / "sabtawya-update.mp4"
VERSION = "1.0.29"

SHOTS = HERE / "shots_feat"

def shot(name):
    return base64.b64encode((SHOTS / f"{name}.png").read_bytes()).decode()

# Real screens (dev project, made-up children): (image, title, body, seconds)
FEATURES = [
    ("01-home", "الصفحة الرئيسية", "أرقام الخدمة وأعياد الميلاد وبيانات ناقصة", 4),
    ("03-attendance", "الحضور", "ورقة الحضور لكل فصل، وتشتغل حتى بدون إنترنت", 4),
    ("05-committed", "ملتزمين", "المخدومين الملتزمين في مكان واحد", 4),
    ("06-birthdays", "أعياد الميلاد", "تهنئة بالواتساب بضغطة", 4),
    ("07-missing-info", "بيانات ناقصة", "شوف مين محتاج يكمّل بياناته", 4),
    ("08-report", "تقرير الطايو", "نسبة الحضور لكل فصل", 4),
    ("09-excel", "تقارير Excel", "تصدير شهري بسهولة", 4),
]

# (icon, title, body, seconds)
SLIDES = [
    ("LOGO", f"تحديث سبتاوية {VERSION}", "خطوات التحديث في دقيقة", 3.5),
    ("🔔", "الجديد", "شاشة «تحديث مطلوب» تظهر عند التحديثات المهمة، علشان الكل يبقى على نفس النسخة", 5),
    ("FEATURES", "", "", 0),
    ("1", "افتح صفحة التحميل", "sabtawya.vercel.app/apk.html", 4.5),
    ("2", "اضغط «تحميل التطبيق»", "لو التحميل ما بدأش اضغط الزر تاني", 4.5),
    ("3", "افتح الملف sabtawya.apk", "من إشعار التحميل أو من «التنزيلات»", 4.5),
    ("4", "«التثبيت من مصادر غير معروفة»؟", "اضغط الإعدادات ← فعّل «السماح من هذا المصدر» ← ارجع واضغط «تثبيت»", 6),
    ("5", "رسالة Play Protect؟", "اضغط «تثبيت على أي حال»", 4),
    ("6", "افتح التطبيق وسجّل الدخول", "بياناتك مش بتضيع، التثبيت فوق القديم", 4.5),
    ("📵", "موبايل قديم والتثبيت فشل؟", "حمّل «موبايل قديم؟» من نفس الصفحة", 4.5),
    ("✅", "تمام!", "أي مشكلة ابعتلي", 3),
]

def feature_html(i, img, title, body):
    return f"""<div class="s f"><img src="data:image/png;base64,{shot(img)}" class="ph">
<h1>{title}</h1><p>{body}</p></div>"""

def slide_html(i, icon, title, body):
    big = (f'<img src="data:image/png;base64,{LOGO}" class="logo">' if icon == "LOGO"
           else f'<div class="badge {"num" if icon.isdigit() else ""}">{icon}</div>')
    dots = "".join(f'<i class="{"on" if k == i else ""}"></i>' for k in range(len(SLIDES)))
    return f"""<div class="s">{big}<h1>{title}</h1><p>{body}</p><div class="dots">{dots}</div></div>"""

PAGE = """<!doctype html><html lang=ar dir=rtl><meta charset=utf-8>
<style>
*{box-sizing:border-box}body{margin:0;height:100vh;font-family:"Segoe UI",Tahoma,sans-serif;
background:linear-gradient(160deg,#1b3669,#2c5aa0);color:#fff;overflow:hidden}
#stage{height:100%}.s{height:100%;display:flex;flex-direction:column;align-items:center;
justify-content:center;gap:22px;padding:36px;text-align:center;animation:in .5s ease both}
@keyframes in{from{opacity:0;transform:translateY(24px)}to{opacity:1;transform:none}}
.logo{width:130px;height:130px;border-radius:30px;background:#fff;padding:10px;object-fit:contain}
.badge{font-size:64px}.badge.num{width:110px;height:110px;border-radius:50%;background:#e8c547;
color:#1b3669;font-weight:800;font-size:60px;display:flex;align-items:center;justify-content:center}
h1{margin:0;font-size:28px;line-height:1.4}p{margin:0;font-size:19px;line-height:1.8;opacity:.92;direction:rtl}
.s.f{gap:10px;padding:18px 24px 40px}.ph{height:62%;border-radius:22px;border:4px solid #ffffff33;
box-shadow:0 10px 30px #0006;object-fit:contain}.s.f h1{font-size:24px}.s.f p{font-size:16px}
.dots{position:fixed;bottom:34px;display:flex;gap:7px}.dots i{width:8px;height:8px;border-radius:50%;background:#ffffff55}
.dots i.on{background:#e8c547}
</style><div id=stage></div>"""

def main():
    shutil.rmtree(RAW, ignore_errors=True)
    with sync_playwright() as p:
        b = p.chromium.launch()
        ctx = b.new_context(viewport={"width": 390, "height": 844},
                            record_video_dir=str(RAW), record_video_size={"width": 390, "height": 844})
        page = ctx.new_page()
        page.set_content(PAGE)
        for i, (icon, title, body, secs) in enumerate(SLIDES):
            if icon == "FEATURES":
                for img, t, cap, sec in FEATURES:
                    page.evaluate("h => document.getElementById('stage').innerHTML = h",
                                  feature_html(i, img, t, cap))
                    page.wait_for_timeout(int(sec * 1000))
                continue
            page.evaluate("h => document.getElementById('stage').innerHTML = h",
                          slide_html(i, icon, title, body))
            page.wait_for_timeout(int(secs * 1000))
        ctx.close()
        b.close()
    webm = next(RAW.glob("*.webm"))
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-i", str(webm), "-c:v", "libx264",
                    "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(OUT)],
                   check=True, capture_output=True)
    shutil.rmtree(RAW, ignore_errors=True)
    print(OUT, round(OUT.stat().st_size / 1024), "KB")

main()
