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
    _Faq(['کند', 'سرعت', 'باز نمی', 'خطا', 'ارور', 'مشکل'], 'اگر برنامه کند شد یا خطا داد چه کنم؟', 'اتصال اینترنت را بررسی کنید، برنامه را ببندید و دوباره باز کنید. اگر خطا ادامه داشت، متن یا تصویر خطا و صفحه‌ای را که در آن رخ داده برای پشتیبانی ارسال کنید.'),
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
              value: category, isExpanded: true,
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
            TextField(controller: details, minLines: 3, maxLines: 6, maxLength: 1200,
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
      .replaceAll('ك', 'ک')
      .replaceAll(RegExp(r'[؟?!.,،؛:ـ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  void _ask([String? value]) {
    final question = (value ?? _controller.text).trim();
    if (question.isEmpty) return;
    _controller.clear();
    final normalized = _normalize(question);
    _Faq? best;
    var bestScore = 0;
    for (final faq in _faqs) {
      final score = faq.keywords.where((word) => normalized.contains(_normalize(word))).length;
      if (score > bestScore) {
        best = faq;
        bestScore = score;
      }
    }
    final answer = bestScore == 0
        ? 'برای این سوال هنوز پاسخ آماده‌ای پیدا نکردم. لطفاً سوال را با کلمات دیگری بنویسید یا از سوال‌های پرتکرار پایین کمک بگیرید. برای پیگیری انسانی، از بخش تماس با پشتیبانی در تنظیمات برنامه استفاده کنید.'
        : best!.answer;
    setState(() {
      _messages.add(_BotMessage(text: question, fromBot: false));
      _messages.add(_BotMessage(text: answer, fromBot: true));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
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
              ..._faqs.take(8).map((faq) => Card(
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
