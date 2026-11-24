/// Arabic UI text for Sabtawya.
///
/// A plain Dart class instead of generated ARB localisations: the app ships in
/// Arabic only, and this keeps every label in one reviewable place.
///
/// Terminology: a *servant* is خادم, a *child* is مخدوم (boy = ولد, girl = بنت).
class AppStrings {
  const AppStrings._();

  // ---------------------------------------------------------------- general
  static const appTitle = 'خدمة 3:6 ابتدائي السبت';
  static const appSubtitle = 'نظام إدارة الحضور والطايو';
  static const churchName =
      'كنيسة السيدة العذراء مريم و القديس اثناسيوس الرسولي بمدينة نصر';
  static const save = 'حفظ';
  static const cancel = 'إلغاء';
  static const delete = 'حذف';
  static const edit = 'تعديل';
  static const add = 'إضافة';
  static const search = 'بحث';
  static const noResults = 'لا توجد نتائج';
  static const promoteClassesTitle = 'ترقية الفصول للسنة الجديدة';
  static const promoteClassesConfirm = 'رقّي الفصول';
  static const retry = 'إعادة المحاولة';
  static const confirm = 'تأكيد';
  static const close = 'إغلاق';
  static const loading = 'جارٍ التحميل…';
  static const noData = 'لا توجد بيانات';
  static const all = 'الكل';
  static const active = 'نشط';
  static const inactive = 'غير نشط';
  static const optional = 'اختياري';
  static const deacon = 'شماس';
  static const yes = 'نعم';
  static const no = 'لا';
  static const total = 'الإجمالي';
  static const points = 'طايو';
  static const notes = 'ملاحظات';
  static const saved = 'تم الحفظ بنجاح';
  static String saveFailedFor(List<String> classes) =>
      'لم يُحفظ: ${classes.join('، ')}. الباقي اتحفظ، اضغط حفظ مرة أخرى.';
  static const somethingWentWrong = 'حدث خطأ غير متوقع';
  static const noPermission = 'ليس لديك صلاحية لهذا الإجراء';
  static const refresh = 'تحديث';
  static const apply = 'تطبيق';
  static const select = 'اختر';
  static const unknown = 'غير معروف';
  static const reset = 'إعادة ضبط';

  // ------------------------------------------------------------------- auth
  static const login = 'تسجيل الدخول';
  static const logout = 'تسجيل الخروج';
  static const email = 'البريد الإلكتروني';
  static const password = 'كلمة المرور';
  static const forgotPassword = 'نسيت كلمة المرور؟';
  static const resetPassword = 'استعادة كلمة المرور';
  static const resetPasswordHint =
      'أدخل بريدك الإلكتروني وسنرسل لك رابط استعادة كلمة المرور.';
  static const resetLinkSent =
      'لو كان هذا البريد مسجلاً عندنا، وصله رابط الاستعادة';
  static const sendResetLink = 'إرسال الرابط';
  static const setNewPassword = 'تعيين كلمة مرور جديدة';
  static const newPassword = 'كلمة المرور الجديدة';
  static const confirmNewPassword = 'تأكيد كلمة المرور الجديدة';
  static const passwordChanged = 'تم تغيير كلمة المرور بنجاح';
  static const backToLogin = 'العودة لتسجيل الدخول';
  static const signUp = 'إنشاء حساب جديد';
  static const signUpHint =
      'أنشئ حسابك ثم انتظر تنشيط المسؤول حتى تظهر لك فصولك.';
  static const noAccountYet = 'ليس لديك حساب؟ أنشئ حساباً';
  static const fullName = 'الاسم بالكامل';
  static const fullNameRequired = 'الاسم مطلوب';
  static const nameArabicOnly = 'الاسم يجب أن يكون باللغة العربية';
  static const confirmPassword = 'تأكيد كلمة المرور';
  static const passwordsDoNotMatch = 'كلمتا المرور غير متطابقتين';
  static const passwordTooShort = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
  static const signUpDone = 'تم إنشاء الحساب';
  static const confirmEmailTitle = 'تأكيد البريد الإلكتروني';
  static const confirmEmailBody =
      'أرسلنا رسالة تأكيد إلى بريدك الإلكتروني. افتح الرابط ثم سجّل الدخول.';
  static const emailAlreadyUsed = 'هذا البريد الإلكتروني مستخدم بالفعل';
  static const emailDisposable =
      'لا يمكن التسجيل ببريد مؤقت. استخدم بريدك الشخصي الذي تستعمله دائماً.';
  static String emailTypo(String? suggestion) => suggestion == null
      ? 'يبدو أن البريد مكتوب خطأ. راجعه ثم سجّل.'
      : 'هل تقصد $suggestion ؟ صحّح البريد ثم سجّل.';
  static String emailDomainNoMail(String domain) =>
      'النطاق $domain لا يستقبل رسائل. تأكد من كتابة البريد صحيحاً.';
  static const emailRejected =
      'لا يمكن التسجيل بهذا البريد. استخدم بريدك الشخصي الصحيح.';
  static const invalidEmail = 'البريد الإلكتروني غير صحيح';
  static const nameAlreadyUsed =
      'هذا الاسم مسجل بالفعل. لو عندك حساب سجّل الدخول، أو اكتب اسمك كاملاً بشكل مختلف.';
  static const emailRequired = 'البريد الإلكتروني مطلوب';
  static const emailInvalid = 'صيغة البريد الإلكتروني غير صحيحة';
  static const passwordRequired = 'كلمة المرور مطلوبة';
  static const invalidCredentials =
      'البريد الإلكتروني أو كلمة المرور غير صحيحة';
  static const accountInactiveTitle = 'الحساب غير مُنشّط';
  static const accountInactiveBody =
      'تم إنشاء حسابك ولكنه في انتظار تنشيط المسؤول. برجاء التواصل مع المسؤول.';
  static const accountNotFoundTitle = 'البريد غير مسجل';
  static const accountNotFoundBody =
      'هذا البريد الإلكتروني غير مسجل في النظام. تواصل مع أمين الخدمة للحصول على دعوة.';
  static const accountRejectedTitle = 'تم رفض الطلب';
  static const accountRejectedBody =
      'تم رفض طلب التسجيل الخاص بك. تواصل مع أمين الخدمة للمزيد من المعلومات.';
  static const signUpSuccess =
      'تم إنشاء حسابك بنجاح — في انتظار موافقة المسؤول';
  static const logoutAndRetry = 'الخروج والمحاولة بحساب آخر';
  static const confirmLogout = 'هل تريد تسجيل الخروج؟';
  static String confirmLogoutPending(int n) =>
      'لديك $n تغيير لم يُرسل بعد. سيبقى محفوظًا على هذا الجهاز ويُرسل عند '
      'تسجيل دخولك مرة أخرى. هل تريد تسجيل الخروج؟';

  // -------------------------------------------------------------- setup gate
  static const setupMissingTitle = 'إعداد غير مكتمل';
  static const setupMissingBody =
      'لم يتم تهيئة بيانات الاتصال بقاعدة البيانات. برجاء تشغيل التطبيق مع تمرير '
      'SUPABASE_URL و SUPABASE_ANON_KEY.';

  // -------------------------------------------------------------- navigation
  static const dashboard = 'الرئيسية';
  static const myClasses = 'فصلي';
  static const classesNav = 'الفصول';
  static const childrenNav = 'المخدومين';
  static const attendanceNav = 'الحضور';
  static const reportsNav = 'ابطال الطايو';
  static const more = 'المزيد';
  static const servantsNav = 'الخدام';
  static const settings = 'الإعدادات';

  // --------------------------------------------------------------- dashboard
  static const welcome = 'مرحباً';
  static const totalClasses = 'الفصول';
  static const totalServants = 'الخدام';
  static const totalChildren = 'المخدومين';
  static const totalPoints = 'إجمالي الطايوهات';
  static const nextAttendance = 'موعد الحضور القادم';
  static const lastAttendance = 'آخر سبت للحضور';
  static const lastSaturdayRate = 'حضور آخر سبت';
  static String classRecordedOn(String day) => 'اتسجّل حضور $day';
  static String classNotRecordedOn(String day) => 'لم يُسجَّل حضور $day بعد';
  static String classWeekAttendance(String day) => 'حضور سبت $day';
  static const recordNow = 'سجّل الحضور';
  static const classNeedsServant = 'محتاج خادم';
  static const prepSentLine = 'التحضير اتبعت';
  static const healthShort = 'صحة الفصل';
  static String healthChipTooltip(int score) =>
      'صحة الفصل $score من 100: من حضور الأطفال وتسجيل الحضور والتحضير والافتقاد';
  static const noUpcomingSession = 'لا توجد جلسة قادمة';
  static const noAttendanceYet = 'لم يُسجَّل حضور بعد';
  static const noBirthdaysToday = 'لا توجد أعياد ميلاد اليوم';
  static const futureSession = 'سبت لم يأتِ بعد';
  static const showUpcoming = 'السبوت القادمة';
  static const averageAttendance = 'متوسط الحضور';
  static const recentActivity = 'آخر التحديثات';
  static const activityLogTitle = 'سجل التعديلات';
  static const logFilters = 'تصفية';
  static const logClear = 'مسح التصفية';
  static const logByServant = 'الخادم';
  static const logAnyServant = 'كل الخدام';
  static const logByChild = 'المخدوم';
  static const logAnyChild = 'كل المخدومين';
  static const logSearchChild = 'ابحث باسم المخدوم';
  static const logEntityAll = 'الكل';
  static const logEntityAttendance = 'الحضور';
  static const logEntityChildren = 'المخدومين';
  static const logEntityAssignments = 'تعيين الخدام';
  static const logEntityAccounts = 'الحسابات';
  static const logPeriodAll = 'كل الأوقات';
  static const logPeriodToday = 'اليوم';
  static const logPeriodWeek = 'آخر 7 أيام';
  static const logPeriodMonth = 'آخر 30 يوم';
  static const logEmpty = 'لا توجد تعديلات بهذه التصفية';
  static const logLoadMore = 'عرض المزيد';
  static const loadFailed = 'تعذّر التحميل';
  static const missingInfoTitle = 'بيانات ناقصة';
  static const missingAny = 'أي بيان ناقص';
  static const missingNone = 'مفيش بيانات ناقصة';
  static const missingNoneAny = 'كل المخدومين بياناتهم كاملة.';
  static String missingNoneField(String field) => 'كل المخدومين عندهم $field.';
  static const missingProgressAll = 'اكتمال بيانات المخدومين';
  static String missingProgressField(String field) => 'اكتمال: $field';
  static String missingCount(int n) => n == 0
      ? 'كله كامل'
      : n == 1
          ? 'مخدوم واحد ناقص'
          : '$n مخدوم ناقص';
  static String missingDoneOf(int done, int total) => 'اكتمل $done من $total';
  static const missingAskFamily = 'اطلب البيانات من الأسرة على واتساب';
  static String askedAlready(int days) => days <= 0
      ? 'اتطلب النهارده'
      : days == 1
          ? 'اتطلب امبارح'
          : days == 2
              ? 'اتطلب من يومين'
              : 'اتطلب من $days أيام';
  static const askAgainQuestion = 'تبعت للأسرة تاني؟';
  static const askAgain = 'ابعت تاني';
  static String missingOnChild(String fields) => 'ناقص: $fields';
  static const missingEditChild = 'كمّل البيانات';
  static String missingHomeCount(int n) =>
      n == 1 ? 'مخدوم واحد بياناته ناقصة' : '$n مخدوم بياناتهم ناقصة';
  static const missingHomeOpen = 'عرض القائمة';
  static const noClassesAssigned = 'لم يتم تعيين أي فصل لك بعد';
  static const noClassesAssignedBody =
      'برجاء التواصل مع المسؤول لتعيينك على فصل.';
  static const quickActions = 'إجراءات سريعة';

