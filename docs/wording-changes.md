# app_strings.dart: Egyptian wording changes (commit 7568002)
231 changed lines.


- قبل: static const noResults = 'لا توجد نتائج';
  بعد: **static const noResults = 'مفيش نتايج';**

- قبل: static const loading = 'جارٍ التحميل…';
  بعد: **static const loading = 'بيتحمّل…';**

- قبل: static const noData = 'لا توجد بيانات';
  بعد: **static const noData = 'مفيش بيانات';**

- قبل: static const saved = 'تم الحفظ بنجاح';
  بعد: **static const saved = 'اتحفظ بنجاح';**

- قبل: 'لم يُحفظ: ${classes.join('، ')}. الباقي اتحفظ، اضغط حفظ مرة أخرى.';
  بعد: **'ما اتحفظش: ${classes.join('، ')}. الباقي اتحفظ، اضغط حفظ تاني.';**

- قبل: static const somethingWentWrong = 'حدث خطأ غير متوقع';
  بعد: **static const somethingWentWrong = 'حصلت مشكلة، جرّب تاني';**

- قبل: static const noPermission = 'ليس لديك صلاحية لهذا الإجراء';
  بعد: **static const noPermission = 'مالكش صلاحية تعمل ده';**

- قبل: 'أدخل بريدك الإلكتروني وسنرسل لك رابط استعادة كلمة المرور.';
  بعد: **'اكتب بريدك الإلكتروني وهنبعتلك رابط استعادة كلمة المرور.';**

- قبل: 'لو كان هذا البريد مسجلاً عندنا، وصله رابط الاستعادة';
  بعد: **'لو البريد ده مسجّل عندنا، هيوصله رابط الاستعادة';**

- قبل: static const passwordChanged = 'تم تغيير كلمة المرور بنجاح';
  بعد: **static const passwordChanged = 'اتغيّرت كلمة المرور';**

- قبل: 'أنشئ حسابك ثم انتظر تنشيط المسؤول حتى تظهر لك فصولك.';
  بعد: **'اعمل حسابك واستنى أمين الخدمة يفعّله علشان تظهرلك فصولك.';**

- قبل: static const noAccountYet = 'ليس لديك حساب؟ أنشئ حساباً';
  بعد: **static const noAccountYet = 'معندكش حساب؟ اعمل حساب جديد';**

- قبل: static const nameArabicOnly = 'الاسم يجب أن يكون باللغة العربية';
  بعد: **static const nameArabicOnly = 'اكتب الاسم بالعربي';**

- قبل: static const passwordsDoNotMatch = 'كلمتا المرور غير متطابقتين';
  بعد: **static const passwordsDoNotMatch = 'كلمتا المرور مش متطابقتين';**

- قبل: static const passwordTooShort = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
  بعد: **static const passwordTooShort = 'كلمة المرور لازم تكون 8 حروف على الأقل';**

- قبل: static const signUpDone = 'تم إنشاء الحساب';
  بعد: **static const signUpDone = 'اتعمل الحساب';**

- قبل: 'أرسلنا رسالة تأكيد إلى بريدك الإلكتروني. افتح الرابط ثم سجّل الدخول.';
  بعد: **'بعتنالك رسالة تأكيد على بريدك الإلكتروني. افتح الرابط وبعدين سجّل دخولك.';**

- قبل: static const emailAlreadyUsed = 'هذا البريد الإلكتروني مستخدم بالفعل';
  بعد: **static const emailAlreadyUsed = 'البريد ده مستخدم قبل كده';**

- قبل: 'لا يمكن التسجيل ببريد مؤقت. استخدم بريدك الشخصي الذي تستعمله دائماً.';
  بعد: **'ما ينفعش التسجيل ببريد مؤقت. استخدم بريدك الشخصي اللي بتستعمله على طول.';**

- قبل: ? 'يبدو أن البريد مكتوب خطأ. راجعه ثم سجّل.'
  بعد: **? 'شكل البريد مكتوب غلط. راجعه وبعدين سجّل.'**

- قبل: : 'هل تقصد $suggestion ؟ صحّح البريد ثم سجّل.';
  بعد: **: 'تقصد $suggestion ؟ صحّح البريد وبعدين سجّل.';**

- قبل: 'النطاق $domain لا يستقبل رسائل. تأكد من كتابة البريد صحيحاً.';
  بعد: **'النطاق $domain مابيستقبلش رسائل. اتأكد إن البريد مكتوب صح.';**

- قبل: 'لا يمكن التسجيل بهذا البريد. استخدم بريدك الشخصي الصحيح.';
  بعد: **'ما ينفعش التسجيل بالبريد ده. استخدم بريدك الشخصي الصح.';**

- قبل: static const invalidEmail = 'البريد الإلكتروني غير صحيح';
  بعد: **static const invalidEmail = 'البريد الإلكتروني مش صح';**

- قبل: 'هذا الاسم مسجل بالفعل. لو عندك حساب سجّل الدخول، أو اكتب اسمك كاملاً بشكل مختلف.';
  بعد: **'الاسم ده متسجّل قبل كده. لو عندك حساب سجّل دخولك، أو اكتب اسمك كامل بشكل مختلف.';**

- قبل: static const emailInvalid = 'صيغة البريد الإلكتروني غير صحيحة';
  بعد: **static const emailInvalid = 'صيغة البريد الإلكتروني مش صح';**

- قبل: 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
  بعد: **'البريد الإلكتروني أو كلمة المرور مش صح';**

