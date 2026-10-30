import os
from playwright.sync_api import sync_playwright

URL = "http://127.0.0.1:55556"
EMAIL = os.environ["DEMO_EMAIL"]
PASSWORD = os.environ["DEMO_PASSWORD"]

SET = """
value => {
  const el = document.activeElement;
  el.focus();
  document.execCommand('insertText', false, value);
}
"""

with sync_playwright() as p:
    browser = p.chromium.launch(channel="chrome", headless=True)
    page = browser.new_context(
        viewport={"width": 390, "height": 844}, is_mobile=True, device_scale_factor=2
    ).new_page()
    page.goto(URL)
    page.wait_for_selector("flt-semantics-placeholder", state="attached", timeout=120000)
    page.wait_for_timeout(2500)
    page.evaluate("() => { if (!document.querySelector('flt-semantics')) document.querySelector('flt-semantics-placeholder')?.click() }")
    page.wait_for_timeout(400)
    page.get_by_role("textbox", name="البريد الإلكتروني").evaluate("el => el.focus()")
    page.evaluate(SET, EMAIL)
    page.get_by_role("textbox", name="كلمة المرور").evaluate("el => el.focus()")
    page.evaluate(SET, PASSWORD)
    page.locator('flt-semantics[role="button"][aria-label="تسجيل الدخول"]').dispatch_event("click")
    page.wait_for_timeout(5000)
    labels = page.evaluate(
        """() => [...document.querySelectorAll('flt-semantics[role="tab"]')].map(el => el.getAttribute('aria-label'))"""
    )
    print("tabs", labels)
    page.mouse.wheel(0, 400)
    page.wait_for_timeout(500)
    labels2 = page.evaluate(
        """() => [...document.querySelectorAll('[role="tab"]')].map(el => el.getAttribute('aria-label') + ' ' + el.tagName)"""
    )
    print("after scroll", labels2)
    page.locator('flt-semantics[role="tab"][aria-label="الفصول"]').dispatch_event("click", timeout=5000)
    page.wait_for_timeout(2000)
    print("title-ish", page.evaluate("() => document.body.innerText.slice(0, 120)"))
    page.screenshot(path="demo/tab-check.png")
    browser.close()