  // ----------------------------------------------------------------- classes
  static const classesTitle = 'الفصول';
  static const classLabel = 'الفصل';
  static const className = 'اسم الفصل';
  static const classDescription = 'الوصف';
  static const addClass = 'إضافة فصل';
  static const editClass = 'تعديل الفصل';
  static const archiveClass = 'أرشفة الفصل';
  static const restoreClass = 'إعادة تنشيط الفصل';
  static const deleteClass = 'حذف الفصل';
  static const confirmDeleteClass =
      'سيتم حذف الفصل وكل جلسات الحضور الخاصة به نهائياً. هل تريد المتابعة؟';
  static const classDeleted = 'تم حذف الفصل';
  static const classHasChildren =
      'لا يمكن حذف فصل به مخدومون. انقلهم إلى فصل آخر أولاً أو استخدم الأرشفة.';
  static const classNameRequired = 'اسم الفصل مطلوب';
  static const patronSaint = 'شفيع الفصل';
  static const patronName = 'اسم الشفيع';
  static const patronPhoto = 'صورة الشفيع';
  static const noPatron = 'لم يتم تحديد شفيع';
  static const childrenCount = 'عدد المخدومين';
  static const servantsCount = 'عدد الخدام';
  static const assignedServants = 'الخدام المعينون';
  static const servantIsMe = 'أنت';
  static const servantInactive = 'غير مفعّل';
  static const classDetails = 'تفاصيل الفصل';
  static const selectClass = 'اختر الفصل';
  static const noClasses = 'لا توجد فصول';
  static const confirmArchiveClass =
      'سيتم إخفاء الفصل من القوائم النشطة مع الاحتفاظ بكل بياناته. هل تريد المتابعة؟';

  // ---------------------------------------------------------------- servants
  static const servantsTitle = 'الخدام';
  static const servantLabel = 'الخادم';
  static const addServant = 'إضافة خادم';
  static const editServant = 'تعديل الخادم';
  static const servantName = 'اسم الخادم';
  static const servantData = 'بيانات الخادم';
  static const confessor = 'آب الاعتراف';
  static const occupation = 'الدراسة أو العمل';
  static const servantDataHint = 'هذه البيانات تظهر لأمين الخدمة فقط.';
  static const mobile = 'رقم الموبايل';
  static const role = 'الصلاحية';
  static const roleAdmin = 'أمين الخدمة';
  static const roleServant = 'خادم';
  static const roleServantFemale = 'خادمة';
  static const roleGeneralServant = 'خادم عام';
  static const pendingRequests = 'طلبات الانضمام';
  static const notificationsTitle = 'الإشعارات';
  static const noNotifications = 'لا توجد إشعارات';
  static const markAllRead = 'تعليم الكل كمقروء';
  static const pendingRequestsBody =
      'طلبات تحتاج موافقتك قبل أن يرى أصحابها أي بيانات.';
  static const noPendingRequests = 'لا توجد طلبات انضمام';
  static const acceptRequest = 'قبول';
  static const rejectRequest = 'رفض';
  static const confirmRejectRequest = 'سيتم رفض الطلب ولن يستطيع صاحبه الدخول.';
  static const requestAccepted = 'تم قبول الطلب';
  static const requestRejected = 'تم رفض الطلب';
  static const assignedClasses = 'الفصل المعين';
  static const activateServant = 'تنشيط';
  static const deactivateServant = 'إلغاء التنشيط';
  static const pendingInvites = 'دعوات في انتظار التسجيل';
  static const registeredServants = 'الخدام المسجلون';
  static const allServants = 'الكل';
  static const servantsShort = 'خدام';
  static const adminsShort = 'أمناء';
  static const moreActions = 'خيارات';
  static const inviteCreated =
      'تم إنشاء الدعوة. يسجّل الخادم بنفس البريد الإلكتروني ليتم تنشيط حسابه تلقائياً.';
  static const inviteHint =
      'سيتم تنشيط الحساب وتعيين الفصل تلقائياً بمجرد تسجيل الخادم بهذا البريد.';
  static const servantOneClass = 'الخادم يُعيَّن على فصل واحد فقط.';
  static const deleteInvite = 'حذف الدعوة';
  static const noServants = 'لا يوجد خدام';
  static const classesWithoutServant = 'فصول بلا خادم';
  static const servantsWithoutClass = 'خدام بلا فصل';
  static const servantsWithoutClassTitle = 'خدام لسه من غير فصل';
  static const classHasNoServant = 'مفيش خادم في الفصل ده لسه';
  static String servantsCountOf(int n) =>
      n == 1 ? 'خادم واحد' : '$n خدام';
  static const allCollected = 'اتحصّل المبلغ كله';
  static const noServantsHint = 'لا يوجد خدام في هذا الفصل بعد. أمين الخدمة هو من يعيّن الخدام.';
  static const classFollowUp = 'متابعة الفصل';
  static String pointsOf(int n) => '$n طايو';
  static const followAbsent = 'غياب متكرر';
  static const followBirthdays = 'أعياد الشهر';
  static const followMissing = 'بيانات ناقصة';
  static String chipCommitted(int n) => 'أبطال الالتزام $n';
  static const championsTitle = 'أبطال الالتزام';
  static const tierCommitted = 'ملتزم';
  static const tierGold = 'ملتزم ذهبي';
  static String absentFor(int n) => 'غاب $n';
  static const actionHistory = 'السجل';
  static const actionMessage = 'رسالة';
  static const actionContacts = 'جهات الاتصال';
  static const servantNameRequired = 'اسم الخادم مطلوب';

  // ------------------------------------------------------------- assignments
  static const assignmentsTitle = 'تعيين الخدام';
  static const assignServant = 'تعيين خادم';
  static const committedStreak = 'أبطال الالتزام';
  static const committedStreakHint =
      '4 سبوت ورا بعض = وسام «ملتزم»، و12 = «ملتزم ذهبي». شجّعهم!';
  static const committedTierNear = 'على الطريق';
  static const committedTierNearSub = '3 سبوت';
  static const committedTierSub4 = '4+ سبوت';
  static const committedTierSub16 = '12+ سبت';
  static const oneLeftForCommitted = 'باقي سبت على وسام «ملتزم»';
  static String leftForGold(int n) =>
      n == 1 ? 'باقي سبت على «ملتزم ذهبي»' : 'باقي $n على «ملتزم ذهبي»';
  static const noCommittedYet = 'لا يوجد مخدومين ملتزمين بعد';
  static const deleteVisit = 'حذف هذا الافتقاد؟';
  static const visitDeleted = 'تم حذف الافتقاد';
  static const myData = 'تعديل بياناتي';
  static const myDataHint =
      'عدّل بياناتك الشخصية: الاسم، الموبايل، تاريخ الميلاد، العنوان وغيرها.';
  static const deleteServant = 'حذف الخادم';
  static const confirmDeleteServant =
      'سيتم حذف حساب هذا الخادم نهائياً مع تحضيراته وحضوره. لا يمكن التراجع.';
  static const removeServant = 'إزالة من الفصل';
  static const confirmRemoveServant = 'هل تريد إزالة هذا الخادم من الفصل؟';
  static const servantAssigned = 'تم تعيين الخادم';
  static const servantMoved = 'تم نقل الخادم إلى الفصل الجديد';
  static const servantRemoved = 'تمت إزالة الخادم';
  static const noServantToAssign = 'جميع الخدام مسندون لهذا الفصل بالفعل';
  static const currentClass = 'الفصل الحالي';