- قبل: static const accountInactiveTitle = 'الحساب غير مُنشّط';
  بعد: **static const accountInactiveTitle = 'الحساب لسه متفعّلش';**

- قبل: 'تم إنشاء حسابك ولكنه في انتظار تنشيط المسؤول. برجاء التواصل مع المسؤول.';
  بعد: **'حسابك اتعمل بس لسه مستني أمين الخدمة يفعّله. كلّمه علشان يفعّله.';**

- قبل: static const accountNotFoundTitle = 'البريد غير مسجل';
  بعد: **static const accountNotFoundTitle = 'البريد ده مش متسجّل';**

- قبل: 'هذا البريد الإلكتروني غير مسجل في النظام. تواصل مع أمين الخدمة للحصول على دعوة.';
  بعد: **'البريد ده مش متسجّل عندنا. كلّم أمين الخدمة يبعتلك دعوة.';**

- قبل: static const accountRejectedTitle = 'تم رفض الطلب';
  بعد: **static const accountRejectedTitle = 'الطلب اترفض';**

- قبل: 'تم رفض طلب التسجيل الخاص بك. تواصل مع أمين الخدمة للمزيد من المعلومات.';
  بعد: **'طلب التسجيل بتاعك اترفض. كلّم أمين الخدمة تعرف التفاصيل.';**

- قبل: 'تم إنشاء حسابك بنجاح — في انتظار موافقة المسؤول';
  بعد: **'حسابك اتعمل — مستني موافقة أمين الخدمة';**

- قبل: static const confirmLogout = 'هل تريد تسجيل الخروج؟';
  بعد: **static const confirmLogout = 'عايز تسجّل خروج؟';**

- قبل: 'لديك $n تغيير لم يُرسل بعد. سيبقى محفوظًا على هذا الجهاز ويُرسل عند '
  بعد: **'عندك $n تغيير لسه ما اتبعتش. هيفضل محفوظ على الموبايل ده وهيتبعت لما '**

- قبل: 'تسجيل دخولك مرة أخرى. هل تريد تسجيل الخروج؟';
  بعد: **'تسجّل دخولك تاني. عايز تسجّل خروج؟';**

- قبل: static String classNotRecordedOn(String day) => 'لم يُسجَّل حضور $day بعد';
  بعد: **static String classNotRecordedOn(String day) => 'لسه ما اتسجّلش حضور $day';**

- قبل: static const noUpcomingSession = 'لا توجد جلسة قادمة';
  بعد: **static const noUpcomingSession = 'مفيش جلسة جاية';**

- قبل: static const noAttendanceYet = 'لم يُسجَّل حضور بعد';
  بعد: **static const noAttendanceYet = 'لسه ما اتسجّلش حضور';**

- قبل: static const noBirthdaysToday = 'لا توجد أعياد ميلاد اليوم';
  بعد: **static const noBirthdaysToday = 'مفيش أعياد ميلاد النهارده';**

- قبل: static const futureSession = 'سبت لم يأتِ بعد';
  بعد: **static const futureSession = 'سبت لسه ما جاش';**

- قبل: static const logEmpty = 'لا توجد تعديلات بهذه التصفية';
  بعد: **static const logEmpty = 'مفيش تعديلات بالتصفية دي';**

- قبل: static const loadFailed = 'تعذّر التحميل';
  بعد: **static const loadFailed = 'ما قدرناش نحمّل';**

- قبل: static const noClassesAssigned = 'لم يتم تعيين أي فصل لك بعد';
  بعد: **static const noClassesAssigned = 'لسه ما اتعيّنش ليك أي فصل';**

- قبل: 'برجاء التواصل مع المسؤول لتعيينك على فصل.';
  بعد: **'كلّم أمين الخدمة يعيّنك على فصل.';**

- قبل: 'سيتم حذف الفصل وكل جلسات الحضور الخاصة به نهائياً. هل تريد المتابعة؟';
  بعد: **'الفصل وكل جلسات الحضور بتاعته هيتمسحوا نهائي. تكمّل؟';**

- قبل: static const classDeleted = 'تم حذف الفصل';
  بعد: **static const classDeleted = 'اتحذف الفصل';**

- قبل: 'لا يمكن حذف فصل به مخدومون. انقلهم إلى فصل آخر أولاً أو استخدم الأرشفة.';
  بعد: **'ما ينفعش تحذف فصل فيه مخدومين. انقلهم لفصل تاني الأول أو استخدم الأرشفة.';**

- قبل: static const noPatron = 'لم يتم تحديد شفيع';
  بعد: **static const noPatron = 'لسه ما اتحدّدش شفيع';**

- قبل: static const noClasses = 'لا توجد فصول';
  بعد: **static const noClasses = 'مفيش فصول';**

- قبل: 'سيتم إخفاء الفصل من القوائم النشطة مع الاحتفاظ بكل بياناته. هل تريد المتابعة؟';
  بعد: **'الفصل هيتخفي من القوائم النشطة وبياناته كلها هتفضل محفوظة. تكمّل؟';**

- قبل: static const servantDataHint = 'هذه البيانات تظهر لأمين الخدمة فقط.';
  بعد: **static const servantDataHint = 'البيانات دي بتظهر لأمين الخدمة بس.';**

- قبل: static const noNotifications = 'لا توجد إشعارات';
  بعد: **static const noNotifications = 'مفيش إشعارات';**

- قبل: 'طلبات تحتاج موافقتك قبل أن يرى أصحابها أي بيانات.';
  بعد: **'طلبات محتاجة موافقتك قبل ما أصحابها يشوفوا أي بيانات.';**

