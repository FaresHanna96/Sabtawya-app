"""Records a phone-sized walkthrough of every screen in the app.

Usage (PowerShell):

    $env:DEMO_EMAIL = "..."; $env:DEMO_PASSWORD = "..."
    python demo/record_demo.py            # writes demo/sabtawya-demo.mp4

Nothing is saved to the database: the attendance toggle is flipped back, and
forms are left with the back button.
"""

import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

import imageio_ffmpeg
from playwright.sync_api import Page, sync_playwright

URL = os.environ.get("DEMO_URL", "http://127.0.0.1:55556")
EMAIL = os.environ["DEMO_EMAIL"]
PASSWORD = os.environ["DEMO_PASSWORD"]

WIDTH, HEIGHT = 390, 844
OUT_DIR = Path(__file__).parent
RAW_DIR = OUT_DIR / "raw"
OUTPUT = OUT_DIR / "sabtawya-demo.mp4"

OVERLAY_JS = """
() => {
  if (window.__demo) return;
  const style = document.createElement('style');
  style.textContent = `
    #demo-caption {
      position: fixed; left: 16px; right: 16px; bottom: 104px; z-index: 2147483647;
      pointer-events: none; direction: rtl; text-align: center;
      font: 700 17px/1.5 "Segoe UI", Tahoma, sans-serif; color: #fff;
      background: rgba(27, 54, 105, .94); border-radius: 16px; padding: 12px 16px;
      box-shadow: 0 8px 24px rgba(0,0,0,.25);
      opacity: 0; transform: translateY(12px); transition: opacity .35s, transform .35s;
    }
    #demo-caption.show { opacity: 1; transform: none; }
    #demo-caption small { display: block; font-weight: 500; font-size: 13px; opacity: .85; }
    #demo-card {
      position: fixed; inset: 0; z-index: 2147483647; pointer-events: none;
      display: flex; flex-direction: column; align-items: center; justify-content: center;
      gap: 14px; direction: rtl; text-align: center; padding: 32px;
      background: linear-gradient(160deg, #1b3669, #2c5aa0); color: #fff;
      font-family: "Segoe UI", Tahoma, sans-serif;
      opacity: 0; transition: opacity .5s;
    }
    #demo-card.show { opacity: 1; }
    #demo-card img { width: 120px; height: 120px; border-radius: 28px; background: #fff;
      object-fit: contain; padding: 8px; }
    #demo-card h1 { margin: 0; font-size: 26px; }
    #demo-card p { margin: 0; font-size: 16px; opacity: .9; line-height: 1.7; }
    #demo-tap {
      position: fixed; z-index: 2147483646; pointer-events: none;
      width: 46px; height: 46px; margin: -23px 0 0 -23px; border-radius: 50%;
      background: rgba(255, 193, 7, .45); border: 2px solid rgba(255, 193, 7, .9);
      opacity: 0; transform: scale(.4); transition: opacity .25s, transform .25s;
    }
    #demo-tap.show { opacity: 1; transform: scale(1); }
  `;
  document.head.appendChild(style);
  const caption = document.createElement('div');
  caption.id = 'demo-caption';
  const card = document.createElement('div');
  card.id = 'demo-card';
  const tapDot = document.createElement('div');
  tapDot.id = 'demo-tap';
  document.body.append(caption, card, tapDot);
  window.__demo = {
    caption(title, sub) {
      if (!title) { caption.classList.remove('show'); return; }
      caption.innerHTML = title + (sub ? `<small>${sub}</small>` : '');
      caption.classList.add('show');
    },
    card(title, body) {
      if (!title) { card.classList.remove('show'); return; }
      card.innerHTML = `<img src="assets/assets/images/logo.png"
        onerror="this.style.display='none'"><h1>${title}</h1><p>${body || ''}</p>`;
      card.classList.add('show');
    },
    tap(x, y) {
      tapDot.style.left = x + 'px';
      tapDot.style.top = y + 'px';
      tapDot.classList.add('show');
      setTimeout(() => tapDot.classList.remove('show'), 450);
    },
  };
}
"""

# The tap dot is decoration only; these are where the controls sit on a
# 390x844 phone, because Flutter's RTL semantics boxes report off-screen.
TAB_X = {"الرئيسية": 351, "الفصول": 273, "المخدومين": 195, "الحضور": 117, "المزيد": 39}