  // ---------------------------------------------------------------- children
  static const childrenTitle = 'المخدومين';
  static const childLabel = 'المخدوم';
  static const addChild = 'إضافة مخدوم';
  static const editChild = 'تعديل بيانات المخدوم';
  static const childProfile = 'ملف المخدوم';
  static const childName = 'اسم المخدوم';
  static const childCode = 'كود المخدوم';
  static const childCodeHint = 'يُولَّد تلقائياً عند إضافة المخدوم';
  static const childCodePending = 'سيظهر بعد الحفظ';
  static const childMobile = 'موبايل المخدوم';
  static const gender = 'النوع';
  static const boy = 'ولد';
  static const girl = 'بنت';
  static const boys = 'أولاد';
  static const girls = 'بنات';
  static const genderRequired = 'النوع مطلوب';
  static const birthDate = 'تاريخ الميلاد';
  static const age = 'السن';
  static const years = 'سنة';
  static const birthDateFuture = 'تاريخ الميلاد لا يمكن أن يكون في المستقبل';
  static const pickBirthDate = 'اختر تاريخ الميلاد';
  static const childPhoto = 'صورة المخدوم';
  static const addPhoto = 'إضافة صورة';
  static const changePhoto = 'تغيير الصورة';
  static const takePhoto = 'التصوير بالكاميرا';
  static const fromGallery = 'اختيار من الصور';
  static const removePhoto = 'حذف الصورة';
  static const confirmRemovePhoto = 'هل تريد حذف صورة المخدوم؟';
  static const photoSaved = 'تم حفظ الصورة';
  static const photoRemoved = 'تم حذف الصورة';
  static const photoTooLarge = 'حجم الصورة كبير. الحد الأقصى 5 ميجابايت.';
  static const photoTypeNotSupported =
      'صيغة الصورة غير مدعومة. استخدم JPG أو PNG.';
  static const motherName = 'اسم الأم';
  static const motherMobile = 'موبايل الأم';
  static const fatherName = 'اسم الأب';
  static const fatherMobile = 'موبايل الأب';
  static const confessionFather = 'أب الاعتراف';
  static const school = 'المدرسة';
  static const address = 'العنوان';
  static const personalInfo = 'البيانات الشخصية';
  static const parentsInfo = 'بيانات الوالدين';
  static const churchInfo = 'البيانات الكنسية';
  static const schoolInfo = 'المدرسة والعنوان';
  static const childNameRequired = 'اسم المخدوم مطلوب';
  static const mobileInvalid = 'رقم الموبايل غير صحيح';
  static const noChildren = 'لا يوجد مخدومين';
  static const noChildrenBody = 'ابدأ بإضافة مخدوم أو استيراد قائمة من Excel.';
  static const childSaved = 'تم حفظ بيانات المخدوم';
  static const moveChild = 'نقل المخدوم لفصل آخر';
  static const moveChildBody =
      'اختر الفصل الجديد. سيتم الاحتفاظ بكل سجلات الحضور السابقة.';
  static const childMoved = 'تم نقل المخدوم';
  static const newClass = 'الفصل الجديد';
  static const deactivateChild = 'إلغاء تنشيط المخدوم';
  static const activateChild = 'تنشيط المخدوم';
  static const confirmDeactivateChild =
      'سيتم إخفاء المخدوم من قوائم الحضور القادمة مع الاحتفاظ بكل سجلاته ودرجاته السابقة. '
      'هل تريد المتابعة؟';
  static const childDeactivated = 'تم إلغاء تنشيط المخدوم';
  static const childActivated = 'تم تنشيط المخدوم';
  static const showInactive = 'إظهار غير النشطين';
  static const inactiveChip = 'غير النشطين';
  static const createdAt = 'تاريخ الإضافة';
  static const updatedAt = 'آخر تحديث';
  static const visitsSection = 'الافتقادات';
  static const lastPhoneVisit = 'آخر افتقاد تليفون';
  static const lastHomeVisit = 'آخر افتقاد منزلي';
  static const visitNotes = 'ملاحظات الافتقاد';
  static const noVisitYet = 'لم يتم بعد';
  static const pickVisitDate = 'اختر تاريخ الافتقاد';
  static const visitsSaved = 'تم حفظ بيانات الافتقاد';
  static const visitHistory = 'سجل الافتقادات';
  static const undo = 'تراجع';
  static const undoEditTitle = 'التراجع عن هذا التعديل';
  static const undoEditMessage =
      'ستعود البيانات إلى ما كانت عليه قبل هذا التعديل. يتعذر ذلك لو تغيّرت بعده.';
  static const undoDone = 'تم التراجع';
  static const recentImports = 'استيرادات حديثة';
  static const undoImportTitle = 'التراجع عن الاستيراد';
  static const undoImportMessage =
      'سيُحذف المخدومون الذين أضافهم هذا الاستيراد وتعود بيانات من عدّلهم إلى ما كانت. يتعذر ذلك لو عُدّل أحدهم بعده.';
  static String importBatchLine(String when, int added, int changed) =>
      '$when: أضاف $added، عدّل $changed';
  static const healthNotesTitle = 'ملاحظات صحية وخاصة';
  static const healthNotesHint =
      'حساسية، حالة صحية، ظروف أسرية... (يراها خدام الفصل والأمين فقط)';
  static const healthNotesEmpty = 'لا توجد ملاحظات';
  static const healthNotesSaved = 'تم حفظ الملاحظات';
  static const healthNotesPrivate = 'خاصة: لا يراها غير خدام الفصل والأمين';
  static const noVisitHistory = 'لا يوجد سجل افتقادات بعد';
  static const childBirthdaysTitle = 'أعياد ميلاد المخدومين';
  static const servantBirthdays = 'أعياد ميلاد الخدام';
  static const childBirthdaysShort = 'المخدومين';
  static const servantBirthdaysShort = 'الخدام';
  static const dayOfMonth = 'اليوم';
  static const pickMonths = 'اختر الشهور';
  static const thisMonth = 'هذا الشهر';
  static const pickMonthToExport = 'اختر الشهر للتصدير';
  static const pickMonth = 'اختر الشهر';
  static const wholeYear = 'السنة كلها';
  static const allClasses = 'كل الفصول';
  static const pickClasses = 'اختر فصلاً أو أكثر';
  static const absenceFollowUp = 'متابعة الغياب';
  static const decliningAttendance = 'حضور في تراجع';
  static const decliningEmpty = 'لا يوجد مخدومين حضورهم في تراجع';
  static const decliningEmptyBody =
      'تظهر هنا حالة من حضورها قل بوضوح في آخر ٤ سبوت عن ٤ قبلها';
  static String decliningLine(int recent, int previous) =>
      'كان $previous٪ وأصبح $recent٪';
  static const searchEverything = 'ابحث عن مخدوم أو فصل أو خادم';
  static const searchHint = 'اكتب حرفين على الأقل';
  static const activityReport = 'الممارسات الروحية';
  static const activityByClass = 'الحضور حسب الممارسة';
  static const saturdaysHeld = 'السبوت حتى الآن';
  static const weeklyAttendance = 'الحضور كل سبت';
  static const attendedLastSaturday = 'حضروا آخر سبت';
  static String attendedOf(int came, int of) => '$came من $of مخدوم';
  static String comparedToPrevious(int diff) => diff == 0
      ? 'زي السبت اللي قبله'
      : diff > 0
          ? 'أعلى $diff% من السبت اللي قبله'
          : 'أقل ${-diff}% من السبت اللي قبله';
  static String notRecordedClasses(List<String> names) =>
      '${names.length == 1 ? 'فصل لم يسجّل' : names.length == 2 ? 'فصلين لم يسجّلوا' : '${names.length} فصول لم يسجّلوا'} الحضور: ${names.join('، ')}';
  static String saturdayDetail(String date, int came, int of, int pct) =>
      'سبت $date: حضر $came من $of ($pct%)';
  static String attendedOn(String date) => 'حضروا سبت $date';
  /// Percentage points from the Saturday before, with both numbers.
  static String pointsChange(int diff, int from, int to) => diff == 0
      ? 'زي السبت اللي قبله ($to%)'
      : diff > 0
          ? 'أعلى $diff بالمئة من السبت اللي قبله (من $from% لـ $to%)'
          : 'أقل ${-diff} بالمئة من السبت اللي قبله (من $from% لـ $to%)';
  static String saturdaysMissed(List<String> dates) => dates.length == 1
      ? 'سبت ${dates.single} ما اتسجلش'
      : 'سبوت ${dates.join('، ')} ما اتسجلتش';
  static String weekNotRecorded(String date) => 'سبت $date: ما اتسجلش';
  static String weekBreak(String date) => 'سبت $date: إجازة، مفيش درس';
  static const todayNoneYet = 'النهارده: لسه محدش سجّل';
  static String todayProgress(int done, int all) =>
      'النهارده: سجّل $done من $all فصول';
  static const stillRecording = 'لسه بيسجّلوا:';
  static const notRecordedLabel = 'لم يسجّل الحضور:';
  static String serviceWide(int pct) => 'الخدمة كلها $pct%';
  static const todayBar = 'النهارده';
  static const breakShort = 'إجازة';
  static const legendHigh = '60% وأكثر';
  static const legendMid = '40–59%';
  static const legendLow = 'أقل من 40%';
  static const goalLine = 'الهدف 60%';
  static const followUpHow = 'كيف تم افتقاد';
  static const followUpNoteGeneric = 'افتقاد بعد غياب متتالي';
  static const logCall = 'سجّل افتقاد';
  static const absenceAlertSettings = 'تنبيهات الغياب';
  static const absenceAlertLevelsLabel =
      'عدد السبوت المتتالية للتنبيه (مثال: 2,3)';
  static const absenceAlertLevelsHelp =
      'يُرسل تنبيه لخدام الفصل عند وصول غياب المخدوم لهذه الأعداد';
  static const absenceAlertLevelsInvalid =
      'اكتب من رقم إلى 4 أرقام بين 1 و20 مفصولة بفاصلة';
  static const followUpPhone = 'مكالمة تليفون';
  static const followUpHome = 'زيارة منزلية';
  static String followUpNote(int n) => 'افتقاد بعد غياب $n سبوت متتالية';
  static String absentInARowShort(String n) => 'غياب $n سبوت';
  static String absentSaturdays(int n) => 'غائب $n سبوت متتالية';
  static String presentSaturdays(int n) => 'حاضر $n سبوت متتالية';
  static const lastPresent = 'آخر حضور';
  static const followedUpOn = 'تم الافتقاد';
  static const notFollowedUp = 'لم يُفتقد بعد';
  static const markFollowedUp = 'تم الافتقاد';
  static const noAbsences = 'لا يوجد غياب متكرر';
  static const noAbsencesBody = 'كل المخدومين حضروا مؤخراً. ربنا يبارك';
  static String updateAvailable(String v) => 'إصدار جديد متاح ($v)';
  static const updateNow = 'تحديث الآن';
  static String visitBy(String name) => 'بواسطة $name';
  static const changeHistory = 'سجل التغييرات';
  static String showAllCount(int n) => 'عرض الكل ($n)';
  static const noChangeHistory = 'لا توجد تغييرات مسجلة';
  static const changeAdded = 'إضافة المخدوم';
  static const changeEdited = 'تعديل بيانات المخدوم';
  static const changeAttendance = 'تسجيل الحضور';
  static const updateRequiredTitle = 'تحديث مطلوب';
  static String updateRequiredBody(String v) =>
      'لازم تحدّث التطبيق للإصدار $v علشان تكمل استخدامه.';
  static String updateDownloading(int p) => 'جاري تحميل التحديث… $p٪';
  static const updateInstalling = 'اضغط «تثبيت» في الشاشة التي ظهرت';
  static const updateNeedsPermission =
      'اسمح للتطبيق بتثبيت التحديثات من الإعدادات، ثم حاول مرة أخرى';
  static const updateBadFile = 'الملف لم يكتمل تحميله. حاول مرة أخرى';
  static const updateFailed = 'تعذر التحديث من داخل التطبيق';
  static const updateNotFinished =
      'لم يكتمل التثبيت. اضغط «تحديث الآن» لتحاول مرة أخرى';
  static const updateOpenPage = 'صفحة التحميل';
  static const checkForUpdates = 'التحقق من التحديثات';
  static const checkingForUpdates = 'جاري التحقق من التحديثات…';
  static String upToDate(String v) => 'أنت على آخر إصدار ($v)';
  static const updateCheckFailed =
      'تعذر التحقق من التحديثات. تأكد من الإنترنت وحاول مرة أخرى';
  static const updateReloadBody =
      'افتح الإصدار الجديد دلوقتي؟ كل اللي سجلته محفوظ.';
  static const updateReload = 'إعادة التحميل';
  static String classesCount(int n) => n <= 10 ? '$n فصول' : '$n فصل';
  static const done = 'تم';
  static String monthsCount(int n) => n <= 10 ? '$n شهور' : '$n شهر';
  static const birthdayPassed = 'مرّ هذا العام';
  static const birthdayTomorrow = 'بكرة';
  static const todayShort = 'اليوم';
  static String birthdayInDays(int days) =>
      days <= 10 ? 'بعد $days أيام' : 'بعد $days يوم';
  static String birthdaysCount(int n) => n == 1
      ? 'عيد ميلاد واحد'
      : n == 2
          ? 'عيدا ميلاد'
          : n <= 10
              ? '$n أعياد ميلاد'
              : '$n عيد ميلاد';
  static const personName = 'الاسم';
  static const turningAgeColumn = 'يكمل (سنة)';
  static const attendanceSummary = 'ملخص الحضور';
  static const monthlyBreakdown = 'التفصيل الشهري';
  static const searchChildHint = 'ابحث بالاسم أو الموبايل أو الكود';