- قبل: static const noPendingRequests = 'لا توجد طلبات انضمام';
  بعد: **static const noPendingRequests = 'مفيش طلبات انضمام';**

- قبل: static const confirmRejectRequest = 'سيتم رفض الطلب ولن يستطيع صاحبه الدخول.';
  بعد: **static const confirmRejectRequest = 'الطلب هيترفض وصاحبه مش هيقدر يدخل.';**

- قبل: static const requestAccepted = 'تم قبول الطلب';
  بعد: **static const requestAccepted = 'الطلب اتقبل';**

- قبل: static const requestRejected = 'تم رفض الطلب';
  بعد: **static const requestRejected = 'الطلب اترفض';**

- قبل: 'تم إنشاء الدعوة. يسجّل الخادم بنفس البريد الإلكتروني ليتم تنشيط حسابه تلقائياً.';
  بعد: **'الدعوة اتعملت. الخادم يسجّل بنفس البريد الإلكتروني وحسابه هيتفعّل لوحده.';**

- قبل: 'سيتم تنشيط الحساب وتعيين الفصل تلقائياً بمجرد تسجيل الخادم بهذا البريد.';
  بعد: **'الحساب هيتفعّل والفصل هيتعيّن لوحدهم أول ما الخادم يسجّل بالبريد ده.';**

- قبل: static const noServants = 'لا يوجد خدام';
  بعد: **static const noServants = 'مفيش خدام';**

- قبل: static const noServantsHint = 'لا يوجد خدام في هذا الفصل بعد. أمين الخدمة هو من يعيّن الخدام.';
  بعد: **static const noServantsHint = 'مفيش خدام في الفصل ده لسه. أمين الخدمة هو اللي بيعيّن الخدام.';**

- قبل: static const noCommittedYet = 'لا يوجد مخدومين ملتزمين بعد';
  بعد: **static const noCommittedYet = 'لسه مفيش مخدومين ملتزمين';**

- قبل: static const deleteVisit = 'حذف هذا الافتقاد؟';
  بعد: **static const deleteVisit = 'تحذف الافتقاد ده؟';**

- قبل: static const visitDeleted = 'تم حذف الافتقاد';
  بعد: **static const visitDeleted = 'اتحذف الافتقاد';**

- قبل: 'سيتم حذف حساب هذا الخادم نهائياً مع تحضيراته وحضوره. لا يمكن التراجع.';
  بعد: **'حساب الخادم ده هيتمسح نهائي مع تحضيراته وحضوره. مفيش رجوع.';**

- قبل: static const confirmRemoveServant = 'هل تريد إزالة هذا الخادم من الفصل؟';
  بعد: **static const confirmRemoveServant = 'تشيل الخادم ده من الفصل؟';**

- قبل: static const servantAssigned = 'تم تعيين الخادم';
  بعد: **static const servantAssigned = 'الخادم اتعيّن';**

- قبل: static const servantMoved = 'تم نقل الخادم إلى الفصل الجديد';
  بعد: **static const servantMoved = 'الخادم اتنقل للفصل الجديد';**

- قبل: static const servantRemoved = 'تمت إزالة الخادم';
  بعد: **static const servantRemoved = 'الخادم اتشال';**

- قبل: static const noServantToAssign = 'جميع الخدام مسندون لهذا الفصل بالفعل';
  بعد: **static const noServantToAssign = 'كل الخدام في الفصل ده بالفعل';**

- قبل: static const birthDateFuture = 'تاريخ الميلاد لا يمكن أن يكون في المستقبل';
  بعد: **static const birthDateFuture = 'تاريخ الميلاد ما ينفعش يكون في المستقبل';**

- قبل: static const confirmRemovePhoto = 'هل تريد حذف صورة المخدوم؟';
  بعد: **static const confirmRemovePhoto = 'تحذف صورة المخدوم؟';**

- قبل: static const photoSaved = 'تم حفظ الصورة';
  بعد: **static const photoSaved = 'الصورة اتحفظت';**

- قبل: static const photoRemoved = 'تم حذف الصورة';
  بعد: **static const photoRemoved = 'الصورة اتحذفت';**

- قبل: 'صيغة الصورة غير مدعومة. استخدم JPG أو PNG.';
  بعد: **'صيغة الصورة مش مدعومة. استخدم JPG أو PNG.';**

- قبل: static const mobileInvalid = 'رقم الموبايل غير صحيح';
  بعد: **static const mobileInvalid = 'رقم الموبايل مش صح';**

- قبل: static const noChildren = 'لا يوجد مخدومين';
  بعد: **static const noChildren = 'مفيش مخدومين';**

- قبل: static const childSaved = 'تم حفظ بيانات المخدوم';
  بعد: **static const childSaved = 'اتحفظت بيانات المخدوم';**

- قبل: 'اختر الفصل الجديد. سيتم الاحتفاظ بكل سجلات الحضور السابقة.';
  بعد: **'اختار الفصل الجديد. كل سجلات الحضور القديمة هتفضل محفوظة.';**

- قبل: static const childMoved = 'تم نقل المخدوم';
  بعد: **static const childMoved = 'المخدوم اتنقل';**

- قبل: 'سيتم إخفاء المخدوم من قوائم الحضور القادمة مع الاحتفاظ بكل سجلاته ودرجاته السابقة. '
  بعد: **'المخدوم هيتخفي من قوائم الحضور الجاية وكل سجلاته ودرجاته القديمة هتفضل محفوظة. '**

- قبل: 'هل تريد المتابعة؟';
  بعد: **'تكمّل؟';**

