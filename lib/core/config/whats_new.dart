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