  // ----------------------------------------------------------------- filters
  static const filters = 'تصفية';
  static const filterResults = 'نتائج التصفية';
  static const clearFilters = 'إلغاء التصفية';
  static const sortBy = 'ترتيب حسب';
  static const sortByName = 'الاسم';
  static const sortByPoints = 'الطايوهات';
  static const sortByAttendance = 'نسبة الحضور';
  static const sortByAge = 'السن';
  static const allMonths = 'كل الشهور';
  static const presentOnly = 'الحاضرون فقط';
  static const absentOnly = 'الغائبون فقط';

  // A child's attendance log (profile), one month at a time.
  static const logPresent = 'حضر';
  static const logAbsent = 'غاب';
  static const logNotRecorded = 'لم يُسجَّل';
  static String logAttendedOf(int attended, int held) =>
      'حضر $attended من $held';
  static String logPoints(int points) => '$points طايو';
  static String logUnrecorded(int n) =>
      n == 1 ? 'سبت لم يُسجَّل' : '$n سبوت لم تُسجَّل';
  static const attendanceLogEmpty = 'لا توجد سبوت في هذه السنة بعد';
  static const logNoMatch = 'لا توجد سبوت بهذا الاختيار';
  static const logNoLesson = 'لا يوجد درس';
  static String logNoLessonCount(int n) =>
      n == 1 ? 'سبت بلا درس' : '$n سبوت بلا درس';
  static String logSaturdays(int n) => n == 1
      ? 'سبت واحد'
      : n == 2
          ? 'سبتان'
          : n <= 10
              ? '$n سبوت'
              : '$n سبت';
  static String logLastTime(String since) => 'آخر مرة $since';
  static const recordedOnly = 'تم تسجيلهم';
  static const notRecordedOnly = 'لم يتم تسجيلهم';
  static const showingOf = 'عرض';
  static const resultsCount = 'نتيجة';

  // -------------------------------------------------------------- attendance
  static const attendanceTitle = 'الحضور';
  static const sundaySchool = 'حضور مدارس الأحد';
  static const vespers = 'حضور عشية';
  static const mass = 'حضور قداس';
  static const confession = 'الاعتراف';
  static const sundaySchoolShort = 'مدارس الأحد';
  static const vespersShort = 'عشية';
  static const massShort = 'قداس';
  static const confessionShort = 'اعتراف';
  static const attendanceDate = 'تاريخ الحضور';
  static const selectSaturday = 'اختر السبت';
  static const attendanceHistory = 'سجل الحضور';
  static const lastActivityTitle = 'آخر مرة لكل ممارسة';
  static const neverAttended = 'لم يحضر بعد';
  static const attendanceRate = 'نسبة الحضور';
  static const birthdaysTitle = 'أعياد الميلاد';
  static const birthdaysEmpty = 'لا توجد أعياد ميلاد هذا الشهر';
  static const birthdaysEmptyBody =
      'اختر شهراً آخر أو أضف تاريخ الميلاد للمخدومين.';
  static const turningAge = 'يكمل';
  static const birthdayToday = 'عيد ميلاده اليوم';
  static const calendarTitle = 'التقويم';
  static const calendarNothing = 'لا يوجد شيء في هذا اليوم';
  static const calendarMonthBirthdays = 'عيد ميلاد';
  static const calendarMonthEvents = 'فعالية';
  static const calendarMonthEmpty = 'لا شيء في هذا الشهر';
  static const today = 'اليوم';
  static const previousMonth = 'الشهر السابق';
  static const nextMonth = 'الشهر التالي';
  static const todayBirthdays = 'أعياد الميلاد اليوم';
  static const sessionsSoFar = 'السبوت المنقضية';
  static const fullAttendance = 'حضور كامل';
  static const sessionLocked = 'جلسة مغلقة';
  static const sessionLockedBody =
      'تم إغلاق هذه الجلسة بواسطة المسؤول ولا يمكن تعديلها.';
  static const lockSession = 'إغلاق الجلسة';
  static const unlockSession = 'إعادة فتح الجلسة';
  static const markAllPresent = 'تحضير الجميع';
  static const clearAll = 'مسح الكل';

  // The attendance roster: finding a child, compact rows, unsaved marks.
  static const attendanceSearchHint = 'ابحث باسم المخدوم';
  static const compactView = 'عرض مختصر';
  static const fullView = 'عرض كامل';
  static const markAllWhich = 'الكل حضروا في:';
  static const allActivities = 'كل الممارسات';
  static String draftRestored(int n) => n == 1
      ? 'رجّعنا علامات مخدوم ما اتحفظتش'
      : 'رجّعنا علامات $n مخدوم ما اتحفظتش';
  static const ignoreDraft = 'تجاهل';
  static const attendanceNotSaved = 'علامات الحضور لسه ما اتحفظتش';
  static const needsAttention = 'محتاج متابعة';
  static const swipeAllPresent = 'حاضر في الكل';
  static const swipeClear = 'مسح العلامات';
  static const messageSentAgain = 'اتبعتت، ابعتها تاني';
  static const previousSaturday = 'السبت اللي قبله';
  static const nextSaturday = 'السبت اللي بعده';

  // ── the child's profile: status strip, tabs, follow-up
  static const profileInactive = 'المخدوم ده متوقف';
  static String profileAbsentRun(int n) => 'غايب آخر $n سبوت ورا بعض';
  static const profileNeverFollowedUp = 'محدش اتصل بيه ولا زاره لسه';
  static String profileLastFollowUp(int days) => 'آخر افتقاد من $days يوم';
  static const profileBirthdayToday = 'النهارده عيد ميلاده';
  static const profileTabOverview = 'نظرة عامة';
  static const profileTabAttendance = 'الحضور';
  static const profileTabData = 'البيانات';
  static const profileTabFollowUp = 'المتابعة';
  static String attendedSaturdays(int came, int of) => 'حضر $came من $of سبت';
  static const profileMoreActions = 'خيارات أكتر';
  static const attendanceChip = 'حضور السنة';
  static const levelsTitle = 'المستويات';
  static const levelsHint =
      'مستوى المخدوم بيتحدد بعدد الطايوهات اللي جمعها السنة دي. بياخد 5 طايو '
      'على كل ممارسة روحية حضرها (مدارس الأحد، القداس، العشية، الاعتراف) + 10 طايو '
      'على كل وسام يكسبه. كل ما الطايوهات تزيد، بيطلع لمستوى أعلى. '
      'والعدّاد بيبدأ من جديد مع كل سنة.';
  static String levelFrom(int points) =>
      points == 0 ? 'من البداية' : 'من $points طايو';
  static const levelYouAreHere = 'مستواه دلوقتي';
  static const levelReached = 'عدّاه';
  static String levelPointsLeft(int n) => 'باقي $n طايو';
  static String servantsMarkedOf(int marked, int total) =>
      'اتسجّل $marked من $total خادم';
  static String prepsWaitingReview(int n) =>
      n == 1 ? 'تحضير مستني مراجعة' : '$n تحضيرات مستنية مراجعة';
  static const generalServantShort = 'خادم عام';
  static String servantAbsentRun(int n) =>
      n == 2 ? 'غاب آخر سبتين' : 'غاب آخر $n سبوت';
  static String servantMissedPreps(int n) =>
      'ما بعتش التحضير $n من آخر 3 سبوت';
  static String trendUp(int points) => 'الشهر ده أحسن بـ $points%';
  static String trendDown(int points) => 'الشهر ده أقل بـ $points%';

  // Servant badges and the monthly report.
  static const servantBadgeFaithful = 'خادم أمين';
  static const servantBadgeGreatPrep = 'تحضير متميّز';
  static const servantBadgeMeeting = 'اجتماع ثابت';
  static const servantBadgeConfession = 'قلب نقي';
  static const servantBadgeFaithfulRule =
      'خدمة وتحضير متبعت 4 سبوت ورا بعض';
  static const servantBadgeGreatPrepRule = '5 تحضيرات اتقبلت';
  static const servantBadgeMeetingRule =
      'اجتماع الخدام كل سبت في شهر كامل';
  static const servantBadgeConfessionRule = 'اعتراف كل شهر، 3 شهور ورا بعض';
  static const badgeEarnedShort = 'اتاخد ✓';
  static const monthReportTitle = 'تقرير الشهر';
  static String reportHeader(String month, String name) =>
      'تقرير $month لـ $name:';
  static String reportPreps(int sent, int accepted) =>
      'تحضير $sent (اتقبل $accepted)';
  static const reportThanks = 'ربنا يبارك تعب محبتك 🙏';
  static const sendToServant = 'ابعته للخادم على واتساب';
  static const shareReport = 'مشاركة';

  // Substitutes («مين غطّى؟»).
  static const whoCovered = 'مين غطّى؟';
  static const pickSubstitute = 'مين غطّى الفصل مكانه؟';
  static const substituteSaved = 'اتسجّل ✓ وخد «خدمة»';
  static const removeSubstitute = 'شيل التغطية';
  static String coveredBy(String name) => 'غطّى مكانه: $name';
  static String coveredFor(String name) => 'غطّى بدل $name';
  static const coversTitle = 'التغطيات';
  static String coveredForOn(String name, String date) =>
      'غطّى بدل $name • $date';
  static String wasCoveredByOn(String name, String date) =>
      '$name غطّى مكانه • $date';
  static String profileBirthdayIn(int days) =>
      days == 1 ? 'عيد ميلاده بكرة' : 'عيد ميلاده بعد $days أيام';

  static const syncedAll = 'تمام، كل اللي سجّلته اتبعت ✓';