- قبل: static const childDeactivated = 'تم إلغاء تنشيط المخدوم';
  بعد: **static const childDeactivated = 'المخدوم اتوقّف';**

- قبل: static const childActivated = 'تم تنشيط المخدوم';
  بعد: **static const childActivated = 'المخدوم اتفعّل';**

- قبل: static const noVisitYet = 'لم يتم بعد';
  بعد: **static const noVisitYet = 'لسه ما اتعملش';**

- قبل: static const visitsSaved = 'تم حفظ بيانات الافتقاد';
  بعد: **static const visitsSaved = 'اتحفظت بيانات الافتقاد';**

- قبل: 'ستعود البيانات إلى ما كانت عليه قبل هذا التعديل. يتعذر ذلك لو تغيّرت بعده.';
  بعد: **'البيانات هترجع زي ما كانت قبل التعديل ده. ومش هينفع لو اتغيّرت بعده.';**

- قبل: static const undoDone = 'تم التراجع';
  بعد: **static const undoDone = 'اتراجع';**

- قبل: static const healthNotesEmpty = 'لا توجد ملاحظات';
  بعد: **static const healthNotesEmpty = 'مفيش ملاحظات';**

- قبل: static const healthNotesSaved = 'تم حفظ الملاحظات';
  بعد: **static const healthNotesSaved = 'اتحفظت الملاحظات';**

- قبل: static const noVisitHistory = 'لا يوجد سجل افتقادات بعد';
  بعد: **static const noVisitHistory = 'لسه مفيش سجل افتقادات';**

- قبل: static const decliningEmpty = 'لا يوجد مخدومين حضورهم في تراجع';
  بعد: **static const decliningEmpty = 'مفيش مخدومين حضورهم في تراجع';**

- قبل: 'تظهر هنا حالة من حضورها قل بوضوح في آخر ٤ سبوت عن ٤ قبلها';
  بعد: **'هنا بتظهر الحالات اللي حضورها قلّ بوضوح في آخر 4 سبوت عن الـ 4 اللي قبلهم';**

- قبل: 'كان $previous٪ وأصبح $recent٪';
  بعد: **'كان $previous٪ وبقى $recent٪';**

- قبل: static const notRecordedLabel = 'لم يسجّل الحضور:';
  بعد: **static const notRecordedLabel = 'ما سجّلوش الحضور:';**

- قبل: static const followUpNoteGeneric = 'افتقاد بعد غياب متتالي';
  بعد: **static const followUpNoteGeneric = 'افتقاد بعد غياب ورا بعض';**

- قبل: 'يُرسل تنبيه لخدام الفصل عند وصول غياب المخدوم لهذه الأعداد';
  بعد: **'بيتبعت تنبيه لخدام الفصل لما غياب المخدوم يوصل للأعداد دي';**

- قبل: static String followUpNote(int n) => 'افتقاد بعد غياب $n سبوت متتالية';
  بعد: **static String followUpNote(int n) => 'افتقاد بعد غياب $n سبوت ورا بعض';**

- قبل: static String absentSaturdays(int n) => 'غائب $n سبوت متتالية';
  بعد: **static String absentSaturdays(int n) => 'غايب $n سبوت ورا بعض';**

- قبل: static String presentSaturdays(int n) => 'حاضر $n سبوت متتالية';
  بعد: **static String presentSaturdays(int n) => 'حاضر $n سبوت ورا بعض';**

- قبل: static const notFollowedUp = 'لم يُفتقد بعد';
  بعد: **static const notFollowedUp = 'لسه ما اتفتقدش';**

- قبل: static const noAbsences = 'لا يوجد غياب متكرر';
  بعد: **static const noAbsences = 'مفيش غياب متكرر';**

- قبل: static const noAbsencesBody = 'كل المخدومين حضروا مؤخراً. ربنا يبارك';
  بعد: **static const noAbsencesBody = 'كل المخدومين حضروا الفترة اللي فاتت. ربنا يبارك';**

- قبل: static String updateAvailable(String v) => 'إصدار جديد متاح ($v)';
  بعد: **static String updateAvailable(String v) => 'فيه إصدار جديد ($v)';**

- قبل: static const updateNow = 'تحديث الآن';
  بعد: **static const updateNow = 'حدّث دلوقتي';**

- قبل: static const noChangeHistory = 'لا توجد تغييرات مسجلة';
  بعد: **static const noChangeHistory = 'مفيش تغييرات متسجّلة';**

- قبل: static String updateDownloading(int p) => 'جاري تحميل التحديث… $p٪';
  بعد: **static String updateDownloading(int p) => 'بيتحمّل التحديث… $p٪';**

- قبل: static const updateInstalling = 'اضغط «تثبيت» في الشاشة التي ظهرت';
  بعد: **static const updateInstalling = 'اضغط «تثبيت» في الشاشة اللي ظهرتلك';**

- قبل: 'اسمح للتطبيق بتثبيت التحديثات من الإعدادات، ثم حاول مرة أخرى';
  بعد: **'اسمح للتطبيق بتثبيت التحديثات من الإعدادات، وبعدين جرّب تاني';**

- قبل: static const updateBadFile = 'الملف لم يكتمل تحميله. حاول مرة أخرى';
  بعد: **static const updateBadFile = 'الملف ما اتحمّلش كامل. جرّب تاني';**

- قبل: static const updateFailed = 'تعذر التحديث من داخل التطبيق';
  بعد: **static const updateFailed = 'ما قدرناش نحدّث من جوه التطبيق';**

