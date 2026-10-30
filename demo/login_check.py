import os
from playwright.sync_api import sync_playwright

URL = "http://127.0.0.1:55556"
EMAIL = os.environ["DEMO_EMAIL"]
PASSWORD = os.environ["DEMO_PASSWORD"]

SET = """
(value) => {
  const el = document.activeElement;
  el.focus();
  el.value = '';
  document.execCommand('insertText', false, value);
  return el.getAttribute('aria-label') + '=' + el.value;
}
"""

with sync_playwright() as p:
    browser = p.chromium.launch(channel="chrome", headless=True)
    page = browser.new_context(
        viewport={"width": 390, "height": 844},
        device_scale_factor=2,
        is_mobile=True,
    ).new_page()
    page.goto(URL)
    page.wait_for_selector("flt-semantics-placeholder", state="attached", timeout=120000)
    page.wait_for_timeout(3000)
    page.evaluate("() => document.querySelector('flt-semantics-placeholder')?.click()")
    page.wait_for_timeout(500)
    page.get_by_role("textbox", name="البريد الإلكتروني").evaluate("el => el.focus()")
    print("email", page.evaluate(SET, EMAIL))
    page.get_by_role("textbox", name="كلمة المرور").evaluate("el => el.focus()")
    print("pass", page.evaluate(SET, PASSWORD))
    page.get_by_role("button", name="تسجيل الدخول").dispatch_event("click")
    page.wait_for_timeout(6000)
    page.evaluate("() => document.querySelector('flt-semantics-placeholder')?.click()")
    page.wait_for_timeout(400)
    print("tabs", page.locator('flt-semantics[role="tab"]').count())
    page.screenshot(path="demo/login-check.png")
    browser.close()
