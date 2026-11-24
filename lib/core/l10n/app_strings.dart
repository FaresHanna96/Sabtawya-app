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
  static const noResults = 'مفيش نتايج';
  static const promoteClassesTitle = 'ترقية الفصول للسنة الجديدة';
  static const promoteClassesConfirm = 'رقّي الفصول';
  static const retry = 'إعادة المحاولة';
  static const confirm = 'تأكيد';
  static const close = 'إغلاق';
  static const loading = 'بيتحمّل…';
  static const noData = 'مفيش بيانات';
  static const all = 'الكل';
  static const badgeFilter = 'وسام';
  static const allBadges = 'كل الأوسمة';
  static const badgeFilterLoadFailed = 'مقدرناش نحمّل الأوسمة دلوقتي. جرّب تاني.';
  static const active = 'نشط';
  static const inactive = 'غير نشط';
  static const optional = 'اختياري';
  static const deacon = 'شماس';
  static const yes = 'نعم';
  static const no = 'لا';
  static const total = 'الإجمالي';
  static const points = 'طايو';
  static const notes = 'ملاحظات';
  static const saved = 'اتحفظ بنجاح';
  static String saveFailedFor(List<String> classes) =>
      'ما اتحفظش: ${classes.join('، ')}. الباقي اتحفظ، اضغط حفظ تاني.';
  static const somethingWentWrong = 'حصلت مشكلة، جرّب تاني';
  static const noPermission = 'مالكش صلاحية تعمل ده';
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
      'اكتب بريدك الإلكتروني وهنبعتلك رابط استعادة كلمة المرور.';
  static const resetLinkSent =
      'لو البريد ده مسجّل عندنا، هيوصله رابط الاستعادة';
  static const sendResetLink = 'إرسال الرابط';
  static const setNewPassword = 'تعيين كلمة مرور جديدة';
  static const newPassword = 'كلمة المرور الجديدة';
  static const confirmNewPassword = 'تأكيد كلمة المرور الجديدة';
  static const passwordChanged = 'اتغيّرت كلمة المرور';
  static const backToLogin = 'العودة لتسجيل الدخول';
  static const signUp = 'إنشاء حساب جديد';
  static const signUpHint =
      'اعمل حسابك واستنى أمين الخدمة يفعّله علشان تظهرلك فصولك.';
  static const noAccountYet = 'معندكش حساب؟ اعمل حساب جديد';
  static const fullName = 'الاسم بالكامل';
  static const fullNameRequired = 'الاسم مطلوب';
  static const nameArabicOnly = 'اكتب الاسم بالعربي';
  static const confirmPassword = 'تأكيد كلمة المرور';
  static const passwordsDoNotMatch = 'كلمتا المرور مش متطابقتين';
  static const passwordTooShort = 'كلمة المرور لازم تكون 8 حروف على الأقل';
  static const signUpDone = 'اتعمل الحساب';
  static const confirmEmailTitle = 'تأكيد البريد الإلكتروني';
  static const confirmEmailBody =
      'بعتنالك رسالة تأكيد على بريدك الإلكتروني. افتح الرابط وبعدين سجّل دخولك.';
  static const emailAlreadyUsed = 'البريد ده مستخدم قبل كده';
  static const emailDisposable =
      'ما ينفعش التسجيل ببريد مؤقت. استخدم بريدك الشخصي اللي بتستعمله على طول.';
  static String emailTypo(String? suggestion) => suggestion == null
      ? 'شكل البريد مكتوب غلط. راجعه وبعدين سجّل.'
      : 'تقصد $suggestion ؟ صحّح البريد وبعدين سجّل.';
  static String emailDomainNoMail(String domain) =>
      'النطاق $domain مابيستقبلش رسائل. اتأكد إن البريد مكتوب صح.';
  static const emailRejected =
      'ما ينفعش التسجيل بالبريد ده. استخدم بريدك الشخصي الصح.';
  static const invalidEmail = 'البريد الإلكتروني مش صح';
  static const nameAlreadyUsed =
      'الاسم ده متسجّل قبل كده. لو عندك حساب سجّل دخولك، أو اكتب اسمك كامل بشكل مختلف.';
  static const emailRequired = 'البريد الإلكتروني مطلوب';
  static const emailInvalid = 'صيغة البريد الإلكتروني مش صح';
  static const passwordRequired = 'كلمة المرور مطلوبة';
  static const invalidCredentials =
      'البريد الإلكتروني أو كلمة المرور مش صح';
  static const accountInactiveTitle = 'الحساب لسه متفعّلش';
  static const accountInactiveBody =
      'حسابك اتعمل بس لسه مستني أمين الخدمة يفعّله. كلّمه علشان يفعّله.';
  static const accountNotFoundTitle = 'البريد ده مش متسجّل';
  static const accountNotFoundBody =
      'البريد ده مش متسجّل عندنا. كلّم أمين الخدمة يبعتلك دعوة.';
  static const accountRejectedTitle = 'الطلب اترفض';
  static const accountRejectedBody =
      'طلب التسجيل بتاعك اترفض. كلّم أمين الخدمة تعرف التفاصيل.';
  static const signUpSuccess =
      'حسابك اتعمل — مستني موافقة أمين الخدمة';
  static const logoutAndRetry = 'الخروج والمحاولة بحساب آخر';
  static const confirmLogout = 'عايز تسجّل خروج؟';
  static String confirmLogoutPending(int n) =>
      'عندك $n تغيير لسه ما اتبعتش. هيفضل محفوظ على الموبايل ده وهيتبعت لما '
      'تسجّل دخولك تاني. عايز تسجّل خروج؟';

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
  static String classNotRecordedOn(String day) => 'لسه ما اتسجّلش حضور $day';
  static String classWeekAttendance(String day) => 'حضور سبت $day';
  static const recordNow = 'سجّل الحضور';
  static const classNeedsServant = 'محتاج خادم';
  static const prepSentLine = 'التحضير اتبعت';
  static const healthShort = 'صحة الفصل';
  static String healthChipTooltip(int score) =>
      'صحة الفصل $score من 100: من حضور الأطفال وتسجيل الحضور والتحضير والافتقاد';
  static const noUpcomingSession = 'مفيش جلسة جاية';
  static const noAttendanceYet = 'لسه ما اتسجّلش حضور';
  static const noBirthdaysToday = 'مفيش أعياد ميلاد النهارده';
  static const futureSession = 'سبت لسه ما جاش';
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
  static const logEmpty = 'مفيش تعديلات بالتصفية دي';
  static const logLoadMore = 'عرض المزيد';
  static const loadFailed = 'ما قدرناش نحمّل';
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
  static const noClassesAssigned = 'لسه ما اتعيّنش ليك أي فصل';
  static const noClassesAssignedBody =
      'كلّم أمين الخدمة يعيّنك على فصل.';
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
      'الفصل وكل جلسات الحضور بتاعته هيتمسحوا نهائي. تكمّل؟';
  static const classDeleted = 'اتحذف الفصل';
  static const classHasChildren =
      'ما ينفعش تحذف فصل فيه مخدومين. انقلهم لفصل تاني الأول أو استخدم الأرشفة.';
  static const classNameRequired = 'اسم الفصل مطلوب';
  static const patronSaint = 'شفيع الفصل';
  static const patronName = 'اسم الشفيع';
  static const patronPhoto = 'صورة الشفيع';
  static const noPatron = 'لسه ما اتحدّدش شفيع';
  static const childrenCount = 'عدد المخدومين';
  static const servantsCount = 'عدد الخدام';
  static const assignedServants = 'الخدام المعينون';
  static const servantIsMe = 'أنت';
  static const servantInactive = 'غير مفعّل';
  static const classDetails = 'تفاصيل الفصل';
  static const selectClass = 'اختر الفصل';
  static const noClasses = 'مفيش فصول';
  static const confirmArchiveClass =
      'الفصل هيتخفي من القوائم النشطة وبياناته كلها هتفضل محفوظة. تكمّل؟';

  // ---------------------------------------------------------------- servants
  static const servantsTitle = 'الخدام';
  static const servantLabel = 'الخادم';
  static const addServant = 'إضافة خادم';
  static const editServant = 'تعديل الخادم';
  static const servantName = 'اسم الخادم';
  static const servantData = 'بيانات الخادم';
  static const confessor = 'آب الاعتراف';
  static const occupation = 'الدراسة أو العمل';
  static const servantDataHint = 'البيانات دي بتظهر لأمين الخدمة بس.';
  static const mobile = 'رقم الموبايل';
  static const role = 'الصلاحية';
  static const roleAdmin = 'أمين الخدمة';
  static const roleServant = 'خادم';
  static const roleServantFemale = 'خادمة';
  static const roleGeneralServant = 'خادم عام';
  static const pendingRequests = 'طلبات الانضمام';
  static const notificationsTitle = 'الإشعارات';
  static const noNotifications = 'مفيش إشعارات';
  static const markAllRead = 'تعليم الكل كمقروء';
  static const pendingRequestsBody =
      'طلبات محتاجة موافقتك قبل ما أصحابها يشوفوا أي بيانات.';
  static const noPendingRequests = 'مفيش طلبات انضمام';
  static const acceptRequest = 'قبول';
  static const rejectRequest = 'رفض';
  static const confirmRejectRequest = 'الطلب هيترفض وصاحبه مش هيقدر يدخل.';
  static const requestAccepted = 'الطلب اتقبل';
  static const requestRejected = 'الطلب اترفض';
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
      'الدعوة اتعملت. الخادم يسجّل بنفس البريد الإلكتروني وحسابه هيتفعّل لوحده.';
  static const inviteHint =
      'الحساب هيتفعّل والفصل هيتعيّن لوحدهم أول ما الخادم يسجّل بالبريد ده.';
  static const servantOneClass = 'الخادم يُعيَّن على فصل واحد فقط.';
  static const deleteInvite = 'حذف الدعوة';
  static const noServants = 'مفيش خدام';
  static const classesWithoutServant = 'فصول بلا خادم';
  static const servantsWithoutClass = 'خدام بلا فصل';
  static const servantsWithoutClassTitle = 'خدام لسه من غير فصل';
  static const classHasNoServant = 'مفيش خادم في الفصل ده لسه';
  static String servantsCountOf(int n) =>
      n == 1 ? 'خادم واحد' : '$n خدام';
  static const allCollected = 'اتحصّل المبلغ كله';
  static const noServantsHint = 'مفيش خدام في الفصل ده لسه. أمين الخدمة هو اللي بيعيّن الخدام.';
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
  static const noCommittedYet = 'لسه مفيش مخدومين ملتزمين';
  static const deleteVisit = 'تحذف الافتقاد ده؟';
  static const visitDeleted = 'اتحذف الافتقاد';
  static const myData = 'تعديل بياناتي';
  static const myDataHint =
      'عدّل بياناتك الشخصية: الاسم، الموبايل، تاريخ الميلاد، العنوان وغيرها.';
  static const deleteServant = 'حذف الخادم';
  static const confirmDeleteServant =
      'حساب الخادم ده هيتمسح نهائي مع تحضيراته وحضوره. مفيش رجوع.';
  static const removeServant = 'إزالة من الفصل';
  static const confirmRemoveServant = 'تشيل الخادم ده من الفصل؟';
  static const servantAssigned = 'الخادم اتعيّن';
  static const servantMoved = 'الخادم اتنقل للفصل الجديد';
  static const servantRemoved = 'الخادم اتشال';
  static const noServantToAssign = 'كل الخدام في الفصل ده بالفعل';
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
  static const birthDateFuture = 'تاريخ الميلاد ما ينفعش يكون في المستقبل';
  static const pickBirthDate = 'اختر تاريخ الميلاد';
  static const childPhoto = 'صورة المخدوم';
  static const addPhoto = 'إضافة صورة';
  static const changePhoto = 'تغيير الصورة';
  static const takePhoto = 'التصوير بالكاميرا';
  static const fromGallery = 'اختيار من الصور';
  static const removePhoto = 'حذف الصورة';
  static const confirmRemovePhoto = 'تحذف صورة المخدوم؟';
  static const photoSaved = 'الصورة اتحفظت';
  static const photoRemoved = 'الصورة اتحذفت';
  static const photoTooLarge = 'حجم الصورة كبير. الحد الأقصى 5 ميجابايت.';
  static const photoTypeNotSupported =
      'صيغة الصورة مش مدعومة. استخدم JPG أو PNG.';
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
  static const mobileInvalid = 'رقم الموبايل مش صح';
  static const noChildren = 'مفيش مخدومين';
  static const noChildrenBody = 'ابدأ بإضافة مخدوم أو استيراد قائمة من Excel.';
  static const childSaved = 'اتحفظت بيانات المخدوم';
  static const moveChild = 'نقل المخدوم لفصل آخر';
  static const moveChildBody =
      'اختار الفصل الجديد. كل سجلات الحضور القديمة هتفضل محفوظة.';
  static const childMoved = 'المخدوم اتنقل';
  static const newClass = 'الفصل الجديد';
  static const deactivateChild = 'إلغاء تنشيط المخدوم';
  static const activateChild = 'تنشيط المخدوم';
  static const confirmDeactivateChild =
      'المخدوم هيتخفي من قوائم الحضور الجاية وكل سجلاته ودرجاته القديمة هتفضل محفوظة. '
      'تكمّل؟';
  static const childDeactivated = 'المخدوم اتوقّف';
  static const childActivated = 'المخدوم اتفعّل';
  static const showInactive = 'إظهار غير النشطين';
  static const inactiveChip = 'غير النشطين';
  static const createdAt = 'تاريخ الإضافة';
  static const updatedAt = 'آخر تحديث';
  static const visitsSection = 'الافتقادات';
  static const lastPhoneVisit = 'آخر افتقاد تليفون';
  static const lastHomeVisit = 'آخر افتقاد منزلي';
  static const visitNotes = 'ملاحظات الافتقاد';
  static const noVisitYet = 'لسه ما اتعملش';
  static const pickVisitDate = 'اختر تاريخ الافتقاد';
  static const visitsSaved = 'اتحفظت بيانات الافتقاد';
  static const visitHistory = 'سجل الافتقادات';
  static const undo = 'تراجع';
  static const undoEditTitle = 'التراجع عن هذا التعديل';
  static const undoEditMessage =
      'البيانات هترجع زي ما كانت قبل التعديل ده. ومش هينفع لو اتغيّرت بعده.';
  static const undoDone = 'اتراجع';
  static const recentImports = 'استيرادات حديثة';
  static const undoImportTitle = 'التراجع عن الاستيراد';
  static const undoImportMessage =
      'سيُحذف المخدومون الذين أضافهم هذا الاستيراد وتعود بيانات من عدّلهم إلى ما كانت. يتعذر ذلك لو عُدّل أحدهم بعده.';
  static String importBatchLine(String when, int added, int changed) =>
      '$when: أضاف $added، عدّل $changed';
  static const healthNotesTitle = 'ملاحظات صحية وخاصة';
  static const healthNotesHint =
      'حساسية، حالة صحية، ظروف أسرية... (يراها خدام الفصل والأمين فقط)';
  static const healthNotesEmpty = 'مفيش ملاحظات';
  static const healthNotesSaved = 'اتحفظت الملاحظات';
  static const healthNotesPrivate = 'خاصة: لا يراها غير خدام الفصل والأمين';
  static const noVisitHistory = 'لسه مفيش سجل افتقادات';
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
  static const decliningEmpty = 'مفيش مخدومين حضورهم في تراجع';
  static const decliningEmptyBody =
      'هنا بتظهر الحالات اللي حضورها قلّ بوضوح في آخر 4 سبوت عن الـ 4 اللي قبلهم';
  static String decliningLine(int recent, int previous) =>
      'كان $previous٪ وبقى $recent٪';
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
  static const notRecordedLabel = 'ما سجّلوش الحضور:';
  static String serviceWide(int pct) => 'الخدمة كلها $pct%';
  static const todayBar = 'النهارده';
  static const breakShort = 'إجازة';
  static const legendHigh = '60% وأكثر';
  static const legendMid = '40–59%';
  static const legendLow = 'أقل من 40%';
  static const goalLine = 'الهدف 60%';
  static const followUpHow = 'كيف تم افتقاد';
  static const followUpNoteGeneric = 'افتقاد بعد غياب ورا بعض';
  static const logCall = 'سجّل افتقاد';
  static const absenceAlertSettings = 'تنبيهات الغياب';
  static const absenceAlertLevelsLabel =
      'عدد السبوت المتتالية للتنبيه (مثال: 2,3)';
  static const absenceAlertLevelsHelp =
      'بيتبعت تنبيه لخدام الفصل لما غياب المخدوم يوصل للأعداد دي';
  static const absenceAlertLevelsInvalid =
      'اكتب من رقم إلى 4 أرقام بين 1 و20 مفصولة بفاصلة';
  static const followUpPhone = 'مكالمة تليفون';
  static const followUpHome = 'زيارة منزلية';
  static String followUpNote(int n) => 'افتقاد بعد غياب $n سبوت ورا بعض';
  static String absentInARowShort(String n) => 'غياب $n سبوت';
  static String absentSaturdays(int n) => 'غايب $n سبوت ورا بعض';
  static String presentSaturdays(int n) => 'حاضر $n سبوت ورا بعض';
  static const lastPresent = 'آخر حضور';
  static const followedUpOn = 'تم الافتقاد';
  static const notFollowedUp = 'لسه ما اتفتقدش';
  static const markFollowedUp = 'تم الافتقاد';
  static const noAbsences = 'مفيش غياب متكرر';
  static const noAbsencesBody = 'كل المخدومين حضروا الفترة اللي فاتت. ربنا يبارك';
  static String updateAvailable(String v) => 'فيه إصدار جديد ($v)';
  static const updateNow = 'حدّث دلوقتي';
  static String visitBy(String name) => 'بواسطة $name';
  static const changeHistory = 'سجل التغييرات';
  static String showAllCount(int n) => 'عرض الكل ($n)';
  static const noChangeHistory = 'مفيش تغييرات متسجّلة';
  static const changeAdded = 'إضافة المخدوم';
  static const changeEdited = 'تعديل بيانات المخدوم';
  static const changeAttendance = 'تسجيل الحضور';
  static const updateRequiredTitle = 'تحديث مطلوب';
  static String updateRequiredBody(String v) =>
      'لازم تحدّث التطبيق للإصدار $v علشان تكمل استخدامه.';
  static String updateDownloading(int p) => 'بيتحمّل التحديث… $p٪';
  static const updateInstalling = 'اضغط «تثبيت» في الشاشة اللي ظهرتلك';
  static const updateNeedsPermission =
      'اسمح للتطبيق بتثبيت التحديثات من الإعدادات، وبعدين جرّب تاني';
  static const updateBadFile = 'الملف ما اتحمّلش كامل. جرّب تاني';
  static const updateFailed = 'ما قدرناش نحدّث من جوه التطبيق';
  static const updateNotFinished =
      'التثبيت ما كملش. اضغط «حدّث دلوقتي» وجرّب تاني';
  static const updateOpenPage = 'صفحة التحميل';
  static const checkForUpdates = 'شوف التحديثات';
  static const checkingForUpdates = 'بندوّر على تحديثات…';
  static String upToDate(String v) => 'معاك آخر إصدار ($v)';
  static const updateCheckFailed =
      'ما قدرناش نشوف التحديثات. اتأكد من الإنترنت وجرّب تاني';
  static const updateReloadBody =
      'افتح الإصدار الجديد دلوقتي؟ كل اللي سجلته محفوظ.';
  static const updateReload = 'إعادة التحميل';
  static String classesCount(int n) => n <= 10 ? '$n فصول' : '$n فصل';
  static const done = 'تم';
  static String monthsCount(int n) => n <= 10 ? '$n شهور' : '$n شهر';
  static const birthdayPassed = 'عدّى السنة دي';
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
  static const logNotRecorded = 'ما اتسجّلش';
  static String logAttendedOf(int attended, int held) =>
      'حضر $attended من $held';
  static String logPoints(int points) => '$points طايو';
  static String logUnrecorded(int n) =>
      n == 1 ? 'سبت ما اتسجّلش' : '$n سبوت ما اتسجّلوش';
  static const attendanceLogEmpty = 'لسه مفيش سبوت في السنة دي';
  static const logNoMatch = 'مفيش سبوت بالاختيار ده';
  static const logNoLesson = 'مفيش درس';
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
  static const birthdaysEmpty = 'مفيش أعياد ميلاد الشهر ده';
  static const birthdaysEmptyBody =
      'اختار شهر تاني أو ضيف تاريخ الميلاد للمخدومين.';
  static const turningAge = 'يكمل';
  static const birthdayToday = 'عيد ميلاده النهارده';
  static const calendarTitle = 'التقويم';
  static const calendarNothing = 'مفيش حاجة في اليوم ده';
  static const calendarMonthBirthdays = 'عيد ميلاد';
  static const calendarMonthEvents = 'فعالية';
  static const calendarMonthEmpty = 'مفيش حاجة في الشهر ده';
  static const today = 'اليوم';
  static const previousMonth = 'الشهر السابق';
  static const nextMonth = 'الشهر التالي';
  static const todayBirthdays = 'أعياد الميلاد النهارده';
  static const sessionsSoFar = 'السبوت المنقضية';
  static const fullAttendance = 'حضور كامل';
  static const sessionLocked = 'جلسة مغلقة';
  static const sessionLockedBody =
      'أمين الخدمة قفل الجلسة دي وما ينفعش تتعدّل.';
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
  static const badgeMassMonth = 'ليتورجي';
  static const badgeMassMonthRule =
      'حضر القداس كل أسبوع في شهر كامل (3 سبوت على الأقل).';
  static const badgeStarYear = 'نجم السنة';
  static const badgeStarYearRule =
      'الأول في فصله بس على مدار السنة كلها (بتتحدد لما السنة تخلص).';
  static const badgeStarSchool = 'نجم مدارس الأحد';
  static const badgeStarSchoolRule =
      'الأول في مدارس الأحد كلها (كل الفصول) على مدار السنة (بتتحدد لما السنة تخلص).';
  static const badgeVespersMonth = 'عشية';
  static const badgeVespersMonthRule =
      'حضر العشية كل أسبوع في شهر كامل (3 سبوت على الأقل).';
  static const badgeMassMonthPending =
      'الشهر لسه ما خلصش. الوسام بيتسجّل أول ما يخلص لو فضل حاضر كل سبت.';
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
      'في «المزيد» هتلاقي اللي محتاج متابعة: الغايبين والبيانات الناقصة وأعياد الميلاد، وعدد كل واحدة جنبها. اضغط على أي طفل تكلّم أهله أو تبعتلهم واتساب.';
  static const tourFollowUpGeneralBody =
      'في «المزيد» هتلاقي «متابعة الغياب» و«بيانات ناقصة» لكل الفصول، وعدد كل واحدة جنبها. اضغط على أي واحدة تفتحلك القايمة.';
  static const tourFollowUpAdminBody =
      'في «المزيد»: الغايبين، البيانات الناقصة، التحضيرات اللي مستنية مراجعة وطلبات الانضمام، كل واحدة بعددها.';
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
  static const noSearchMatch = 'مفيش مخدوم بالبحث ده';
  static const backToTop = 'إلى أعلى';

  // A Saturday with no lesson, or a save with nobody ticked.
  static String breakDayBanner(String reason) =>
      'السبت ده $reason: مفيش درس ومش بيتسجّل حضور.';
  static const breakHoliday = 'إجازة';
  static const breakActivity = 'نشاط ترفيهي';
  static const breakNone = 'يوم درس عادي';
  static const markNoLesson = 'إجازة / نشاط ترفيهي';
  static const breakSheetTitle = 'فيه درس السبت ده؟';
  static const breakShift = 'أجّل الدروس أسبوع';
  static const breakShiftHint =
      'الدروس بعد السبت ده هتتأجل أسبوع. اقفله لو الدرس اتلغى بس.';
  static const breakHasRecords =
      'اتسجّل حضور اليوم ده قبل كده: مش هيتحسب في أبطال الالتزام ولا الغياب.';
  static const change = 'تغيير';
  static const nobodyPresentTitle = 'ما علّمتش على أي مخدوم';
  static String nobodyPresentBody(int n) =>
      'لو حفظت دلوقتي، الـ $n مخدوم كلهم هيتسجّلوا غياب. لو مكانش فيه درس '
      'النهارده ماتحفظش.';
  static const saveAsAbsent = 'سجّلهم غياب';
  static const attendanceSaved = 'اتسجّل الحضور';
  static const attendanceSavedOffline =
      'اتحفظ على الموبايل • هيتبعت لما النت يرجع';
  static const offlineMode = 'مفيش نت — اللي بتسجّله محفوظ على الموبايل';
  static String pendingSyncCount(int n) => '$n تغيير مستني يتبعت';
  static String failedSyncCount(int n) => '$n ما اتقبلش';
  static const syncingNow = 'بيتزامن...';
  static const lessonOfWeek = 'درس الأسبوع ده';
  static const lessonSchedule = 'برنامج الدروس';

  // صلوات (المزيد): the servants' prayers before and after the lesson.
  static const prayersTitle = 'صلوات';
  static const prayerCopied = 'الصلاة اتنسخت';
  static const prayersIntro =
      'صلّي قبل ما تبدأ خدمتك وبعد ما تخلصها. اقراها بهدوء، أو بصوت عالي مع الخدام.';
  static String prayerReadTime(int n) =>
      n == 1 ? 'قراءة دقيقة' : 'قراءة $n دقايق';
  static const textBigger = 'تكبير الخط';
  static const textSmaller = 'تصغير الخط';
  static const copy = 'نسخ';
  static const noLessonThisWeek = 'مفيش درس الأسبوع ده';
  static const jumpToUpcomingLesson = 'الأسبوع الجاي';
  static const lessonUpcoming = 'القادم';
  static const lessonNoClass = 'بلا درس';
  static const page = 'ص';
  static const pulpit = 'المنبر';
  static const hymns = 'الترانيم / الألحان';
  static const lessonForPrep = 'الدرس المطلوب تحضيره';
  static const lessonPostponed = 'مفيش درس الأسبوع ده (اتأجل للأسبوع اللي بعده)';
  static const lessonCancelled = 'مفيش درس الأسبوع ده (اتلغى)';
  static const postponeLesson = 'تأجيل للأسبوع التالي';
  static const cancelLesson = 'إلغاء الدرس';
  static const restoreLesson = 'إرجاع الدرس';
  static const editLesson = 'تعديل الدرس';
  static const lessonTitleLabel = 'عنوان الدرس';
  static const lessonPageLabel = 'الصفحة';
  static const syncTitle = 'المزامنة';
  static const syncNow = 'مزامنة الآن';
  static const syncPending = 'في الانتظار';
  static const syncFailed = 'السيرفر ما قبلهاش';
  static const syncNothing = 'كله اتبعت';
  static const syncRetry = 'إعادة المحاولة';
  static const syncDiscard = 'تجاهل';
  static const needsConnection = 'الإجراء ده محتاج نت';
  static const saveAttendance = 'حفظ الحضور';
  static const noSessionsTitle = 'مفيش جلسات حضور';
  static const noSessionsBody =
      'لسه ما اتعملتش جلسات للفصل ده. راجع سنة الحضور من إعدادات أمين الخدمة.';
  static const presentCount = 'الحاضرون';
  static const recordedCount = 'تم تسجيلهم';
  static const presentOf = 'حضر';
  static const showAll = 'عرض الكل';
  static const nextSaturdayTitle = 'السبت القادم';
  static const pastSaturdays = 'السبوت السابقة';
  static const upcomingSaturdays = 'باقي السنة';
  static const prepMissing = 'التحضير ما اترفعش';
  static const searchServantHint = 'ابحث باسم الخادم';
  static const servantDirectory = 'دليل الخدام';
  static const noServantMobile = 'مفيش رقم';
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
      'ما اتسمحش. فعّل الإذن من إعدادات التطبيق وجرّب تاني';
  static const contactsExportTitle = 'جهات اتصال المخدومين';
  static const contactsExportBody =
      'حمّل ملف بأرقام الأمهات والآباء والمخدومين وافتحه على موبايلك '
      'علشان يتحفظوا في جهات الاتصال. بعدها هيظهرلك اسم المتصل (زي «أم مينا جورج – '
      'فصل 5 بنات») حتى لو رقمه مش محفوظ عندك.';
  static const contactsExportWho = 'مين يتحفظ؟';
  static const contactsMothers = 'الأمهات';
  static const contactsFathers = 'الآباء';
  static const contactsChildren = 'المخدومين';
  static String contactsCount(int n) => '$n جهة اتصال';
  static const contactsNone = 'مفيش أرقام تتحفظ';
  static const contactsDownload = 'تحميل ملف جهات الاتصال';
  static const contactsFileName = 'جهات اتصال المخدومين';
  static const contactsPrivacy =
      'الأرقام دي هتتحفظ في جهات اتصال موبايلك. استخدمها في خدمتك بس.';
  static const callChild = 'المخدوم';
  static const callMother = 'الأم';
  static const callFather = 'الأب';
  static const importExcelShort = 'استيراد Excel';
  static const showLess = 'عرض أقل';
  static const ofWord = 'من';
  static const notTakenYet = 'لسه ما اتسجّلش';
  static const partlyTaken = 'تسجيل جزئي';
  static const takenDone = 'اتسجّل';
  static const upcomingSaturday = 'سبت قادم';
  static const clearAllConfirm = 'مسح كل العلامات لهذا السبت؟';
  static const clearAllConfirmBody =
      'كل علامات الحضور على الشاشة هتتمسح. مفيش حاجة هتتحفظ غير لما تضغط حفظ.';
  static const sessionScore = 'درجة الجلسة';
  static const unsavedChanges = 'تغييرات غير محفوظة';
  static const unsavedChangesBody =
      'عندك تغييرات ما اتحفظتش. تخرج وتتجاهلها؟';
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
  static const sessionsGenerated = 'الجلسات اتعملت';
  static const yearNameRequired = 'اسم السنة مطلوب';
  static const endBeforeStart = 'تاريخ النهاية لازم يكون بعد تاريخ البداية';
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
  static const templateSaved = 'اتعمل ملف النموذج';
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
  static const importRowsSkipped = 'هتتجاهل';
  static const importDone = 'اتعمل الاستيراد';
  static const importInserted = 'اتضاف';
  static const importUpdated = 'اتحدّث';
  static const importNoValidRows = 'مفيش صفوف صحيحة للاستيراد';
  static const importEmptyFile = 'الملف مفيهوش بيانات';
  static const importMissingHeader =
      'ما قدرناش نتعرف على أعمدة الملف. استخدم ملف النموذج.';
  static const importErrorNameMissing = 'اسم المخدوم ناقص';
  static const importErrorGenderMissing = 'النوع ناقص أو مش مفهوم (ولد/بنت)';
  static const importErrorDuplicateInFile = 'مكرر في نفس الملف';
  static const importErrorNotFound = 'مفيش مخدوم مطابق';
  static const importErrorExists = 'مخدوم موجود بالفعل';
  static const importErrorMobile = 'رقم موبايل مش صح';
  static const importErrorBirthDate = 'تاريخ ميلاد مش صح';
  static const importWillMoveClass = 'هيتنقل للفصل ده';
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
  static const exportDone = 'اتعمل الملف';
  static const share = 'مشاركة الملف';
  static const exporting = 'بيتصدّر…';

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
  static const prepNotSent = 'ما بعتش تحضير';
  static const missedPrepsTitle = 'التحضيرات اللي ما اتبعتتش';
  static const prepMarkedByHand = 'تحضير اتسجّل يدوي';
  static const acceptPrep = 'قبول';
  static const addComment = 'تعليقات';
  static const noLessonPreps = 'مفيش تحضيرات مرفوعة';
  static const noLessonPrepsBody = 'ارفع تحضيرك لأول سبت.';
  static const recordAttendance = 'تسجيل الحضور';
  static const noAttendanceRecords = 'مفيش سجلات حضور';
  static const noAttendanceRecordsBody = 'لسه ما اتسجّلش أي حضور هنا.';
  static const pickPhotos = 'اختيار صور';
  static const pickPdf = 'اختيار PDF';
  static const pdfFile = 'ملف PDF';
  static const openFile = 'افتح الملف';
  static const pickAPdfFile = 'اختر ملف بصيغة PDF';
  static const photosSelected = 'صور مختارة';
  static const submittedSuccessfully = 'التحضير اترفع';
  static const reviewedSuccessfully = 'اتراجع';
  static const enterComment = 'اكتب التعليق';
  static const commentRequired = 'التعليق مطلوب';
  static const noPhotosSelected = 'اختار صورة أو ملف PDF واحد على الأقل';
  static const lessonPrepTitle = 'تحضير الدرس';
  static const alreadySubmitted = 'اترفع';

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
  static const prepTodoNotSent = 'لسه ما اتبعتش';
  static const prepTodoUpload = 'ارفع التحضير';
  static const myAttendanceTitle = 'حضوري';
  static String myAttendanceOf(int came, int held) => 'حضرت $came من $held';
  static const removeFileTitle = 'حذف هذا الملف من التحضير؟';
  static const couldNotLoad = 'ما قدرناش نحمّل';
  static const uploadNeedsInternet = 'رفع التحضير يحتاج إنترنت. حاول تاني لما يرجع الاتصال.';
  static String uploadingProgress(int done, int total) => 'رفع $done من $total';
  static String uploadFailedSome(int n) =>
      n == 1 ? 'ملف واحد ما اترفعش — جرّب تاني' : '$n ملفات ما اترفعوش — جرّب تاني';
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
  static const noCompetitions = 'مفيش مسابقات';
  static const noCompetitionsBody = 'ضيف مسابقة أسبوعية علشان تبدأ.';
  static const noCompetitionsViewer = 'لسه مفيش مسابقات اتسجلت.';
  static const noScoresYet = 'لسه مفيش درجات';
  static const noScoresYetBody =
      'الترتيب بيظهر بعد ما تتسجل درجات أول مسابقة.';
  static const competitionToday = 'النهارده';
  static const competitionUpcoming = 'جاية';
  static String competitionsCountLabel(int n) =>
      n == 1 ? 'مسابقة واحدة' : '$n مسابقات';
  static const noMarkEntered = 'ما اتسجّلتش علامة';
  static const markSaved = 'اتحفظت العلامات';
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
      'تحذف المسابقة دي وكل علاماتها؟';

  // ------------------------------------------------------------------- events
  static const events = 'نشاطات ترفيهية';
  static const addEvent = 'إضافة نشاط';
  static const editEvent = 'تعديل النشاط';
  static const deleteEvent = 'حذف النشاط';
  static const eventTitleLabel = 'اسم النشاط';
  static const eventDateLabel = 'تاريخ النشاط';
  static const eventCost = 'التكلفة (ج.م)';
  static const eventDescription = 'وصف (اختياري)';
  static const noEvents = 'مفيش نشاطات ترفيهية';
  static const noEventsBody = 'ضيف نشاط علشان تبدأ.';
  static const eventTitleRequired = 'اسم النشاط مطلوب';
  static const eventCostRequired = 'التكلفة مطلوبة';
  static const eventCostInvalid = 'التكلفة لازم تكون أكبر من صفر';
  static const confirmDeleteEvent = 'تحذف النشاط ده وكل مدفوعاته؟';
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
      'حجز المخدوم ده في الرحلة هيتلغى. المدفوعات ما بتتأثرش.';
  static const reservedBadge = 'حاجز';
  static const reservedSaved = 'اتحجز';
  static const reservationCancelled = 'الحجز اتلغى';
  static const reservedUnpaidStatus = 'حاجز (لسه ما دفعش)';
  static const bookShort = 'حجز الرحلة';
  static const bookedShort = 'اتحجزت الرحلة';
  static const bookedPaidShort = 'دفع';
  static const pickEvent = 'اختر النشاط';
  static const bookingPaidNote = 'دفع قبل كده: الدفع من شاشة النشاط';
  static String bookingFor(String title) => 'حجز: $title';
  static String bookedOf(int n, int m) => 'محجوز $n من $m';
  static const paymentStatus = 'الحالة';
  static const serialNo = 'م';
  static const remaining = 'المتبقي';
  static const paidInFull = 'مسدَّد';
  static const paymentSaved = 'الدفعة اتحفظت';
  static const paymentDeleted = 'الدفعة اتحذفت';
  static const noPayments = 'مفيش مدفوعات';
  static const paymentAmountRequired = 'المبلغ مطلوب';
  static const paymentAmountInvalid = 'المبلغ لازم يكون أكبر من صفر';
  static const paymentAmountExceeds = 'المبلغ أكبر من المتبقي';
  static const paymentMethodLabel = 'طريقة الدفع';
  static const paymentMethodCash = 'كاش';
  static const paymentMethodTayo = 'كيتي';
  static const confirmDeletePayment = 'تحذف الدفعة دي؟';
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
  static const notPaidTab = 'ما دفعش';

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
  static const noPhoneNumber = 'مفيش رقم';

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
  static const noAnnouncements = 'مفيش إعلانات';
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
  static String announcementSent(int n) => 'اتبعت لـ $n';
  static const announcementNeedsConnection =
      'إرسال الإعلان محتاج إنترنت. اتصل وجرّب تاني.';
  static String readOf(int read, int total) => 'قرأه $read من $total';
  static const notReadYet = 'لسه ما قراش';
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
  static const noTemplates = 'لسه مفيش قوالب';
  static const noTemplatesBody =
      'القوالب اللي هنا بتظهر لكل الخدام وهما بيبعتوا للأهالي، جنب الجاهزة في التطبيق.';
  static const builtInTemplate = 'جاهز';
  static String messagesSent(int sent, int total) => 'اتبعت $sent من $total';
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