  // ── points and badges
  static const badgesTitle = 'الأوسمة';
  static const gamePointsLabel = 'طايوهات الأوسمة السنة دي';
  static const pointsWord = 'طايو';
  static String toNextLevel(int n, String level) =>
      'باقي $n طايو وتبقى «$level»';
  static const topLevelReached = 'وصلت لأعلى مستوى';
  static String saturdaysInARow(int n) => '$n سبوت';
  static const inARow = 'ورا بعض';
  static String rankInClass(int rank) => switch (rank) {
        1 => 'الأولى',
        2 => 'التانية',
        3 => 'التالتة',
        _ => 'رقم $rank',
      };
  static const inClassLink = 'في الفصل ›';
  static String badgesOf(int earned, int all) => '$earned من $all';
  static String earnedOnDay(String day) => 'اتاخد $day';
  static const notYet = 'لسه';
  static String progressOf(int done, int of) => '$done من $of';
  static const levelSeed = 'بذرة';
  static const levelSprout = 'نبتة';
  static const levelTree = 'شجرة';
  static const levelFruit = 'ثمرة';
  static const badgeStreak4 = 'ملتزم';
  static const badgeStreak4Rule =
      '4 سبوت ورا بعض أو أكتر. بيفضل معاه طول ما الحضور مكمّل.';
  static const badgeMassMonth = 'قداسي كامل';
  static const badgeMassMonthRule =
      'حضر القداس كل أسبوع في شهر كامل (3 سبوت على الأقل).';
  static const badgeFullDay = 'يوم كامل';
  static const badgeFullDayRule =
      'حضر مدارس الأحد والعشية والقداس في نفس السبت 5 مرات.';
  static const badgeConfession3 = 'قلب نقي';
  static const badgeConfession3Rule = 'اعترف كل شهر، 3 شهور ورا بعض.';
  static const badgeStarMonth = 'نجم الشهر';
  static const badgeStarMonthRule = 'الأول في الفصل في طايوهات شهر خلص.';
  static const badgeStreak16 = 'ملتزم ذهبي';
  static const badgeStreak16Rule =
      '12 سبت ورا بعض أو أكتر. بيفضل معاه طول ما الحضور مكمّل.';
  static const classRankingTitle = 'ترتيب الفصل';
  static String classRankingOf(String className) => 'ترتيب فصل $className';
  static const seeAll = 'عرض الكل';
  static const rankingThisMonth = 'الشهر ده';
  static const rankingThisYear = 'السنة دي';
  static String badgesCount(int n) => '$n أوسمة';
  static const rankingPointsNote =
      'الطايوهات من الحضور (5 لكل ممارسة) + 10 لكل وسام، وبتظهر بنفس الشكل في التقارير والـ Excel.';
  static const noRankingYet = 'لسه مفيش طايوهات الشهر ده';
  static const newBadge = 'وسام جديد';
  static String newBadgesCount(int n) => '$n أوسمة جديدة';
  static String badgeWonBy(String child, String badge, {required bool girl}) =>
      girl
          ? '$child خدت وسام «$badge». برافو عليها!'
          : '$child خد وسام «$badge». برافو عليه!';
  static String badgeBonus(int n) => '+$n طايو مكافأة';
  static String congratsParents({required bool girl}) =>
      girl ? 'ابعت تهنئة لأهلها' : 'ابعت تهنئة لأهله';
  static String congratsMessage(String child, String badge,
          {required bool girl}) =>
      girl
          ? 'مبروك! $child خدت النهارده وسام «$badge» في خدمة السبت. ربنا يبارك فيها ويفرّحكم بيها 🌟'
          : 'مبروك! $child خد النهارده وسام «$badge» في خدمة السبت. ربنا يبارك فيه ويفرّحكم بيه 🌟';
  static String sendCongratsTo(String child) => 'تهنئة لأهل $child';
  static const badgeOk = 'تمام';

  // ── the welcome tour
  static const tourMenu = 'جولة في التطبيق';
  static const tourSkip = 'تخطي';
  static const tourNext = 'التالي';
  static const tourStart = 'يلا نبدأ';
  static const tourWelcomeTitle = 'أهلاً بيك في سبتاوية';
  static const tourWelcomeBody =
      'كل حاجة للخدمة في مكان واحد: الحضور، المخدومين، المتابعة والتحضير. خلّينا نوريك أهم حاجات في دقيقة.';
  static const tourAttendanceTitle = 'الحضور في ثواني';
  static const tourAttendanceBody =
      'اضغط على الممارسة تحت اسم كل طفل، أو اسحب السطر شمال يبقى حاضر في الكل ويمين تمسحه. وفي الآخر «حفظ الحضور». شغال من غير نت كمان.';
  static const tourAttendanceGeneralBody =
      'تقدر تسجّل الحضور لأي فصل: اضغط على الممارسة تحت اسم الطفل، أو اسحب السطر شمال يبقى حاضر في الكل. وفي الآخر «حفظ الحضور».';
  static const tourFollowUpTitle = 'محدش يفوتك';
  static const tourFollowUpServantBody =
      'في الرئيسية هتلاقي اللي محتاج متابعة: الغايبين والبيانات الناقصة وأعياد الميلاد. اضغط على أي طفل تكلّم أهله أو تبعتلهم واتساب.';
  static const tourFollowUpGeneralBody =
      '«محتاج متابعة» في الرئيسية بيجمعلك الغايبين والبيانات الناقصة من كل الفصول، واضغط على أي سطر يفتحلك القايمة.';
  static const tourFollowUpAdminBody =
      '«محتاج متابعة» في الرئيسية: الغايبين، البيانات الناقصة، التحضيرات اللي مستنية مراجعة وطلبات الانضمام، كل واحدة بعددها.';
  static const tourPrepTitle = 'ارفع تحضيرك';
  static const tourPrepBody =
      'من «تحضيراتي» ارفع تحضير الدرس قبل السبت، وتحت كل درس هتلاقي وسائل إيضاح وأفكار من خدام تانيين.';
  static const tourMoreTitle = 'التقارير والتقويم';
  static const tourMoreBody =
      'في «المزيد»: التقارير، سجل الحضور، التقويم والمسابقات. وفيه بحث يوصلك لأي حاجة بسرعة.';
  static const tourClassesTitle = 'صحة كل فصل';
  static const tourClassesBody =
      'تاب الفصول بيوريك كل فصل: ماشيين كويس ولا محتاجين دعم، حضور السبت، التحضير، ولو الفصل محتاج خادم.';
  static const backToAttendance = 'ارجع احفظ';
  static const noSearchMatch = 'لا يوجد مخدوم بهذا البحث';
  static const backToTop = 'إلى أعلى';

  // A Saturday with no lesson, or a save with nobody ticked.
  static String breakDayBanner(String reason) =>
      'هذا السبت $reason: لا يوجد درس ولا يُسجَّل حضور.';
  static const breakHoliday = 'إجازة';
  static const breakActivity = 'نشاط ترفيهي';
  static const breakNone = 'يوم درس عادي';
  static const markNoLesson = 'إجازة / نشاط ترفيهي';
  static const breakSheetTitle = 'هل يوجد درس هذا السبت؟';
  static const breakShift = 'تأجيل الدروس أسبوعاً';
  static const breakShiftHint =
      'الدروس بعد هذا السبت تتحرك أسبوعاً. اقفلها لو الدرس اتلغى فقط.';
  static const breakHasRecords =
      'اتسجّل حضور هذا اليوم بالفعل: لن يُحسب في أبطال الالتزام ولا الغياب.';
  static const change = 'تغيير';
  static const nobodyPresentTitle = 'لم تعلّم أي مخدوم';
  static String nobodyPresentBody(int n) =>
      'الحفظ الآن يسجّل الـ $n مخدوم كلهم غياب. لو اليوم لم يكن فيه درس '
      'فلا تحفظ.';
  static const saveAsAbsent = 'سجّلهم غياب';
  static const attendanceSaved = 'تم تسجيل الحضور';
  static const attendanceSavedOffline =
      'تم الحفظ محلياً • سيتم المزامنة عند عودة الاتصال';
  static const offlineMode = 'وضع عدم الاتصال — البيانات محفوظة محلياً';
  static String pendingSyncCount(int n) => '$n تغيير في انتظار المزامنة';
  static String failedSyncCount(int n) => '$n لم يُقبل';
  static const syncingNow = 'جارٍ المزامنة...';
  static const lessonOfWeek = 'درس هذا الأسبوع';
  static const lessonSchedule = 'برنامج الدروس';

