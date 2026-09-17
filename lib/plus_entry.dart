import 'package:flutter/material.dart';
import 'advanced_features_v2.dart';

class PlusEntryButton extends StatelessWidget {
  const PlusEntryButton({super.key});
  @override Widget build(BuildContext context)=>ListTile(leading:const Icon(Icons.auto_awesome),title:const Text('قابلیت‌های کامل پیام‌رسان'),subtitle:const Text('همه امکانات بجز کیف پول'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const MessengerPlusPage())));
}
