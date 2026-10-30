"""Feature presentation for خدمة 3:6 ابتدائي السبت."""

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.oxml.ns import qn
from pptx.util import Emu, Inches, Pt

NAVY = RGBColor(0x1B, 0x36, 0x69)
NAVY_SOFT = RGBColor(0x2C, 0x5A, 0xA0)
OLIVE = RGBColor(0x6B, 0x7C, 0x3A)
GOLD = RGBColor(0xC4, 0x8A, 0x1A)
CREAM = RGBColor(0xF4, 0xF6, 0xF8)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
INK = RGBColor(0x1C, 0x24, 0x33)
MUTED = RGBColor(0x5C, 0x6B, 0x7A)
CARD = RGBColor(0xFF, 0xFF, 0xFF)
LINE = RGBColor(0xD5, 0xDC, 0xE6)
DANGER = RGBColor(0xA3, 0x3B, 0x3B)

W, H = Inches(13.333), Inches(7.5)
OUT = r"D:\Projects\sabtawya\demo\sabtawya-features.pptx"


def rtl(paragraph):
    paragraph.alignment = PP_ALIGN.RIGHT
    pPr = paragraph._p.get_or_add_pPr()
    pPr.set("rtl", "1")


def font(run, size, bold=False, color=INK, name="Segoe UI"):
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.color.rgb = color
    run.font.name = name
    rPr = run._r.get_or_add_rPr()
    for tag in ("latin", "cs", "ea"):
        el = rPr.find(qn(f"a:{tag}"))
        if el is None:
            el = rPr.makeelement(qn(f"a:{tag}"), {})
            rPr.append(el)
        el.set("typeface", name)


def add_text(shape, lines, size=18, bold=False, color=INK, align=PP_ALIGN.RIGHT):
    tf = shape.text_frame
    tf.word_wrap = True
    tf.auto_size = None
    for i, line in enumerate(lines):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        if align == PP_ALIGN.RIGHT:
            rtl(p)
        else:
            p.alignment = align
        p.space_after = Pt(6)
        run = p.add_run()
        run.text = line
        font(run, size, bold, color)
    return tf


def rect(slide, x, y, w, h, fill, line=None):
    shape = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, x, y, w, h)
    shape.fill.solid()
    shape.fill.fore_color.rgb = fill
    if line is None:
        shape.line.fill.background()
    else:
        shape.line.color.rgb = line
    shape.adjustments[0] = 0.08
    shape.shadow.inherit = False
    return shape


def bar(slide, color=NAVY):
    shape = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, W, Inches(0.12))
    shape.fill.solid()
    shape.fill.fore_color.rgb = color
    shape.line.fill.background()


def footer(slide, page, total):
    box = slide.shapes.add_textbox(Inches(0.45), Inches(7.12), Inches(12.4), Inches(0.28))
    p = box.text_frame.paragraphs[0]
    p.alignment = PP_ALIGN.LEFT
    run = p.add_run()
    run.text = f"خدمة 3:6 ابتدائي السبت    {page} / {total}"
    font(run, 11, False, MUTED)


def title_block(slide, kicker, title, subtitle=None):
    bar(slide)
    k = slide.shapes.add_textbox(Inches(0.55), Inches(0.32), Inches(12.2), Inches(0.32))
    p = k.text_frame.paragraphs[0]
    rtl(p)
    run = p.add_run()
    run.text = kicker
    font(run, 13, True, NAVY_SOFT)
    t = slide.shapes.add_textbox(Inches(0.5), Inches(0.58), Inches(12.3), Inches(0.62))
    p = t.text_frame.paragraphs[0]
    rtl(p)
    run = p.add_run()
    run.text = title
    font(run, 30, True, NAVY)
    if subtitle:
        s = slide.shapes.add_textbox(Inches(0.55), Inches(1.22), Inches(12.2), Inches(0.4))
        p = s.text_frame.paragraphs[0]
        rtl(p)
        run = p.add_run()
        run.text = subtitle
        font(run, 15, False, MUTED)


def bullets(slide, items, x, y, w, h, size=16):
    box = slide.shapes.add_textbox(x, y, w, h)
    tf = box.text_frame
    tf.word_wrap = True
    for i, item in enumerate(items):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        rtl(p)
        p.level = 0
        p.space_after = Pt(8)
        run = p.add_run()
        run.text = item
        font(run, size, False, INK)
    return box