  // صلوات (المزيد): the servants' prayers before and after the lesson.
  static const prayersTitle = 'صلوات';
  static const prayerCopied = 'تم نسخ الصلاة';
  static const prayersIntro =
      'صلّي قبل ما تبدأ خدمتك وبعد ما تخلصها. اقراها بهدوء، أو بصوت عالي مع الخدام.';
  static String prayerReadTime(int n) =>
      n == 1 ? 'قراءة دقيقة' : 'قراءة $n دقايق';
  static const textBigger = 'تكبير الخط';
  static const textSmaller = 'تصغير الخط';
  static const copy = 'نسخ';
  static const noLessonThisWeek = 'لا يوجد درس في هذا الأسبوع';
  static const jumpToUpcomingLesson = 'الأسبوع الجاي';
  static const lessonUpcoming = 'القادم';
  static const lessonNoClass = 'بلا درس';
  static const page = 'ص';
  static const pulpit = 'المنبر';
  static const hymns = 'الترانيم / الألحان';
  static const lessonForPrep = 'الدرس المطلوب تحضيره';
  static const lessonPostponed = 'لا درس هذا الأسبوع (تأجل للأسبوع التالي)';
  static const lessonCancelled = 'لا درس هذا الأسبوع (ألغي)';
  static const postponeLesson = 'تأجيل للأسبوع التالي';
  static const cancelLesson = 'إلغاء الدرس';
  static const restoreLesson = 'إرجاع الدرس';
  static const editLesson = 'تعديل الدرس';
  static const lessonTitleLabel = 'عنوان الدرس';
  static const lessonPageLabel = 'الصفحة';
  static const syncTitle = 'المزامنة';
  static const syncNow = 'مزامنة الآن';
  static const syncPending = 'في الانتظار';
  static const syncFailed = 'لم يقبلها الخادم';
  static const syncNothing = 'كل شيء متزامن';
  static const syncRetry = 'إعادة المحاولة';
  static const syncDiscard = 'تجاهل';
  static const needsConnection = 'هذا الإجراء يحتاج اتصالاً بالإنترنت';
  static const saveAttendance = 'حفظ الحضور';
  static const noSessionsTitle = 'لا توجد جلسات حضور';
  static const noSessionsBody =
      'لم يتم إنشاء جلسات لهذا الفصل. برجاء مراجعة سنة الحضور من إعدادات المسؤول.';
  static const presentCount = 'الحاضرون';
  static const recordedCount = 'تم تسجيلهم';
  static const presentOf = 'حضر';
  static const showAll = 'عرض الكل';
  static const nextSaturdayTitle = 'السبت القادم';
  static const pastSaturdays = 'السبوت السابقة';
  static const upcomingSaturdays = 'باقي السنة';
  static const prepMissing = 'لم يُرفع التحضير';
  static const searchServantHint = 'ابحث باسم الخادم';
  static const servantDirectory = 'دليل الخدام';
  static const noServantMobile = 'لا يوجد رقم';
  static const callerIdTitle = 'اسم المتصل';
  static const callerIdSwitch = 'إظهار اسم المتصل من المخدومين';
  static const callerIdBody =
      'لما حد من أهالي مخدومينك يتصل بيك، يظهر اسمه وفصله حتى لو رقمه مش '
      'محفوظ عندك. الأرقام بتتحفظ على موبايلك بس وتتمسح لما تقفل الخاصية '
      'أو تسجل خروج. في بعض الموبايلات لازم تسمح للتطبيق يشتغل في الخلفية، '
      'وعلى الآيفون فعّل «سبتاوية» من الإعدادات > الهاتف > حظر المكالمات '
      'والتعرّف على المتصل.';
  static const callerIdAsk =
      'لما حد من أهالي مخدومينك يتصل بيك، هيظهر اسمه وفصله حتى لو رقمه مش '
      'محفوظ عندك. الموبايل هيطلب إذن الهاتف وسجل المكالمات علشان يعرف '
      'الرقم، والأرقام بتفضل على موبايلك بس. تقدر تقفلها في أي وقت من '
      'الإعدادات.';
  static const callerIdAllow = 'تفعيل';
  static const callerIdDenied =
      'لم يتم السماح. فعّل الإذن من إعدادات التطبيق ثم حاول مرة أخرى';
  static const contactsExportTitle = 'جهات اتصال المخدومين';
  static const contactsExportBody =
      'حمّل ملفاً بأرقام الأمهات والآباء والمخدومين، وافتحه على موبايلك '
      'ليحفظها في جهات الاتصال. بعدها يظهر اسم المتصل (مثل «أم مينا جورج – '
      'فصل 5 بنات») حتى لو الرقم لم يكن محفوظاً عندك.';
  static const contactsExportWho = 'مين يتحفظ؟';
  static const contactsMothers = 'الأمهات';
  static const contactsFathers = 'الآباء';
  static const contactsChildren = 'المخدومين';
  static String contactsCount(int n) => '$n جهة اتصال';
  static const contactsNone = 'لا توجد أرقام لحفظها';
  static const contactsDownload = 'تحميل ملف جهات الاتصال';
  static const contactsFileName = 'جهات اتصال المخدومين';
  static const contactsPrivacy =
      'ستُحفظ هذه الأرقام في جهات اتصال موبايلك. استخدمها لخدمتك فقط.';
  static const callChild = 'المخدوم';
  static const callMother = 'الأم';
  static const callFather = 'الأب';
  static const importExcelShort = 'استيراد Excel';
  static const showLess = 'عرض أقل';
  static const ofWord = 'من';
  static const notTakenYet = 'لم يُسجَّل بعد';
  static const partlyTaken = 'تسجيل جزئي';
  static const takenDone = 'تم التسجيل';
  static const upcomingSaturday = 'سبت قادم';
  static const clearAllConfirm = 'مسح كل العلامات لهذا السبت؟';
  static const clearAllConfirmBody =
      'سيتم إلغاء كل علامات الحضور على الشاشة. لن يُحفظ شيء حتى تضغط حفظ.';
  static const sessionScore = 'درجة الجلسة';
  static const unsavedChanges = 'تغييرات غير محفوظة';
  static const unsavedChangesBody =
      'لديك تغييرات لم تُحفظ. هل تريد الخروج وتجاهلها؟';
  static const discard = 'تجاهل';
  static const lastModifiedBy = 'آخر تعديل بواسطة';
  static const attendanceYears = 'سنوات الحضور';
  static const attendanceYear = 'سنة الحضور';
  static const addAttendanceYear = 'إضافة سنة حضور';
  static const editAttendanceYear = 'تعديل سنة الحضور';
  static const yearName = 'اسم السنة';
  static const startDate = 'تاريخ البداية';
  static const endDate = 'تاريخ النهاية';
  static const currentYear = 'السنة الحالية';
  static const setAsCurrent = 'تعيين كسنة حالية';
  static const pointsPerActivity = 'طايوهات كل ممارسة';
  static const generateSessions = 'إنشاء جلسات السبوت';
  static const sessionsGenerated = 'تم إنشاء الجلسات';
  static const yearNameRequired = 'اسم السنة مطلوب';
  static const endBeforeStart = 'تاريخ النهاية يجب أن يكون بعد تاريخ البداية';
  static const totalSessions = 'عدد الجلسات';
  static const maxPoints = 'الحد الأقصى للطايوهات';

  // ----------------------------------------------------------------- reports
  static const reportsTitle = 'ابطال الطايو';
  static const classReport = 'تقرير الفصل';
  static const childReport = 'تقرير المخدوم';
  static const monthlyReport = 'التقرير الشهري';
  static const overallReport = 'التقرير العام';
  static const month = 'الشهر';
  static const attendedSessions = 'السبوت المحضورة';
  static const rank = 'الترتيب';
  static const periodFilter = 'الفترة';
  static const periodAll = 'كل السنة';
  static const periodFrom = 'من';
  static const periodTo = 'إلى';
  static const pointsInPeriod = 'طايوهات الفترة';
  static const filterDay = 'يوم';
  static const filterMonth = 'شهر';
  static const filterYear = 'سنة';

  // ------------------------------------------------------------------- excel
  static const importChildren = 'استيراد مخدومين من Excel';
  static const importTitle = 'استيراد من Excel';
  static const pickFile = 'اختيار ملف';
  static const pickFileHint = 'اختر ملف بصيغة xlsx';
  static const downloadTemplate = 'تنزيل ملف نموذج';
  static const templateSaved = 'تم إنشاء ملف النموذج';
  static const importMode = 'نمط الاستيراد';
  static const importModeAdd = 'إضافة الجدد فقط';
  static const importModeUpdate = 'تحديث الموجودين فقط';
  static const importModeAddUpdate = 'إضافة وتحديث';
  static const importPreview = 'معاينة البيانات';
  static const importConfirm = 'تأكيد الاستيراد';
  static const importRowsValid = 'صفوف صحيحة';
  static const importRowsInvalid = 'صفوف بها أخطاء';
  static const importRowsNew = 'جديد';
  static const importRowsExisting = 'تحديث';
  static const importRowsSkipped = 'سيتم تجاهلها';
  static const importDone = 'تم الاستيراد';
  static const importInserted = 'تمت إضافة';
  static const importUpdated = 'تم تحديث';
  static const importNoValidRows = 'لا توجد صفوف صحيحة للاستيراد';
  static const importEmptyFile = 'الملف لا يحتوي على بيانات';
  static const importMissingHeader =
      'تعذّر التعرف على أعمدة الملف. برجاء استخدام ملف النموذج.';
  static const importErrorNameMissing = 'اسم المخدوم مفقود';
  static const importErrorGenderMissing = 'النوع مفقود أو غير مفهوم (ولد/بنت)';
  static const importErrorDuplicateInFile = 'مكرر داخل نفس الملف';
  static const importErrorNotFound = 'لا يوجد مخدوم مطابق';
  static const importErrorExists = 'مخدوم موجود بالفعل';
  static const importErrorMobile = 'رقم موبايل غير صحيح';
  static const importErrorBirthDate = 'تاريخ ميلاد غير صحيح';
  static const importWillMoveClass = 'سيتم نقله لهذا الفصل';
  static const rowNumber = 'صف';
  static const export = 'تصدير';
  static const exportTitle = 'تصدير Excel';
  static const excelReportsTitle = 'تقارير Excel';
  static const exportChildren = 'قائمة المخدومين';
  static const exportAttendanceSheet = 'كشف حضور سبت';
  static const exportMonthlyAttendance = 'الحضور الشهري';
  static const exportYearlyAttendance = 'الحضور السنوي';
  static const exportClassReport = 'تقرير الفصل';
  static const exportOverallReport = 'التقرير العام';
  static const exportDone = 'تم إنشاء الملف';
  static const share = 'مشاركة الملف';
  static const exporting = 'جارٍ التصدير…';

  // -------------------------------------------------------- servant activities
  static const myActivities = 'تحضيراتي';
  static const activitiesNav = 'متابعة الخدام';
  static const exportServantMonthly = 'تقرير شهري - الخدام';
  static const exportServantYearly = 'تقرير سنوي - الخدام';
  static const servantActivities = 'متابعة الخدام';
  static const servantActivityReport = 'تقرير متابعة الخدام';
  static const lessonPrep = 'تحضير الدرس';
  static const sundaySchoolAttendance = 'حضور مدارس الأحد';
  static const servantMeetingAttendance = 'حضور اجتماع الخدمة';
  static const servantMeetingShort = 'اجتماع الخدمة';
  static const submitLessonPrep = 'رفع تحضير الدرس';
  static const prepPending = 'قيد المراجعة';
  static const prepAccepted = 'مقبول';
  static const prepCommented = 'يوجد تعليق';

  // نشاط الخدام (admin): the tabs and the chips on each servant's row.
  static const servantsTab = 'ملخص الخدام';
  static const servantAttendanceTab = 'حضور الخدام';
  static const chipService = 'خدمة';
  static const chipMeeting = 'اجتماع';
  static const chipPrep = 'تحضير';
  static const statServants = 'خادم';
  static const statSaturdays = 'سبت';
  static const sortServantName = 'الاسم';
  static const sortServantLowest = 'الأقل حضوراً';
  static const sortServantLeastPrep = 'الأقل تحضيراً';
  static const sortServantPending = 'قيد المراجعة';
  static const onlyPendingPreps = 'عندهم تحضير قيد المراجعة';
  static const allServantsCame = 'الكل حضروا';
  static String prepRate(int sent, int held) => 'تحضير $sent/$held';
  static String prepCount(int sent) => 'تحضير $sent';
  static const reportTotalServants = 'إجمالي الخدام';
  static const reportYearSaturdays = 'سبوت السنة حتى الآن';
  static const reportServantDetails = 'تفاصيل الخدام';
  static const prepNotSent = 'لم يُرسل تحضير';
  static const missedPrepsTitle = 'لم يُرسل تحضيرها';
  static const prepMarkedByHand = 'تحضير مسجّل يدوياً';
  static const acceptPrep = 'قبول';
  static const addComment = 'تعليقات';
  static const noLessonPreps = 'لا توجد تحضيرات مرفوعة';
  static const noLessonPrepsBody = 'ارفع تحضيرك لأول سبت.';
  static const recordAttendance = 'تسجيل الحضور';
  static const noAttendanceRecords = 'لا توجد سجلات حضور';
  static const noAttendanceRecordsBody = 'لم يتم تسجيل أي حضور لهذا النشاط.';
  static const pickPhotos = 'اختيار صور';
  static const pickPdf = 'اختيار PDF';
  static const pdfFile = 'ملف PDF';
  static const openFile = 'افتح الملف';
  static const pickAPdfFile = 'اختر ملف بصيغة PDF';
  static const photosSelected = 'صور مختارة';
  static const submittedSuccessfully = 'تم رفع التحضير بنجاح';
  static const reviewedSuccessfully = 'تمت المراجعة';
  static const enterComment = 'اكتب التعليق';
  static const commentRequired = 'التعليق مطلوب';
  static const noPhotosSelected = 'يجب اختيار صورة أو ملف PDF واحد على الأقل';
  static const lessonPrepTitle = 'تحضير الدرس';
  static const alreadySubmitted = 'تم الرفع';

