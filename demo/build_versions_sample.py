"""One picture: what a servant sees on each app version (mock-ups in the app's style;
the first phone is a real capture from the dev project)."""
import base64
from pathlib import Path
from playwright.sync_api import sync_playwright

HERE = Path(__file__).parent
home = base64.b64encode((HERE / "shots_feat/01-home.png").read_bytes()).decode()
MSG = "لازم تحدّث التطبيق: اضغط «تحديث الآن» في الشريط الأخضر أعلى الصفحة الرئيسية، أو افتح sabtawya.vercel.app/apk.html"
OLDMSG = "لازم تحدّث التطبيق: افتح sabtawya.vercel.app/apk.html"

def bar(title="خدمة 3:6 ابتدائي السبت"):
    return f'<div class="bar">{title}</div>'

banner = '<div class="ban"><span>⬇ إصدار جديد متاح (1.0.31)</span><b>تحديث الآن</b></div>'
def err(m): return f'<div class="card err"><div class="x">⚠</div>{m}</div>' * 1

phones = [
  ("1.0.31", "التطبيق شغال عادي، بدون أي شاشة تحديث",
   f'<img src="data:image/png;base64,{home}" style="width:100%;height:100%;object-fit:cover;object-position:top">'),
  ("1.0.29 و 1.0.30", "شاشة «تحديث مطلوب» تغطي التطبيق",
   '<div class="force"><div class="ic">⬇</div><h2>تحديث مطلوب</h2>'
   '<p>لازم تحدّث التطبيق للإصدار 1.0.31 علشان تكمل استخدامه.</p><button>تحديث الآن</button></div>'),
  ("1.0.28 وأقدم (من 1.0.2)", "الرئيسية تفتح مع شريط أخضر، وباقي الشاشات رسالة",
   bar() + banner + '<div class="body">' + err(MSG) + err(MSG) + '</div>'
   + '<div class="nav">الرئيسية · فصلي · المخدومين · الحضور · المزيد</div>'),
  ("قبل 1.0.2", "رسالة بس، بدون زرار. لازم صفحة التحميل",
   bar() + '<div class="body">' + err(OLDMSG) + err(OLDMSG) + '</div>'),
]
html = """<!doctype html><meta charset=utf-8><style>
*{box-sizing:border-box}body{margin:0;background:#eef0f5;font-family:"Segoe UI",Tahoma,sans-serif;direction:rtl}
.row{display:flex;gap:26px;padding:28px;width:max-content}
.col{width:300px;text-align:center}.col h3{margin:0 0 4px;font-size:19px;color:#1b3669}
.col small{display:block;height:36px;color:#555;font-size:13px;line-height:1.4}
.ph{height:600px;border:6px solid #1b3669;border-radius:30px;overflow:hidden;background:#f6f7fb;position:relative;text-align:right}
.bar{background:#1b3669;color:#fff;font-weight:700;padding:14px;text-align:center;font-size:15px}
.ban{background:#8a9a2a;color:#fff;display:flex;justify-content:space-between;align-items:center;padding:9px 12px;font-size:12px;font-weight:700}
.ban b{background:#fff;color:#8a9a2a;border-radius:16px;padding:5px 11px;font-size:11px}
.body{padding:14px}.card{background:#fff;border-radius:14px;padding:14px;margin-bottom:12px;font-size:12.5px;line-height:1.7;box-shadow:0 2px 8px #0001}
.err{border:1px solid #e5b4ad;color:#a33}.x{font-size:18px}
.nav{position:absolute;bottom:0;left:0;right:0;background:#fff;padding:10px;font-size:10px;color:#555;text-align:center}
.force{height:100%;background:linear-gradient(160deg,#1b3669,#2c5aa0);color:#fff;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:12px;padding:26px;text-align:center}
.force .ic{font-size:58px}.force h2{margin:0;font-size:22px}.force p{margin:0;opacity:.85;font-size:14px;line-height:1.7}
.force button{margin-top:10px;background:#fff;color:#1b3669;border:0;border-radius:24px;padding:12px 38px;font-weight:800;font-size:14px}
</style><div class=row>""" + "".join(
    f'<div class=col><h3>{t}</h3><small>{d}</small><div class=ph>{body}</div></div>' for t, d, body in phones) + "</div>"
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={"width": 1400, "height": 720}, device_scale_factor=1.5)
    pg.set_content(html); pg.wait_for_timeout(500)
    pg.screenshot(path=str(HERE / "versions-sample.png"), full_page=True); b.close()
print("ok")