- قبل: 'لم يكتمل التثبيت. اضغط «تحديث الآن» لتحاول مرة أخرى';
  بعد: **'التثبيت ما كملش. اضغط «حدّث دلوقتي» وجرّب تاني';**

- قبل: static const checkForUpdates = 'التحقق من التحديثات';
  بعد: **static const checkForUpdates = 'شوف التحديثات';**

- قبل: static const checkingForUpdates = 'جاري التحقق من التحديثات…';
  بعد: **static const checkingForUpdates = 'بندوّر على تحديثات…';**

- قبل: static String upToDate(String v) => 'أنت على آخر إصدار ($v)';
  بعد: **static String upToDate(String v) => 'معاك آخر إصدار ($v)';**

- قبل: 'تعذر التحقق من التحديثات. تأكد من الإنترنت وحاول مرة أخرى';
  بعد: **'ما قدرناش نشوف التحديثات. اتأكد من الإنترنت وجرّب تاني';**

- قبل: static const birthdayPassed = 'مرّ هذا العام';
  بعد: **static const birthdayPassed = 'عدّى السنة دي';**

- قبل: static const logNotRecorded = 'لم يُسجَّل';
  بعد: **static const logNotRecorded = 'ما اتسجّلش';**

- قبل: n == 1 ? 'سبت لم يُسجَّل' : '$n سبوت لم تُسجَّل';
  بعد: **n == 1 ? 'سبت ما اتسجّلش' : '$n سبوت ما اتسجّلوش';**

- قبل: static const attendanceLogEmpty = 'لا توجد سبوت في هذه السنة بعد';
  بعد: **static const attendanceLogEmpty = 'لسه مفيش سبوت في السنة دي';**

- قبل: static const logNoMatch = 'لا توجد سبوت بهذا الاختيار';
  بعد: **static const logNoMatch = 'مفيش سبوت بالاختيار ده';**

- قبل: static const logNoLesson = 'لا يوجد درس';
  بعد: **static const logNoLesson = 'مفيش درس';**

- قبل: static const birthdaysEmpty = 'لا توجد أعياد ميلاد هذا الشهر';
  بعد: **static const birthdaysEmpty = 'مفيش أعياد ميلاد الشهر ده';**

- قبل: 'اختر شهراً آخر أو أضف تاريخ الميلاد للمخدومين.';
  بعد: **'اختار شهر تاني أو ضيف تاريخ الميلاد للمخدومين.';**

- قبل: static const birthdayToday = 'عيد ميلاده اليوم';
  بعد: **static const birthdayToday = 'عيد ميلاده النهارده';**

- قبل: static const calendarNothing = 'لا يوجد شيء في هذا اليوم';
  بعد: **static const calendarNothing = 'مفيش حاجة في اليوم ده';**

- قبل: static const calendarMonthEmpty = 'لا شيء في هذا الشهر';
  بعد: **static const calendarMonthEmpty = 'مفيش حاجة في الشهر ده';**

- قبل: static const todayBirthdays = 'أعياد الميلاد اليوم';
  بعد: **static const todayBirthdays = 'أعياد الميلاد النهارده';**

- قبل: 'تم إغلاق هذه الجلسة بواسطة المسؤول ولا يمكن تعديلها.';
  بعد: **'أمين الخدمة قفل الجلسة دي وما ينفعش تتعدّل.';**

- قبل: 'في الرئيسية هتلاقي اللي محتاج متابعة: الغايبين والبيانات الناقصة وأعياد الميلاد. اضغط على أي طفل تكلّم أهله أو تبعتلهم واتساب.';
  بعد: **'في «المزيد» هتلاقي اللي محتاج متابعة: الغايبين والبيانات الناقصة وأعياد الميلاد، وعدد كل واحدة جنبها. اضغط على أي طفل تكلّم أهله أو تبعتلهم واتساب.';**

- قبل: '«محتاج متابعة» في الرئيسية بيجمعلك الغايبين والبيانات الناقصة من كل الفصول، واضغط على أي سطر يفتحلك القايمة.';
  بعد: **'في «المزيد» هتلاقي «متابعة الغياب» و«بيانات ناقصة» لكل الفصول، وعدد كل واحدة جنبها. اضغط على أي واحدة تفتحلك القايمة.';**

- قبل: '«محتاج متابعة» في الرئيسية: الغايبين، البيانات الناقصة، التحضيرات اللي مستنية مراجعة وطلبات الانضمام، كل واحدة بعددها.';
  بعد: **'في «المزيد»: الغايبين، البيانات الناقصة، التحضيرات اللي مستنية مراجعة وطلبات الانضمام، كل واحدة بعددها.';**

- قبل: static const noSearchMatch = 'لا يوجد مخدوم بهذا البحث';
  بعد: **static const noSearchMatch = 'مفيش مخدوم بالبحث ده';**

- قبل: 'هذا السبت $reason: لا يوجد درس ولا يُسجَّل حضور.';
  بعد: **'السبت ده $reason: مفيش درس ومش بيتسجّل حضور.';**

- قبل: static const breakSheetTitle = 'هل يوجد درس هذا السبت؟';
  بعد: **static const breakSheetTitle = 'فيه درس السبت ده؟';**

- قبل: static const breakShift = 'تأجيل الدروس أسبوعاً';
  بعد: **static const breakShift = 'أجّل الدروس أسبوع';**

- قبل: 'الدروس بعد هذا السبت تتحرك أسبوعاً. اقفلها لو الدرس اتلغى فقط.';
  بعد: **'الدروس بعد السبت ده هتتأجل أسبوع. اقفله لو الدرس اتلغى بس.';**