  // The prep page: fixing after a comment, sending back, uploading.
  static const adminCommentTitle = 'تعليق أمين الخدمة';
  static const prepFixHint = 'عدّل الملفات حسب التعليق ثم أرسل للمراجعة تاني';
  static const prepResend = 'أرسل للمراجعة تاني';
  static const prepResent = 'اتبعت التحضير للمراجعة من جديد';
  static const prepUploadAdded = 'ارفع الملفات المضافة';
  static const prepAddFilesHint = 'أضف صور التحضير أو ملف PDF';
  static const prepNewFiles = 'جديد';
  static const prepSharedAsExample = 'تمت مشاركته كمثال للخدام';
  static const prepSharedShort = 'مثال';
  static const prepTodoTitle = 'تحضير السبت القادم';
  static const prepTodoNotSent = 'لم يُرسل بعد';
  static const prepTodoUpload = 'ارفع التحضير';
  static const myAttendanceTitle = 'حضوري';
  static String myAttendanceOf(int came, int held) => 'حضرت $came من $held';
  static const removeFileTitle = 'حذف هذا الملف من التحضير؟';
  static const couldNotLoad = 'تعذّر التحميل';
  static const uploadNeedsInternet = 'رفع التحضير يحتاج إنترنت. حاول تاني لما يرجع الاتصال.';
  static String uploadingProgress(int done, int total) => 'رفع $done من $total';
  static String uploadFailedSome(int n) =>
      n == 1 ? 'لم يُرفع ملف واحد — حاول تاني' : 'لم يُرفع $n ملفات — حاول تاني';
  static const pendingPreps = 'تحضيرات قيد المراجعة';

  // -------------------------------------------------------------- competitions
  static const competitions = 'المسابقات';
  static const competitionsList = 'قائمة المسابقات';
  static const weeklyCompetition = 'المسابقة الأسبوعية';
  static const addCompetition = 'إضافة مسابقة';
  static const editCompetition = 'تعديل المسابقة';
  static const deleteCompetition = 'حذف المسابقة';
  static const competitionTitle = 'عنوان المسابقة';
  static const competitionWeekDate = 'تاريخ الأسبوع';
  static const competitionMaxMark = 'العلامة القصوى';
  static const markChildren = 'تسجيل العلامات';
  static const cumulativeScores = 'المجموع التراكمي';
  static const noCompetitions = 'لا توجد مسابقات';
  static const noCompetitionsBody = 'أضف مسابقة أسبوعية للبدء.';
  static const noCompetitionsViewer = 'لسه مفيش مسابقات اتسجلت.';
  static const noScoresYet = 'لسه مفيش درجات';
  static const noScoresYetBody =
      'الترتيب بيظهر بعد ما تتسجل درجات أول مسابقة.';
  static const competitionToday = 'النهارده';
  static const competitionUpcoming = 'جاية';
  static String competitionsCountLabel(int n) =>
      n == 1 ? 'مسابقة واحدة' : '$n مسابقات';
  static const noMarkEntered = 'لم تُسجَّل علامة';
  static const markSaved = 'تم حفظ العلامات';
  static const totalMarks = 'مجموع العلامات';
  static const avgMark = 'متوسط العلامة';
  static const exportCompetitions = 'تصدير درجات المسابقات';
  static const exportCompetitionsHint = 'اختر المسابقات المطلوبة';
  static const selectAll = 'تحديد الكل';
  static const clearSelection = 'إلغاء التحديد';
  static const exportSelected = 'تصدير المحدد';
  static const mark = 'الدرجة';
  static const competitionTitleRequired = 'عنوان المسابقة مطلوب';
  static const confirmDeleteCompetition =
      'هل تريد حذف هذه المسابقة وكل علاماتها؟';

  // ------------------------------------------------------------------- events
  static const events = 'نشاطات ترفيهية';
  static const addEvent = 'إضافة نشاط';
  static const editEvent = 'تعديل النشاط';
  static const deleteEvent = 'حذف النشاط';
  static const eventTitleLabel = 'اسم النشاط';
  static const eventDateLabel = 'تاريخ النشاط';
  static const eventCost = 'التكلفة (ج.م)';
  static const eventDescription = 'وصف (اختياري)';
  static const noEvents = 'لا توجد نشاطات ترفيهية';
  static const noEventsBody = 'أضف نشاطاً للبدء.';
  static const eventTitleRequired = 'اسم النشاط مطلوب';
  static const eventCostRequired = 'التكلفة مطلوبة';
  static const eventCostInvalid = 'التكلفة يجب أن تكون أكبر من صفر';
  static const confirmDeleteEvent = 'هل تريد حذف هذا النشاط وكل مدفوعاته؟';
  static const addPayment = 'إضافة دفعة';
  static const deletePayment = 'حذف الدفعة';
  static const paymentAmount = 'المبلغ المدفوع (ج.م)';
  static const paymentNotes = 'ملاحظة (اختياري)';
  static const totalPaid = 'المدفوع';
  static const exportEvent = 'تصدير إلى Excel';
  static const exportEventHint = 'اختر الحالات المطلوبة في الملف';
  static const reserveWithoutPay = 'حجز بدون دفع';
  static const cancelReservation = 'إلغاء الحجز';
  static const cancelReservationBody =
      'سيتم إلغاء حجز هذا المخدوم في الرحلة. المدفوعات لا تتأثر.';
  static const reservedBadge = 'حاجز';
  static const reservedSaved = 'تم الحجز';
  static const reservationCancelled = 'تم إلغاء الحجز';
  static const reservedUnpaidStatus = 'حاجز (لم يدفع)';
  static const bookShort = 'حجز الرحلة';
  static const bookedShort = 'تم حجز الرحلة';
  static const bookedPaidShort = 'دفع';
  static const pickEvent = 'اختر النشاط';
  static const bookingPaidNote = 'دفع بالفعل: الدفع من شاشة النشاط';
  static String bookingFor(String title) => 'حجز: $title';
  static String bookedOf(int n, int m) => 'محجوز $n من $m';
  static const paymentStatus = 'الحالة';
  static const serialNo = 'م';
  static const remaining = 'المتبقي';
  static const paidInFull = 'مسدَّد';
  static const paymentSaved = 'تم حفظ الدفعة';
  static const paymentDeleted = 'تم حذف الدفعة';
  static const noPayments = 'لا توجد مدفوعات';
  static const paymentAmountRequired = 'المبلغ مطلوب';
  static const paymentAmountInvalid = 'المبلغ يجب أن يكون أكبر من صفر';
  static const paymentAmountExceeds = 'المبلغ يتجاوز المتبقي';
  static const paymentMethodLabel = 'طريقة الدفع';
  static const paymentMethodCash = 'كاش';
  static const paymentMethodTayo = 'كيتي';
  static const confirmDeletePayment = 'هل تريد حذف هذه الدفعة؟';
  static const paymentHistory = 'سجل الدفعات';
  // On ملف المخدوم.
  static String tripsOwed(String amount) => 'لسه باقي $amount';
  static String tripPaidOf(String paid, String cost) => 'دفع $paid من $cost';
  static const tripNotBooked = 'لسه محجزش';
  static String moreTrips(int n) => n == 1 ? 'ونشاط كمان' : 'و$n نشاطات كمان';
  static String marksOf(int mark, int max) => '$mark من $max';
  static String inCompetitions(int n) =>
      n == 1 ? 'في مسابقة واحدة' : 'في $n مسابقات';
  static const collected = 'محصَّل';
  static const expected = 'متوقع';
  static const partialPay = 'بدأ الدفع';
  static const bookedTab = 'حاجزين';
  static const notPaidTab = 'لم يدفع';

  // ---------------------------------------------------------------- settings
  static const settingsTitle = 'الإعدادات';
  static const account = 'الحساب';
  static const myProfile = 'ملفي الشخصي';
  static const about = 'عن التطبيق';
  static const version = 'الإصدار';
  static const systemManagement = 'إدارة النظام';
  static const changePassword = 'تغيير كلمة المرور';
  static const currentPassword = 'كلمة المرور الحالية';
  static const currentPasswordRequired = 'كلمة المرور الحالية مطلوبة';
  static const newPasswordRequired = 'كلمة المرور الجديدة مطلوبة';
  static const confirmNewPasswordRequired = 'تأكيد كلمة المرور الجديدة مطلوب';
  // ---- UI polish: labels, tooltips
  static const pillChildren = 'مخدومين';
  static const pillServants = 'خدام';
  static const reportsAndFollowUp = 'التقارير والمتابعة';
  static const importExportTitle = 'ملفات Excel';
  static const competitionsAndEvents = 'المسابقات والنشاطات';

  // ── المزيد ────────────────────────────────────────────────────────────────
  static const moreFollowUp = 'المتابعة';
  static const moreReportsExcel = 'التقارير والإكسل';
  static const moreService = 'الخدمة';
  static const moreAdmin = 'الإدارة';
  static const moreApp = 'التطبيق';
  static const moreSearchHint = 'ابحث في المزيد…';
  static const moreNoMatches = 'مفيش حاجة بالاسم ده';
  static const whatsNewTitle = 'جديد في سبتاوية';
  static String versionLabel(String version, int build) =>
      'الإصدار $version ($build)';
  static const showPassword = 'إظهار كلمة المرور';
  static const hidePassword = 'إخفاء كلمة المرور';
  static const clearSearch = 'مسح البحث';
  static const call = 'اتصال';
  static const whatsapp = 'رسالة واتساب';
  static String whatsappTo(String who) => 'واتساب $who';
  static const whatsappBirthday = 'تهنئة بواتساب';
  static const copyNumber = 'نسخ الرقم';
  static const locationTitle = 'الموقع على الخريطة';
  static const locationAddPrompt = 'أضف موقع بيت المخدوم على الخريطة';
  static const locationOpen = 'عرض على الخريطة';
  static const locationDirections = 'اتجاهات للوصول';
  static const locationClear = 'مسح الموقع';
  static const locationPasteLabel = 'ألصق رابط الموقع أو الإحداثيات';
  static const locationPasteFromClipboard = 'لصق من الحافظة';
  static const locationUseCurrent = 'استخدم موقعي الحالي';
  static const locationLocating = 'جارٍ تحديد موقعك...';
  static const locationNotRecognised =
      'مش قادرين نقرا الموقع من النص ده. ألصق رابط من خرائط جوجل أو الإحداثيات '
      '(مثال: 30.0561, 31.3416).';
  static const locationShortLink =
      'مش قادرين نفتح الرابط المختصر دلوقتي. جرّب تاني بعد شوية، أو انسخ الرابط '
      'الكامل أو الإحداثيات من خرائط جوجل.';
  static const locationNamedPlace =
      'الرابط ده لمكان معروف بالاسم أو العنوان، ومفيهوش نقطة دقيقة لبيت '
      'المخدوم. افتحه في خرائط جوجل، واضغط مطولاً على مكان البيت بالظبط '
      'لتحط دبوس، وشارك الرابط ده. أو استخدم «موقعي الحالي» وإنت قدام البيت.';
  static const locationFromPlacePage =
      'الرابط ده لمكان معروف بالاسم، فالموقع اتحدد من صفحته وممكن يكون '
      'تقريبي. اضغط «عرض على الخريطة» وتأكد إنه بيت المخدوم قبل الحفظ.';
  static const locationReadingLink = 'جارٍ قراءة الرابط...';
  static const locationClipboardEmpty =
      'مفيش حاجة منسوخة. افتح خرائط جوجل وانسخ رابط المكان الأول.';
  static const locationPasteButton = 'لصق رابط من الحافظة';
  static const locationOpenMaps = 'افتح خرائط جوجل';
  static const locationTypeInstead = 'أو اكتب الرابط أو الإحداثيات';
  static const locationUseCurrentHint = 'لو إنت واقف قدام بيت المخدوم دلوقتي';
  static const locationHowTo =
      'من خرائط جوجل: اضغط على المكان، ثم شارك، ثم انسخ الرابط المختصر، وارجع هنا';
  static const locationEdit = 'تعديل الموقع';
  static const locationSave = 'حفظ الموقع';
  static const locationSaved = 'تم حفظ الموقع';
  static String locationWeakFix(int meters) =>
      'دقة الموقع ضعيفة (حوالي $meters متر). الأفضل تقف بره المبنى وتجرّب تاني.';
  static const locationOutsideEgypt =
      'الموقع ده خارج مصر. اتأكد إنه الرابط الصح.';
  static const locationServiceOff =
      'خدمة الموقع مقفولة في التليفون. افتحها وجرّب تاني.';
  static const locationDenied = 'مفيش إذن للوصول لموقعك. وافق عليه وجرّب تاني.';
  static const locationDeniedForever =
      'إذن الموقع مرفوض. فعّله من إعدادات التطبيق في التليفون.';
  static const locationTimeout =
      'ما قدرناش نحدد موقعك. اتأكد إنك في مكان مفتوح وجرّب تاني.';
  static const locationFailed = 'تعذّر تحديد الموقع.';
  static const numberCopied = 'تم نسخ الرقم';
  static const clearField = 'مسح';
  static const noPhoneNumber = 'لا يوجد رقم';

