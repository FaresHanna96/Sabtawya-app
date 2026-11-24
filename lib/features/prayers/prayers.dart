import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A prayer a servant says, kept in the app so it is at hand on any phone.
class Prayer {
  const Prayer({
    required this.id,
    required this.title,
    required this.when,
    required this.paragraphs,
    required this.icon,
    required this.color,
  });

  final String id;
  final String title;

  /// A short line on when it is said, under the title in the list.
  final String when;

  /// The text, split where a pause reads naturally.
  final List<String> paragraphs;

  /// How it looks in the list and at the top of the page: the morning sun
  /// in gold before the service, the evening moon in navy after it.
  final IconData icon;
  final Color color;

  /// A calm reading time, from about 110 words a minute (never under one).
  int get readMinutes {
    final words = paragraphs
        .expand((p) => p.split(RegExp(r'\s+')))
        .where((w) => w.trim().isNotEmpty && w != '...')
        .length;
    return (words / 110).ceil().clamp(1, 99);
  }
}

/// The servants' prayers before and after the lesson.
class Prayers {
  const Prayers._();

  static const beforeService = Prayer(
    id: 'before',
    title: 'صلاة قبل الخدمة',
    when: 'قبل أن تبدأ خدمتك',
    icon: Icons.wb_sunny_rounded,
    color: AppColors.gold,
    paragraphs: [
      'أيها الرب العارف قلب كل أحد ... الفاحص القلوب والكُلى ... إذ وأنا '
          'غير مستحق دعوتني لخدمتك المقدسة هذه ... لأنك قلت بفمك القدوس: '
          '"ليس أنتم اخترتموني بل أنا اخترتكم، وأقمتكم ... لتذهبوا وتأتوا '
          'بثمر، ويدوم ثمركم" ...',
      'أستعطفك أيها الرب القادر على كل شيء، أنا الضعيف العاجز غير المفلح '
          'بين جميع خدامك، نعم أيها الرب الذي ترحم كل أحد ... اجعلني أهلاً '
          'بقلب طاهر وشفتين نقيتين أن أخدم اسمك القدوس المكرم بغير سكوت ... '
          'لكي أجد أجرة الوكيل الأمين الحكيم في يوم مجازاتك الحقيقية يا حافظ '
          'الأطفال الصغار ...',
      'أذكر أولادك الذين منحتني شرف خدمتهم ... افتح أذهانهم وقلوبهم '
          'ليقبلوك .. أباً، وإلهاً، ومعلماً، وصديقاً ... احفظهم في اسمك '
          'الذين أعطيتني ... من أجلهم أنا أسأل، لأنهم لك ...',
      'أذكر سلامة إخوتي الخدام ... أذكر طهارتي ... أذكر توبتي ... اقبل '
          'إليك صلاتي بشفاعة أمي البتول، وكل آبائي الشهداء والأبرار ... لأنك '
          'إلهي العظيم ... الذي ينبغي لك المجد مع أبيك الصالح والروح القدس '
          'آمين ...',
    ],
  );

  static const afterService = Prayer(
    id: 'after',
    title: 'صلاة بعد الخدمة',
    when: 'بعد أن تنتهي من خدمتك',
    icon: Icons.nights_stay_rounded,
    color: AppColors.navyLight,
    paragraphs: [
      'أيها الرب الإله الذي يحب كل أحد ... الذي دعاني بنعمته وأنا غير '
          'مستحق إلى خدمته ... أشكرك أيها الطويل الأناة إذ حسبتني في هذا '
          'اليوم بين خدامك الأتقياء ..',
      'نعم أيها الرب الذي يثبت وعده إلى الأبد، أنت تكلمت بفم أشعياء النبي '
          'العظيم قائلاً: "كلمتي التي تخرج من فمي لا ترجع إليَّ فارغة بل '
          'تفعل ما سررت به .. وتنجح فيما أرسلتها إليه" ...',
      'كلمتك يا سيدي التي خرجت من فمك هذا المساء أعطها قوة هذا الوعد كي '
          'تنجح فيما أرسلتها إليه ... هبها أن تثمر فينا جميعاً .. أولادك '
          'المخدومين وإخوتي الخدام وضعفي ... وإن كنت قد سمحت لنا أن نزرع هذه '
          'البذرة فأعطها أن تُغرَس في القلوب وساعدنا على سقيها .. ومُر لها '
          'بالخصب والنماء ...',
      'تفضل يا رب أذكر سلامة الكنيسة والآباء وسلامة إخوتي الخدام ... أذكر '
          'أولادك المخدومين البعيدين عنك والقريبين ... أذكر طهارتي .. أذكر '
          'توبتي .. أذكر أبي وأمي وأذكر إخوتي ...',
      'اقبل إليك صلاتي بشفاعة أمي البتول، وكل آبائي الشهداء والأبرار ... '
          'لأنك إلهي العظيم ... الذي ينبغي لك المجد مع أبيك الصالح والروح '
          'القدس آمين ...',
    ],
  );

  static const all = [beforeService, afterService];
}