- قبل: 'اتسجّل حضور هذا اليوم بالفعل: لن يُحسب في أبطال الالتزام ولا الغياب.';
  بعد: **'اتسجّل حضور اليوم ده قبل كده: مش هيتحسب في أبطال الالتزام ولا الغياب.';**

- قبل: static const nobodyPresentTitle = 'لم تعلّم أي مخدوم';
  بعد: **static const nobodyPresentTitle = 'ما علّمتش على أي مخدوم';**

- قبل: 'الحفظ الآن يسجّل الـ $n مخدوم كلهم غياب. لو اليوم لم يكن فيه درس '
  بعد: **'لو حفظت دلوقتي، الـ $n مخدوم كلهم هيتسجّلوا غياب. لو مكانش فيه درس '**

- قبل: 'فلا تحفظ.';
  بعد: **'النهارده ماتحفظش.';**

- قبل: static const attendanceSaved = 'تم تسجيل الحضور';
  بعد: **static const attendanceSaved = 'اتسجّل الحضور';**

- قبل: 'تم الحفظ محلياً • سيتم المزامنة عند عودة الاتصال';
  بعد: **'اتحفظ على الموبايل • هيتبعت لما النت يرجع';**

- قبل: static const offlineMode = 'وضع عدم الاتصال — البيانات محفوظة محلياً';
  بعد: **static const offlineMode = 'مفيش نت — اللي بتسجّله محفوظ على الموبايل';**

- قبل: static String pendingSyncCount(int n) => '$n تغيير في انتظار المزامنة';
  بعد: **static String pendingSyncCount(int n) => '$n تغيير مستني يتبعت';**

- قبل: static String failedSyncCount(int n) => '$n لم يُقبل';
  بعد: **static String failedSyncCount(int n) => '$n ما اتقبلش';**

- قبل: static const syncingNow = 'جارٍ المزامنة...';
  بعد: **static const syncingNow = 'بيتزامن...';**

- قبل: static const lessonOfWeek = 'درس هذا الأسبوع';
  بعد: **static const lessonOfWeek = 'درس الأسبوع ده';**

- قبل: static const prayerCopied = 'تم نسخ الصلاة';
  بعد: **static const prayerCopied = 'الصلاة اتنسخت';**

- قبل: static const noLessonThisWeek = 'لا يوجد درس في هذا الأسبوع';
  بعد: **static const noLessonThisWeek = 'مفيش درس الأسبوع ده';**

- قبل: static const lessonPostponed = 'لا درس هذا الأسبوع (تأجل للأسبوع التالي)';
  بعد: **static const lessonPostponed = 'مفيش درس الأسبوع ده (اتأجل للأسبوع اللي بعده)';**

- قبل: static const lessonCancelled = 'لا درس هذا الأسبوع (ألغي)';
  بعد: **static const lessonCancelled = 'مفيش درس الأسبوع ده (اتلغى)';**

- قبل: static const syncFailed = 'لم يقبلها الخادم';
  بعد: **static const syncFailed = 'السيرفر ما قبلهاش';**

- قبل: static const syncNothing = 'كل شيء متزامن';
  بعد: **static const syncNothing = 'كله اتبعت';**

- قبل: static const needsConnection = 'هذا الإجراء يحتاج اتصالاً بالإنترنت';
  بعد: **static const needsConnection = 'الإجراء ده محتاج نت';**

- قبل: static const noSessionsTitle = 'لا توجد جلسات حضور';
  بعد: **static const noSessionsTitle = 'مفيش جلسات حضور';**

- قبل: 'لم يتم إنشاء جلسات لهذا الفصل. برجاء مراجعة سنة الحضور من إعدادات المسؤول.';
  بعد: **'لسه ما اتعملتش جلسات للفصل ده. راجع سنة الحضور من إعدادات أمين الخدمة.';**

- قبل: static const prepMissing = 'لم يُرفع التحضير';
  بعد: **static const prepMissing = 'التحضير ما اترفعش';**

- قبل: static const noServantMobile = 'لا يوجد رقم';
  بعد: **static const noServantMobile = 'مفيش رقم';**

- قبل: 'لم يتم السماح. فعّل الإذن من إعدادات التطبيق ثم حاول مرة أخرى';
  بعد: **'ما اتسمحش. فعّل الإذن من إعدادات التطبيق وجرّب تاني';**

- قبل: 'حمّل ملفاً بأرقام الأمهات والآباء والمخدومين، وافتحه على موبايلك '
  بعد: **'حمّل ملف بأرقام الأمهات والآباء والمخدومين وافتحه على موبايلك '**

- قبل: 'ليحفظها في جهات الاتصال. بعدها يظهر اسم المتصل (مثل «أم مينا جورج – '
  بعد: **'علشان يتحفظوا في جهات الاتصال. بعدها هيظهرلك اسم المتصل (زي «أم مينا جورج – '**

- قبل: 'فصل 5 بنات») حتى لو الرقم لم يكن محفوظاً عندك.';
  بعد: **'فصل 5 بنات») حتى لو رقمه مش محفوظ عندك.';**

- قبل: static const contactsNone = 'لا توجد أرقام لحفظها';
  بعد: **static const contactsNone = 'مفيش أرقام تتحفظ';**

- قبل: 'ستُحفظ هذه الأرقام في جهات اتصال موبايلك. استخدمها لخدمتك فقط.';
  بعد: **'الأرقام دي هتتحفظ في جهات اتصال موبايلك. استخدمها في خدمتك بس.';**

