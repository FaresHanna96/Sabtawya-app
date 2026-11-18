"""Phone screenshots of the newer features, from the DEV project (fake data).

    $env:DEMO_URL="http://127.0.0.1:8095"; $env:DEMO_EMAIL=...; $env:DEMO_PASSWORD=...
    python demo/capture_features.py     # writes demo/shots_feat/*.png
"""
import capture_shots as cs
from pathlib import Path
from playwright.sync_api import sync_playwright

OUT = Path(__file__).parent / "shots_feat"
OUT.mkdir(exist_ok=True)
cs.OUT = OUT


def soft_tap(app, role, name, pause=2200):
    try:
        app.tap(role, name, pause)
        return True
    except Exception as e:  # a label that is not on this build: skip it
        print("skip", name, type(e).__name__)
        return False


def more(app, label, filename, scroll=0):
    app.tap("tab", "المزيد", 900)
    if soft_tap(app, "button", label):
        if scroll:
            app.page.mouse.wheel(0, scroll)
            app.wait(400)
        app.shot(filename)
        app.back()


def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(channel="chrome", headless=True)
        page = browser.new_context(viewport={"width": 390, "height": 844},
                                   device_scale_factor=2, is_mobile=True,
                                   has_touch=True).new_page()
        page.goto(cs.URL)
        page.wait_for_selector("flt-semantics-placeholder", state="attached", timeout=120000)
        page.wait_for_timeout(2500)
        app = cs.Shot(page)
        app.login_fields()
        app.tap("button", "تسجيل الدخول", 6000)
        app.shot("01-home")
        page.mouse.wheel(0, 600)
        app.wait(600)
        app.shot("02-home-chart")
        app.tap("tab", "الحضور", 2500)
        app.shot("03-attendance")
        more(app, "متابعة الغياب", "04-absence-followup")
        more(app, "ملتزمين", "05-committed")
        more(app, "أعياد الميلاد", "06-birthdays")
        more(app, "بيانات ناقصة", "07-missing-info")
        more(app, "تقرير الطايو", "08-report")
        more(app, "تقارير Excel", "09-excel")
        more(app, "سجل النشاط", "10-activity-log")
        browser.close()


if __name__ == "__main__":
    main()