  // ── Duplicate child warning ────────────────────────────────────────────────
  static const similarTitle = 'يمكن الطفل ده متسجل قبل كده';
  static const similarBody =
      'لقينا طفل شبهه في البيانات. اتأكد إنه مش نفس الطفل قبل ما تضيفه.';
  static const similarSaveAnyway = 'حفظ على أي حال';
  static const similarBack = 'رجوع';
  static const similarOpen = 'فتح الملف';
  static const similarInactive = 'غير نشط';
  static String similarReason(String reason) => switch (reason) {
        'same_name' => 'نفس الاسم',
        'same_first_and_father' => 'نفس الاسم الأول واسم الأب',
        _ => 'نفس الاسم الأول ونفس رقم التليفون',
      };
  static String similarRow(String name, String className) =>
      'يشبه: $name ($className)';
  static const similarSkipRow = 'لا تضف';
  static String similarImportWarning(int n) =>
      'تنبيه: $n ${n == 1 ? 'صف يشبه طفلًا مسجلًا' : 'صفوف تشبه أطفالًا مسجلين'}';

  // ── Announcements ──────────────────────────────────────────────────────────
  static const announcementsTitle = 'الإعلانات';
  static const announcementsMoreTitle = 'رسائل وأخبار للخدام';
  static const newAnnouncement = 'إعلان جديد';
  static const noAnnouncements = 'لا توجد إعلانات';
  static const noAnnouncementsBody =
      'اكتب إعلانًا يوصل للخدام في الجرس وكإشعار على التليفون.';
  static const announcementTitleLabel = 'العنوان';
  static const announcementBodyLabel = 'نص الإعلان';
  static const announcementAudience = 'يوصل لمين؟';
  static const audienceAll = 'كل الخدام';
  static const audienceServants = 'خدام الفصول';
  static const audienceGeneral = 'الخدام العامين';
  static const audienceClasses = 'فصول محددة';
  static const pickClassesFirst = 'اختر فصلًا واحدًا على الأقل';
  static const sendAnnouncement = 'إرسال الإعلان';
  static String confirmSendAnnouncement(String audience) =>
      'هيوصل الإعلان لـ: $audience، في الجرس وكإشعار. متأكد؟';
  static String announcementSent(int n) => 'تم الإرسال إلى $n';
  static const announcementNeedsConnection =
      'إرسال الإعلان محتاج إنترنت. اتصل وجرّب تاني.';
  static String readOf(int read, int total) => 'قرأه $read من $total';
  static const notReadYet = 'لم يقرأ بعد';
  static const readAt = 'قرأه';
  static const announcementReads = 'مين قرأ الإعلان';
  static const remindOnWhatsApp = 'تذكير على واتساب';
  static String announcementReminder(String first, String title) =>
      'سلام ونعمة يا $first، فيه إعلان جديد في تطبيق سبتاوية: «$title». '
      'افتحه من الجرس لما يكون عندك وقت. ربنا يبارك خدمتك.';
  static const announcement = 'إعلان';
  static const deleteAnnouncement = 'حذف الإعلان';
  static const confirmDeleteAnnouncement =
      'هيتشال الإعلان من عند كل اللي وصلهم. متأكد؟';
  static const requiredField = 'مطلوب';

  // ── Parent messages ────────────────────────────────────────────────────────
  static const parentMessages = 'رسالة للأهالي';
  static const messageTemplates = 'قوالب الرسائل';
  static const newMessage = 'رسالة جديدة';
  static const messageText = 'نص الرسالة';
  static const messageTagsHint = 'اضغط لإضافة: ';
  static const messageTemplateTitle = 'اسم القالب';
  static const addTemplate = 'إضافة قالب';
  static const editTemplate = 'تعديل القالب';
  static const deleteTemplate = 'حذف القالب';
  static const confirmDeleteTemplate =
      'هيتشال القالب ده من عند كل الخدام. متأكد؟';
  static const noTemplates = 'لا توجد قوالب بعد';
  static const noTemplatesBody =
      'القوالب اللي هنا بتظهر لكل الخدام وهما بيبعتوا للأهالي، جنب الجاهزة في التطبيق.';
  static const builtInTemplate = 'جاهز';
  static String messagesSent(int sent, int total) => 'أُرسل $sent من $total';
  static const openNext = 'افتح التالي';
  static const allMessagesSent = 'اتبعتت كل الرسائل';
  static const familiesNoNumber = 'بدون رقم واتساب';
  static const messagePreview = 'شكل الرسالة';
  static const writeMessageFirst = 'اكتب الرسالة الأول';
  static const noChildrenToMessage = 'مفيش أطفال في القائمة دي';
  static String messageFamilies(int n) => '$n ${n == 1 ? 'أسرة' : 'أسر'}';

  // ── Class health ───────────────────────────────────────────────────────────
  static const classHealthTitle = 'متابعة الفصول';
  static const myClassHealthTitle = 'متابعة فصلي';
  static const noClassHealth = 'لسه مفيش بيانات لمتابعة الفصول';
  static const noClassHealthBody =
      'الدرجة بتظهر بعد أول سبت يتسجّل فيه الحضور.';
  static const allClassesHealthy =
      'كل الفصول ماشية كويس السنة دي. ربنا يبارك تعبكم!';
  static const healthServants = 'الخدام';
  static const healthChildren = 'الأطفال النشطين';
  static const healthTaken = 'الحضور المسجّل';
  static const healthLate = 'اتسجّل متأخر';
  static const healthPresent = 'نسبة الحضور';
  static const healthPrep = 'التحضير المرفوع';
  static const healthAccepted = 'مقبول';
  static const healthFollowUp = 'الغائبين اللي اتعمل لهم افتقاد';
  static String outOf(int a, int b) => '$a من $b';
  static const healthGood = 'ماشيين كويس';
  static const healthToFollow = 'محتاجين متابعة';
  static const healthNeedsSupport = 'محتاجين دعم';
  static String classesDoingWell(int n) =>
      n == 1 ? 'فصل واحد ماشي كويس' : '$n فصول ماشية كويس';
  static const healthScoreHint =
      'الدرجة من حضور الأطفال وتسجيل الحضور والتحضير والافتقاد. اضغط على الفصل للتفاصيل.';
  static const healthNoAbsent = 'مفيش غياب متكرر';
  static String showAllClasses(int n) => 'عرض الكل ($n)';
  static const openClass = 'فتح الفصل';

  // ── Lesson materials ───────────────────────────────────────────────────────
  static const materialsTitle = 'وسائل الإيضاح';
  static const materialsLink = 'وسائل الإيضاح';
  static String gradeLabel(int grade) => 'صف $grade';
  static const noMaterials =
      'لسه مفيش مواد للدرس ده. لو عندك فيديو أو صورة أو ملف ساعدك، ضيفه هنا لباقي الخدام.';
  static const allGrades = 'لكل الصفوف';
  static const forAllGrades = 'لكل الصفوف في نفس الأسبوع';
  static const addMaterial = 'إضافة رابط أو ملف';
  static const deleteMaterial = 'حذف المادة';
  static const materialAdded = 'تمت الإضافة';
  static const materialLink = 'رابط';
  static const materialFile = 'ملف';
  static const materialTitle = 'الاسم';
  static const materialUrl = 'الرابط';
  static const materialBadUrl = 'اكتب رابط يبدأ بـ https://';
  static const picture = 'صورة';
  static const pickFileFirst = 'اختر الملف الأول';
  static const materialUnavailable = 'الملف مش متاح دلوقتي';
  static const sharedPrepsTitle = 'تحضيرات مميزة';
  static const prepFile = 'ملف';
  static const sharePrep = 'مشاركة كمثال لخدام نفس الصف';
  static const sharePrepHint =
      'هيظهر التحضير ده تحت «وسائل الإيضاح» لنفس الدرس عند كل الخدام.';
  static const sharePrepNoLesson = 'السبت ده ماكانش فيه درس، فمينفعش يتشارك.';
  static const sharePrepNeedsAccept = 'اقبل التحضير الأول عشان تقدر تشاركه.';
  static const prepShared = 'تمت المشاركة';
  static const prepsInboxTitle = 'التحضيرات';
  static const prepsReviewed = 'اتراجعت';
  static String prepsPendingChip(int n) => 'قيد المراجعة ($n)';
  static String reviewAllInRow(int n) => 'راجع ورا بعض ($n)';
  static String prepPosition(int i, int n) => '$i من $n';
  static const skip = 'تخطي';
  static const prepsAllReviewed = 'خلصت المراجعة';
  static const noPendingPreps = 'مفيش تحضيرات مستنية مراجعة 👌';
  static const noReviewedPreps = 'لسه مفيش تحضيرات اتراجعت';
  static String prepFilesCount(int n) => n == 1
      ? 'ملف واحد'
      : n == 2
          ? 'ملفين'
          : n <= 10
              ? '$n ملفات'
              : '$n ملف';
  static const prepUnshared = 'اتشال من المشاركة';
}