- قبل: static const notTakenYet = 'لم يُسجَّل بعد';
  بعد: **static const notTakenYet = 'لسه ما اتسجّلش';**

- قبل: static const takenDone = 'تم التسجيل';
  بعد: **static const takenDone = 'اتسجّل';**

- قبل: 'سيتم إلغاء كل علامات الحضور على الشاشة. لن يُحفظ شيء حتى تضغط حفظ.';
  بعد: **'كل علامات الحضور على الشاشة هتتمسح. مفيش حاجة هتتحفظ غير لما تضغط حفظ.';**

- قبل: 'لديك تغييرات لم تُحفظ. هل تريد الخروج وتجاهلها؟';
  بعد: **'عندك تغييرات ما اتحفظتش. تخرج وتتجاهلها؟';**

- قبل: static const sessionsGenerated = 'تم إنشاء الجلسات';
  بعد: **static const sessionsGenerated = 'الجلسات اتعملت';**

- قبل: static const endBeforeStart = 'تاريخ النهاية يجب أن يكون بعد تاريخ البداية';
  بعد: **static const endBeforeStart = 'تاريخ النهاية لازم يكون بعد تاريخ البداية';**

- قبل: static const templateSaved = 'تم إنشاء ملف النموذج';
  بعد: **static const templateSaved = 'اتعمل ملف النموذج';**

- قبل: static const importRowsSkipped = 'سيتم تجاهلها';
  بعد: **static const importRowsSkipped = 'هتتجاهل';**

- قبل: static const importDone = 'تم الاستيراد';
  بعد: **static const importDone = 'اتعمل الاستيراد';**

- قبل: static const importInserted = 'تمت إضافة';
  بعد: **static const importInserted = 'اتضاف';**

- قبل: static const importUpdated = 'تم تحديث';
  بعد: **static const importUpdated = 'اتحدّث';**

- قبل: static const importNoValidRows = 'لا توجد صفوف صحيحة للاستيراد';
  بعد: **static const importNoValidRows = 'مفيش صفوف صحيحة للاستيراد';**

- قبل: static const importEmptyFile = 'الملف لا يحتوي على بيانات';
  بعد: **static const importEmptyFile = 'الملف مفيهوش بيانات';**

- قبل: 'تعذّر التعرف على أعمدة الملف. برجاء استخدام ملف النموذج.';
  بعد: **'ما قدرناش نتعرف على أعمدة الملف. استخدم ملف النموذج.';**

- قبل: static const importErrorNameMissing = 'اسم المخدوم مفقود';
  بعد: **static const importErrorNameMissing = 'اسم المخدوم ناقص';**

- قبل: static const importErrorGenderMissing = 'النوع مفقود أو غير مفهوم (ولد/بنت)';
  بعد: **static const importErrorGenderMissing = 'النوع ناقص أو مش مفهوم (ولد/بنت)';**

- قبل: static const importErrorDuplicateInFile = 'مكرر داخل نفس الملف';
  بعد: **static const importErrorDuplicateInFile = 'مكرر في نفس الملف';**

- قبل: static const importErrorNotFound = 'لا يوجد مخدوم مطابق';
  بعد: **static const importErrorNotFound = 'مفيش مخدوم مطابق';**

- قبل: static const importErrorMobile = 'رقم موبايل غير صحيح';
  بعد: **static const importErrorMobile = 'رقم موبايل مش صح';**

- قبل: static const importErrorBirthDate = 'تاريخ ميلاد غير صحيح';
  بعد: **static const importErrorBirthDate = 'تاريخ ميلاد مش صح';**

- قبل: static const importWillMoveClass = 'سيتم نقله لهذا الفصل';
  بعد: **static const importWillMoveClass = 'هيتنقل للفصل ده';**

- قبل: static const exportDone = 'تم إنشاء الملف';
  بعد: **static const exportDone = 'اتعمل الملف';**

- قبل: static const exporting = 'جارٍ التصدير…';
  بعد: **static const exporting = 'بيتصدّر…';**

- قبل: static const prepNotSent = 'لم يُرسل تحضير';
  بعد: **static const prepNotSent = 'ما بعتش تحضير';**

- قبل: static const missedPrepsTitle = 'لم يُرسل تحضيرها';
  بعد: **static const missedPrepsTitle = 'التحضيرات اللي ما اتبعتتش';**

- قبل: static const prepMarkedByHand = 'تحضير مسجّل يدوياً';
  بعد: **static const prepMarkedByHand = 'تحضير اتسجّل يدوي';**

- قبل: static const noLessonPreps = 'لا توجد تحضيرات مرفوعة';
  بعد: **static const noLessonPreps = 'مفيش تحضيرات مرفوعة';**

- قبل: static const noAttendanceRecords = 'لا توجد سجلات حضور';
  بعد: **static const noAttendanceRecords = 'مفيش سجلات حضور';**

- قبل: static const noAttendanceRecordsBody = 'لم يتم تسجيل أي حضور لهذا النشاط.';
  بعد: **static const noAttendanceRecordsBody = 'لسه ما اتسجّلش أي حضور هنا.';**

- قبل: static const submittedSuccessfully = 'تم رفع التحضير بنجاح';
  بعد: **static const submittedSuccessfully = 'التحضير اترفع';**

- قبل: static const reviewedSuccessfully = 'تمت المراجعة';
  بعد: **static const reviewedSuccessfully = 'اتراجع';**

- قبل: static const noPhotosSelected = 'يجب اختيار صورة أو ملف PDF واحد على الأقل';
  بعد: **static const noPhotosSelected = 'اختار صورة أو ملف PDF واحد على الأقل';**

