"""Logs in at phone size and dumps the accessible elements of every screen."""

import json
import os
import sys

from playwright.sync_api import sync_playwright

URL = os.environ.get("DEMO_URL", "http://127.0.0.1:55555")
EMAIL = os.environ["DEMO_EMAIL"]
PASSWORD = os.environ["DEMO_PASSWORD"]

DUMP_JS = """
() => [...document.querySelectorAll('flt-semantics, input, textarea')]
  .map(el => ({
    role: el.getAttribute('role'),
    label: (el.getAttribute('aria-label') || el.innerText || '').trim()
      .replace(/\\s+/g, ' ').slice(0, 70),
  }))
  .filter(e => e.label && (e.role || true))
"""

MORE_ENTRIES = [
    "التقارير",
    "سجل الحضور",
    "استيراد المخدومين",
    "تصدير",
    "طلبات الانضمام",
    "الخدام",
    "تعيين الخدام",
    "سنوات الحضور",
    "الإعدادات",
]


def enable_semantics(page):
    page.evaluate(
        "() => { const p = document.querySelector('flt-semantics-placeholder');"
        " if (p) p.click(); }"
    )
    page.wait_for_timeout(600)


def dump(page, title):
    enable_semantics(page)
    seen = set()
    print(f"===== {title} =====")
    for item in page.evaluate(DUMP_JS):
        key = (item["role"], item["label"])
        if key in seen:
            continue
        seen.add(key)
        print(json.dumps(item, ensure_ascii=False))
    sys.stdout.flush()


def tap(locator):
    # Flutter's RTL semantics nodes report off-screen boxes, so a positional
    # click misses; the node's own click handler runs the tap action instead.
    locator.first.dispatch_event("click")


def back(page):
    tap(page.get_by_role("button", name="رجوع"))
    page.wait_for_timeout(1500)


with sync_playwright() as p:
    browser = p.chromium.launch(channel="chrome", headless=True)
    context = browser.new_context(
        viewport={"width": 390, "height": 844},
        device_scale_factor=2,
        is_mobile=True,
        has_touch=True,
    )
    page = context.new_page()
    page.goto(URL)
    page.wait_for_selector(
        "flt-semantics-placeholder", state="attached", timeout=120_000
    )
    page.wait_for_timeout(4000)
    enable_semantics(page)
    page.get_by_role("textbox", name="البريد الإلكتروني").fill(EMAIL)
    page.get_by_role("textbox", name="كلمة المرور").fill(PASSWORD)
    tap(page.get_by_role("button", name="تسجيل الدخول"))
    page.wait_for_timeout(6000)

    for tab in ["الرئيسية", "الفصول", "المخدومين", "الحضور", "المزيد"]:
        enable_semantics(page)
        tap(page.get_by_role("tab", name=tab))
        page.wait_for_timeout(3000)
        dump(page, f"tab {tab}")
        page.screenshot(path=f"demo/probe-tab-{tab}.png")

    for entry in MORE_ENTRIES:
        enable_semantics(page)
        try:
            tap(page.get_by_role("tab", name="المزيد"))
            page.wait_for_timeout(800)
            enable_semantics(page)
            tap(page.locator(f'flt-semantics[role="button"]:has-text("{entry}")'))
            page.wait_for_timeout(3500)
            dump(page, f"more {entry}")
            page.screenshot(path=f"demo/probe-more-{entry}.png")
            back(page)
        except Exception as error:  # noqa: BLE001
            print(f"!!!!! {entry}: {error}".splitlines()[0])

    browser.close()
