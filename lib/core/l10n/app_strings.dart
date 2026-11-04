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
  static const promoteClassesBody =
      'ينتقل كل فصل بخدامه ومخدوميه وشفيعه: 5 إلى 6، و4 إلى 5، و3 إلى 4، '
      'ويُؤرشف فصل 6 بمخدوميه، وتُضاف فصول 3 ولاد و3 بنات جديدة.';
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
  static const points = 'نقطة';
  static const notes = 'ملاحظات';
  static const saved = 'تم الحفظ بنجاح';
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
  static const resetLinkSent = 'تم إرسال رابط الاستعادة إلى بريدك الإلكتروني';
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
  static const nameArabicOnly  = 'الاسم يجب أن يكون باللغة العربية';
  static const confirmPassword = 'تأكيد كلمة المرور';
  static const passwordsDoNotMatch = 'كلمتا المرور غير متطابقتين';
  static const passwordTooShort = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
  static const signUpDone = 'تم إنشاء الحساب';
  static const confirmEmailTitle = 'تأكيد البريد الإلكتروني';
  static const confirmEmailBody =
      'أرسلنا رسالة تأكيد إلى بريدك الإلكتروني. افتح الرابط ثم سجّل الدخول.';
  static const emailAlreadyUsed = 'هذا البريد الإلكتروني مستخدم بالفعل';
  static const emailRequired = 'البريد الإلكتروني مطلوب';
  static const emailInvalid = 'صيغة البريد الإلكتروني غير صحيحة';
  static const passwordRequired = 'كلمة المرور مطلوبة';
  static const invalidCredentials = 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
  static const accountInactiveTitle = 'الحساب غير مُنشّط';
  static const accountInactiveBody =
      'تم إنشاء حسابك ولكنه في انتظار تنشيط المسؤول. برجاء التواصل مع المسؤول.';
  static const accountNotFoundTitle = 'البريد غير مسجل';
  static const accountNotFoundBody =
      'هذا البريد الإلكتروني غير مسجل في النظام. تواصل مع أمين الخدمة للحصول على دعوة.';
  static const accountRejectedTitle = 'تم رفض الطلب';
  static const accountRejectedBody =
      'تم رفض طلب التسجيل الخاص بك. تواصل مع أمين الخدمة للمزيد من المعلومات.';
  static const signUpSuccess = 'تم إنشاء حسابك بنجاح — في انتظار موافقة المسؤول';
  static const logoutAndRetry = 'الخروج والمحاولة بحساب آخر';
  static const confirmLogout = 'هل تريد تسجيل الخروج؟';

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
  static const reportsNav = 'تقرير الطايو';
  static const more = 'المزيد';
  static const servantsNav = 'الخدام';
  static const settings = 'الإعدادات';

  // --------------------------------------------------------------- dashboard
  static const welcome = 'مرحباً';
  static const totalClasses = 'الفصول';
  static const totalServants = 'الخدام';
  static const totalChildren = 'المخدومين';
  static const totalPoints = 'إجمالي النقاط';
  static const nextAttendance = 'موعد الحضور القادم';
  static const lastAttendance = 'آخر سبت للحضور';
  static const noUpcomingSession = 'لا توجد جلسة قادمة';
  static const futureSession = 'سبت لم يأتِ بعد';
  static const showUpcoming = 'السبوت القادمة';
  static const averageAttendance = 'متوسط الحضور';
  static const classPerformance = 'أداء الفصول';
  static const lowAttendanceChildren = 'مخدومون بحضور منخفض';
  static const recentActivity = 'آخر النشاطات';
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
  static const inviteCreated =
      'تم إنشاء الدعوة. يسجّل الخادم بنفس البريد الإلكتروني ليتم تنشيط حسابه تلقائياً.';
  static const inviteHint =
      'سيتم تنشيط الحساب وتعيين الفصل تلقائياً بمجرد تسجيل الخادم بهذا البريد.';
  static const servantOneClass = 'الخادم يُعيَّن على فصل واحد فقط.';
  static const deleteInvite = 'حذف الدعوة';
  static const noServants = 'لا يوجد خدام';
  static const servantNameRequired = 'اسم الخادم مطلوب';

  // ------------------------------------------------------------- assignments
  static const assignmentsTitle = 'تعيين الخدام';
  static const assignServant = 'تعيين خادم';
  static const myData = 'بياناتي';
  static const myDataHint =
      'عدّل بياناتك الشخصية: الاسم، الموبايل، تاريخ الميلاد، العنوان وغيرها.';
  static const deleteServant ='حذف الخادم';
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
  static const noVisitHistory = 'لا يوجد سجل افتقادات بعد';
  static const childBirthdaysTitle = 'أعياد ميلاد المخدومين';
  static const servantBirthdays = 'أعياد ميلاد الخدام';
  static const childBirthdaysShort = 'المخدومين';
  static const servantBirthdaysShort = 'الخدام';
  static const attendanceSummary = 'ملخص الحضور';
  static const monthlyBreakdown = 'التفصيل الشهري';
  static const searchChildHint = 'ابحث بالاسم أو الموبايل أو الكود';

  // ----------------------------------------------------------------- filters
  static const filters = 'تصفية';
  static const filterResults = 'نتائج التصفية';
  static const clearFilters = 'إلغاء التصفية';
  static const sortBy = 'ترتيب حسب';
  static const sortByName = 'الاسم';
  static const sortByPoints = 'النقاط';
  static const sortByAttendance = 'نسبة الحضور';
  static const sortByAge = 'السن';
  static const allMonths = 'كل الشهور';
  static const presentOnly = 'الحاضرون فقط';
  static const absentOnly = 'الغائبون فقط';
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
  static const lastActivityTitle = 'آخر مرة لكل نشاط';
  static const neverAttended = 'لم يحضر بعد';
  static const outstandingTitle = 'المميزون والملتزمون';
  static const outstandingTab = 'المميزون';
  static const committedTab = 'الملتزمون';
  static const outstandingEmpty = 'لا توجد بيانات حضور بعد';
  static const outstandingEmptyBody =
      'سجّل حضور سبت واحد على الأقل حتى تظهر النتائج.';
  static const committedEmpty = 'لا يوجد ملتزمون بعد';
  static const committedEmptyBody =
      'الملتزم هو من حضر كل السبوت المنقضية أو أغلبها.';
  static const attendanceRate = 'نسبة الحضور';
  static const birthdaysTitle = 'أعياد الميلاد';
  static const birthdaysEmpty = 'لا توجد أعياد ميلاد هذا الشهر';
  static const birthdaysEmptyBody = 'اختر شهراً آخر أو أضف تاريخ الميلاد للمخدومين.';
  static const turningAge = 'يكمل';
  static const birthdayToday = 'عيد ميلاده اليوم';
  static const calendarTitle = 'التقويم';
  static const calendarNothing = 'لا يوجد شيء في هذا اليوم';
  static const today = 'اليوم';
  static const previousMonth = 'الشهر السابق';
  static const nextMonth = 'الشهر التالي';
  static const todayBirthdays = 'أعياد الميلاد اليوم';
  static const attendanceStreak = 'حضور متصل';
  static const sessionsSoFar = 'السبوت المنقضية';
  static const streakWeeks = 'سبت متصل';
  static const fullAttendance = 'حضور كامل';
  static const sessionLocked = 'جلسة مغلقة';
  static const sessionLockedBody =
      'تم إغلاق هذه الجلسة بواسطة المسؤول ولا يمكن تعديلها.';
  static const lockSession = 'إغلاق الجلسة';
  static const unlockSession = 'إعادة فتح الجلسة';
  static const markAllPresent = 'تحضير الجميع';
  static const clearAll = 'مسح الكل';
  static const attendanceSaved = 'تم تسجيل الحضور';
  static const attendanceSavedOffline =
      'تم الحفظ محلياً • سيتم المزامنة عند عودة الاتصال';
  static const offlineMode = 'وضع عدم الاتصال — البيانات محفوظة محلياً';
  static String pendingSyncCount(int n) => '$n تغيير في انتظار المزامنة';
  static String failedSyncCount(int n) => '$n لم يُقبل';
  static const syncingNow = 'جارٍ المزامنة...';
  static const lessonOfWeek = 'درس هذا الأسبوع';
  static const lessonSchedule = 'برنامج الدروس';
  static const noLessonThisWeek = 'لا يوجد درس في هذا الأسبوع';
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
  static const sessionScore = 'درجة الجلسة';
  static const unsavedChanges = 'تغييرات غير محفوظة';
  static const unsavedChangesBody = 'لديك تغييرات لم تُحفظ. هل تريد الخروج وتجاهلها؟';
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
  static const pointsPerActivity = 'نقاط كل نشاط';
  static const generateSessions = 'إنشاء جلسات السبوت';
  static const sessionsGenerated = 'تم إنشاء الجلسات';
  static const yearNameRequired = 'اسم السنة مطلوب';
  static const endBeforeStart = 'تاريخ النهاية يجب أن يكون بعد تاريخ البداية';
  static const totalSessions = 'عدد الجلسات';
  static const maxPoints = 'الحد الأقصى للنقاط';

  // ----------------------------------------------------------------- reports
  static const reportsTitle = 'تقرير الطايو';
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
  static const pointsInPeriod = 'نقاط الفترة';
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
  static const myActivities               = 'تحضيراتي';
  static const activitiesNav              = 'نشاط الخدام';
  static const exportServantMonthly       = 'تقرير شهري - الخدام';
  static const exportServantYearly        = 'تقرير سنوي - الخدام';
  static const servantActivities          = 'نشاطات الخدام';
  static const servantActivityReport      = 'تقرير نشاطات الخدام';
  static const lessonPrep                 = 'تحضير الدرس';
  static const sundaySchoolAttendance     = 'حضور مدارس الأحد';
  static const servantMeetingAttendance   = 'حضور اجتماع الخدمة';
  static const servantMeetingShort        = 'اجتماع الخدمة';
  static const submitLessonPrep           = 'رفع تحضير الدرس';
  static const prepPending                = 'قيد المراجعة';
  static const prepAccepted               = 'مقبول';
  static const prepCommented              = 'يوجد تعليق';
  static const acceptPrep                 = 'قبول';
  static const addComment                 = 'تعليقات';
  static const noLessonPreps              = 'لا توجد تحضيرات مرفوعة';
  static const noLessonPrepsBody          = 'ارفع تحضيرك لأول سبت.';
  static const recordAttendance           = 'تسجيل الحضور';
  static const noAttendanceRecords        = 'لا توجد سجلات حضور';
  static const noAttendanceRecordsBody    = 'لم يتم تسجيل أي حضور لهذا النشاط.';
  static const pickPhotos                 = 'اختيار صور';
  static const pickPdf                    = 'اختيار PDF';
  static const pdfFile                    = 'ملف PDF';
  static const pickAPdfFile               = 'اختر ملف بصيغة PDF';
  static const photosSelected             = 'صور مختارة';
  static const submittedSuccessfully      = 'تم رفع التحضير بنجاح';
  static const reviewedSuccessfully       = 'تمت المراجعة';
  static const enterComment               = 'اكتب التعليق';
  static const commentRequired            = 'التعليق مطلوب';
  static const noPhotosSelected           = 'يجب اختيار صورة أو ملف PDF واحد على الأقل';
  static const lessonPrepTitle            = 'تحضير الدرس';
  static const alreadySubmitted           = 'تم الرفع';
  static const pendingPreps               = 'تحضيرات قيد المراجعة';

  // -------------------------------------------------------------- competitions
  static const competitions            = 'المسابقات';
  static const competitionsList        = 'قائمة المسابقات';
  static const weeklyCompetition       = 'المسابقة الأسبوعية';
  static const addCompetition          = 'إضافة مسابقة';
  static const editCompetition         = 'تعديل المسابقة';
  static const deleteCompetition       = 'حذف المسابقة';
  static const competitionTitle        = 'عنوان المسابقة';
  static const competitionWeekDate     = 'تاريخ الأسبوع';
  static const competitionMaxMark      = 'العلامة القصوى';
  static const markChildren            = 'تسجيل العلامات';
  static const cumulativeScores        = 'المجموع التراكمي';
  static const noCompetitions          = 'لا توجد مسابقات';
  static const noCompetitionsBody      = 'أضف مسابقة أسبوعية للبدء.';
  static const noMarkEntered           = 'لم تُسجَّل علامة';
  static const markSaved               = 'تم حفظ العلامات';
  static const totalMarks              = 'مجموع العلامات';
  static const avgMark                 = 'متوسط العلامة';
  static const exportCompetitions      = 'تصدير درجات المسابقات';
  static const exportCompetitionsHint  = 'اختر المسابقات المطلوبة';
  static const selectAll               = 'تحديد الكل';
  static const clearSelection          = 'إلغاء التحديد';
  static const exportSelected          = 'تصدير المحدد';
  static const mark                    = 'الدرجة';
  static const competitionTitleRequired = 'عنوان المسابقة مطلوب';
  static const confirmDeleteCompetition = 'هل تريد حذف هذه المسابقة وكل علاماتها؟';

  // ------------------------------------------------------------------- events
  static const events                  = 'نشاطات ترفيهية';
  static const addEvent                = 'إضافة نشاط';
  static const editEvent               = 'تعديل النشاط';
  static const deleteEvent             = 'حذف النشاط';
  static const eventTitleLabel         = 'اسم النشاط';
  static const eventDateLabel          = 'تاريخ النشاط';
  static const eventCost               = 'التكلفة (ج.م)';
  static const eventDescription        = 'وصف (اختياري)';
  static const noEvents                = 'لا توجد نشاطات ترفيهية';
  static const noEventsBody            = 'أضف نشاطاً للبدء.';
  static const eventTitleRequired      = 'اسم النشاط مطلوب';
  static const eventCostRequired       = 'التكلفة مطلوبة';
  static const eventCostInvalid        = 'التكلفة يجب أن تكون أكبر من صفر';
  static const confirmDeleteEvent      = 'هل تريد حذف هذا النشاط وكل مدفوعاته؟';
  static const addPayment              = 'إضافة دفعة';
  static const deletePayment           = 'حذف الدفعة';
  static const paymentAmount           = 'المبلغ المدفوع (ج.م)';
  static const paymentNotes            = 'ملاحظة (اختياري)';
  static const totalPaid               = 'المدفوع';
  static const remaining               = 'المتبقي';
  static const paidInFull              = 'مسدَّد';
  static const paymentSaved            = 'تم حفظ الدفعة';
  static const paymentDeleted          = 'تم حذف الدفعة';
  static const noPayments              = 'لا توجد مدفوعات';
  static const paymentAmountRequired   = 'المبلغ مطلوب';
  static const paymentAmountInvalid    = 'المبلغ يجب أن يكون أكبر من صفر';
  static const paymentAmountExceeds    = 'المبلغ يتجاوز المتبقي';
  static const paymentMethodLabel      = 'طريقة الدفع';
  static const paymentMethodCash       = 'كاش';
  static const paymentMethodTayo       = 'كيتي';
  static const confirmDeletePayment    = 'هل تريد حذف هذه الدفعة؟';
  static const paymentHistory          = 'سجل الدفعات';
  static const collected               = 'محصَّل';
  static const expected                = 'متوقع';
  static const partialPay              = 'بدأ الدفع';
  static const notPaidTab              = 'لم يدفع';

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
}