class Demo:
    def __init__(self, page: Page):
        self.page = page
        self.failures: list[str] = []

    # ----------------------------------------------------------- primitives

    def wait(self, ms: int):
        self.page.wait_for_timeout(ms)

    def semantics(self):
        # The placeholder toggles the tree. Click it only while it is still off.
        self.page.evaluate(
            """() => {
              if (document.querySelector('flt-semantics')) return;
              const p = document.querySelector('flt-semantics-placeholder');
              if (p) p.click();
            }"""
        )
        self.wait(200)

    def overlay(self):
        self.page.evaluate(OVERLAY_JS)

    def caption(self, title: str | None, sub: str | None = None):
        self.overlay()
        self.page.evaluate("([t, s]) => window.__demo.caption(t, s)", [title, sub])

    def card(self, title: str | None, body: str | None = None):
        self.overlay()
        self.page.evaluate("([t, b]) => window.__demo.card(t, b)", [title, body])

    def dot(self, x: float, y: float):
        self.overlay()
        self.page.evaluate("([x, y]) => window.__demo.tap(x, y)", [x, y])

    def tap(self, selector: str, has_text: str | None = None, dot=None, pause=1400):
        self.semantics()
        if selector.startswith("role:"):
            role, name = selector.split(":", 2)[1:]
            locator = self.page.get_by_role(role, name=name)
        else:
            locator = self.page.locator(selector)
            if has_text is not None:
                locator = locator.filter(has_text=has_text)
        if dot:
            self.dot(*dot)
            self.wait(200)
        locator.first.dispatch_event("click", timeout=8_000)
        self.wait(pause)

    def button(self, text: str, dot=None, pause=1400):
        self.tap(f"role:button:{text}", dot=dot, pause=pause)

    def tab(self, name: str, pause=2200):
        self.tap(f"role:tab:{name}", dot=(TAB_X[name], 800), pause=pause)

    def chip(self, text: str, pause=1400):
        self.tap(f"role:checkbox:{text}", pause=pause)

    def back(self):
        self.tap("role:button:رجوع", dot=(360, 42))

    def scroll(self, dy: int, steps: int = 12, y: int = 430):
        self.page.mouse.move(WIDTH / 2, y)
        for _ in range(steps):
            self.page.mouse.wheel(0, dy / steps)
            self.wait(45)
        self.wait(700)

    def type_into(self, label: str, text: str, delay=70):
        self.semantics()
        field = self.page.get_by_role("textbox", name=label).first
        field.evaluate("el => el.focus()")
        self.wait(80)
        if text == "":
            field.evaluate(
                """el => {
                  el.focus();
                  el.value = '';
                  el.dispatchEvent(new Event('input', { bubbles: true }));
                }"""
            )
            return
        # insertText reaches Flutter; a real click misses these off-screen inputs.
        self.page.evaluate(
            """value => {
              const el = document.activeElement;
              el.focus();
              document.execCommand('insertText', false, value);
            }""",
            text,
        )
        self.wait(max(delay * min(len(text), 8), 200))

    def step(self, name: str, action):
        try:
            action()
        except Exception as error:  # noqa: BLE001 - keep recording the rest
            message = str(error).splitlines()[0]
            self.failures.append(f"{name}: {message}")
            print(f"!! {name}: {message}", flush=True)
            self.page.keyboard.press("Escape")
            self.wait(800)

    # -------------------------------------------------------------- scenes

    def intro(self):
        self.card(
            "خدمة 3:6 ابتدائي السبت",
            "نظام إدارة الحضور والدرجات<br>جولة سريعة في كل مميزات التطبيق",
        )
        self.wait(3800)
        self.card(None)
        self.wait(600)

    def login(self):
        self.semantics()
        self.caption("تسجيل الدخول", "كل خادم يدخل بحسابه ويرى فصله فقط")
        self.wait(1500)
        self.type_into("البريد الإلكتروني", EMAIL, delay=45)
        self.wait(400)
        self.type_into("كلمة المرور", PASSWORD, delay=55)
        self.wait(700)
        self.button("تسجيل الدخول", dot=(195, 571), pause=6500)
        self.semantics()

    def dashboard(self):
        self.caption("الرئيسية", "ملخص المخدومين والفصول والخدام وإجمالي النقاط")
        self.wait(3200)
        self.scroll(420)
        self.caption("إجراءات سريعة وأداء الفصول", "ترتيب الفصول حسب نسبة الحضور")
        self.wait(2800)
        self.scroll(500)
        self.wait(1500)
        self.scroll(-1200, steps=16)

    def classes(self):
        self.tab("الفصول")
        self.caption("الفصول", "كل فصل بشفيعه وعدد الأولاد والبنات وآخر سبت")
        self.wait(2800)
        self.scroll(450)
        self.wait(1000)
        self.scroll(-450)
        self.button("القديسة فيرينا", dot=(195, 200), pause=2600)
        self.caption("تفاصيل الفصل", "الإحصائيات، الشفيع، الخدام المعينون والمخدومين")
        self.wait(2800)
        self.scroll(500)
        self.wait(1800)
        self.scroll(500)
        self.wait(1500)
        self.back()

    def children(self):
        self.tab("المخدومين")
        self.caption("المخدومين", "كل مخدوم بكود ثابت يُولَّد تلقائياً")
        self.wait(2800)
        self.caption("البحث", "بالاسم أو الموبايل أو الكود")
        self.type_into("ابحث بالاسم أو الموبايل أو الكود", "مينا", delay=160)
        self.wait(2600)
        self.type_into("ابحث بالاسم أو الموبايل أو الكود", "", delay=0)
        self.wait(1200)
        self.caption("الفلترة", "حسب الفصل أو النوع، مع إظهار غير النشطين والترتيب")
        self.chip("بنات")
        self.wait(1500)
        self.chip("أولاد")
        self.wait(1500)
        self.chip("5 ولاد")
        self.wait(1800)
        self.chip("الكل")
        self.wait(1000)

    def child_profile(self):
        self.button("C105", dot=(195, 430), pause=3000)
        self.caption("ملف المخدوم", "البيانات الشخصية، الوالدين، أب الاعتراف والمدرسة")
        self.wait(3000)
        self.scroll(550)
        self.wait(1800)
        self.caption("درجات وسجل الحضور", "آخر حضور لكل نشاط ونقاط كل سبت")
        self.scroll(600)
        self.wait(1800)
        self.scroll(600)
        self.wait(1800)
        self.back()

    def add_child(self):
        self.button("إضافة مخدوم", dot=(290, 720), pause=2600)
        self.caption("إضافة مخدوم", "صورة، بيانات، والكود يظهر تلقائياً بعد الحفظ")
        self.wait(3200)
        self.scroll(450)
        self.wait(1800)
        self.scroll(500)
        self.wait(1500)
        self.back()

    def attendance(self):
        self.tab("الحضور")
        self.caption("تسجيل الحضور", "مدارس الأحد، عشية، قداس، اعتراف — لكل سبت")
        self.wait(3200)
        self.caption("النقاط تُحسب تلقائياً", "اضغط على النشاط لتسجيله")
        self.button("قداس", dot=(250, 560), pause=1600)
        self.wait(1400)
        self.button("قداس", dot=(250, 560), pause=1200)
        self.caption("تحضير الجميع أو مسح الكل", "مع عدد الحاضرين وإجمالي النقاط")
        self.wait(2600)
        self.button("اختر السبت", dot=(195, 195), pause=2200)
        self.caption("اختيار السبت", "كل سبوت السنة مرتبة بالتاريخ")
        self.wait(2600)
        self.page.keyboard.press("Escape")
        self.wait(1200)
        self.scroll(600)
        self.wait(1800)
        self.scroll(-600)

    def more(self):
        self.tab("المزيد")
        self.caption("المزيد", "التقارير، Excel، وإدارة النظام")
        self.wait(2800)

    def open_more(self, entry: str, title: str, sub: str, extra=None):
        self.tab("المزيد", pause=1200)
        # Exact label first: "الخدام" is also a substring of "تعيين الخدام".
        self.semantics()
        self.tap(f"role:button:{entry}", pause=2600)
        self.caption(title, sub)
        self.wait(3000)
        if extra:
            extra()
        self.back()

    def reports_extra(self):
        self.scroll(500)
        self.wait(1200)
        self.tap("role:tab:تقرير الفصل", dot=(195, 110))
        self.caption("تقرير الفصل", "نسبة حضور كل فصل ونقاطه")
        self.wait(2600)
        self.tap("role:tab:التقرير الشهري", dot=(70, 110))
        self.caption("التقرير الشهري", "ترتيب المخدومين في كل شهر")
        self.wait(2600)

    def history_extra(self):
        self.chip("السبوت القادمة")
        self.caption("السبوت القادمة", "بالترتيب من الأقرب للأبعد")
        self.wait(2600)
        self.scroll(500)
        self.wait(1200)

    def export_extra(self):
        self.scroll(450)
        self.wait(1500)

    def settings_extra(self):
        self.scroll(500)
        self.wait(1500)

    def outro(self):
        self.caption(None)
        self.wait(400)
        self.card(
            "خدمة 3:6 ابتدائي السبت",
            "حضور • درجات • تقارير • Excel • إدارة الخدام",
        )
        self.wait(3800)

    def run(self):
        scenes = [
            ("intro", self.intro),
            ("login", self.login),
            ("dashboard", self.dashboard),
            ("classes", self.classes),
            ("children", self.children),
            ("child profile", self.child_profile),
            ("add child", self.add_child),
            ("attendance", self.attendance),
            ("more", self.more),
            ("reports", lambda: self.open_more(
                "التقارير", "التقارير", "الترتيب العام للمخدومين على مدار السنة",
                self.reports_extra)),
            ("history", lambda: self.open_more(
                "سجل الحضور", "سجل الحضور", "كل سبت وعدد الحاضرين والنقاط",
                self.history_extra)),
            ("import", lambda: self.open_more(
                "استيراد مخدومين من Excel", "استيراد من Excel",
                "ملف نموذج جاهز، ومراجعة قبل الحفظ")),
            ("export", lambda: self.open_more(
                "تصدير Excel", "تصدير Excel",
                "قائمة المخدومين، كشف سبت، الحضور الشهري والسنوي",
                self.export_extra)),
            ("requests", lambda: self.open_more(
                "طلبات الانضمام", "طلبات الانضمام",
                "أمين الخدمة يقبل أو يرفض الخدام الجدد")),
            ("servants", lambda: self.open_more(
                "الخدام", "الخدام", "دعوة خادم جديد، تنشيط أو إلغاء تنشيط")),
            ("assignments", lambda: self.open_more(
                "تعيين الخدام", "تعيين الخدام", "كل خادم على فصل واحد فقط")),
            ("years", lambda: self.open_more(
                "سنوات الحضور", "سنوات الحضور",
                "نقاط كل نشاط وإنشاء جلسات السبوت")),
            ("settings", lambda: self.open_more(
                "الإعدادات", "الإعدادات", "الملف الشخصي وسنة الحضور وتسجيل الخروج",
                self.settings_extra)),
            ("outro", self.outro),
        ]
        for name, action in scenes:
            print(f"-- {name}", flush=True)
            self.step(name, action)
            if name == "login" and self.failures:
                print("Login failed; stopping.", flush=True)
                return


