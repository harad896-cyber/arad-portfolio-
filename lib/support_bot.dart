import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupportBotPage extends StatefulWidget {
  const SupportBotPage({super.key});

  @override
  State<SupportBotPage> createState() => _SupportBotPageState();
}

class _SupportBotPageState extends State<SupportBotPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  late Future<List<Map<String, dynamic>>> _reportsFuture;
  bool _sendingReport = false;
  String _faqSearch = '';
  _Faq? _lastMatchedFaq;
  final List<_BotMessage> _messages = [
    const _BotMessage(
      text: 'سلام! من راهنمای گپ‌رسان هستم. می‌توانم دربارهٔ حساب کاربری، پیام‌ها، گروه‌ها، امنیت و تنظیمات راهنمایی‌تان کنم. سوال‌تان را بنویسید یا یکی از سوال‌های پرتکرار را انتخاب کنید.',
      fromBot: true,
    ),
  ];

  static const List<_Faq> _faqs = [
    _Faq(['ورود', 'لاگین', 'وارد', 'حساب', 'ایمیل', 'رمز'], 'چطور وارد حساب شوم؟', 'در صفحهٔ ورود، ایمیل و رمز عبوری را که هنگام ثبت‌نام ساخته‌اید وارد کنید. اگر رمز را فراموش کرده‌اید، گزینهٔ بازیابی رمز را انتخاب کنید.'),
    _Faq(['ثبت نام', 'ساخت حساب', 'اکانت جدید', 'حساب جدید'], 'چطور حساب جدید بسازم؟', 'در صفحهٔ ورود گزینهٔ ثبت‌نام را بزنید، ایمیل و رمز عبور معتبر وارد کنید و مراحل تأیید و تکمیل پروفایل را انجام دهید.'),
    _Faq(['پروفایل', 'عکس', 'نام کاربری', 'بیو', 'تصویر'], 'چطور پروفایلم را ویرایش کنم؟', 'از نوار پایین وارد پروفایل شوید. در آن‌جا می‌توانید اطلاعات قابل ویرایش مانند نام، نام کاربری، معرفی و عکس پروفایل را تغییر دهید.'),
    _Faq(['پیام', 'ارسال', 'چت', 'گفتگو', 'فرستادن'], 'چطور پیام بفرستم؟', 'وارد گفتگو شوید، متن را در کادر پایین بنویسید و دکمهٔ ارسال را بزنید. برای فرستادن عکس یا فایل از دکمهٔ پیوست استفاده کنید.'),
    _Faq(['گروه', 'مدیر', 'عضو', 'ادمین', 'مدیریت گروه'], 'چطور گروه بسازم یا اعضا را مدیریت کنم؟', 'از بخش گفت‌وگوها گزینهٔ گفت‌وگوی جدید یا ساخت گروه را انتخاب کنید. تنظیمات و دسترسی‌های مدیریت گروه از صفحهٔ اطلاعات همان گروه در دسترس است.'),
    _Faq(['اعلان', 'نوتیفیکیشن', 'خبر', 'صدا'], 'چرا اعلان پیام‌ها را دریافت نمی‌کنم؟', 'ابتدا مجوز اعلان گپ‌رسان را در تنظیمات گوشی بررسی کنید. سپس اتصال اینترنت و تنظیمات اعلان داخل برنامه را بررسی کرده و برنامه را یک‌بار دوباره باز کنید.'),
    _Faq(['زبان', 'دری', 'هزارگی', 'پشتو', 'فارسی', 'انگلیسی'], 'چطور زبان برنامه را تغییر بدهم؟', 'از تنظیمات برنامه وارد بخش زبان شوید و زبان مورد نظر را انتخاب کنید. اگر بخشی ترجمه نشده بود، برنامه را به‌روز کنید و آن مورد را به پشتیبانی گزارش دهید.'),
    _Faq(['قالب', 'تم', 'رنگ', 'تاریک', 'روشن', 'پس زمینه'], 'چطور قالب و پس‌زمینه را تغییر بدهم؟', 'از تنظیمات یا بخش ظاهر برنامه، قالب روشن، تاریک یا یکی از رنگ‌بندی‌های موجود را انتخاب کنید. برای پس‌زمینهٔ گفتگو نیز تنظیمات همان گفتگو را باز کنید.'),
    _Faq(['امنیت', 'حریم خصوصی', 'مسدود', 'بلاک', 'رمز'], 'چطور امنیت و حریم خصوصی را تنظیم کنم؟', 'از تنظیمات، بخش حریم خصوصی و امنیت را باز کنید. نمایش اطلاعات پروفایل، کاربران مسدودشده و گزینه‌های امنیتی را از همان‌جا بررسی کنید.'),
    _Faq(['مخاطب', 'مخاطبین', 'پیدا', 'جستجو'], 'چرا مخاطبین یا گفتگوهایم نمایش داده نمی‌شوند؟', 'اتصال اینترنت را بررسی و صفحه را تازه‌سازی کنید. اگر مشکل ادامه داشت، یک‌بار خارج و دوباره وارد حساب شوید. اگر باز هم حل نشد، نام کاربری و زمان بروز مشکل را برای پشتیبانی بفرستید.'),
    _Faq(['کند', 'سرعت', 'باز نمی', 'خطا', 'ارور', 'مشکل', 'هنگ', 'گیر'], 'اگر برنامه کند شد یا خطا داد چه کنم؟', 'اول اتصال اینترنت را بررسی کنید و یک‌بار همان صفحه را دوباره باز کنید. اگر فقط یک گفتگو مشکل دارد، از فهرست گفتگوها بیرون شوید و دوباره وارد شوید. اگر مشکل تکرار شد، از همین صفحه گزارش مشکل بفرستید و نام صفحه، زمان و متن خطا را بنویسید.'),
    _Faq(['اینترنت ضعیف', 'نت ضعیف', 'آفلاین', 'بدون اینترنت', 'قطع اینترنت', 'وصل نیست'], 'با اینترنت ضعیف یا بدون اینترنت چه کار کنم؟', 'اگر قبلاً گفتگو باز شده باشد، ممکن است بخشی از پیام‌های ذخیره‌شده روی همین دستگاه نمایش داده شود. پیام تازه تا وصل‌شدن اینترنت ارسال نمی‌شود؛ پس از وصل‌شدن دوباره تلاش کنید و وضعیت ارسال را بررسی کنید. برای جلوگیری از گم‌شدن پیام، متن مهم را تا تأیید ارسال نگه دارید.'),
    _Faq(['عکس ارسال', 'تصویر ارسال', 'ویدیو', 'فایل', 'پیوست', 'عکس نمی'], 'چطور عکس، ویدیو یا فایل بفرستم؟', 'گفتگوی مورد نظر را باز کنید و دکمهٔ پیوست کنار کادر نوشتن را بزنید. فایل را انتخاب کنید و تا پایان بارگذاری صفحه را نبندید. اگر ارسال متوقف شد، اندازهٔ فایل و اتصال اینترنت را بررسی کنید.'),
    _Faq(['حذف پیام', 'پاک کردن پیام', 'ویرایش پیام', 'پس گرفتن پیام'], 'چطور پیام را حذف یا ویرایش کنم؟', 'روی پیام مورد نظر چند لحظه نگه دارید تا گزینه‌های همان پیام نمایش داده شود. گزینهٔ حذف یا ویرایش را انتخاب کنید و متن تأیید را با دقت بخوانید؛ حذف ممکن است قابل برگشت نباشد.'),
    _Faq(['کانال', 'ساخت کانال', 'مدیر کانال', 'عضویت کانال'], 'چطور کانال بسازم یا مدیریت کنم؟', 'از بخش گفتگوی جدید، گزینهٔ ساخت کانال را انتخاب کنید. بعد از ساخت، صفحهٔ اطلاعات کانال را باز کنید تا نام، توضیحات، تصویر و دسترسی مدیران را بررسی کنید. گزینه‌هایی که در نسخهٔ فعلی برنامه نمایش داده نمی‌شوند هنوز قابل استفاده نیستند.'),
    _Faq(['نام کاربری', 'یوزرنیم', 'شناسه', 'منشن', 'تگ کردن'], 'چطور با نام کاربری یک نفر را پیدا کنم؟', 'نام کاربری را در جستجوی کاربران وارد کنید و نتیجه را با دقت بررسی کنید. پیش از ارسال پیام، تصویر و اطلاعات پروفایل را ببینید تا فرد اشتباهی را انتخاب نکنید.'),
    _Faq(['بلاک', 'مسدود کردن', 'رفع مسدودی', 'مزاحمت'], 'چطور یک کاربر را مسدود کنم؟', 'اگر گزینهٔ مسدودسازی در پروفایل یا منوی گفتگو موجود است، آن را انتخاب و تأیید کنید. برای رفع مسدودی، فهرست کاربران مسدودشده را در بخش حریم خصوصی بررسی کنید. اگر این گزینه را نمی‌بینید، از پشتیبانی گزارش بفرستید.'),
    _Faq(['گزارش کاربر', 'شکایت', 'تخلف', 'محتوای آزاردهنده'], 'چطور رفتار یا محتوای نامناسب را گزارش کنم؟', 'از گزینهٔ گزارش در پروفایل یا منوی مربوط استفاده کنید، اگر در دسترس باشد. شرح کوتاه و دقیق بنویسید و اطلاعات حساس یا رمز عبور را نفرستید. برای مشکل فنی هم دکمهٔ «ثبت گزارش مشکل» در همین صفحه را بزنید.'),
    _Faq(['حریم خصوصی', 'اطلاعات من', 'امنیت حساب', 'رمز عبور', 'تأیید دو مرحله'], 'چطور از امنیت حسابم محافظت کنم؟', 'رمز عبور یکتا و قوی انتخاب کنید و آن را با هیچ‌کس شریک نسازید. کد ورود و کد تأیید را برای هیچ فردی نفرستید. فقط از نسخهٔ رسمی برنامه استفاده کنید و در دستگاه مشترک، پس از پایان کار از حساب خارج شوید.'),
    _Faq(['تغییر رمز', 'رمز فراموش', 'بازیابی رمز', 'پسورد'], 'اگر رمز عبور را فراموش کردم چه کنم؟', 'در صفحهٔ ورود گزینهٔ بازیابی رمز را انتخاب کنید و ایمیل حساب خود را وارد کنید. صندوق ورودی و پوشهٔ هرزنامه را بررسی کنید. اگر ایمیل بازیابی نرسید، چند دقیقه صبر کنید و دوباره درخواست بدهید؛ رمز یا کد تأیید را برای کسی نفرستید.'),
    _Faq(['حساب پیدا نمی', 'اکانت پیدا نمی', 'پروفایل بالا نمی', 'مخاطب نیست', 'چت نیست', 'سابقه چت'], 'چرا حساب، مخاطب یا سابقهٔ گفتگو نمایش داده نمی‌شود؟', 'مطمئن شوید با همان ایمیلی وارد شده‌اید که قبلاً استفاده می‌کردید. اینترنت را بررسی و صفحه را تازه‌سازی کنید. اگر گفتگو هنوز پیدا نشد، از حساب خارج نشوید و داده‌های برنامه را پاک نکنید؛ گزارش بفرستید تا مشکل حساب و همگام‌سازی بررسی شود.'),
    _Faq(['عکس پروفایل', 'تصویر پروفایل', 'آواتار'], 'چرا عکس پروفایلم نمایش داده نمی‌شود؟', 'اتصال اینترنت را بررسی و صفحهٔ پروفایل را دوباره باز کنید. اگر عکس تازه بارگذاری کرده‌اید، کمی برای تکمیل بارگذاری صبر کنید. اگر همچنان نمایش داده نمی‌شود، از همین صفحه گزارش مشکل ثبت کنید.'),
    _Faq(['گپ‌رسان چیست', 'چه کار میکنی', 'کمک', 'راهنما', 'سلام', 'درود'], 'ربات پشتیبانی چه کمکی می‌کند؟', 'سلام! من راهنمای داخل گپ‌رسان هستم. دربارهٔ حساب، گفتگوها، پیام‌ها، گروه‌ها، کانال‌ها، زبان و امنیت راهنمایی می‌کنم. اگر پاسخ دقیق را ندانم، حدس نمی‌زنم؛ می‌توانی جزئیات مشکل را بنویسی یا گزارش پشتیبانی بفرستی.'),
    _Faq(['تماس صوتی', 'تماس تصویری', 'ویدیوکال', 'زنگ زدن', 'تماس'], 'چطور تماس صوتی یا تصویری بگیرم؟', 'اگر دکمهٔ تماس در صفحهٔ گفتگو برای حساب شما فعال باشد، از همان‌جا تماس را آغاز کنید و اجازهٔ میکروفون یا کمره را فقط در صورت نیاز بدهید. اگر دکمه را نمی‌بینید، ممکن است این قابلیت در نسخهٔ فعلی یا برای آن گفتگو فعال نباشد.'),
    _Faq(['پیام صوتی', 'ویس', 'صدا ضبط', 'ضبط صدا'], 'چطور پیام صوتی بفرستم؟', 'در صفحهٔ گفتگو، اگر دکمهٔ میکروفون فعال است آن را نگه دارید یا طبق راهنمای روی صفحه برای ضبط استفاده کنید. پیش از ارسال، مجوز میکروفون را بررسی کنید. اگر این دکمه وجود ندارد، قابلیت در نسخهٔ فعلی شما در دسترس نیست.'),
    _Faq(['خروج از حساب', 'لاگ اوت', 'بیرون شدن', 'خروج'], 'چطور از حساب خارج شوم؟', 'به تنظیمات حساب بروید و گزینهٔ خروج را انتخاب کنید. اگر گوشی مشترک است، پیش از خروج مطمئن شوید رمز و کد ورودتان در اختیار دیگران نیست. خروج از حساب نباید به‌معنای حذف حساب یا پیام‌های ذخیره‌شده روی سرور باشد.'),
    _Faq(['حذف حساب', 'بستن حساب', 'پاک کردن اکانت'], 'چطور حسابم را حذف کنم؟', 'حذف حساب یک کار حساس و احتمالاً برگشت‌ناپذیر است. فقط از گزینهٔ رسمی حذف حساب در تنظیمات، اگر موجود باشد، استفاده کنید و پیش از تأیید پیامدها را بخوانید. اگر چنین گزینه‌ای نمی‌بینید، از پشتیبانی درخواست راهنمایی کنید؛ خروج از حساب با حذف حساب فرق دارد.'),
    _Faq(['ذخیره عکس', 'دانلود عکس', 'ذخیره فایل', 'دانلود فایل'], 'چطور عکس یا فایل دریافتی را ذخیره کنم؟', 'روی فایل یا تصویر بازشده، گزینهٔ ذخیره یا دانلود را انتخاب کنید، اگر در آن صفحه وجود دارد. مجوزهای ذخیره‌سازی دستگاه و فضای خالی را بررسی کنید. فایل‌های موقت برنامه را با فایل‌های ذخیره‌شده در گالری اشتباه نگیرید.'),
    _Faq(['بی صدا', 'سایلنت', 'خاموش اعلان', 'اعلان گروه'], 'چطور اعلان یک گفتگو یا گروه را بی‌صدا کنم؟', 'صفحهٔ اطلاعات همان گفتگو یا گروه را باز کنید و اگر گزینهٔ بی‌صداکردن اعلان موجود است، مدت مورد نظر را انتخاب کنید. برای فعال‌کردن دوباره، به همان بخش برگردید و حالت بی‌صدا را لغو کنید.'),
    _Faq(['مدیر گروه', 'ادمین گروه', 'سطح دسترسی', 'اجازه اعضا'], 'چطور دسترسی مدیران و اعضای گروه را تنظیم کنم؟', 'از صفحهٔ اطلاعات گروه، بخش مدیران یا دسترسی‌ها را باز کنید، اگر برای شما به‌عنوان مدیر نمایش داده می‌شود. فقط دسترسی‌هایی را تغییر دهید که اختیار آن را دارید و پیش از حذف یا محروم‌کردن عضو، انتخاب را بررسی کنید.'),
    _Faq(['پیام نرسید', 'ارسال نشد', 'تیک نخورده', 'در انتظار ارسال'], 'چرا پیامم ارسال نمی‌شود؟', 'اتصال اینترنت را بررسی کنید و ببینید پیام وضعیت در انتظار ارسال یا خطا دارد. اگر اینترنت ضعیف است، برنامه را باز نگه دارید تا دوباره تلاش کند؛ از فرستادن چندبارهٔ یک پیام یکسان خودداری کنید. اگر مشکل ادامه داشت، زمان و وضعیت پیام را گزارش کنید.'),
    _Faq(['همگام سازی', 'چت قدیمی', 'پیام های قدیمی', 'تاریخچه'], 'چرا پیام‌های قدیمی من همگام نمی‌شوند؟', 'با همان حساب قبلی وارد شوید و اتصال اینترنت را پایدار کنید. برنامه را به‌روز کنید و برای رفع مشکل، داده‌های برنامه را پاک نکنید؛ این کار ممکن است نسخهٔ محلی گفتگوها را از بین ببرد. اگر سابقه همچنان نیست، گزارش حساب و زمان آخرین مشاهده را ثبت کنید.'),
    _Faq(['تغییر زبان', 'زبان هزارگی', 'دری افغانستان', 'زبان پشتو'], 'اگر زبان انتخاب‌شده درست ترجمه نشده باشد چه کنم؟', 'از تنظیمات زبان مورد نظر را دوباره انتخاب کنید و برنامه را باز و بسته کنید. اگر بخشی هنوز به زبان قبلی است، نام همان صفحه و عبارت نمایش‌داده‌شده را در گزارش بنویسید تا ترجمهٔ همان بخش بررسی شود.'),
    _Faq(['ربات جواب نمی دهد', 'پاسخ اشتباه', 'جواب نامربوط', 'سوال را نمی فهمد'], 'اگر ربات پاسخ نامربوط داد چه کنم؟', 'لطفاً پرسش را کوتاه‌تر و با نام دقیق بخش برنامه بنویسید. این راهنمای فعلی از پاسخ‌های داخلی استفاده می‌کند و هنوز مدل هوش مصنوعی آنلاین نیست؛ بنابراین به همهٔ پرسش‌های عمومی پاسخ نمی‌دهد. پاسخ نادرست را هم می‌توانید گزارش کنید.'),
    _Faq(['تشکر', 'ممنون', 'سپاس', 'مرسی'], 'خواهش می‌کنم!', 'خوشحال شدم کمک کردم. اگر هنوز مشکلی مانده، همان بخش را نام ببر تا دقیق‌تر راهنمایی‌ات کنم.'),
  ];

  @override
  void initState() {
    super.initState();
    _reportsFuture = _loadReports();
  }

  Future<List<Map<String, dynamic>>> _loadReports() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const [];
    final rows = await Supabase.instance.client.from('support_reports')
        .select('id, category, description, status, created_at')
        .eq('reporter_id', user.id).order('created_at', ascending: false).limit(20);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _openReportDialog() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برای ثبت گزارش، ابتدا وارد حساب شوید.')));
      return;
    }
    final details = TextEditingController();
    var category = 'technical';
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('گزارش مشکل'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: category, isExpanded: true,
              decoration: const InputDecoration(labelText: 'نوع مشکل'),
              items: const [
                DropdownMenuItem(value: 'technical', child: Text('خطا یا مشکل فنی')),
                DropdownMenuItem(value: 'login', child: Text('ورود و حساب کاربری')),
                DropdownMenuItem(value: 'messages', child: Text('پیام‌ها و گفتگوها')),
                DropdownMenuItem(value: 'groups', child: Text('گروه‌ها و کانال‌ها')),
                DropdownMenuItem(value: 'profile', child: Text('پروفایل و تصویر')),
                DropdownMenuItem(value: 'other', child: Text('سایر موارد')),
              ],
              onChanged: (value) => setDialogState(() => category = value ?? 'technical'),
            ),
            const SizedBox(height: 12),
            TextField(controller: details, onChanged: (_) => setDialogState(() {}), minLines: 3, maxLines: 6, maxLength: 1200,
              decoration: const InputDecoration(labelText: 'شرح مشکل', hintText: 'چه کاری انجام می‌دادید و چه خطایی دیدید؟', alignLabelWithHint: true, border: OutlineInputBorder())),
            const Text('لطفاً رمز عبور، کد ورود، متن پیام‌های خصوصی یا توکن‌ها را ننویسید.', style: TextStyle(fontSize: 12)),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
            FilledButton(onPressed: details.text.trim().length < 8 ? null : () => Navigator.pop(dialogContext, true), child: const Text('ثبت گزارش')),
          ],
        ),
      ),
    );
    if (submitted != true) { details.dispose(); return; }
    final description = details.text.trim();
    details.dispose();
    if (!mounted) return;
    setState(() => _sendingReport = true);
    try {
      await Supabase.instance.client.from('support_reports').insert({
        'reporter_id': user.id, 'category': category, 'description': description,
      });
      if (!mounted) return;
      setState(() { _reportsFuture = _loadReports(); });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('گزارش شما با موفقیت ثبت شد.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ثبت گزارش انجام نشد. اتصال اینترنت را بررسی و دوباره تلاش کنید.')));
    } finally {
      if (mounted) setState(() => _sendingReport = false);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open': return 'در انتظار بررسی';
      case 'in_progress': return 'در حال پیگیری';
      case 'resolved': return 'رسیدگی شد';
      case 'closed': return 'بسته شد';
      default: return 'ثبت‌شده';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('ي', 'ی')
      .replaceAll('ى', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u200C\u200D]'), '')
      .replaceAll(RegExp(r'[؟?!.,،؛:ـ()\[\]{}"“”«»]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Set<String> _tokens(String value) {
    const ignored = {'از', 'به', 'را', 'در', 'که', 'و', 'یا', 'برای', 'چطور', 'چگونه', 'چی', 'چه', 'من', 'می', 'شود', 'است', 'یک'};
    return _normalize(value).split(' ').where((word) => word.length > 1 && !ignored.contains(word)).toSet();
  }

  int _similarityScore(String question, _Faq faq) {
    final normalizedQuestion = _normalize(question);
    final questionTokens = _tokens(normalizedQuestion);
    if (normalizedQuestion.isEmpty || questionTokens.isEmpty) return 0;

    // Prefer a specific multi-word phrase over a generic single word.
    var bestPhraseScore = 0;
    var tokenScore = 0;
    for (final keyword in faq.keywords) {
      final phrase = _normalize(keyword);
      if (phrase.isEmpty) continue;
      if (normalizedQuestion == phrase) {
        bestPhraseScore = bestPhraseScore < 14 ? 14 : bestPhraseScore;
      } else if (phrase.length >= 4 && normalizedQuestion.contains(phrase)) {
        final phraseScore = phrase.contains(' ') ? 9 : 4;
        if (phraseScore > bestPhraseScore) bestPhraseScore = phraseScore;
      }
      final keywordTokens = _tokens(phrase);
      if (keywordTokens.isNotEmpty) {
        final overlap = keywordTokens.intersection(questionTokens).length;
        if (overlap > 0) tokenScore += overlap * (keywordTokens.length > 1 ? 3 : 2);
      }
    }
    // Cap token contribution so duplicated synonyms cannot dominate ranking.
    return bestPhraseScore + (tokenScore > 8 ? 8 : tokenScore);
  }

  String _answerFor(String question) {
    final normalized = _normalize(question);
    final followUp = RegExp(r'^(بیشتر|توضیح بیشتر|واضح تر|مثال|چطور دقیق|مرحله به مرحله|حل نشد|درست نشد|باز هم|هنوز مشکل|همین مشکل)').hasMatch(normalized);
    if (followUp && _lastMatchedFaq != null) {
      final previous = _lastMatchedFaq!;
      if (RegExp(r'^(حل نشد|درست نشد|باز هم|هنوز مشکل)').hasMatch(normalized)) {
        return 'متوجه شدم؛ مشکل «${previous.question}» هنوز حل نشده است. لطفاً این سه مورد را بنویس: ۱) در کدام صفحه هستی؟ ۲) دقیقاً چه کاری انجام می‌دهی؟ ۳) چه پیام خطایی می‌بینی؟ اگر خطا نداری، بنویس بعد از زدن کدام دکمه چه اتفاقی می‌افتد. برای پیگیری هم می‌توانی گزارش مشکل ثبت کنی.';
      }
      return 'دربارهٔ «${previous.question}» قدم‌به‌قدم: ${previous.answer}\n\nاگر این مراحل با صفحه‌ای که می‌بینی فرق دارد، نام دکمه یا گزینه‌ای را که پیدا نمی‌کنی بنویس تا راهنمایی دقیق‌تری بدهم.';
    }

    final ranked = _faqs
        .map((faq) => (faq: faq, score: _similarityScore(question, faq)))
        .where((item) => item.score > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    if (ranked.isEmpty || ranked.first.score < 4) {
      _lastMatchedFaq = null;
      return 'برای این پرسش هنوز پاسخ مطمئنی پیدا نکردم و نمی‌خواهم حدس نادرست بزنم. لطفاً نام بخشی را که درباره‌اش پرسش داری و کاری را که انجام می‌دادی بنویس. اگر خطا می‌بینی، متن خطا را هم اضافه کن. برای پیگیری مستقیم، دکمهٔ «ثبت گزارش مشکل» در همین صفحه را بزن.';
    }
    if (ranked.length > 1 && ranked.first.score - ranked[1].score < 2) {
      _lastMatchedFaq = null;
      return 'پرسشت می‌تواند به چند بخش مربوط باشد. لطفاً مشخص کن منظورت کدام است: حساب و ورود، پیام و گفتگو، گروه و کانال، یا تنظیمات و امنیت؟';
    }
    _lastMatchedFaq = ranked.first.faq;
    return ranked.first.faq.answer;
  }

  void _ask([String? value]) {
    final question = (value ?? _controller.text).trim();
    if (question.isEmpty) return;
    _controller.clear();
    final answer = _answerFor(question);

    setState(() {
      _messages.add(_BotMessage(text: question, fromBot: false));
      _messages.add(_BotMessage(text: answer, fromBot: true));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          CircleAvatar(radius: 17, child: Icon(Icons.smart_toy_rounded, size: 20)),
          SizedBox(width: 10),
          Text('ربات پشتیبانی'),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            children: [
              Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(backgroundColor: scheme.primaryContainer, child: Icon(Icons.support_agent_rounded, color: scheme.primary)),
                  const SizedBox(width: 10),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('مرکز پشتیبانی', style: TextStyle(fontWeight: FontWeight.w900)),
                    Text('مشکل را گزارش کنید و وضعیت پیگیری را ببینید.', style: TextStyle(fontSize: 12)),
                  ])),
                ]),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: FilledButton.icon(
                  onPressed: _sendingReport ? null : _openReportDialog,
                  icon: _sendingReport ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.bug_report_outlined),
                  label: const Text('ثبت گزارش مشکل'),
                )),
                const SizedBox(height: 10),
                Row(children: [
                  const Expanded(child: Text('گزارش‌های قبلی', style: TextStyle(fontWeight: FontWeight.w800))),
                  IconButton(tooltip: 'تازه‌سازی', onPressed: () => setState(() { _reportsFuture = _loadReports(); }), icon: const Icon(Icons.refresh_rounded)),
                ]),
                FutureBuilder<List<Map<String, dynamic>>>(future: _reportsFuture, builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                  if (snapshot.hasError) return const Text('بارگذاری گزارش‌ها ناموفق بود.');
                  final reports = snapshot.data ?? const [];
                  if (reports.isEmpty) return const Text('هنوز گزارشی ثبت نکرده‌اید.', style: TextStyle(fontSize: 12));
                  return Column(children: reports.map((report) => ListTile(
                    contentPadding: EdgeInsets.zero, dense: true,
                    leading: Icon(Icons.assignment_outlined, color: scheme.primary),
                    title: Text(_statusLabel('${report['status'] ?? 'open'}'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${report['category'] ?? 'other'} · ${report['description'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  )).toList());
                }),
              ]))),
              const SizedBox(height: 12),
              ..._messages.map((message) => Align(
                alignment: message.fromBot ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 330),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: message.fromBot ? scheme.surfaceContainerHighest : scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(message.text, style: TextStyle(
                    color: message.fromBot ? scheme.onSurface : scheme.onPrimaryContainer,
                    height: 1.45,
                  )),
                ),
              )),
              const SizedBox(height: 8),
              Text('سوال‌های پرتکرار', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => setState(() => _faqSearch = value),
                decoration: InputDecoration(
                  hintText: 'جستجو در راهنما…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _faqSearch.isEmpty ? null : IconButton(
                    tooltip: 'پاک‌کردن جستجو',
                    onPressed: () => setState(() => _faqSearch = ''),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              ..._faqs.where((faq) => _faqSearch.trim().isEmpty ||
                  _normalize('${faq.question} ${faq.keywords.join(' ')}').contains(_normalize(_faqSearch)) ||
                  _tokens(_faqSearch).intersection(_tokens('${faq.question} ${faq.keywords.join(' ')}')).isNotEmpty).map((faq) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.help_outline_rounded, color: scheme.primary),
                  title: Text(faq.question, style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => _ask(faq.question),
                ),
              )),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _ask(),
                decoration: const InputDecoration(
                  hintText: 'سوال خود را بنویسید…',
                  prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(22))),
                  isDense: true,
                ),
              )),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'ارسال سوال',
                onPressed: _ask,
                icon: const Icon(Icons.send_rounded),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _BotMessage {
  final String text;
  final bool fromBot;
  const _BotMessage({required this.text, required this.fromBot});
}

class _Faq {
  final List<String> keywords;
  final String question;
  final String answer;
  const _Faq(this.keywords, this.question, this.answer);
}
