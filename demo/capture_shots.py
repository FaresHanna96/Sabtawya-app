"""Phone-sized screenshots of every main screen. Images fill the viewport."""

import os
from pathlib import Path

from playwright.sync_api import sync_playwright

URL = os.environ.get("DEMO_URL", "http://127.0.0.1:55556")
EMAIL = os.environ["DEMO_EMAIL"]
PASSWORD = os.environ["DEMO_PASSWORD"]
OUT = Path(__file__).parent / "shots"
OUT.mkdir(exist_ok=True)

INSERT = """
value => {
  const el = document.activeElement;
  el.focus();
  document.execCommand('insertText', false, value);
}
"""


class Shot:
    def __init__(self, page):
        self.page = page

    def wait(self, ms):
        self.page.wait_for_timeout(ms)

    def semantics(self):
        self.page.evaluate(
            """() => {
              if (document.querySelector('flt-semantics')) return;
              document.querySelector('flt-semantics-placeholder')?.click();
            }"""
        )
        self.wait(250)

    def tap(self, role, name, pause=1800):
        self.semantics()
        self.page.get_by_role(role, name=name).first.dispatch_event("click", timeout=8000)
        self.wait(pause)

    def shot(self, name):
        self.wait(400)
        path = OUT / f"{name}.png"
        self.page.screenshot(path=str(path), full_page=False)
        print(name, path.stat().st_size, flush=True)

    def login_fields(self):
        self.semantics()
        self.page.get_by_role("textbox", name="البريد الإلكتروني").first.evaluate("el => el.focus()")
        self.page.evaluate(INSERT, EMAIL)
        self.page.get_by_role("textbox", name="كلمة المرور").first.evaluate("el => el.focus()")
        self.page.evaluate(INSERT, PASSWORD)

    def back(self):
        self.tap("button", "رجوع", 1200)


def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(channel="chrome", headless=True)
        page = browser.new_context(
            viewport={"width": 390, "height": 844},
            device_scale_factor=2,
            is_mobile=True,
            has_touch=True,
        ).new_page()
        page.goto(URL)
        page.wait_for_selector("flt-semantics-placeholder", state="attached", timeout=120000)
        page.wait_for_timeout(2500)
        app = Shot(page)

        app.shot("01-login")
        app.tap("button", "ليس لديك حساب؟ أنشئ حساباً", 1500)
        app.shot("02-signup")
        app.back()
        app.tap("button", "نسيت كلمة المرور؟", 1500)
        app.shot("03-forgot")
        app.back()

        app.login_fields()
        app.tap("button", "تسجيل الدخول", 5000)
        app.shot("04-home")

        app.tap("tab", "الفصول", 2200)
        app.shot("05-classes")
        app.tap("button", "القديسة فيرينا", 2500)
        app.shot("06-class-detail")
        app.page.mouse.wheel(0, 500)
        app.wait(600)
        app.shot("07-class-detail-children")
        app.back()

        app.tap("tab", "المخدومين", 2200)
        app.shot("08-children")
        app.tap("button", "C105", 2500)
        app.shot("09-child-profile")
        app.page.mouse.wheel(0, 700)
        app.wait(500)
        app.shot("10-child-profile-more")
        app.back()
        app.tap("button", "إضافة مخدوم", 2000)
        app.shot("11-add-child")
        app.back()

        app.tap("tab", "الحضور", 2500)
        app.shot("12-attendance")
        app.page.mouse.wheel(0, 450)
        app.wait(400)
        app.shot("13-attendance-roster")

        app.tap("tab", "المزيد", 1500)
        app.shot("14-more")

        def open_more(label, filename, scroll=0):
            app.tap("tab", "المزيد", 900)
            app.tap("button", label, 2200)
            if scroll:
                app.page.mouse.wheel(0, scroll)
                app.wait(400)
            app.shot(filename)
            app.back()

        open_more("التقارير", "15-reports")
        open_more("سجل الحضور", "16-history")
        open_more("استيراد مخدومين من Excel", "17-import")
        open_more("تصدير Excel", "18-export")
        open_more("طلبات الانضمام", "19-requests")
        open_more("الخدام", "20-servants")
        open_more("تعيين الخدام", "21-assignments")
        open_more("سنوات الحضور", "22-years")
        open_more("الإعدادات", "23-settings", scroll=400)

        browser.close()


if __name__ == "__main__":
    main()