- قبل: static const alreadySubmitted = 'تم الرفع';
  بعد: **static const alreadySubmitted = 'اترفع';**

- قبل: static const prepTodoNotSent = 'لم يُرسل بعد';
  بعد: **static const prepTodoNotSent = 'لسه ما اتبعتش';**

- قبل: static const couldNotLoad = 'تعذّر التحميل';
  بعد: **static const couldNotLoad = 'ما قدرناش نحمّل';**

- قبل: n == 1 ? 'لم يُرفع ملف واحد — حاول تاني' : 'لم يُرفع $n ملفات — حاول تاني';
  بعد: **n == 1 ? 'ملف واحد ما اترفعش — جرّب تاني' : '$n ملفات ما اترفعوش — جرّب تاني';**

- قبل: static const noCompetitions = 'لا توجد مسابقات';
  بعد: **static const noCompetitions = 'مفيش مسابقات';**

- قبل: static const noCompetitionsBody = 'أضف مسابقة أسبوعية للبدء.';
  بعد: **static const noCompetitionsBody = 'ضيف مسابقة أسبوعية علشان تبدأ.';**

- قبل: static const noMarkEntered = 'لم تُسجَّل علامة';
  بعد: **static const noMarkEntered = 'ما اتسجّلتش علامة';**

- قبل: static const markSaved = 'تم حفظ العلامات';
  بعد: **static const markSaved = 'اتحفظت العلامات';**

- قبل: 'هل تريد حذف هذه المسابقة وكل علاماتها؟';
  بعد: **'تحذف المسابقة دي وكل علاماتها؟';**

- قبل: static const noEvents = 'لا توجد نشاطات ترفيهية';
  بعد: **static const noEvents = 'مفيش نشاطات ترفيهية';**

- قبل: static const noEventsBody = 'أضف نشاطاً للبدء.';
  بعد: **static const noEventsBody = 'ضيف نشاط علشان تبدأ.';**

- قبل: static const eventCostInvalid = 'التكلفة يجب أن تكون أكبر من صفر';
  بعد: **static const eventCostInvalid = 'التكلفة لازم تكون أكبر من صفر';**

- قبل: static const confirmDeleteEvent = 'هل تريد حذف هذا النشاط وكل مدفوعاته؟';
  بعد: **static const confirmDeleteEvent = 'تحذف النشاط ده وكل مدفوعاته؟';**

- قبل: 'سيتم إلغاء حجز هذا المخدوم في الرحلة. المدفوعات لا تتأثر.';
  بعد: **'حجز المخدوم ده في الرحلة هيتلغى. المدفوعات ما بتتأثرش.';**

- قبل: static const reservedSaved = 'تم الحجز';
  بعد: **static const reservedSaved = 'اتحجز';**

- قبل: static const reservationCancelled = 'تم إلغاء الحجز';
  بعد: **static const reservationCancelled = 'الحجز اتلغى';**

- قبل: static const reservedUnpaidStatus = 'حاجز (لم يدفع)';
  بعد: **static const reservedUnpaidStatus = 'حاجز (لسه ما دفعش)';**

- قبل: static const bookedShort = 'تم حجز الرحلة';
  بعد: **static const bookedShort = 'اتحجزت الرحلة';**

- قبل: static const bookingPaidNote = 'دفع بالفعل: الدفع من شاشة النشاط';
  بعد: **static const bookingPaidNote = 'دفع قبل كده: الدفع من شاشة النشاط';**

- قبل: static const paymentSaved = 'تم حفظ الدفعة';
  بعد: **static const paymentSaved = 'الدفعة اتحفظت';**

- قبل: static const paymentDeleted = 'تم حذف الدفعة';
  بعد: **static const paymentDeleted = 'الدفعة اتحذفت';**

- قبل: static const noPayments = 'لا توجد مدفوعات';
  بعد: **static const noPayments = 'مفيش مدفوعات';**

- قبل: static const paymentAmountInvalid = 'المبلغ يجب أن يكون أكبر من صفر';
  بعد: **static const paymentAmountInvalid = 'المبلغ لازم يكون أكبر من صفر';**

- قبل: static const paymentAmountExceeds = 'المبلغ يتجاوز المتبقي';
  بعد: **static const paymentAmountExceeds = 'المبلغ أكبر من المتبقي';**

- قبل: static const confirmDeletePayment = 'هل تريد حذف هذه الدفعة؟';
  بعد: **static const confirmDeletePayment = 'تحذف الدفعة دي؟';**

- قبل: static const notPaidTab = 'لم يدفع';
  بعد: **static const notPaidTab = 'ما دفعش';**

- قبل: static const noPhoneNumber = 'لا يوجد رقم';
  بعد: **static const noPhoneNumber = 'مفيش رقم';**

- قبل: static const noAnnouncements = 'لا توجد إعلانات';
  بعد: **static const noAnnouncements = 'مفيش إعلانات';**

- قبل: static String announcementSent(int n) => 'تم الإرسال إلى $n';
  بعد: **static String announcementSent(int n) => 'اتبعت لـ $n';**

- قبل: static const notReadYet = 'لم يقرأ بعد';
  بعد: **static const notReadYet = 'لسه ما قراش';**

- قبل: static const noTemplates = 'لا توجد قوالب بعد';
  بعد: **static const noTemplates = 'لسه مفيش قوالب';**

- قبل: static String messagesSent(int sent, int total) => 'أُرسل $sent من $total';
  بعد: **static String messagesSent(int sent, int total) => 'اتبعت $sent من $total';**
