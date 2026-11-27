import 'package:flutter/material.dart';

/// One line of the "what's new" popup shown once after an update.
class WhatsNewItem {
  const WhatsNewItem(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

/// What each release added, keyed by the build number that ships it. The popup
/// shows the entry of the running build once per phone. A build with no entry
/// shows nothing. Add the new entry for every release that users should hear about.
const Map<int, List<WhatsNewItem>> kWhatsNew = {
  67: [
    WhatsNewItem(Icons.cloud_off_rounded, 'من غير نت أحسن',
        'التطبيق بيفضل شغال من غير نت حتى بعد وقت طويل، والحفظ بيتبعت لما النت يرجع من غير ما يتكرر.'),
    WhatsNewItem(Icons.shield_outlined, 'أمان أكتر',
        'لما تسجّل خروج، الموبايل بيبطّل يستقبل إشعاراتك.'),
    WhatsNewItem(Icons.build_circle_outlined, 'تصليحات',
        'أرقام الخدام بقت كاملة، والحضور مبيضيعش وإنت بتغيّر حالة السبت، ومفيش دفع أكتر من المطلوب في الرحلات.'),
  ],
  65: [
    WhatsNewItem(Icons.touch_app_outlined, 'اختصارات الشريط',
        'اتصلّح إن قوائم الاختصارات كانت بتفتح فوق بعض، ودلوقتي الجديدة بتاخد مكان القديمة.'),
  ],
  64: [
    WhatsNewItem(Icons.notifications_active_outlined, 'الإشعار بيفتح مكانه',
        'اضغط على أي إشعار، من الجرس أو من برّه، يوديك على الصفحة بتاعته. وكلام الإشعارات بقى أبسط وأوضح.'),
    WhatsNewItem(Icons.dashboard_customize_rounded, 'شكل وتنقّل أسهل',
        'الشريط اللي تحت بقى ظاهر في كل الصفحات، واضغط عليه ضغطة طويلة تلاقي اختصارات.'),
    WhatsNewItem(Icons.event_busy_rounded, 'السبت اللي مفيهوش درس',
        'إشعار واحد فيه السبب وحالة الدرس والحضور.'),
    WhatsNewItem(Icons.phone_iphone_rounded, 'الآيفون',
        'زرار للإشعارات في الإعدادات، والموقع بيفتح من غير نت.'),
  ],
  63: [
    WhatsNewItem(Icons.campaign_rounded, 'إعلان لخدام بالاسم',
        'أمين الخدمة يقدر يبعت الإعلان لخدام يختارهم بالاسم.'),
    WhatsNewItem(Icons.child_care_rounded, 'ملف المخدوم أوضح',
        'ملخص الحضور بقى أخف، وكارت النشاطات الترفيهية بيعرض الجاية بس، واتصلّح فتح التبويبات وكارت المتابعة.'),
  ],
  62: [
    WhatsNewItem(Icons.tune_rounded, 'تحسينات صغيرة',
        'عدد الأمناء في الرئيسية بقى مظبوط، وتحسينات في متابعة التحديثات.'),
  ],
  61: [
    WhatsNewItem(Icons.dashboard_customize_rounded, 'رئيسية أخف وأوضح',
        'كارت واحد فيه الاسم والأرقام، و«محتاج متابعة» بأرقامه، وأعياد الميلاد في سطر، و«السبت الجاي» فيه الدرس والتحضير. ونفس الشكل للأمين والخادم.'),
    WhatsNewItem(Icons.undo_rounded, 'تراجع بعد «تحضير الجميع»',
        'لو ضغطت غلط تقدر ترجّع العلامات بضغطة، ومتابعة الغياب فيها شريط «اتفتقد X من Y».'),
    WhatsNewItem(Icons.filter_alt_rounded, 'فلاتر سريعة للمخدومين',
        'غايب، عيد ميلاده الشهر ده، بيانات ناقصة. وتحت كل مخدوم آخر مرة حضر فيها.'),
    WhatsNewItem(Icons.phone_in_talk_rounded, 'الاتصال والواتساب',
        'الرقم بيتاخد من المخدوم نفسه، وبعدين الأم، وبعدين الأب، في كل مكان. واتشال اسم الأم واسم الأب من البيانات.'),
    WhatsNewItem(Icons.beach_access_rounded, 'الإجازة أبسط',
        'لما تعلّم السبت إجازة مبقاش بيسألك إيه اللي يحصل للدرس.'),
  ],
  60: [
    WhatsNewItem(Icons.emoji_events_rounded, 'ترتيب المخدوم',
        'الترتيب في كارت المخدوم بقى «الأول» و«التاني» للولد و«الأولى» و«التانية» للبنت.'),
    WhatsNewItem(Icons.local_fire_department_rounded, 'ملتزم ذهبي',
        'وسام ملتزم ذهبي (١٢ سبت ورا بعض) كان مش بيتحسب كمكسوب، وبقى بيظهر صح.'),
  ],
  59: [
    WhatsNewItem(Icons.celebration_rounded, 'نشاط ترفيهي بحضور',
        'الأمين يقدر يختار إن حضور الأطفال بيتسجّل في النشاط الترفيهي ويتحسب زي أي سبت. حضور الخدام بيتحسب دايمًا، والتحضير لأ.'),
    WhatsNewItem(Icons.speed_rounded, 'ثبات أكتر',
        'تحسينات صغيرة عشان الشاشات تفضل شغالة حتى لو التحديث لسه واصل لقاعدة البيانات.'),
  ],
  58: [
    WhatsNewItem(Icons.event_busy_rounded, 'السبت اللي مفيهوش درس',
        'إجازة ونشاط ترفيهي وتأجيل وإلغاء الدرس بقوا في شاشة واحدة سهلة، من تبويب الدروس ومن الحضور، ومكتوب على السبت سببه.'),
    WhatsNewItem(Icons.assignment_turned_in_outlined, 'عدّاد التحضير',
        'بقى بيبان «1/7» ومعاه النسبة، زي باقي النشاطات.'),
  ],
  57: [
    WhatsNewItem(Icons.beach_access_rounded, 'الإجازة مش بتتحسب',
        'السبت اللي اتعلّم إجازة أو نشاط ترفيهي مبقاش بيدخل في الأوسمة ولا طايوهات الفصل ولا تحضيرات الخدام.'),
    WhatsNewItem(Icons.assignment_turned_in_outlined, 'عدّاد التحضير',
        'بقى بيحسب التحضير اللي الخادم رفعه واللي الأمين علّمه له بإيده، مرة واحدة لكل سبت.'),
  ],
  56: [
    WhatsNewItem(Icons.event_rounded, 'تاريخ السبت كامل',
        'في شاشة الحضور بقى التاريخ ياخد عرضه كله ومش بيتقطع.'),
    WhatsNewItem(Icons.calendar_month_rounded, 'سنة الحضور',
        'وفي سنة الحضور بقى مكتوب كام سبت في السنة.'),
  ],
  55: [
    WhatsNewItem(Icons.settings_rounded, 'الإعدادات مترتبة',
        'اسمك فوق، وبعده «الحساب» و«التطبيق»، وللأمين بس تنبيهات الغياب وسنة الحضور.'),
    WhatsNewItem(Icons.percent_rounded, 'شاشة الحضور أوضح',
        'فوق نسبة الحضور وشريط ملون وعلامة حالة، وتاريخ السبت بشكل أوضح.'),
  ],
  54: [
    WhatsNewItem(Icons.military_tech_rounded, 'أوسمة جديدة',
        'ليتورجي وعشية للي بيحضر كل سبت في شهر كامل، ونجم السنة ونجم مدارس الأحد في آخر السنة. وأمين الخدمة يقدر يفلتر المخدومين بالوسام.'),
    WhatsNewItem(Icons.palette_outlined, 'شكل جديد',
        'أيقونات ملونة ومتحركة في الشريط تحت، وشكل أوضح لأوسمة الخدام وفورم إضافة مخدوم.'),
    WhatsNewItem(Icons.event_rounded, 'اختار التاريخ بضغطة',
        'التقويم بقى يختار اليوم أول ما تضغط عليه من غير زرار «حسنًا».'),
    WhatsNewItem(Icons.bookmark_add_outlined, 'احجز للنشاط من الحضور',
        'وانت بتسجل الحضور، اضغط «حجز» على أي مخدوم يتحجز له في النشاط الترفيهي الجاي، ومكتوب فوق كام واحد حجز.'),
  ],
  53: [
    WhatsNewItem(Icons.bar_chart_rounded, 'الحضور كل سبت',
        'بقى واضح هو عن أنهي سبت، والسبت اللي ما اتسجلش بيبان «—» والإجازة «إجازة»، واضغط على أي سبت تشوف كل فصل.'),
    WhatsNewItem(Icons.edit_calendar_outlined, 'سجّل من الكارت',
        'الفصل اللي ما سجّلش بيظهر تحت الأعمدة، اضغط عليه يفتحلك الحضور بتاعه للسبت ده.'),
    WhatsNewItem(Icons.groups_outlined, 'فصلك والخدمة',
        'خادم الفصل يشوف نسبة فصله جنب نسبة الخدمة كلها.'),
    WhatsNewItem(Icons.monitor_heart_outlined, 'متابعة فصلي',
        'لو عندك فصل واحد، تفاصيل متابعته بتظهر على طول.'),
  ],
  52: [
    WhatsNewItem(Icons.more_horiz_rounded, 'المزيد بشكل جديد',
        'اسمك فوق، بحث، وأهم ٦ حاجات بتستخدمها بأرقام اللي مستنيك فيها، و«التحقق من التحديثات» تحت.'),
    WhatsNewItem(Icons.fact_check_rounded, 'التحضيرات',
        'لأمين الخدمة: كل التحضيرات في مكان واحد، و«راجع ورا بعض» يفتحهم واحد ورا التاني.'),
    WhatsNewItem(Icons.monitor_heart_outlined, 'متابعة الفصول',
        'بقت في تاب الفصول، وخادم الفصل الواحد يفتح فصله على طول من غير ما يدوّر.'),
    WhatsNewItem(Icons.attach_file_rounded, 'وسائل الإيضاح',
        'ده الاسم الجديد لـ«المواد والأفكار» تحت كل درس.'),
  ],
  51: [
    WhatsNewItem(Icons.monitor_heart_outlined, 'فصلي',
        'في الرئيسية: كل فصل بعدد أطفاله ودرجة صحته، واضغط عليه تشوف التفاصيل وتفتح الفصل.'),
  ],
  50: [
    WhatsNewItem(Icons.monitor_heart_outlined, 'صحة الفصل',
        'درجة واحدة لكل فصل من حضور الأطفال وتسجيل الحضور والتحضير والافتقاد، وخادم الفصل يشوف حال فصله في الرئيسية.'),
    WhatsNewItem(Icons.attach_file_rounded, 'شارك مواد الدرس',
        'أي خادم يقدر يضيف رابط فيديو أو صورة أو ملف تحت «المواد والأفكار» للدرس، حتى وهو بيرفع التحضير.'),
    WhatsNewItem(Icons.cleaning_services_outlined, 'صفحات أخف',
        'شيلنا الحاجات اللي مش محتاجينها: «رسالة للأهالي» بقت في قائمة الفصل (⋮).'),
  ],
  49: [
    WhatsNewItem(Icons.chat_outlined, 'رسالة للأهالي',
        'من صفحة الفصل أو الرحلة: ابعت رسالة جاهزة لكل أسرة على واتساب، والإخوات في رسالة واحدة.'),
    WhatsNewItem(Icons.attach_file_rounded, 'المواد والأفكار',
        'تحت كل درس: ملفات وروابط تساعدك في التحضير، وتحضيرات مميزة من خدام نفس الصف.'),
    WhatsNewItem(Icons.campaign_outlined, 'إعلانات الخدمة',
        'إعلانات أمين الخدمة توصلك في الجرس، واضغط عليها تقرأها كاملة.'),
    WhatsNewItem(Icons.content_copy_rounded, 'تنبيه الطفل المكرر',
        'وإنت بتضيف طفل، التطبيق ينبهك لو فيه طفل شبهه متسجل قبل كده.'),
    WhatsNewItem(Icons.child_care_outlined, 'إشعارات الطفل',
        'إشعار «تغيير في فصلك» عن طفل بيفتح صفحة الطفل نفسه.'),
  ],
  47: [
    WhatsNewItem(Icons.favorite_border, 'ملاحظات صحية للطفل',
        'سجّل ملاحظات صحية خاصة لكل طفل، يراها خدام الفصل والأدمن فقط.'),
    WhatsNewItem(Icons.notifications_active_outlined, 'تنبيه الغياب',
        'تنبيه لخدام الفصل لما الطفل يغيب مرتين أو ثلاث، مع زر لتسجيل الاتصال.'),
    WhatsNewItem(Icons.show_chart, 'منحنى الحضور',
        'منحنى حضور في صفحة الطفل، وقائمة الأطفال اللي حضورهم بيقل.'),
    WhatsNewItem(Icons.undo, 'تراجع عن التعديل',
        'تقدر تتراجع عن تعديل بيانات طفل أو عن استيراد ملف Excel.'),
    WhatsNewItem(Icons.contacts_outlined, 'ملف جهات الاتصال',
        'ملف جهات اتصال للأسر، واسم المتصل يظهر على الأندرويد.'),
    WhatsNewItem(Icons.history, 'سجل التغييرات',
        'سجل تغييرات الطفل يوضح إيه اللي اتغير ومين غيّره.'),
  ],
};