def card(slide, x, y, w, h, heading, lines, accent=NAVY):
    shape = rect(slide, x, y, w, h, WHITE, LINE)
    shape.text_frame.word_wrap = True
    shape.text_frame.margin_left = Inches(0.18)
    shape.text_frame.margin_right = Inches(0.18)
    shape.text_frame.margin_top = Inches(0.12)
    tf = shape.text_frame
    p = tf.paragraphs[0]
    rtl(p)
    run = p.add_run()
    run.text = heading
    font(run, 16, True, accent)
    for line in lines:
        p = tf.add_paragraph()
        rtl(p)
        p.space_before = Pt(4)
        run = p.add_run()
        run.text = line
        font(run, 13, False, INK)
    return shape


def blank(prs):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    bg = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, W, H)
    bg.fill.solid()
    bg.fill.fore_color.rgb = CREAM
    bg.line.fill.background()
    spTree = slide.shapes._spTree
    sp = bg._element
    spTree.remove(sp)
    spTree.insert(2, sp)
    return slide


def build():
    prs = Presentation()
    prs.slide_width = W
    prs.slide_height = H
    prs.core_properties.title = "خدمة 3:6 ابتدائي السبت — دليل الصفحات والمميزات"
    prs.core_properties.author = "Sabtawya"

    # 1 cover
    s = blank(prs)
    band = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, Inches(0.28), H)
    band.fill.solid()
    band.fill.fore_color.rgb = NAVY
    band.line.fill.background()
    box = s.shapes.add_textbox(Inches(0.8), Inches(1.7), Inches(11.5), Inches(1.1))
    p = box.text_frame.paragraphs[0]
    rtl(p)
    run = p.add_run()
    run.text = "خدمة 3:6 ابتدائي السبت"
    font(run, 40, True, NAVY)
    box = s.shapes.add_textbox(Inches(0.8), Inches(2.85), Inches(11.5), Inches(0.7))
    p = box.text_frame.paragraphs[0]
    rtl(p)
    run = p.add_run()
    run.text = "عرض الصفحات والمميزات والإجراءات لكل نوع مستخدم"
    font(run, 22, False, INK)
    box = s.shapes.add_textbox(Inches(0.8), Inches(3.7), Inches(11), Inches(1.2))
    p = box.text_frame.paragraphs[0]
    rtl(p)
    run = p.add_run()
    run.text = "حضور السبوت  ·  درجات الأنشطة  ·  المخدومين والفصول  ·  التقارير وExcel"
    font(run, 16, False, MUTED)
    chips = ["أمين الخدمة", "الخادم / الخادمة", "حساب بانتظار الموافقة"]
    for i, label in enumerate(chips):
        c = rect(s, Inches(0.8 + i * 3.3), Inches(5.4), Inches(3.0), Inches(0.62), NAVY if i == 0 else WHITE, None if i == 0 else LINE)
        tf = c.text_frame
        tf.paragraphs[0].alignment = PP_ALIGN.CENTER
        c.text_frame.paragraphs[0].clear()
        run = tf.paragraphs[0].add_run()
        run.text = label
        font(run, 15, True, WHITE if i == 0 else NAVY)

    # 2 users
    s = blank(prs)
    title_block(s, "المستخدمون", "ثلاثة أوضاع للحساب", "الصلاحية من الدور، والرؤية من سياسات قاعدة البيانات")
    card(s, Inches(0.45), Inches(1.85), Inches(4.0), Inches(4.7), "أمين الخدمة", [
        "يرى كل الفصول والمخدومين.",
        "يدير الخدام وطلبات الانضمام.",
        "ينشئ الفصول وسنوات الحضور.",
        "يقفل جلسات الحضور ويفتحها.",
        "ينقل مخدوماً من فصل إلى فصل.",
    ], NAVY)
    card(s, Inches(4.65), Inches(1.85), Inches(4.0), Inches(4.7), "خادم / خادمة", [
        "نفس الصلاحيات. الاسم يختلف حسب النوع.",
        "يُعيَّن على فصل واحد فقط.",
        "يرى مخدومي فصله وسجل حضورهم.",
        "يسجّل الحضور ويعدّل بيانات المخدوم.",
        "لا يدير النظام ولا يقفل الجلسات.",
    ], OLIVE)
    card(s, Inches(8.85), Inches(1.85), Inches(4.0), Inches(4.7), "قبل التفعيل", [
        "التسجيل من شاشة إنشاء حساب.",
        "الحساب يُنشأ غير نشط بلا دعوة.",
        "لا يرى أي بيانات حتى الموافقة.",
        "أمين الخدمة يقبل أو يرفض الطلب.",
        "الدعوة بالبريد تفعّل الحساب وتعيّن الفصل.",
    ], GOLD)

    # 3 map
    s = blank(prs)
    title_block(s, "التنقّل", "خمس تبويبات، ثم شاشات من «المزيد»")
    tabs = [
        ("الرئيسية", "ملخص السنة والنقاط"),
        ("الفصول", "قائمة الفصول وتفاصيلها"),
        ("المخدومين", "البحث والفلترة والملف"),
        ("الحضور", "تسجيل سبت واحد"),
        ("المزيد", "تقارير وإدارة وحساب"),
    ]
    for i, (name, desc) in enumerate(tabs):
        c = rect(s, Inches(0.45 + i * 2.55), Inches(1.9), Inches(2.4), Inches(1.7), WHITE, LINE)
        tf = c.text_frame
        tf.word_wrap = True
        p = tf.paragraphs[0]
        p.alignment = PP_ALIGN.CENTER
        run = p.add_run()
        run.text = name
        font(run, 18, True, NAVY)
        p = tf.add_paragraph()
        p.alignment = PP_ALIGN.CENTER
        run = p.add_run()
        run.text = desc
        font(run, 13, False, MUTED)
    bullets(s, [
        "من المزيد: التقارير، سجل الحضور، استيراد Excel، تصدير Excel، الإعدادات.",
        "لأمين الخدمة فقط: طلبات الانضمام، الخدام، تعيين الخدام، سنوات الحضور.",
        "الخادم يرى «فصولي» بدل «الفصول»، ويختفي منه قسم إدارة النظام.",
    ], Inches(0.55), Inches(4.0), Inches(12.2), Inches(2.4), 18)

    # 4 matrix
    s = blank(prs)
    title_block(s, "الصلاحيات", "من يفعل ماذا")
    rows = [
        ["الإجراء", "أمين الخدمة", "الخادم"],
        ["رؤية كل الفصول", "نعم", "فصله فقط"],
        ["إضافة / أرشفة / حذف فصل", "نعم", "لا"],
        ["إضافة وتعديل مخدوم", "نعم", "نعم، داخل فصله"],
        ["نقل مخدوم لفصل آخر", "نعم", "لا"],
        ["تسجيل الحضور", "نعم", "نعم"],
        ["قفل الجلسة أو فتحها", "نعم", "لا، الجلسة المقفلة للقراءة"],
        ["التقارير والتصدير", "كل الفصول", "فصله فقط"],
        ["استيراد Excel", "نعم", "حسب صلاحية الكتابة"],
        ["قبول الخدام وتعيينهم", "نعم", "لا"],
        ["سنوات الحضور ونقاط الأنشطة", "نعم", "عرض فقط من الإعدادات"],
    ]
    table_shape = s.shapes.add_table(len(rows), 3, Inches(0.5), Inches(1.75), Inches(12.3), Inches(5.1))
    table = table_shape.table
    table.columns[0].width = Inches(5.1)
    table.columns[1].width = Inches(3.6)
    table.columns[2].width = Inches(3.6)
    for r, row in enumerate(rows):
        for c, value in enumerate(row):
            cell = table.cell(r, c)
            cell.text = ""
            cell.vertical_anchor = MSO_ANCHOR.MIDDLE
            p = cell.text_frame.paragraphs[0]
            rtl(p)
            run = p.add_run()
            run.text = value
            font(run, 13, r == 0 or c == 0, WHITE if r == 0 else INK)
            fill = NAVY if r == 0 else (RGBColor(0xE8, 0xEE, 0xF6) if r % 2 == 0 else WHITE)
            cell.fill.solid()
            cell.fill.fore_color.rgb = fill

    # 5 auth
    s = blank(prs)
    title_block(s, "قبل الدخول", "تسجيل الدخول وإنشاء الحساب", "متاحة لأي شخص لم يدخل بعد")
    card(s, Inches(0.45), Inches(1.85), Inches(4.0), Inches(4.6), "تسجيل الدخول", [
        "البريد وكلمة المرور.",
        "بعد النجاح تُفتح الرئيسية حسب الدور.",
        "بيانات خاطئة: رسالة عربية واضحة.",
    ])
    card(s, Inches(4.65), Inches(1.85), Inches(4.0), Inches(4.6), "نسيت كلمة المرور", [
        "إدخال البريد.",
        "يُرسل رابط استعادة من Supabase.",
        "لا يغيّر كلمة المرور داخل التطبيق.",
    ])
    card(s, Inches(8.85), Inches(1.85), Inches(4.0), Inches(4.6), "إنشاء حساب", [
        "الاسم، البريد، الموبايل، النوع، كلمة المرور.",
        "بلا دعوة: الحساب غير نشط ويظهر في الطلبات.",
        "بدعوة مطابقة للبريد: يُفعَّل ويُربَط بالفصل.",
    ], OLIVE)

    # 6 home
    s = blank(prs)
    title_block(s, "الرئيسية", "ملخص مختلف لكل دور")
    card(s, Inches(0.45), Inches(1.8), Inches(6.1), Inches(4.8), "أمين الخدمة", [
        "عدد المخدومين والفصول والخدام وإجمالي النقاط.",
        "آخر سبت، وعدد الأولاد والبنات.",
        "إجراءات سريعة: الحضور، إضافة مخدوم، استيراد Excel.",
        "أداء الفصول مرتباً بنسبة الحضور. الضغط يفتح الفصل.",
        "مخدومون بحاجة متابعة، وسجل آخر التعديلات.",
    ])
    card(s, Inches(6.8), Inches(1.8), Inches(6.05), Inches(4.8), "الخادم", [
        "ترحيب باسمه وسنة الحضور الحالية.",
        "فصله فقط: عدد المخدومين وموعد الحضور.",
        "إن لم يُعيَّن على فصل: شاشة فارغة توضّح ذلك.",
        "لا يرى إحصائيات بقية الفصول.",
        "زر التحديث في الشريط يعيد تحميل الفصول.",
    ], OLIVE)

    # 7 classes
    s = blank(prs)
    title_block(s, "الفصول", "القائمة وتفاصيل الفصل")
    card(s, Inches(0.45), Inches(1.8), Inches(6.1), Inches(4.8), "قائمة الفصول", [
        "كل فصل: الشفيع، الأولاد، البنات، آخر سبت.",
        "أمين الخدمة: زر إضافة فصل.",
        "الخادم: «فصولي» وبلا زر إضافة.",
        "الضغط يفتح تفاصيل الفصل.",
    ])
    card(s, Inches(6.8), Inches(1.8), Inches(6.05), Inches(4.8), "تفاصيل الفصل", [
        "إحصائيات، شفيع الفصل، الخدام المعينون.",
        "قائمة المخدومين مع بحث وفلتر.",
        "الحضور وسجل الحضور وإضافة مخدوم.",
        "أمين الخدمة: تعديل، أرشفة أو استعادة، حذف.",
        "الحذف يُمنع إن وُجدت بيانات مرتبطة.",
    ])

    # 8 class form
    s = blank(prs)
    title_block(s, "الفصل", "إضافة فصل أو تعديله — أمين الخدمة")
    bullets(s, [
        "الاسم، والوصف، وشفيع الفصل مع صورته.",
        "صورة من الكاميرا أو المعرض، أو حذف الصورة الحالية.",
        "الأرشفة تخفي الفصل من العمل اليومي دون مسح سجلاته.",
        "الاستعادة تعيد الفصل إلى القوائم.",
        "الخادم يفتح التفاصيل فقط، بلا قائمة التعديل.",
    ], Inches(0.6), Inches(1.9), Inches(12), Inches(4.5), 20)

    # 9 children
    s = blank(prs)
    title_block(s, "المخدومين", "الدليل والبحث")
    bullets(s, [
        "كل بطاقة: الاسم، النوع، الكود (C001…)، الفصل، السن، الموبايل، المدرسة.",
        "الكود يصدره قاعدة البيانات عند الحفظ، ولا يكتبه المستخدم.",
        "بحث بالاسم أو الموبايل أو الكود.",
        "فلتر الفصل، وفلتر أولاد / بنات، وإظهار غير النشطين.",
        "ترتيب بالاسم أو السن، تصاعدياً أو عكسه.",
        "إضافة مخدوم، واستيراد Excel من زر الشريط.",
        "الخادم لا يرى إلا مخدومي فصله.",
    ], Inches(0.6), Inches(1.85), Inches(12), Inches(4.8), 18)

    # 10 child form + profile
    s = blank(prs)
    title_block(s, "المخدوم", "النموذج والملف")
    card(s, Inches(0.45), Inches(1.8), Inches(6.1), Inches(4.8), "إضافة أو تعديل", [
        "صورة، الفصل، الاسم، النوع، تاريخ الميلاد، الموبايل.",
        "بيانات الأم والأب، أب الاعتراف، المدرسة، العنوان، الملاحظات.",
        "حقل الكود للقراءة: «سيظهر بعد الحفظ».",
        "بعد الحفظ تظهر رسالة فيها الكود الجديد.",
        "تاريخ ميلاد في المستقبل ترفضه قاعدة البيانات.",
    ])
    card(s, Inches(6.8), Inches(1.8), Inches(6.05), Inches(4.8), "الملف", [
        "البيانات، آخر حضور لكل نشاط، ودرجات السنة والشهور.",
        "سجل السبوت السابقة حتى بعد النقل.",
        "تعديل البيانات، وتنشيط أو إلغاء التنشيط.",
        "إلغاء التنشيط يخفيه من الحضور القادم ويبقي درجاته.",
        "أمين الخدمة فقط: نقل إلى فصل آخر.",
    ], OLIVE)

    # 11 attendance
    s = blank(prs)
    title_block(s, "الحضور", "تسجيل سبت واحد", "أربع أنشطة، والنقاط تحسبها قاعدة البيانات")
    card(s, Inches(0.45), Inches(1.8), Inches(4.0), Inches(4.7), "الشاشة", [
        "اختيار الفصل إن كان للمستخدم أكثر من فصل.",
        "التنقل بين السبوت أو فتح قائمة السنة.",
        "كل المخدومين النشطين يظهرون، حتى بلا سجل سابق.",
        "الحاضرون، المسجَّلون، وإجمالي النقاط.",
    ])
    card(s, Inches(4.65), Inches(1.8), Inches(4.0), Inches(4.7), "الإجراءات", [
        "مدارس الأحد، عشية، قداس، اعتراف. كل نشاط +5 افتراضياً.",
        "تحضير الجميع، أو مسح الكل.",
        "الحفظ يكتب الغياب صفراً وليس بيانات ناقصة.",
        "يظهر اسم آخر من عدّل وتاريخ التعديل.",
    ], OLIVE)
    card(s, Inches(8.85), Inches(1.8), Inches(4.0), Inches(4.7), "القفل", [
        "أمين الخدمة يقفل الجلسة أو يفتحها.",
        "الخادم يقرأ الجلسة المقفلة ولا يعدّلها.",
        "الدرجات المعروضة بعد الحفظ هي درجات قاعدة البيانات.",
    ], GOLD)

    # 12 history + reports
    s = blank(prs)
    title_block(s, "المتابعة", "سجل الحضور والتقارير")
    card(s, Inches(0.45), Inches(1.8), Inches(6.1), Inches(4.8), "سجل الحضور", [
        "سبوت الفصل من الأقدم للأحدث.",
        "لكل سبت: الحاضرون، المسجَّلون، والنقاط.",
        "افتراضياً تُخفى السبوت القادمة الفارغة.",
        "فلتر «تم تسجيلهم» وفلتر «السبوت القادمة».",
        "الضغط يفتح ذلك السبت للتسجيل.",
    ])
    card(s, Inches(6.8), Inches(1.8), Inches(6.05), Inches(4.8), "التقارير", [
        "التقرير العام: ترتيب المخدومين ونقاط السنة.",
        "تقرير الفصل: نسبة كل فصل ونقاطه.",
        "التقرير الشهري: ترتيب الشهر المختار.",
        "فلتر الفصل عندما يرى المستخدم أكثر من فصل.",
        "من الشريط: فتح تصدير Excel.",
    ], OLIVE)

    # 13 excel
    s = blank(prs)
    title_block(s, "Excel", "استيراد وتصدير")
    card(s, Inches(0.45), Inches(1.8), Inches(6.1), Inches(4.8), "استيراد المخدومين", [
        "تنزيل ملف نموذج.",
        "اختيار ملف xlsx ومراجعة الصفوف قبل الحفظ.",
        "المطابقة بالكود أولاً، ثم بالاسم داخل الفصل.",
        "صف بكود موجود يحدّث المخدوم ولا يكرره.",
        "صف بلا كود يُدرج ويأخذ كوداً جديداً من قاعدة البيانات.",
    ])
    card(s, Inches(6.8), Inches(1.8), Inches(6.05), Inches(4.8), "تصدير", [
        "قائمة المخدومين.",
        "كشف حضور سبت بعد اختيار التاريخ.",
        "الحضور الشهري، والحضور السنوي.",
        "تقرير الفصل.",
        "النطاق: الكل أو فصل واحد، في حدود ما يراه المستخدم.",
    ], OLIVE)

    # 14 admin servants
    s = blank(prs)
    title_block(s, "إدارة النظام", "الخدام والتعيين — أمين الخدمة فقط")
    card(s, Inches(0.45), Inches(1.8), Inches(4.0), Inches(4.7), "طلبات الانضمام", [
        "حسابات سجّلت بلا دعوة.",
        "قبول: يصبح الحساب نشطاً.",
        "رفض: لا يستطيع صاحبه الدخول.",
    ])
    card(s, Inches(4.65), Inches(1.8), Inches(4.0), Inches(4.7), "الخدام", [
        "قائمة المسجّلين والدعوات المنتظرة.",
        "إضافة خادم: دعوة بالبريد والدور والفصل.",
        "تنشيط أو إلغاء تنشيط.",
        "حذف دعوة لم تُقبل بعد.",
    ], OLIVE)
    card(s, Inches(8.85), Inches(1.8), Inches(4.0), Inches(4.7), "تعيين الخدام", [
        "كل فصل وخدامه.",
        "تعيين خادم غير مرتبط بفصل.",
        "إزالة الخادم من الفصل.",
        "القاعدة: خادم واحد على فصل واحد. الفصل قد يضم عدة خدام.",
    ], NAVY)

    # 15 years + settings
    s = blank(prs)
    title_block(s, "النظام والحساب", "سنوات الحضور والإعدادات")
    card(s, Inches(0.45), Inches(1.8), Inches(6.1), Inches(4.8), "سنوات الحضور — أمين الخدمة", [
        "السنة الحالية، البداية والنهاية.",
        "نقاط كل نشاط والحد الأقصى للجلسة.",
        "تعديل السنة.",
        "إنشاء جلسات السبوت لكل الفصول.",
        "إضافة سنة وجعلها الحالية.",
    ])
    card(s, Inches(6.8), Inches(1.8), Inches(6.05), Inches(4.8), "الإعدادات — الجميع", [
        "الاسم، البريد، الموبايل، الدور، الفصل المعين.",
        "بيانات سنة الحضور الحالية للعرض.",
        "عن التطبيق.",
        "تسجيل الخروج بعد تأكيد.",
        "الخادم لا يعدّل نقاط السنة من هنا.",
    ], OLIVE)

    # 16 flow
    s = blank(prs)
    title_block(s, "مسار العمل", "من السنة إلى التقرير")
    steps = [
        ("1", "سنة الحضور", "الأمين يحدد التواريخ والنقاط وينشئ السبوت."),
        ("2", "الفصول والخدام", "فصل، شفيع، ثم تعيين خادم واحد لكل فصل."),
        ("3", "المخدومون", "إضافة أو استيراد. الكود يصدر تلقائياً."),
        ("4", "كل سبت", "تسجيل الأنشطة الأربعة ثم الحفظ. القفل عند الانتهاء."),
        ("5", "المتابعة", "تقارير السنة والشهر، وتصدير Excel."),
    ]
    for i, (n, title, body) in enumerate(steps):
        y = Inches(1.75 + i * 0.95)
        badge = rect(s, Inches(11.7), y, Inches(0.7), Inches(0.7), NAVY)
        tf = badge.text_frame
        tf.paragraphs[0].alignment = PP_ALIGN.CENTER
        run = tf.paragraphs[0].add_run()
        run.text = n
        font(run, 18, True, WHITE)
        box = s.shapes.add_textbox(Inches(0.55), y, Inches(10.9), Inches(0.8))
        p = box.text_frame.paragraphs[0]
        rtl(p)
        run = p.add_run()
        run.text = title
        font(run, 18, True, NAVY)
        p = box.text_frame.add_paragraph()
        rtl(p)
        run = p.add_run()
        run.text = body
        font(run, 14, False, INK)

    total = len(prs.slides)
    for i, slide in enumerate(prs.slides, start=1):
        if i == 1:
            continue
        footer(slide, i, total)

    prs.save(OUT)
    print(OUT, total)


if __name__ == "__main__":
    build()