def encode(webm: Path, start: float):
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    subprocess.run(
        [
            ffmpeg, "-y", "-ss", f"{max(start, 0):.2f}", "-i", str(webm),
            "-vf", "scale=780:1688:flags=lanczos,fps=30",
            "-c:v", "libx264", "-preset", "slow", "-crf", "20",
            "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(OUTPUT),
        ],
        check=True,
    )


def main():
    raw_dir = RAW_DIR
    if raw_dir.exists():
        try:
            shutil.rmtree(raw_dir)
        except OSError:
            raw_dir = OUT_DIR / f"raw-{int(time.time())}"
            print(f"Could not clear {RAW_DIR}; using {raw_dir.name}", flush=True)
    with sync_playwright() as p:
        browser = p.chromium.launch(channel="chrome", headless=True)
        context = browser.new_context(
            viewport={"width": WIDTH, "height": HEIGHT},
            device_scale_factor=2,
            is_mobile=True,
            has_touch=True,
            record_video_dir=str(raw_dir),
            record_video_size={"width": WIDTH * 2, "height": HEIGHT * 2},
        )
        page = context.new_page()
        started = time.monotonic()
        page.goto(URL)
        page.wait_for_selector(
            "flt-semantics-placeholder", state="attached", timeout=120_000
        )
        page.wait_for_timeout(2500)
        ready = time.monotonic() - started

        demo = Demo(page)
        demo.run()

        video = page.video
        context.close()
        browser.close()
        webm = Path(video.path())

    encode(webm, ready - 0.2)
    print(f"\nSaved {OUTPUT}")
    if demo.failures:
        print("Scenes with problems:")
        for failure in demo.failures:
            print(f"  - {failure}")
        if len(demo.failures) > 3:
            sys.exit(1)


if __name__ == "__main__":
    main()
