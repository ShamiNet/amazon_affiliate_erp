// ============================================================================
// منظومة إدارة أمازون أفلييت والحملات الإعلانية - تطبيق سطح المكتب (Windows)
// Amazon Affiliate & Ad Campaigns ERP - Professional Flutter Windows App
// ============================================================================
// طريقة التشغيل على ويندوز (How to Run on Windows):
// 1. أنشئ مشروع فلاتر جديد يدعم ويندوز:
//    flutter create --platforms=windows amazon_affiliate_erp
// 2. استبدل محتوى الملف lib/main.dart بهذا الكود بالكامل.
// 3. شغّل التطبيق مباشرة على ويندوز:
//    flutter run -d windows
// 4. أو استخرج نسخة تنفيذية نهائية (.exe):
//    flutter build windows --release
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'campaign_report_mapper.dart';
import 'report_backend_launcher.dart';
import 'report_image_import_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(ReportBackendLauncher.instance.start());
  AppLifecycleListener(
    onExitRequested: () async {
      ReportBackendLauncher.instance.stop();
      return AppExitResponse.exit;
    },
    onDetach: ReportBackendLauncher.instance.stop,
  );
  runApp(const AmazonAffiliateWindowsApp());
}

// ============================================================================
// 1. نماذج البيانات (Data Models)
// ============================================================================

class BeneficiaryModel {
  int id;
  String name;
  double baseCapital;
  String accountCodeRange;

  BeneficiaryModel({
    required this.id,
    required this.name,
    required this.baseCapital,
    required this.accountCodeRange,
  });

  factory BeneficiaryModel.fromJson(Map<String, dynamic> j) => BeneficiaryModel(
        id: (j['id'] ?? 0) as int,
        name: (j['name'] ?? '').toString(),
        baseCapital: ((j['baseCapital'] ?? 0) as num).toDouble(),
        accountCodeRange: (j['accountCodeRange'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseCapital': baseCapital,
        'accountCodeRange': accountCodeRange,
      };
}

class ProductCatalogModel {
  int id;
  String product;
  String beneficiary;
  String accountCode;
  String profile;
  double capital;
  String email;
  String password;
  String adUrl;

  ProductCatalogModel({
    required this.id,
    required this.product,
    required this.beneficiary,
    required this.accountCode,
    required this.profile,
    required this.capital,
    required this.email,
    required this.password,
    required this.adUrl,
  });

  factory ProductCatalogModel.fromJson(Map<String, dynamic> j) =>
      ProductCatalogModel(
        id: (j['id'] ?? 0) as int,
        product: (j['product'] ?? '').toString(),
        beneficiary: (j['beneficiary'] ?? '').toString(),
        accountCode: (j['accountCode'] ?? '').toString(),
        profile: (j['profile'] ?? '').toString(),
        capital: ((j['capital'] ?? 0) as num).toDouble(),
        email: (j['email'] ?? '').toString(),
        password: (j['password'] ?? '').toString(),
        adUrl: (j['adUrl'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'product': product,
        'beneficiary': beneficiary,
        'accountCode': accountCode,
        'profile': profile,
        'capital': capital,
        'email': email,
        'password': password,
        'adUrl': adUrl,
      };
}

class CampaignLogModel {
  int seq;
  String date;
  String beneficiary;
  String accountCode;
  String product;
  String email;
  double cost;
  String profile;
  String password;
  int clicks;
  int orderedItems;
  double orderedRevenue;
  int shippedItems;
  int returnedItems;
  double totalRevenue;
  double commission;
  double bonus;
  bool isPending;
  String adUrl;

  CampaignLogModel({
    required this.seq,
    required this.date,
    required this.beneficiary,
    required this.accountCode,
    required this.product,
    required this.email,
    required this.cost,
    required this.profile,
    required this.password,
    required this.clicks,
    required this.orderedItems,
    required this.orderedRevenue,
    required this.shippedItems,
    required this.returnedItems,
    required this.totalRevenue,
    required this.commission,
    required this.bonus,
    required this.isPending,
    required this.adUrl,
  });

  // المعادلات المحاسبية الديناميكية المطابقة لملف الإكسل
  double get conversionRate => clicks > 0 ? orderedItems / clicks : 0.0;
  double get totalEarnings => isPending ? 0.0 : (commission + bonus);
  double get netProfit => isPending ? 0.0 : (totalEarnings - cost);
  double? get roi => (isPending || cost <= 0) ? null : (netProfit / cost);

  String get smartRecommendation {
    if (isPending) {
      return '⏳ بانتظار النتائج (قيد التشغيل)';
    }
    final crPrefix = conversionRate > 0
        ? 'CR: ${(conversionRate * 100).toStringAsFixed(1)}% | '
        : '';
    if (netProfit > 0) {
      if (cost == 0 || (roi != null && roi! >= 0.5)) {
        return '${crPrefix}🚀 كرر الحملة وضاعف الميزانية';
      }
      return '${crPrefix}✅ رابحة - استمر بتكرارها';
    } else if (netProfit == 0) {
      if (cost == 0) {
        return '${crPrefix}⚪ حملة مجانية / تجريبية';
      }
      return '${crPrefix}⚖️ تعادل - راقب قبل التكرار';
    } else {
      final r = roi ?? -1.0;
      if (r <= -0.8) {
        return '${crPrefix}🛑 إيقاف الحملة فوراً (خسارة مرتفعة)';
      } else if (r <= -0.4) {
        return '${crPrefix}🔧 تعديل الحملة (الاستهداف/الإعلان)';
      }
      return '${crPrefix}⚠️ تعديل طفيف لتحسين العائد';
    }
  }

  factory CampaignLogModel.fromJson(Map<String, dynamic> j) => CampaignLogModel(
        seq: (j['seq'] ?? 0) as int,
        date: (j['date'] ?? '').toString(),
        beneficiary: (j['beneficiary'] ?? '').toString(),
        accountCode: (j['accountCode'] ?? '').toString(),
        product: (j['product'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        cost: ((j['cost'] ?? 0) as num).toDouble(),
        profile: (j['profile'] ?? '').toString(),
        password: (j['password'] ?? '').toString(),
        clicks: ((j['clicks'] ?? 0) as num).toInt(),
        orderedItems: ((j['orderedItems'] ?? 0) as num).toInt(),
        orderedRevenue: ((j['orderedRevenue'] ?? 0) as num).toDouble(),
        shippedItems: ((j['shippedItems'] ?? 0) as num).toInt(),
        returnedItems: ((j['returnedItems'] ?? 0) as num).toInt(),
        totalRevenue: ((j['totalRevenue'] ?? 0) as num).toDouble(),
        commission: ((j['commission'] ?? 0) as num).toDouble(),
        bonus: ((j['bonus'] ?? 0) as num).toDouble(),
        isPending: (j['isPending'] ?? false) as bool,
        adUrl: (j['adUrl'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'seq': seq,
        'date': date,
        'beneficiary': beneficiary,
        'accountCode': accountCode,
        'product': product,
        'email': email,
        'cost': cost,
        'profile': profile,
        'password': password,
        'clicks': clicks,
        'orderedItems': orderedItems,
        'orderedRevenue': orderedRevenue,
        'shippedItems': shippedItems,
        'returnedItems': returnedItems,
        'totalRevenue': totalRevenue,
        'commission': commission,
        'bonus': bonus,
        'isPending': isPending,
        'adUrl': adUrl,
      };
}

class AmazonAccountModel {
  String beneficiary;
  String code;
  String name;
  String storeId;
  String country;
  String status;
  String product1;
  String promoStatus1;
  String tweetUrl1;
  String product2;
  String promoStatus2;
  String tweetUrl2;
  String affiliateUrl1;
  String affiliateUrl2;
  String adsterraUrl;
  String email;
  String password;
  String linkage;
  String notes;

  AmazonAccountModel({
    required this.beneficiary,
    required this.code,
    required this.name,
    required this.storeId,
    required this.country,
    required this.status,
    required this.product1,
    required this.promoStatus1,
    required this.tweetUrl1,
    required this.product2,
    required this.promoStatus2,
    required this.tweetUrl2,
    required this.affiliateUrl1,
    required this.affiliateUrl2,
    required this.adsterraUrl,
    required this.email,
    required this.password,
    required this.linkage,
    required this.notes,
  });

  bool get isArchivedOrBanned =>
      status.contains('محظور') ||
      promoStatus1.contains('ملغى') ||
      promoStatus2.contains('ملغى') ||
      promoStatus2.contains('إيقاف');

  factory AmazonAccountModel.fromJson(Map<String, dynamic> j) =>
      AmazonAccountModel(
        beneficiary: (j['beneficiary'] ?? '').toString(),
        code: (j['code'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        storeId: (j['storeId'] ?? '').toString(),
        country: (j['country'] ?? '').toString(),
        status: (j['status'] ?? 'نشط').toString(),
        product1: (j['product1'] ?? '').toString(),
        promoStatus1: (j['promoStatus1'] ?? '').toString(),
        tweetUrl1: (j['tweetUrl1'] ?? '').toString(),
        product2: (j['product2'] ?? '').toString(),
        promoStatus2: (j['promoStatus2'] ?? '').toString(),
        tweetUrl2: (j['tweetUrl2'] ?? '').toString(),
        affiliateUrl1: (j['affiliateUrl1'] ?? '').toString(),
        affiliateUrl2: (j['affiliateUrl2'] ?? '').toString(),
        adsterraUrl: (j['adsterraUrl'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        password: (j['password'] ?? '').toString(),
        linkage: (j['linkage'] ?? '').toString(),
        notes: (j['notes'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'beneficiary': beneficiary,
        'code': code,
        'name': name,
        'storeId': storeId,
        'country': country,
        'status': status,
        'product1': product1,
        'promoStatus1': promoStatus1,
        'tweetUrl1': tweetUrl1,
        'product2': product2,
        'promoStatus2': promoStatus2,
        'tweetUrl2': tweetUrl2,
        'affiliateUrl1': affiliateUrl1,
        'affiliateUrl2': affiliateUrl2,
        'adsterraUrl': adsterraUrl,
        'email': email,
        'password': password,
        'linkage': linkage,
        'notes': notes,
      };
}

class HistoricalLinkModel {
  String beneficiary;
  String accountName;
  String product;
  String linkType;
  String url;
  String notes;

  HistoricalLinkModel({
    required this.beneficiary,
    required this.accountName,
    required this.product,
    required this.linkType,
    required this.url,
    required this.notes,
  });

  factory HistoricalLinkModel.fromJson(Map<String, dynamic> j) =>
      HistoricalLinkModel(
        beneficiary: (j['beneficiary'] ?? '').toString(),
        accountName: (j['accountName'] ?? '').toString(),
        product: (j['product'] ?? '').toString(),
        linkType: (j['linkType'] ?? '').toString(),
        url: (j['url'] ?? '').toString(),
        notes: (j['notes'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'beneficiary': beneficiary,
        'accountName': accountName,
        'product': product,
        'linkType': linkType,
        'url': url,
        'notes': notes,
      };
}

class EmailAccountModel {
  String email;
  String password;
  String gologin;
  String recovery;
  String twoFa;
  String status;
  String notes;
  String country;
  String phone;

  EmailAccountModel({
    required this.email,
    required this.password,
    required this.gologin,
    required this.recovery,
    required this.twoFa,
    required this.status,
    required this.notes,
    required this.country,
    required this.phone,
  });

  factory EmailAccountModel.fromJson(Map<String, dynamic> j) =>
      EmailAccountModel(
        email: (j['email'] ?? '').toString(),
        password: (j['password'] ?? '').toString(),
        gologin: (j['gologin'] ?? '').toString(),
        recovery: (j['recovery'] ?? '').toString(),
        twoFa: (j['twoFa'] ?? '').toString(),
        status: (j['status'] ?? 'غير محدد').toString(),
        notes: (j['notes'] ?? '').toString(),
        country: (j['country'] ?? '').toString(),
        phone: (j['phone'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'gologin': gologin,
        'recovery': recovery,
        'twoFa': twoFa,
        'status': status,
        'notes': notes,
        'country': country,
        'phone': phone,
      };
}

class GoLoginAccountModel {
  String accountType;
  String platform;
  String email;
  String password;
  String profile1;
  String profile2;
  String profile3;
  String notes;
  String country;

  GoLoginAccountModel({
    required this.accountType,
    required this.platform,
    required this.email,
    required this.password,
    required this.profile1,
    required this.profile2,
    required this.profile3,
    required this.notes,
    required this.country,
  });

  int get registeredProfilesCount =>
      [profile1, profile2, profile3].where((p) => p.trim().isNotEmpty).length;

  factory GoLoginAccountModel.fromJson(Map<String, dynamic> j) =>
      GoLoginAccountModel(
        accountType: (j['accountType'] ?? '').toString(),
        platform: (j['platform'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        password: (j['password'] ?? '').toString(),
        profile1: (j['profile1'] ?? '').toString(),
        profile2: (j['profile2'] ?? '').toString(),
        profile3: (j['profile3'] ?? '').toString(),
        notes: (j['notes'] ?? '').toString(),
        country: (j['country'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'accountType': accountType,
        'platform': platform,
        'email': email,
        'password': password,
        'profile1': profile1,
        'profile2': profile2,
        'profile3': profile3,
        'notes': notes,
        'country': country,
      };
}

class ProxyModel {
  String country;
  bool isUsed;
  String portType;
  String protocol;
  String username;
  String password;
  String host;
  int port;

  ProxyModel({
    required this.country,
    required this.isUsed,
    required this.portType,
    required this.protocol,
    required this.username,
    required this.password,
    required this.host,
    required this.port,
  });

  String get fullProxyString => '$username:$password@$host:$port';

  factory ProxyModel.fromJson(Map<String, dynamic> j) => ProxyModel(
        country: (j['country'] ?? '').toString(),
        isUsed: (j['isUsed'] ?? false) as bool,
        portType: (j['portType'] ?? 'ثابت').toString(),
        protocol: (j['protocol'] ?? 'http').toString(),
        username: (j['username'] ?? '').toString(),
        password: (j['password'] ?? '').toString(),
        host: (j['host'] ?? '').toString(),
        port: ((j['port'] ?? 0) as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'country': country,
        'isUsed': isUsed,
        'portType': portType,
        'protocol': protocol,
        'username': username,
        'password': password,
        'host': host,
        'port': port,
      };
}

class BankAccountModel {
  String iban;
  String beneficiaryName;
  String bic;
  String bankName;
  String bankAddress;
  String postalAndCountry;
  String status;
  String verificationDoc;
  String amazonEmail;
  String amazonAccountName;

  BankAccountModel({
    required this.iban,
    required this.beneficiaryName,
    required this.bic,
    required this.bankName,
    required this.bankAddress,
    required this.postalAndCountry,
    required this.status,
    required this.verificationDoc,
    required this.amazonEmail,
    required this.amazonAccountName,
  });

  bool get isLinked => status.contains('تم الربط');

  factory BankAccountModel.fromJson(Map<String, dynamic> j) => BankAccountModel(
        iban: (j['iban'] ?? '').toString(),
        beneficiaryName: (j['beneficiaryName'] ?? '').toString(),
        bic: (j['bic'] ?? '').toString(),
        bankName: (j['bankName'] ?? '').toString(),
        bankAddress: (j['bankAddress'] ?? '').toString(),
        postalAndCountry: (j['postalAndCountry'] ?? '').toString(),
        status: (j['status'] ?? 'جاهز للربط').toString(),
        verificationDoc: (j['verificationDoc'] ?? '').toString(),
        amazonEmail: (j['amazonEmail'] ?? '').toString(),
        amazonAccountName: (j['amazonAccountName'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'iban': iban,
        'beneficiaryName': beneficiaryName,
        'bic': bic,
        'bankName': bankName,
        'bankAddress': bankAddress,
        'postalAndCountry': postalAndCountry,
        'status': status,
        'verificationDoc': verificationDoc,
        'amazonEmail': amazonEmail,
        'amazonAccountName': amazonAccountName,
      };
}

class PlatformAccountModel {
  String category;
  String name;
  String usernameOrEmail;
  String password;
  String notes;
  String url;

  PlatformAccountModel({
    required this.category,
    required this.name,
    required this.usernameOrEmail,
    required this.password,
    required this.notes,
    required this.url,
  });

  factory PlatformAccountModel.fromJson(Map<String, dynamic> j) =>
      PlatformAccountModel(
        category: (j['category'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        usernameOrEmail: (j['usernameOrEmail'] ?? '').toString(),
        password: (j['password'] ?? '').toString(),
        notes: (j['notes'] ?? '').toString(),
        url: (j['url'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'category': category,
        'name': name,
        'usernameOrEmail': usernameOrEmail,
        'password': password,
        'notes': notes,
        'url': url,
      };
}

class PromoTimeWindowModel {
  String windowName;
  String syriaTime;
  String usTime;

  PromoTimeWindowModel({
    required this.windowName,
    required this.syriaTime,
    required this.usTime,
  });

  factory PromoTimeWindowModel.fromJson(Map<String, dynamic> j) =>
      PromoTimeWindowModel(
        windowName: (j['windowName'] ?? '').toString(),
        syriaTime: (j['syriaTime'] ?? '').toString(),
        usTime: (j['usTime'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'windowName': windowName,
        'syriaTime': syriaTime,
        'usTime': usTime,
      };
}

class WorkflowStepModel {
  int stepNumber;
  String title;
  String details;
  String stage;
  bool isCompleted;
  String notes;

  WorkflowStepModel({
    required this.stepNumber,
    required this.title,
    required this.details,
    required this.stage,
    required this.isCompleted,
    required this.notes,
  });

  factory WorkflowStepModel.fromJson(Map<String, dynamic> j) =>
      WorkflowStepModel(
        stepNumber: ((j['stepNumber'] ?? 0) as num).toInt(),
        title: (j['title'] ?? '').toString(),
        details: (j['details'] ?? '').toString(),
        stage: (j['stage'] ?? '').toString(),
        isCompleted: (j['isCompleted'] ?? false) as bool,
        notes: (j['notes'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'stepNumber': stepNumber,
        'title': title,
        'details': details,
        'stage': stage,
        'isCompleted': isCompleted,
        'notes': notes,
      };
}

// ============================================================================
// 2. البيانات الأولية المستخرجة بالكامل من ملف الإكسل (Initial Seed Data)
// ============================================================================

const String kInitialSeedJson = r'''
{
  "emails": [
    {"email": "josheprichad2555@gmail.com", "password": "..Sdf123..", "gologin": "josheprichad2555", "recovery": "shami313p@gmail.com", "twoFa": "", "status": "يعمل", "notes": "", "country": "فرنسي", "phone": ""},
    {"email": "alasuf600@gmail.com", "password": "alasef10", "gologin": "josheprichad2555", "recovery": "shami313p@gmail.com", "twoFa": "", "status": "يعمل", "notes": "تم ربطه برقم وهمي بولندي", "country": "فرنسي", "phone": ""},
    {"email": "aboaboah43@gmail.com", "password": "qqwwee123z", "gologin": "josheprichad2555", "recovery": "shami313p@gmail.com", "twoFa": "", "status": "يعمل", "notes": "من ابو جنادى", "country": "فرنسي", "phone": ""},
    {"email": "abw225275@gmail.com", "password": "as1234as", "gologin": "wp988015", "recovery": "shami313p@gmail.com", "twoFa": "", "status": "يعمل", "notes": "", "country": "المانيا", "phone": ""},
    {"email": "asefabwasad@gmail.com", "password": "alasef11", "gologin": "wp988015", "recovery": "shami313p@gmail.com", "twoFa": "", "status": "يعمل", "notes": "تم ربطه برقم وهمي بولندي", "country": "المانيا", "phone": "48721619166"},
    {"email": "alasuf700@gmail.com", "password": "alasef11", "gologin": "awetorop09", "recovery": "shami313p@gmail.com", "twoFa": "", "status": "يعمل", "notes": "تم ربطه برقم وهمي بولندي", "country": "امريكا", "phone": "48729665939"},
    {"email": "alasuf200@gmail.com", "password": "alasef10", "gologin": "awetorop09", "recovery": "shami313p@gmail.com", "twoFa": "", "status": "يعمل", "notes": "تم ربطه برقم وهمي بولندي", "country": "المانيا", "phone": "48739573841"},
    {"email": "abwasadsyd123@gmail.com", "password": "alasef11", "gologin": "awetorop09", "recovery": "shami313p@gmail.com", "twoFa": "", "status": "يعمل", "notes": "تم ربطه برقم وهمي Thailand", "country": "امريكا", "phone": "66838408751"},
    {"email": "505gacim505@gmail.com", "password": "(+505gacim505+)", "gologin": "wp988015", "recovery": "ابو خليل", "twoFa": "", "status": "يعمل", "notes": "جديد", "country": "المانيا", "phone": "رقمه السوري"},
    {"email": "manaralforqan@gmail.com", "password": "forqanforqan1122334455jjkk", "gologin": "wp988015", "recovery": "shami313p@gmail.com", "twoFa": "", "status": "يعمل", "notes": "من جودت", "country": "", "phone": ""},
    {"email": "abdalahsyd222@gmail.com", "password": "alasef12", "gologin": "", "recovery": "", "twoFa": "", "status": "غير محدد", "notes": "", "country": "", "phone": ""},
    {"email": "suafaladlbe@gmail.com", "password": "alasef12", "gologin": "", "recovery": "", "twoFa": "", "status": "غير محدد", "notes": "", "country": "", "phone": ""},
    {"email": "abwalsuaf1@gmail.com", "password": "alasef12", "gologin": "", "recovery": "", "twoFa": "", "status": "غير محدد", "notes": "", "country": "", "phone": ""},
    {"email": "alshameasef@gmail.com", "password": "alasef12", "gologin": "", "recovery": "", "twoFa": "", "status": "غير محدد", "notes": "", "country": "", "phone": ""},
    {"email": "abwasadalhame@gmail.com", "password": "aaa12345aaa", "gologin": "", "recovery": "", "twoFa": "", "status": "غير محدد", "notes": "", "country": "", "phone": ""},
    {"email": "aa6057765@gmail.com", "password": "alasef11", "gologin": "", "recovery": "", "twoFa": "", "status": "غير محدد", "notes": "", "country": "", "phone": ""},
    {"email": "alasuf500@gmail.com", "password": "alasef11", "gologin": "", "recovery": "", "twoFa": "", "status": "غير محدد", "notes": "", "country": "", "phone": ""},
    {"email": "alasuf800@gmail.com", "password": "alasef11", "gologin": "", "recovery": "", "twoFa": "", "status": "قيد المراجعة", "notes": "", "country": "", "phone": ""},
    {"email": "abwasad1100@gmail.com", "password": "alasef11", "gologin": "", "recovery": "", "twoFa": "", "status": "قيد المراجعة", "notes": "", "country": "", "phone": ""},
    {"email": "alasuf400@gmail.com", "password": "alasef11", "gologin": "", "recovery": "", "twoFa": "", "status": "قيد المراجعة", "notes": "", "country": "", "phone": ""},
    {"email": "abw290280@gmail.com", "password": "as1234as", "gologin": "", "recovery": "", "twoFa": "", "status": "قيد المراجعة", "notes": "", "country": "", "phone": ""},
    {"email": "606omar606@gmail.com", "password": "@O12345$$@", "gologin": "wp988015", "recovery": "ابو خليل", "twoFa": "", "status": "مقفول", "notes": "", "country": "فرنسا", "phone": ""},
    {"email": "alasyfabw12@gmail.com", "password": "alasef11", "gologin": "wp988015", "recovery": "shami313p@gmail.com", "twoFa": "", "status": "مقفول", "notes": "تم ربطه برقم وهمي بولندي", "country": "المانيا", "phone": "48724817335"},
    {"email": "alasuf300@gmail.com", "password": "alasef11", "gologin": "", "recovery": "", "twoFa": "", "status": "مقفول", "notes": "", "country": "", "phone": ""},
    {"email": "wp988015@gmail.com", "password": "..Fgh345..", "gologin": "", "recovery": "shami313p@gmail.com", "twoFa": "ايذينتكيتور", "status": "مقفول", "notes": "تم استرداده لك مقفول على الرقم", "country": "", "phone": ""},
    {"email": "kamolrakhi2@gmail.com", "password": "..Ghj456..", "gologin": "", "recovery": "shami313p@gmail.com", "twoFa": "ايذينتكيتور", "status": "مقفول", "notes": "رقم وهمي بولندي / تم قفله", "country": "", "phone": "48731656843"},
    {"email": "awetorop09@gmail.com", "password": "..Dfg234..", "gologin": "", "recovery": "shami313p@gmail.com", "twoFa": "ايذينتكيتور", "status": "مقفول", "notes": "تم سحب الحساب", "country": "", "phone": "رقم وهمي بولندي"},
    {"email": "Ywoo3407@gmail.com", "password": "ytrMNB852@@", "gologin": "", "recovery": "", "twoFa": "", "status": "مقفول", "notes": "مقفول على الرقم", "country": "", "phone": ""}
  ],
  "gologin": [
    {"accountType": "جيميل", "platform": "جو لوجن لمنصة بلوبلر ادس", "email": "baynancish@gmail.com", "password": "abduallrahman.Alshami1", "profile1": "", "profile2": "", "profile3": "", "notes": "", "country": ""},
    {"accountType": "Gologin", "platform": "Gologin", "email": "josheprichad2555@gmail.com", "password": "josheprichad2555@gmail.com", "profile1": "CaseVault Tech", "profile2": "Armande Odilon", "profile3": "Lara Floriane", "notes": "3 برو", "country": "فرنسي"},
    {"accountType": "Gologin", "platform": "Gologin", "email": "awetorop09@gmail.com", "password": "awetorop09@gmail.com", "profile1": "Munroe Sharleen", "profile2": "Michel Brunhilde", "profile3": "Fredy Christian", "notes": "3 برو", "country": "امريكي"},
    {"accountType": "Gologin", "platform": "Gologin", "email": "wp988015@gmail.com", "password": "wp988015@gmail.com", "profile1": "manaralforqan", "profile2": "asefabwasad", "profile3": "505gacim505", "notes": "3 برو", "country": "الماني"},
    {"accountType": "Gologin", "platform": "Gologin", "email": "kamolrakhi2@gmail.com", "password": "kamolrakhi2", "profile1": "", "profile2": "", "profile3": "", "notes": "فاضي حتى الان", "country": ""}
  ],
  "amazon_accounts": [
    {"beneficiary": "شامي", "code": "SH-01", "name": "Josefiina Eliina", "storeId": "b0gvymq3gt-20", "country": "فرنسي", "status": "نشط", "product1": "قناع وجه 3 %", "promoStatus1": "جاري الترويج", "tweetUrl1": "https://t.co/hTJkFEO6dJ", "product2": "قناع وجه 3 %", "promoStatus2": "جاري الترويج", "tweetUrl2": "https://t.co/jwlZBoY2r3", "affiliateUrl1": "https://link.amazon/B0bpSTE9U", "affiliateUrl2": "https://link.amazon/B0ca2QTx6", "adsterraUrl": "https://anker-deals.baynancish.workers.dev/", "email": "josheprichad2555", "password": "..Sdf123..", "linkage": "امزون   - تويتر", "notes": "حساب رئيسي"},
    {"beneficiary": "شامي", "code": "SH-02", "name": "Armande Odilon", "storeId": "b0cwq39rb9-20", "country": "فرنسي", "status": "نشط", "product1": "شاحن لاسلكي أبل", "promoStatus1": "جاري الترويج", "tweetUrl1": "https://t.co/yY1SFiBNeG", "product2": "", "promoStatus2": "", "tweetUrl2": "", "affiliateUrl1": "https://link.amazon/B06KywfDL", "affiliateUrl2": "", "adsterraUrl": "https://tech-deals-hub.baynancish.workers.dev/", "email": "aboaboah43", "password": "qqwwee123z", "linkage": "امزون   - تويتر", "notes": "الحمد لله"},
    {"beneficiary": "شامي", "code": "SH-03", "name": "Munroe Sharleen", "storeId": "b0bv4sxtfz-20", "country": "اوكرانيا", "status": "نشط", "product1": "شاحن لاسلكي أبل", "promoStatus1": "جاري الترويج", "tweetUrl1": "https://t.co/kKS1jSj7dZ", "product2": "", "promoStatus2": "", "tweetUrl2": "", "affiliateUrl1": "https://link.amazon/B03wK6Z6F", "affiliateUrl2": "", "adsterraUrl": "https://baby-care-deals.baynancish.workers.dev/", "email": "alasuf700", "password": "alasef11", "linkage": "امزون   - تويتر", "notes": ""},
    {"beneficiary": "شامي", "code": "SH-04", "name": "Michel Brunhilde", "storeId": "b0fmxh8stx-20", "country": "اوكرانيا", "status": "نشط", "product1": "قناع وجه 1%", "promoStatus1": "جاري الترويج", "tweetUrl1": "https://t.co/bUvpXyBVvH", "product2": "قناع وجه 3%", "promoStatus2": "جاري الترويج", "tweetUrl2": "https://t.co/l3bfTVfW9z", "affiliateUrl1": "https://amzn.to/4rzwfaK", "affiliateUrl2": "https://link.amazon/B00QDbkmn", "adsterraUrl": "https://beauty-deals-hub.baynancish.workers.dev/", "email": "alasuf200", "password": "alasef10", "linkage": "امزون   - تويتر", "notes": ""},
    {"beneficiary": "شامي", "code": "SH-05", "name": "Calixte Athanase", "storeId": "b0fmxh8stx02-20", "country": "فرنسي", "status": "نشط", "product1": "ماكينة قهوي", "promoStatus1": "جاري الترويج", "tweetUrl1": "https://t.co/prhaMFIZ9K", "product2": "Natural Honey", "promoStatus2": "جاري الترويج", "tweetUrl2": "https://t.co/bn5HobgtQG", "affiliateUrl1": "https://amzn.to/4rU1tcK", "affiliateUrl2": "https://amzn.to/3VBMybb", "adsterraUrl": "", "email": "abdalahsyd222", "password": "alasef12", "linkage": "امزون   - تويتر", "notes": "35"},
    {"beneficiary": "ابو مخلص", "code": "MK-01", "name": "Lara Floriane", "storeId": "b09mqwwp8705-20", "country": "فرنسي", "status": "نشط", "product1": "كرياتين", "promoStatus1": "جاري الترويج", "tweetUrl1": "https://t.co/8nl4GnND5X", "product2": "منفاخ هواء", "promoStatus2": "جاري الترويج", "tweetUrl2": "https://t.co/WAbruhKUYz", "affiliateUrl1": "https://link.amazon/B030oVGHn", "affiliateUrl2": "https://link.amazon/B01xSCmPG", "adsterraUrl": "https://travel-pack-deals.baynancish.workers.dev/", "email": "alasuf600", "password": "alasef10", "linkage": "امزون   - تويتر", "notes": ""},
    {"beneficiary": "ابو خليل", "code": "KH-01", "name": "Nora Frank", "storeId": "b08fj678yk-20", "country": "الماني", "status": "محظور", "product1": "منقي هواء", "promoStatus1": "ملغى / مؤرشف", "tweetUrl1": "https://t.co/RiJi2dBukN", "product2": "", "promoStatus2": "ملغى / مؤرشف", "tweetUrl2": "", "affiliateUrl1": "https://amzn.to/46ULjX1", "affiliateUrl2": "", "adsterraUrl": "", "email": "505gacim505", "password": "(+505gacim505+)", "linkage": "امزون   - تويتر", "notes": ""},
    {"beneficiary": "جودت", "code": "JD-01", "name": "Louise Gottschalk", "storeId": "b0fjldnqz7-20", "country": "الماني", "status": "محظور", "product1": "كرسي اطفال للسيارة", "promoStatus1": "ملغى / مؤرشف", "tweetUrl1": "https://t.co/li3KOirH1o", "product2": "", "promoStatus2": "ملغى / مؤرشف", "tweetUrl2": "", "affiliateUrl1": "https://amzn.to/4i31oA2", "affiliateUrl2": "", "adsterraUrl": "", "email": "manaralforqan", "password": "forqanforqan1122334455jjkk", "linkage": "امزون   - تويتر", "notes": ""},
    {"beneficiary": "شامي", "code": "SH-06", "name": "Fredy Christian", "storeId": "b01n5c39cx-20", "country": "الماني", "status": "محظور", "product1": "شواحن وبنوك طاقة", "promoStatus1": "ملغى / مؤرشف", "tweetUrl1": "", "product2": "", "promoStatus2": "تم الإيقاف", "tweetUrl2": "", "affiliateUrl1": "https://link.amazon/B0bi7G1yS", "affiliateUrl2": "https://amzn.to/4rzwfaK", "adsterraUrl": "", "email": "abwasadsyd123", "password": "alasef11", "linkage": "امزون   - تويتر", "notes": "موقوف مؤقتاً"},
    {"beneficiary": "شامي", "code": "SH-07", "name": "Hannes Ignaz", "storeId": "sparkplaytoys-20", "country": "الماني", "status": "محظور", "product1": "إلكترونيات وملحقات", "promoStatus1": "ملغى / مؤرشف", "tweetUrl1": "https://t.co/NfPZeTssmt", "product2": "", "promoStatus2": "", "tweetUrl2": "", "affiliateUrl1": "https://link.amazon/B01Dxim28", "affiliateUrl2": "", "adsterraUrl": "https://toys-deals-hub.baynancish.workers.dev/", "email": "asefabwasad", "password": "alasef11", "linkage": "امزون   - تويتر", "notes": "تقيد الإيميل والحساب"}
  ],
  "historical_links": [
    {"beneficiary": "شامي", "accountName": "Josefiina Eliina", "product": "قناع وجه 3 %", "linkType": "رابط أفلييت قديم", "url": "https://link.amazon/B05EtNv4X", "notes": "أفلييت قديم محفوظ مرجعياً"},
    {"beneficiary": "شامي", "accountName": "Josefiina Eliina", "product": "قناع وجه 3 %", "linkType": "رابط أفلييت قديم", "url": "https://link.amazon/B0hDq4Y87", "notes": "أفلييت قديم محفوظ مرجعياً"},
    {"beneficiary": "شامي", "accountName": "Josefiina Eliina", "product": "قناع وجه 3 %", "linkType": "تغريدة تويتر بديلة", "url": "https://t.co/xI5apfjus1", "notes": "تغريدة قديمة محفوظة"},
    {"beneficiary": "ابو مخلص", "accountName": "Lara Floriane", "product": "Creatine Monohydrate", "linkType": "رابط أفلييت قديم", "url": "https://link.amazon/B0dR4Edig", "notes": "أفلييت قديم محفوظ مرجعياً"},
    {"beneficiary": "ابو مخلص", "accountName": "Lara Floriane", "product": "Creatine Monohydrate", "linkType": "رابط أفلييت قديم", "url": "https://link.amazon/B08HCvBtj", "notes": "أفلييت قديم محفوظ مرجعياً"},
    {"beneficiary": "ابو مخلص", "accountName": "Lara Floriane", "product": "Creatine Monohydrate", "linkType": "تغريدة تويتر بديلة", "url": "https://t.co/pmppT6sipk", "notes": "تغريدة قديمة محفوظة"},
    {"beneficiary": "شامي", "accountName": "Josefiina Eliina", "product": "قناع وجه 3 %", "linkType": "رابط أفلييت سابق", "url": "https://link.amazon/B0ca2QTx6", "notes": "رابط بديل محفوظ"}
  ],
  "beneficiaries": [
    {"id": 1, "name": "شامي", "baseCapital": 100.0, "accountCodeRange": "SH-01:07"},
    {"id": 2, "name": "ابو مخلص", "baseCapital": 30.0, "accountCodeRange": "MK-01"},
    {"id": 3, "name": "ابو خليل", "baseCapital": 100.0, "accountCodeRange": "KH-01"},
    {"id": 4, "name": "جودت", "baseCapital": 20.0, "accountCodeRange": "JD-01"}
  ],
  "products_catalog": [
    {"id": 1, "product": "قناع وجه 3 %", "beneficiary": "شامي", "accountCode": "SH-01", "profile": "Josefiina Eliina", "capital": 100.0, "email": "josheprichad2555@gmail.com", "password": "..Sdf123..", "adUrl": "https://t.co/hTJkFEO6dJ"},
    {"id": 2, "product": "شاحن لاسلكي أبل", "beneficiary": "شامي", "accountCode": "SH-02", "profile": "Armande Odilon", "capital": 100.0, "email": "aboaboah43@gmail.com", "password": "qqwwee123z", "adUrl": "https://t.co/yY1SFiBNeG"},
    {"id": 3, "product": "شاحن لاسلكي أبل - أوكرانيا", "beneficiary": "شامي", "accountCode": "SH-03", "profile": "Munroe Sharleen", "capital": 100.0, "email": "alasuf700@gmail.com", "password": "alasef11", "adUrl": "https://t.co/kKS1jSj7dZ"},
    {"id": 4, "product": "قناع وجه 1%", "beneficiary": "شامي", "accountCode": "SH-04", "profile": "Michel Brunhilde", "capital": 100.0, "email": "alasuf200@gmail.com", "password": "alasef10", "adUrl": "https://t.co/bUvpXyBVvH"},
    {"id": 5, "product": "ماكينة قهوي", "beneficiary": "شامي", "accountCode": "SH-05", "profile": "Calixte Athanase", "capital": 100.0, "email": "abdalahsyd222@gmail.com", "password": "alasef12", "adUrl": "https://t.co/prhaMFIZ9K"},
    {"id": 6, "product": "Natural Honey", "beneficiary": "شامي", "accountCode": "SH-05", "profile": "Calixte Athanase", "capital": 100.0, "email": "abdalahsyd222@gmail.com", "password": "alasef12", "adUrl": "https://t.co/bn5HobgtQG"},
    {"id": 7, "product": "كرياتين", "beneficiary": "ابو مخلص", "accountCode": "MK-01", "profile": "Lara Floriane", "capital": 30.0, "email": "alasuf600@gmail.com", "password": "alasef10", "adUrl": "https://t.co/8nl4GnND5X"},
    {"id": 8, "product": "منفاخ هواء", "beneficiary": "ابو مخلص", "accountCode": "MK-01", "profile": "Lara Floriane", "capital": 30.0, "email": "alasuf600@gmail.com", "password": "alasef10", "adUrl": "https://t.co/WAbruhKUYz"},
    {"id": 9, "product": "منقي هواء", "beneficiary": "ابو خليل", "accountCode": "KH-01", "profile": "Nora Frank", "capital": 100.0, "email": "505gacim505@gmail.com", "password": "(+505gacim505+)", "adUrl": "https://t.co/RiJi2dBukN"},
    {"id": 10, "product": "كرسي اطفال للسيارة", "beneficiary": "جودت", "accountCode": "JD-01", "profile": "Louise Gottschalk", "capital": 20.0, "email": "manaralforqan@gmail.com", "password": "forqanforqan1122334455jjkk", "adUrl": "https://t.co/li3KOirH1o"},
    {"id": 11, "product": "شواحن وبنوك طاقة", "beneficiary": "شامي", "accountCode": "SH-06", "profile": "Fredy Christian", "capital": 100.0, "email": "abwasadsyd123@gmail.com", "password": "alasef11", "adUrl": "https://anker-deals.baynancish.workers.dev/"},
    {"id": 12, "product": "إلكترونيات وملحقات", "beneficiary": "شامي", "accountCode": "SH-07", "profile": "Hannes Ignaz", "capital": 100.0, "email": "asefabwasad@gmail.com", "password": "alasef11", "adUrl": "https://t.co/NfPZeTssmt"},
    {"id": 13, "product": "قناع وجه 3%", "beneficiary": "شامي", "accountCode": "SH-04", "profile": "Michel Brunhilde", "capital": 100.0, "email": "alasuf200@gmail.com", "password": "alasef10", "adUrl": "[link removed]"}
  ],
  "campaigns": [
    {"seq": 1, "date": "2026-09-25", "beneficiary": "شامي", "accountCode": "SH-04", "product": "قناع وجه 1%", "email": "alasuf200", "cost": 0.45, "profile": "Michel Brunhilde", "password": "alasef10", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/bUvpXyBVvH"},
    {"seq": 2, "date": "2026-09-25", "beneficiary": "ابو مخلص", "accountCode": "MK-01", "product": "كرياتين", "email": "alasuf600", "cost": 0.623, "profile": "Lara Floriane", "password": "alasef10", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/8nl4GnND5X"},
    {"seq": 3, "date": "2026-09-25", "beneficiary": "شامي", "accountCode": "SH-02", "product": "شاحن لاسلكي أبل", "email": "aboaboah43", "cost": 0.634, "profile": "Armande Odilon", "password": "qqwwee123z", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 14.65, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/yY1SFiBNeG"},
    {"seq": 4, "date": "2026-09-27", "beneficiary": "شامي", "accountCode": "SH-04", "product": "قناع وجه 1%", "email": "alasuf200", "cost": 2.756, "profile": "Michel Brunhilde", "password": "alasef10", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/bUvpXyBVvH"},
    {"seq": 5, "date": "2026-09-27", "beneficiary": "ابو مخلص", "accountCode": "MK-01", "product": "كرياتين", "email": "alasuf600", "cost": 7.237, "profile": "Lara Floriane", "password": "alasef10", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/8nl4GnND5X"},
    {"seq": 6, "date": "2026-09-27", "beneficiary": "شامي", "accountCode": "SH-02", "product": "شاحن لاسلكي أبل", "email": "aboaboah43", "cost": 7.15, "profile": "Armande Odilon", "password": "qqwwee123z", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/yY1SFiBNeG"},
    {"seq": 7, "date": "2026-09-28", "beneficiary": "شامي", "accountCode": "SH-04", "product": "قناع وجه 1%", "email": "alasuf200", "cost": 1.554, "profile": "Michel Brunhilde", "password": "alasef10", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 1.92, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/bUvpXyBVvH"},
    {"seq": 8, "date": "2026-09-28", "beneficiary": "ابو مخلص", "accountCode": "MK-01", "product": "كرياتين", "email": "alasuf600", "cost": 1.564, "profile": "Lara Floriane", "password": "alasef10", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.4, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/8nl4GnND5X"},
    {"seq": 9, "date": "2026-09-28", "beneficiary": "شامي", "accountCode": "SH-02", "product": "شاحن لاسلكي أبل", "email": "aboaboah43", "cost": 1.545, "profile": "Armande Odilon", "password": "qqwwee123z", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 9.76, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/yY1SFiBNeG"},
    {"seq": 10, "date": "2026-09-29", "beneficiary": "شامي", "accountCode": "SH-04", "product": "قناع وجه 1%", "email": "alasuf200", "cost": 5.914, "profile": "Michel Brunhilde", "password": "alasef10", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 3.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/bUvpXyBVvH"},
    {"seq": 11, "date": "2026-09-29", "beneficiary": "ابو مخلص", "accountCode": "MK-01", "product": "كرياتين", "email": "alasuf600", "cost": 8.861, "profile": "Lara Floriane", "password": "alasef10", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 12.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/8nl4GnND5X"},
    {"seq": 12, "date": "2026-09-29", "beneficiary": "شامي", "accountCode": "SH-02", "product": "شاحن لاسلكي أبل", "email": "aboaboah43", "cost": 9.249, "profile": "Armande Odilon", "password": "qqwwee123z", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/yY1SFiBNeG"},
    {"seq": 13, "date": "2026-10-01", "beneficiary": "شامي", "accountCode": "SH-04", "product": "قناع وجه 1%", "email": "alasuf200", "cost": 1.546, "profile": "Michel Brunhilde", "password": "alasef10", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/bUvpXyBVvH"},
    {"seq": 14, "date": "2026-10-01", "beneficiary": "شامي", "accountCode": "SH-02", "product": "شاحن لاسلكي أبل", "email": "aboaboah43", "cost": 1.416, "profile": "Armande Odilon", "password": "qqwwee123z", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/yY1SFiBNeG"},
    {"seq": 15, "date": "2026-10-02", "beneficiary": "شامي", "accountCode": "SH-04", "product": "قناع وجه 1%", "email": "alasuf200", "cost": 3.089, "profile": "Michel Brunhilde", "password": "alasef10", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 51.27, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/bUvpXyBVvH"},
    {"seq": 16, "date": "2026-10-02", "beneficiary": "ابو مخلص", "accountCode": "MK-01", "product": "كرياتين", "email": "alasuf600", "cost": 0.0, "profile": "Lara Floriane", "password": "alasef10", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 25.41, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/8nl4GnND5X"},
    {"seq": 17, "date": "2026-10-02", "beneficiary": "شامي", "accountCode": "SH-02", "product": "شاحن لاسلكي أبل", "email": "aboaboah43", "cost": 3.119, "profile": "Armande Odilon", "password": "qqwwee123z", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 18.16, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/yY1SFiBNeG"},
    {"seq": 18, "date": "2026-10-02", "beneficiary": "شامي", "accountCode": "SH-01", "product": "قناع وجه 3 %", "email": "josheprichad2555", "cost": 0.0, "profile": "Josefiina Eliina", "password": "..Sdf123..", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 1.14, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/hTJkFEO6dJ"},
    {"seq": 19, "date": "2026-10-03", "beneficiary": "ابو خليل", "accountCode": "KH-01", "product": "منقي هواء", "email": "505gacim505", "cost": 0.0, "profile": "Nora Frank", "password": "(+505gacim505+)", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/RiJi2dBukN"},
    {"seq": 20, "date": "2026-10-03", "beneficiary": "شامي", "accountCode": "SH-01", "product": "قناع وجه 3 %", "email": "josheprichad2555", "cost": 5.235, "profile": "Josefiina Eliina", "password": "..Sdf123..", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/hTJkFEO6dJ"},
    {"seq": 21, "date": "2026-10-03", "beneficiary": "شامي", "accountCode": "SH-01", "product": "قناع وجه 3 %", "email": "josheprichad2555", "cost": 5.182, "profile": "Josefiina Eliina", "password": "..Sdf123..", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 1.8, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/hTJkFEO6dJ"},
    {"seq": 22, "date": "2026-10-03", "beneficiary": "شامي", "accountCode": "SH-04", "product": "قناع وجه 1%", "email": "alasuf200", "cost": 5.723, "profile": "Michel Brunhilde", "password": "alasef10", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 10.46, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/bUvpXyBVvH"},
    {"seq": 23, "date": "2026-10-03", "beneficiary": "ابو مخلص", "accountCode": "MK-01", "product": "كرياتين", "email": "alasuf600", "cost": 6.365, "profile": "Lara Floriane", "password": "alasef10", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.17, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/8nl4GnND5X"},
    {"seq": 24, "date": "2026-10-03", "beneficiary": "شامي", "accountCode": "SH-02", "product": "شاحن لاسلكي أبل", "email": "aboaboah43", "cost": 5.215, "profile": "Armande Odilon", "password": "qqwwee123z", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 12.95, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/yY1SFiBNeG"},
    {"seq": 25, "date": "2026-10-04", "beneficiary": "شامي", "accountCode": "SH-01", "product": "قناع وجه 3 %", "email": "josheprichad2555", "cost": 1.634, "profile": "Josefiina Eliina", "password": "..Sdf123..", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/hTJkFEO6dJ"},
    {"seq": 26, "date": "2026-10-04", "beneficiary": "شامي", "accountCode": "SH-01", "product": "قناع وجه 3 %", "email": "josheprichad2555", "cost": 1.614, "profile": "Josefiina Eliina", "password": "..Sdf123..", "clicks": 1188, "orderedItems": 11, "orderedRevenue": 271.89, "shippedItems": 12, "returnedItems": 0, "totalRevenue": 274.56, "commission": 8.21, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/hTJkFEO6dJ"},
    {"seq": 27, "date": "2026-10-04", "beneficiary": "شامي", "accountCode": "SH-04", "product": "قناع وجه 1%", "email": "alasuf200", "cost": 1.757, "profile": "Michel Brunhilde", "password": "alasef10", "clicks": 1285, "orderedItems": 37, "orderedRevenue": 564.71, "shippedItems": 87, "returnedItems": 0, "totalRevenue": 522.99, "commission": 11.43, "bonus": 80.0, "isPending": false, "adUrl": "https://t.co/bUvpXyBVvH"},
    {"seq": 28, "date": "2026-10-04", "beneficiary": "شامي", "accountCode": "SH-02", "product": "شاحن لاسلكي أبل", "email": "aboaboah43", "cost": 1.204, "profile": "Armande Odilon", "password": "qqwwee123z", "clicks": 912, "orderedItems": 30, "orderedRevenue": 1247.02, "shippedItems": 29, "returnedItems": 0, "totalRevenue": 987.4, "commission": 29.08, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/yY1SFiBNeG"},
    {"seq": 29, "date": "2026-10-04", "beneficiary": "ابو مخلص", "accountCode": "MK-01", "product": "كرياتين", "email": "alasuf600", "cost": 1.864, "profile": "Lara Floriane", "password": "alasef10", "clicks": 685, "orderedItems": 6, "orderedRevenue": 98.32, "shippedItems": 10, "returnedItems": 0, "totalRevenue": 183.18, "commission": 5.04, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/8nl4GnND5X"},
    {"seq": 30, "date": "2026-10-04", "beneficiary": "ابو خليل", "accountCode": "KH-01", "product": "منقي هواء", "email": "505gacim505", "cost": 1.625, "profile": "Nora Frank", "password": "(+505gacim505+)", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/RiJi2dBukN"},
    {"seq": 31, "date": "2026-10-05", "beneficiary": "جودت", "accountCode": "JD-01", "product": "كرسي اطفال للسيارة", "email": "manaralforqan", "cost": 3.024, "profile": "Louise Gottschalk", "password": "forqanforqan1122334455jjkk", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/li3KOirH1o"},
    {"seq": 32, "date": "2026-10-05", "beneficiary": "ابو خليل", "accountCode": "KH-01", "product": "منقي هواء", "email": "505gacim505", "cost": 1.633, "profile": "Nora Frank", "password": "(+505gacim505+)", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/RiJi2dBukN"},
    {"seq": 33, "date": "2026-10-05", "beneficiary": "شامي", "accountCode": "SH-03", "product": "شاحن لاسلكي أبل - أوكرانيا", "email": "alasuf700", "cost": 0.775, "profile": "Munroe Sharleen", "password": "alasef11", "clicks": 1, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/kKS1jSj7dZ"},
    {"seq": 34, "date": "2026-10-05", "beneficiary": "شامي", "accountCode": "SH-01", "product": "قناع وجه 3 %", "email": "josheprichad2555", "cost": 4.09, "profile": "Josefiina Eliina", "password": "..Sdf123..", "clicks": 1418, "orderedItems": 27, "orderedRevenue": 671.29, "shippedItems": 22, "returnedItems": 0, "totalRevenue": 487.58, "commission": 14.22, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/hTJkFEO6dJ"},
    {"seq": 35, "date": "2026-10-05", "beneficiary": "شامي", "accountCode": "SH-04", "product": "قناع وجه 1%", "email": "alasuf200", "cost": 4.393, "profile": "Michel Brunhilde", "password": "alasef10", "clicks": 3008, "orderedItems": 44, "orderedRevenue": 892.92, "shippedItems": 33, "returnedItems": 1, "totalRevenue": 695.61, "commission": 25.11, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/bUvpXyBVvH"},
    {"seq": 36, "date": "2026-10-05", "beneficiary": "ابو مخلص", "accountCode": "MK-01", "product": "كرياتين", "email": "alasuf600", "cost": 4.293, "profile": "Lara Floriane", "password": "alasef10", "clicks": 1440, "orderedItems": 32, "orderedRevenue": 221.56, "shippedItems": 20, "returnedItems": 0, "totalRevenue": 136.61, "commission": 4.29, "bonus": 3.0, "isPending": false, "adUrl": "https://t.co/8nl4GnND5X"},
    {"seq": 37, "date": "2026-10-05", "beneficiary": "شامي", "accountCode": "SH-02", "product": "شاحن لاسلكي أبل", "email": "aboaboah43", "cost": 4.874, "profile": "Armande Odilon", "password": "qqwwee123z", "clicks": 3385, "orderedItems": 46, "orderedRevenue": 969.98, "shippedItems": 34, "returnedItems": 1, "totalRevenue": 736.92, "commission": 20.71, "bonus": 40.0, "isPending": false, "adUrl": "https://t.co/yY1SFiBNeG"},
    {"seq": 38, "date": "2026-10-06", "beneficiary": "جودت", "accountCode": "JD-01", "product": "كرسي اطفال للسيارة", "email": "manaralforqan", "cost": 5.15, "profile": "Louise Gottschalk", "password": "forqanforqan1122334455jjkk", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/li3KOirH1o"},
    {"seq": 39, "date": "2026-10-06", "beneficiary": "ابو خليل", "accountCode": "KH-01", "product": "منقي هواء", "email": "505gacim505", "cost": 4.925, "profile": "Nora Frank", "password": "(+505gacim505+)", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/RiJi2dBukN"},
    {"seq": 40, "date": "2026-10-06", "beneficiary": "شامي", "accountCode": "SH-03", "product": "شاحن لاسلكي أبل - أوكرانيا", "email": "alasuf700", "cost": 5.037, "profile": "Munroe Sharleen", "password": "alasef11", "clicks": 2343, "orderedItems": 11, "orderedRevenue": 217.75, "shippedItems": 1, "returnedItems": 0, "totalRevenue": 10.99, "commission": 0.0, "bonus": 3.0, "isPending": false, "adUrl": "https://t.co/kKS1jSj7dZ"},
    {"seq": 41, "date": "2026-10-06", "beneficiary": "شامي", "accountCode": "SH-01", "product": "قناع وجه 3 %", "email": "josheprichad2555", "cost": 5.083, "profile": "Josefiina Eliina", "password": "..Sdf123..", "clicks": 1563, "orderedItems": 7, "orderedRevenue": 122.55, "shippedItems": 7, "returnedItems": 0, "totalRevenue": 169.01, "commission": 7.33, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/hTJkFEO6dJ"},
    {"seq": 42, "date": "2026-10-06", "beneficiary": "شامي", "accountCode": "SH-04", "product": "قناع وجه 1%", "email": "alasuf200", "cost": 5.045, "profile": "Michel Brunhilde", "password": "alasef10", "clicks": 3447, "orderedItems": 60, "orderedRevenue": 1577.75, "shippedItems": 52, "returnedItems": 0, "totalRevenue": 1009.97, "commission": 33.02, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/bUvpXyBVvH"},
    {"seq": 43, "date": "2026-10-06", "beneficiary": "ابو مخلص", "accountCode": "MK-01", "product": "كرياتين", "email": "alasuf600", "cost": 5.226, "profile": "Lara Floriane", "password": "alasef10", "clicks": 1529, "orderedItems": 9, "orderedRevenue": 112.94, "shippedItems": 16, "returnedItems": 0, "totalRevenue": 166.89, "commission": 4.89, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/8nl4GnND5X"},
    {"seq": 44, "date": "2026-10-06", "beneficiary": "شامي", "accountCode": "SH-02", "product": "شاحن لاسلكي أبل", "email": "aboaboah43", "cost": 5.754, "profile": "Armande Odilon", "password": "qqwwee123z", "clicks": 4275, "orderedItems": 74, "orderedRevenue": 1386.08, "shippedItems": 48, "returnedItems": 0, "totalRevenue": 1132.16, "commission": 37.42, "bonus": 80.0, "isPending": false, "adUrl": "https://t.co/yY1SFiBNeG"},
    {"seq": 45, "date": "2026-10-07", "beneficiary": "جودت", "accountCode": "JD-01", "product": "كرسي اطفال للسيارة", "email": "manaralforqan", "cost": 0.006, "profile": "Louise Gottschalk", "password": "forqanforqan1122334455jjkk", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/li3KOirH1o"},
    {"seq": 46, "date": "2026-10-07", "beneficiary": "ابو خليل", "accountCode": "KH-01", "product": "منقي هواء", "email": "505gacim505", "cost": 0.101, "profile": "Nora Frank", "password": "(+505gacim505+)", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/RiJi2dBukN"},
    {"seq": 47, "date": "2026-10-07", "beneficiary": "شامي", "accountCode": "SH-03", "product": "شاحن لاسلكي أبل - أوكرانيا", "email": "alasuf700", "cost": 0.0, "profile": "Munroe Sharleen", "password": "alasef11", "clicks": 17, "orderedItems": 18, "orderedRevenue": 302.94, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/kKS1jSj7dZ"},
    {"seq": 48, "date": "2026-10-07", "beneficiary": "شامي", "accountCode": "SH-01", "product": "قناع وجه 3 %", "email": "josheprichad2555", "cost": 0.006, "profile": "Josefiina Eliina", "password": "..Sdf123..", "clicks": 41, "orderedItems": 37, "orderedRevenue": 224.55, "shippedItems": 39, "returnedItems": 0, "totalRevenue": 273.62, "commission": 10.75, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/hTJkFEO6dJ"},
    {"seq": 49, "date": "2026-10-07", "beneficiary": "شامي", "accountCode": "SH-04", "product": "قناع وجه 1%", "email": "alasuf200", "cost": 3.19, "profile": "Michel Brunhilde", "password": "alasef10", "clicks": 2260, "orderedItems": 105, "orderedRevenue": 2588.56, "shippedItems": 59, "returnedItems": 0, "totalRevenue": 1022.82, "commission": 31.4, "bonus": 40.0, "isPending": false, "adUrl": "https://t.co/bUvpXyBVvH"},
    {"seq": 50, "date": "2026-10-07", "beneficiary": "ابو مخلص", "accountCode": "MK-01", "product": "كرياتين", "email": "alasuf600", "cost": 0.006, "profile": "Lara Floriane", "password": "alasef10", "clicks": 37, "orderedItems": 13, "orderedRevenue": 527.38, "shippedItems": 6, "returnedItems": 0, "totalRevenue": 111.25, "commission": 3.5, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/8nl4GnND5X"},
    {"seq": 51, "date": "2026-10-07", "beneficiary": "شامي", "accountCode": "SH-02", "product": "شاحن لاسلكي أبل", "email": "aboaboah43", "cost": 3.627, "profile": "Armande Odilon", "password": "qqwwee123z", "clicks": 2708, "orderedItems": 126, "orderedRevenue": 3010.74, "shippedItems": 70, "returnedItems": 0, "totalRevenue": 1230.81, "commission": 40.76, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/yY1SFiBNeG"},
    {"seq": 52, "date": "2026-10-08", "beneficiary": "جودت", "accountCode": "JD-01", "product": "كرسي اطفال للسيارة", "email": "manaralforqan", "cost": 0.0, "profile": "Louise Gottschalk", "password": "forqanforqan1122334455jjkk", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/li3KOirH1o"},
    {"seq": 53, "date": "2026-10-08", "beneficiary": "ابو خليل", "accountCode": "KH-01", "product": "منقي هواء", "email": "505gacim505", "cost": 0.0, "profile": "Nora Frank", "password": "(+505gacim505+)", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/RiJi2dBukN"},
    {"seq": 54, "date": "2026-10-08", "beneficiary": "شامي", "accountCode": "SH-03", "product": "شاحن لاسلكي أبل - أوكرانيا", "email": "alasuf700", "cost": 0.0, "profile": "Munroe Sharleen", "password": "alasef11", "clicks": 12, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 13, "returnedItems": 0, "totalRevenue": 291.01, "commission": 8.34, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/kKS1jSj7dZ"},
    {"seq": 55, "date": "2026-10-08", "beneficiary": "شامي", "accountCode": "SH-01", "product": "قناع وجه 3 %", "email": "josheprichad2555", "cost": 0.0, "profile": "Josefiina Eliina", "password": "..Sdf123..", "clicks": 23, "orderedItems": 1, "orderedRevenue": 25.99, "shippedItems": 6, "returnedItems": 0, "totalRevenue": 131.23, "commission": 4.63, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/hTJkFEO6dJ"},
    {"seq": 56, "date": "2026-10-08", "beneficiary": "شامي", "accountCode": "SH-04", "product": "قناع وجه 1%", "email": "alasuf200", "cost": 0.0, "profile": "Michel Brunhilde", "password": "alasef10", "clicks": 11, "orderedItems": 15, "orderedRevenue": 328.08, "shippedItems": 37, "returnedItems": 0, "totalRevenue": 1032.21, "commission": 31.43, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/bUvpXyBVvH"},
    {"seq": 57, "date": "2026-10-08", "beneficiary": "ابو مخلص", "accountCode": "MK-01", "product": "كرياتين", "email": "alasuf600", "cost": 0.0, "profile": "Lara Floriane", "password": "alasef10", "clicks": 19, "orderedItems": 3, "orderedRevenue": 51.84, "shippedItems": 6, "returnedItems": 0, "totalRevenue": 148.71, "commission": 5.41, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/8nl4GnND5X"},
    {"seq": 58, "date": "2026-10-08", "beneficiary": "شامي", "accountCode": "SH-02", "product": "شاحن لاسلكي أبل", "email": "aboaboah43", "cost": 0.0, "profile": "Armande Odilon", "password": "qqwwee123z", "clicks": 15, "orderedItems": 31, "orderedRevenue": 534.27, "shippedItems": 56, "returnedItems": 0, "totalRevenue": 1118.95, "commission": 34.87, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/yY1SFiBNeG"},
    {"seq": 59, "date": "2026-10-09", "beneficiary": "ابو مخلص", "accountCode": "MK-01", "product": "كرياتين", "email": "alasuf600", "cost": 1.43, "profile": "Lara Floriane", "password": "alasef10", "clicks": 896, "orderedItems": 10, "orderedRevenue": 162.48, "shippedItems": 5, "returnedItems": 0, "totalRevenue": 319.48, "commission": 9.12, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/8nl4GnND5X"},
    {"seq": 60, "date": "2026-10-09", "beneficiary": "شامي", "accountCode": "SH-05", "product": "ماكينة قهوي", "email": "abdalahsyd222", "cost": 1.53, "profile": "Calixte Athanase", "password": "alasef12", "clicks": 1134, "orderedItems": 4, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/prhaMFIZ9K"},
    {"seq": 61, "date": "2026-10-09", "beneficiary": "شامي", "accountCode": "SH-04", "product": "قناع وجه 1%", "email": "alasuf200", "cost": 0.91, "profile": "Michel Brunhilde", "password": "alasef10", "clicks": 1227, "orderedItems": 18, "orderedRevenue": 451.12, "shippedItems": 28, "returnedItems": 1, "totalRevenue": 602.75, "commission": 18.35, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/bUvpXyBVvH"},
    {"seq": 62, "date": "2026-10-09", "beneficiary": "شامي", "accountCode": "SH-03", "product": "شاحن لاسلكي أبل - أوكرانيا", "email": "alasuf700", "cost": 0.46, "profile": "Munroe Sharleen", "password": "alasef11", "clicks": 9, "orderedItems": 1, "orderedRevenue": 34.99, "shippedItems": 5, "returnedItems": 0, "totalRevenue": 88.97, "commission": 2.9, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/kKS1jSj7dZ"},
    {"seq": 63, "date": "2026-10-09", "beneficiary": "شامي", "accountCode": "SH-01", "product": "قناع وجه 3 %", "email": "josheprichad2555", "cost": 0.89, "profile": "Josefiina Eliina", "password": "..Sdf123..", "clicks": 226, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 1, "returnedItems": 0, "totalRevenue": 28.47, "commission": 0.85, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/hTJkFEO6dJ"},
    {"seq": 64, "date": "2026-10-09", "beneficiary": "شامي", "accountCode": "SH-04", "product": "قناع وجه 1%", "email": "alasuf200", "cost": 0.94, "profile": "Michel Brunhilde", "password": "alasef10", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": true, "adUrl": "https://t.co/bUvpXyBVvH"},
    {"seq": 65, "date": "2026-10-09", "beneficiary": "ابو مخلص", "accountCode": "MK-01", "product": "منفاخ هواء", "email": "alasuf600", "cost": 1.41, "profile": "Lara Floriane", "password": "alasef10", "clicks": 409, "orderedItems": 5, "orderedRevenue": 71.24, "shippedItems": 11, "returnedItems": 0, "totalRevenue": 166.97, "commission": 8.45, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/WAbruhKUYz"},
    {"seq": 66, "date": "2026-10-09", "beneficiary": "شامي", "accountCode": "SH-02", "product": "شاحن لاسلكي أبل", "email": "aboaboah43", "cost": 0.46, "profile": "Armande Odilon", "password": "qqwwee123z", "clicks": 664, "orderedItems": 4, "orderedRevenue": 40.44, "shippedItems": 16, "returnedItems": 1, "totalRevenue": 235.14, "commission": 7.54, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/yY1SFiBNeG"},
    {"seq": 67, "date": "2026-10-10", "beneficiary": "ابو مخلص", "accountCode": "MK-01", "product": "كرياتين", "email": "alasuf600", "cost": 0.0, "profile": "Lara Floriane", "password": "alasef10", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": true, "adUrl": "https://t.co/8nl4GnND5X"},
    {"seq": 68, "date": "2026-10-10", "beneficiary": "شامي", "accountCode": "SH-05", "product": "ماكينة قهوي", "email": "abdalahsyd222", "cost": 1.6, "profile": "Calixte Athanase", "password": "alasef12", "clicks": 1217, "orderedItems": 24, "orderedRevenue": 0.0, "shippedItems": 14, "returnedItems": 0, "totalRevenue": 0.0, "commission": 7.74, "bonus": 0.5, "isPending": false, "adUrl": "https://t.co/prhaMFIZ9K"},
    {"seq": 69, "date": "2026-10-10", "beneficiary": "شامي", "accountCode": "SH-04", "product": "قناع وجه 1%", "email": "alasuf200", "cost": 0.0, "profile": "Michel Brunhilde", "password": "alasef10", "clicks": 26, "orderedItems": 17, "orderedRevenue": 351.36, "shippedItems": 27, "returnedItems": 1, "totalRevenue": 880.78, "commission": 31.65, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/bUvpXyBVvH"},
    {"seq": 70, "date": "2026-10-10", "beneficiary": "شامي", "accountCode": "SH-03", "product": "شاحن لاسلكي أبل - أوكرانيا", "email": "alasuf700", "cost": 0.0, "profile": "Munroe Sharleen", "password": "alasef11", "clicks": 7, "orderedItems": 1, "orderedRevenue": 392.04, "shippedItems": 2, "returnedItems": 0, "totalRevenue": 400.03, "commission": 12.08, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/kKS1jSj7dZ"},
    {"seq": 71, "date": "2026-10-10", "beneficiary": "شامي", "accountCode": "SH-01", "product": "قناع وجه 3 %", "email": "josheprichad2555", "cost": 0.34, "profile": "Josefiina Eliina", "password": "..Sdf123..", "clicks": 137, "orderedItems": 1, "orderedRevenue": 29.95, "shippedItems": 1, "returnedItems": 0, "totalRevenue": 29.95, "commission": 0.3, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/hTJkFEO6dJ"},
    {"seq": 72, "date": "2026-10-10", "beneficiary": "شامي", "accountCode": "SH-04", "product": "قناع وجه 1%", "email": "alasuf200", "cost": 0.0, "profile": "Michel Brunhilde", "password": "alasef10", "clicks": 0, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": true, "adUrl": "https://t.co/bUvpXyBVvH"},
    {"seq": 73, "date": "2026-10-10", "beneficiary": "ابو مخلص", "accountCode": "MK-01", "product": "منفاخ هواء", "email": "alasuf600", "cost": 1.51, "profile": "Lara Floriane", "password": "alasef10", "clicks": 409, "orderedItems": 5, "orderedRevenue": 71.24, "shippedItems": 11, "returnedItems": 0, "totalRevenue": 166.97, "commission": 8.45, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/WAbruhKUYz"},
    {"seq": 74, "date": "2026-10-10", "beneficiary": "شامي", "accountCode": "SH-02", "product": "شاحن لاسلكي أبل", "email": "aboaboah43", "cost": 0.54, "profile": "Armande Odilon", "password": "qqwwee123z", "clicks": 393, "orderedItems": 4, "orderedRevenue": 58.47, "shippedItems": 44, "returnedItems": 0, "totalRevenue": 1389.66, "commission": 48.76, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/yY1SFiBNeG"},
    {"seq": 75, "date": "2026-10-11", "beneficiary": "شامي", "accountCode": "SH-05", "product": "ماكينة قهوي", "email": "abdalahsyd222", "cost": 0.0, "profile": "Calixte Athanase", "password": "alasef12", "clicks": 5, "orderedItems": 3, "orderedRevenue": 0.0, "shippedItems": 11, "returnedItems": 0, "totalRevenue": 0.0, "commission": 12.6, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/prhaMFIZ9K"},
    {"seq": 76, "date": "2026-10-11", "beneficiary": "شامي", "accountCode": "SH-04", "product": "قناع وجه 1%", "email": "alasuf200", "cost": 0.0, "profile": "Michel Brunhilde", "password": "alasef10", "clicks": 13, "orderedItems": 7, "orderedRevenue": 208.92, "shippedItems": 28, "returnedItems": 1, "totalRevenue": 381.21, "commission": 11.87, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/bUvpXyBVvH"},
    {"seq": 77, "date": "2026-10-11", "beneficiary": "شامي", "accountCode": "SH-02", "product": "شاحن لاسلكي أبل", "email": "aboaboah43", "cost": 0.0, "profile": "Armande Odilon", "password": "qqwwee123z", "clicks": 9, "orderedItems": 9, "orderedRevenue": 180.33, "shippedItems": 15, "returnedItems": 0, "totalRevenue": 312.31, "commission": 9.12, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/yY1SFiBNeG"},
    {"seq": 78, "date": "2026-10-11", "beneficiary": "ابو مخلص", "accountCode": "MK-01", "product": "منفاخ هواء", "email": "alasuf600", "cost": 0.0, "profile": "Lara Floriane", "password": "alasef10", "clicks": 18, "orderedItems": 1, "orderedRevenue": 7.14, "shippedItems": 4, "returnedItems": 0, "totalRevenue": 80.91, "commission": 3.13, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/WAbruhKUYz"},
    {"seq": 79, "date": "2026-10-11", "beneficiary": "شامي", "accountCode": "SH-01", "product": "قناع وجه 3 %", "email": "josheprichad2555", "cost": 0.0, "profile": "Josefiina Eliina", "password": "..Sdf123..", "clicks": 20, "orderedItems": 0, "orderedRevenue": 0.0, "shippedItems": 0, "returnedItems": 0, "totalRevenue": 0.0, "commission": 0.0, "bonus": 0.0, "isPending": false, "adUrl": "https://t.co/hTJkFEO6dJ"}
  ],
  "proxies": [
    {"country": "فرنسا", "isUsed": true, "portType": "ثابت", "protocol": "http", "username": "d40709dca079091ad4c6__cr.fr", "password": "8d8236cd708ed7c7", "host": "gw.dataimpulse.com", "port": 0},
    {"country": "فرنسا", "isUsed": false, "portType": "ثابت", "protocol": "http", "username": "d40709dca079091ad4c6__cr.fr", "password": "8d8236cd708ed7c7", "host": "gw.dataimpulse.com", "port": 0},
    {"country": "فرنسا", "isUsed": false, "portType": "ثابت", "protocol": "http", "username": "d40709dca079091ad4c6__cr.fr", "password": "8d8236cd708ed7c7", "host": "gw.dataimpulse.com", "port": 0},
    {"country": "فرنسا", "isUsed": false, "portType": "ثابت", "protocol": "http", "username": "d40709dca079091ad4c6__cr.fr", "password": "8d8236cd708ed7c7", "host": "gw.dataimpulse.com", "port": 10014},
    {"country": "فرنسا", "isUsed": false, "portType": "ثابت", "protocol": "http", "username": "d40709dca079091ad4c6__cr.fr", "password": "8d8236cd708ed7c7", "host": "gw.dataimpulse.com", "port": 10015},
    {"country": "فرنسا", "isUsed": false, "portType": "ثابت", "protocol": "http", "username": "d40709dca079091ad4c6__cr.fr", "password": "8d8236cd708ed7c7", "host": "gw.dataimpulse.com", "port": 10016},
    {"country": "فرنسا", "isUsed": false, "portType": "ثابت", "protocol": "http", "username": "d40709dca079091ad4c6__cr.fr", "password": "8d8236cd708ed7c7", "host": "gw.dataimpulse.com", "port": 10017},
    {"country": "فرنسا", "isUsed": false, "portType": "ثابت", "protocol": "http", "username": "d40709dca079091ad4c6__cr.fr", "password": "8d8236cd708ed7c7", "host": "gw.dataimpulse.com", "port": 10018},
    {"country": "فرنسا", "isUsed": false, "portType": "ثابت", "protocol": "http", "username": "d40709dca079091ad4c6__cr.fr", "password": "8d8236cd708ed7c7", "host": "gw.dataimpulse.com", "port": 10019},
    {"country": "فرنسا", "isUsed": false, "portType": "ثابت", "protocol": "http", "username": "d40709dca079091ad4c6__cr.fr", "password": "8d8236cd708ed7c7", "host": "gw.dataimpulse.com", "port": 10020},
    {"country": "فرنسا", "isUsed": false, "portType": "ثابت", "protocol": "http", "username": "d40709dca079091ad4c6__cr.fr", "password": "8d8236cd708ed7c7", "host": "gw.dataimpulse.com", "port": 10021},
    {"country": "فرنسا", "isUsed": false, "portType": "ثابت", "protocol": "http", "username": "d40709dca079091ad4c6__cr.fr", "password": "8d8236cd708ed7c7", "host": "gw.dataimpulse.com", "port": 10022},
    {"country": "أمريكا", "isUsed": false, "portType": "ثابت", "protocol": "http", "username": "d40709dca079091ad4c6__cr.us", "password": "8d8236cd708ed7c7", "host": "gw.dataimpulse.com", "port": 10023},
    {"country": "أمريكا", "isUsed": false, "portType": "ثابت", "protocol": "http", "username": "d40709dca079091ad4c6__cr.us", "password": "8d8236cd708ed7c7", "host": "gw.dataimpulse.com", "port": 10024},
    {"country": "أمريكا", "isUsed": false, "portType": "ثابت", "protocol": "http", "username": "d40709dca079091ad4c6__cr.us", "password": "8d8236cd708ed7c7", "host": "gw.dataimpulse.com", "port": 0},
    {"country": "أمريكا", "isUsed": false, "portType": "ثابت", "protocol": "http", "username": "d40709dca079091ad4c6__cr.us", "password": "8d8236cd708ed7c7", "host": "gw.dataimpulse.com", "port": 10026},
    {"country": "أمريكا", "isUsed": false, "portType": "ثابت", "protocol": "http", "username": "d40709dca079091ad4c6__cr.us", "password": "8d8236cd708ed7c7", "host": "gw.dataimpulse.com", "port": 10027},
    {"country": "ألمانيا", "isUsed": false, "portType": "ثابت", "protocol": "http", "username": "d40709dca079091ad4c6__cr.de", "password": "8d8236cd708ed7c7", "host": "gw.dataimpulse.com", "port": 0},
    {"country": "ألمانيا", "isUsed": false, "portType": "ثابت", "protocol": "http", "username": "d40709dca079091ad4c6__cr.de", "password": "8d8236cd708ed7c7", "host": "gw.dataimpulse.com", "port": 10029},
    {"country": "ألمانيا", "isUsed": false, "portType": "ثابت", "protocol": "http", "username": "d40709dca079091ad4c6__cr.de", "password": "8d8236cd708ed7c7", "host": "gw.dataimpulse.com", "port": 0},
    {"country": "ألمانيا", "isUsed": false, "portType": "ثابت", "protocol": "http", "username": "d40709dca079091ad4c6__cr.de", "password": "8d8236cd708ed7c7", "host": "gw.dataimpulse.com", "port": 10031},
    {"country": "ألمانيا", "isUsed": false, "portType": "ثابت", "protocol": "http", "username": "d40709dca079091ad4c6__cr.de", "password": "8d8236cd708ed7c7", "host": "gw.dataimpulse.com", "port": 0}
  ],
  "workflow_steps": [
    {"stepNumber": 1, "title": "إنشاء حساب جيميل", "details": "تجهيز بريد إلكتروني مخصص للعمل", "stage": "1. إعداد الحسابات", "isCompleted": false, "notes": ""},
    {"stepNumber": 2, "title": "إنشاء حساب جو لوجن (GoLogin)", "details": "تثبيت وضبط البرنامج", "stage": "1. إعداد الحسابات", "isCompleted": false, "notes": ""},
    {"stepNumber": 3, "title": "إنشاء 3 بروفايلات للمتصفح", "details": "توزيع المهام عبر البروفايلات", "stage": "2. المتصفح والبروكسي", "isCompleted": false, "notes": ""},
    {"stepNumber": 4, "title": "تفعيل البروكسي على البروفايلات", "details": "ربط البروكسي وضبط الدولة المناسبة", "stage": "2. المتصفح والبروكسي", "isCompleted": false, "notes": ""},
    {"stepNumber": 5, "title": "فتح البروفايل والتأكد من الاتصال", "details": "فحص IP وجودة الاتصال", "stage": "2. المتصفح والبروكسي", "isCompleted": false, "notes": ""},
    {"stepNumber": 6, "title": "تسجيل الدخول بحساب الجيميل", "details": "التحقق من الدخول وحفظ الجلسة", "stage": "2. المتصفح والبروكسي", "isCompleted": false, "notes": ""},
    {"stepNumber": 7, "title": "تجهيز أسماء حساب تويتر (X) عبر الذكاء الاصطناعي", "details": "استخراج أسماء مستعارة مقنعة ومتوافقة مع النيتش", "stage": "3. إعداد حساب تويتر (X)", "isCompleted": false, "notes": ""},
    {"stepNumber": 8, "title": "تسجيل الحساب بالاسم والمعرف المختار", "details": "إنشاء الحساب وضبط اسم المستخدم (@handle)", "stage": "3. إعداد حساب تويتر (X)", "isCompleted": false, "notes": ""},
    {"stepNumber": 9, "title": "تصميم صورة احترافية للبروفايل والغلاف", "details": "استخدام أدوات التصميم أو الذكاء الاصطناعي", "stage": "3. إعداد حساب تويتر (X)", "isCompleted": false, "notes": ""},
    {"stepNumber": 10, "title": "تعديل البايو (Bio) في البروفايل", "details": "كتابة سيرة ذاتية جذابة ومقنعة للمتابعين", "stage": "3. إعداد حساب تويتر (X)", "isCompleted": false, "notes": ""},
    {"stepNumber": 11, "title": "جلب وتعيين الموقع الجغرافي من خرائط جوجل", "details": "9 Rue des Archives, 75004 Paris, France", "stage": "3. إعداد حساب تويتر (X)", "isCompleted": false, "notes": ""},
    {"stepNumber": 12, "title": "الانتقال إلى موقع أمازون أفلييت", "details": "https://affiliate-program.amazon.com/", "stage": "4. إدارة منتجات أمازون", "isCompleted": false, "notes": ""},
    {"stepNumber": 13, "title": "جلب ID / معرف السلعة (ASIN)", "details": "اختيار منتج رابح ونسخ المعرف", "stage": "4. إدارة منتجات أمازون", "isCompleted": false, "notes": ""},
    {"stepNumber": 14, "title": "تحديد وتعبئة نوع المحتوى المطلوب", "details": "product review", "stage": "4. إدارة منتجات أمازون", "isCompleted": false, "notes": ""},
    {"stepNumber": 15, "title": "اختيار نوع الموقع / النشاط الأساسي", "details": "مدونة (Blog)", "stage": "4. إدارة منتجات أمازون", "isCompleted": false, "notes": ""},
    {"stepNumber": 16, "title": "تأكيد نوع النشاط الثانوي", "details": "مدونة (Blog)", "stage": "4. إدارة منتجات أمازون", "isCompleted": false, "notes": ""},
    {"stepNumber": 17, "title": "إنشاء نص تغريدة تسويقية بالذكاء الاصطناعي", "details": "صياغة نص جذاب مع رابط المنتج الأساسي", "stage": "5. النشر والترويج", "isCompleted": false, "notes": ""},
    {"stepNumber": 18, "title": "جلب رابط التتبع (Affiliate Link) من أمازون", "details": "مع استبدال الرابط الأساسي برابط التتبع", "stage": "5. النشر والترويج", "isCompleted": false, "notes": ""},
    {"stepNumber": 19, "title": "رفع وإرفاق صور عالية الجودة للمنتج", "details": "تنسيق الصور ضمن التغريدة لجذب الانتباه", "stage": "5. النشر والترويج", "isCompleted": false, "notes": ""},
    {"stepNumber": 20, "title": "نشر التغريدة وحفظ رابط التغريدة المباشر", "details": "[link removed]", "stage": "5. النشر والترويج", "isCompleted": false, "notes": ""},
    {"stepNumber": 21, "title": "إطلاق الترويج والتسويق للحملة", "details": "بدء الحملة الإعلانية ومتابعة التفاعل", "stage": "5. النشر والترويج", "isCompleted": false, "notes": ""}
  ],
  "bank_accounts": [
    {"iban": "LT343500010019212211", "beneficiaryName": "Nassima Kadeche", "bic": "EVIULT2VXXX", "bankName": "Paysera LT, UAB", "bankAddress": "Pilaitės pr. 16, Vilnius", "postalAndCountry": "LT-04352, Lithuania", "status": "تم الربط بنجاح", "verificationDoc": "", "amazonEmail": "josheprichad2555", "amazonAccountName": "Josefiina Eliina"},
    {"iban": "LT523500010019212178", "beneficiaryName": "Nassima Kadeche", "bic": "EVIULT2VXXX", "bankName": "Paysera LT, UAB", "bankAddress": "Pilaitės pr. 16, Vilnius", "postalAndCountry": "LT-04352, Lithuania", "status": "تم الربط بنجاح", "verificationDoc": "", "amazonEmail": "aboaboah43", "amazonAccountName": "Armande Odilon"},
    {"iban": "LT923500010019212234", "beneficiaryName": "Nassima Kadeche", "bic": "EVIULT2VXXX", "bankName": "Paysera LT, UAB", "bankAddress": "Pilaitės pr. 16, Vilnius", "postalAndCountry": "LT-04352, Lithuania", "status": "تم الربط بنجاح", "verificationDoc": "", "amazonEmail": "alasuf700", "amazonAccountName": "Munroe Sharleen"},
    {"iban": "LT653500010019212235", "beneficiaryName": "Nassima Kadeche", "bic": "EVIULT2VXXX", "bankName": "Paysera LT, UAB", "bankAddress": "Pilaitės pr. 16, Vilnius", "postalAndCountry": "LT-04352, Lithuania", "status": "تم الربط بنجاح", "verificationDoc": "", "amazonEmail": "alasuf200", "amazonAccountName": "Michel Brunhilde"},
    {"iban": "LT863500010019212245", "beneficiaryName": "Nassima Kadeche", "bic": "EVIULT2VXXX", "bankName": "Paysera LT, UAB", "bankAddress": "Pilaitės pr. 16, Vilnius", "postalAndCountry": "LT-04352, Lithuania", "status": "تم الربط بنجاح", "verificationDoc": "", "amazonEmail": "alasuf600", "amazonAccountName": "Lara Floriane"},
    {"iban": "LT593500010019212246", "beneficiaryName": "Nassima Kadeche", "bic": "EVIULT2VXXX", "bankName": "Paysera LT, UAB", "bankAddress": "Pilaitės pr. 16, Vilnius", "postalAndCountry": "LT-04352, Lithuania", "status": "تم الربط بنجاح", "verificationDoc": "", "amazonEmail": "abwasadsyd123", "amazonAccountName": "Fredy Christian"},
    {"iban": "LT323500010019212247", "beneficiaryName": "Nassima Kadeche", "bic": "EVIULT2VXXX", "bankName": "Paysera LT, UAB", "bankAddress": "Pilaitės pr. 16, Vilnius", "postalAndCountry": "LT-04352, Lithuania", "status": "تم الربط بنجاح", "verificationDoc": "", "amazonEmail": "abdalahsyd222", "amazonAccountName": "Calixte Athanase"},
    {"iban": "LT053500010019212248", "beneficiaryName": "Nassima Kadeche", "bic": "EVIULT2VXXX", "bankName": "Paysera LT, UAB", "bankAddress": "Pilaitės pr. 16, Vilnius", "postalAndCountry": "LT-04352, Lithuania", "status": "جاهز للربط", "verificationDoc": "", "amazonEmail": "", "amazonAccountName": ""},
    {"iban": "LT753500010019212249", "beneficiaryName": "Nassima Kadeche", "bic": "EVIULT2VXXX", "bankName": "Paysera LT, UAB", "bankAddress": "Pilaitės pr. 16, Vilnius", "postalAndCountry": "LT-04352, Lithuania", "status": "جاهز للربط", "verificationDoc": "", "amazonEmail": "", "amazonAccountName": ""},
    {"iban": "LT483500010019212250", "beneficiaryName": "Nassima Kadeche", "bic": "EVIULT2VXXX", "bankName": "Paysera LT, UAB", "bankAddress": "Pilaitės pr. 16, Vilnius", "postalAndCountry": "LT-04352, Lithuania", "status": "جاهز للربط", "verificationDoc": "", "amazonEmail": "", "amazonAccountName": ""},
    {"iban": "LT913500010019212252", "beneficiaryName": "Nassima Kadeche", "bic": "EVIULT2VXXX", "bankName": "Paysera LT, UAB", "bankAddress": "Pilaitės pr. 16, Vilnius", "postalAndCountry": "LT-04352, Lithuania", "status": "جاهز للربط", "verificationDoc": "", "amazonEmail": "", "amazonAccountName": ""},
    {"iban": "LT643500010019212253", "beneficiaryName": "Nassima Kadeche", "bic": "EVIULT2VXXX", "bankName": "Paysera LT, UAB", "bankAddress": "Pilaitės pr. 16, Vilnius", "postalAndCountry": "LT-04352, Lithuania", "status": "جاهز للربط", "verificationDoc": "", "amazonEmail": "", "amazonAccountName": ""},
    {"iban": "LT103500010019212255", "beneficiaryName": "Nassima Kadeche", "bic": "EVIULT2VXXX", "bankName": "Paysera LT, UAB", "bankAddress": "Pilaitės pr. 16, Vilnius", "postalAndCountry": "LT-04352, Lithuania", "status": "جاهز للربط", "verificationDoc": "", "amazonEmail": "", "amazonAccountName": ""},
    {"iban": "LT803500010019212256", "beneficiaryName": "Nassima Kadeche", "bic": "EVIULT2VXXX", "bankName": "Paysera LT, UAB", "bankAddress": "Pilaitės pr. 16, Vilnius", "postalAndCountry": "LT-04352, Lithuania", "status": "جاهز للربط", "verificationDoc": "", "amazonEmail": "", "amazonAccountName": ""},
    {"iban": "LT533500010019212257", "beneficiaryName": "Nassima Kadeche", "bic": "EVIULT2VXXX", "bankName": "Paysera LT, UAB", "bankAddress": "Pilaitės pr. 16, Vilnius", "postalAndCountry": "LT-04352, Lithuania", "status": "جاهز للربط", "verificationDoc": "", "amazonEmail": "", "amazonAccountName": ""},
    {"iban": "LT263500010019212258", "beneficiaryName": "Nassima Kadeche", "bic": "EVIULT2VXXX", "bankName": "Paysera LT, UAB", "bankAddress": "Pilaitės pr. 16, Vilnius", "postalAndCountry": "LT-04352, Lithuania", "status": "جاهز للربط", "verificationDoc": "", "amazonEmail": "", "amazonAccountName": ""},
    {"iban": "LT963500010019212259", "beneficiaryName": "Nassima Kadeche", "bic": "EVIULT2VXXX", "bankName": "Paysera LT, UAB", "bankAddress": "Pilaitės pr. 16, Vilnius", "postalAndCountry": "LT-04352, Lithuania", "status": "جاهز للربط", "verificationDoc": "", "amazonEmail": "", "amazonAccountName": ""}
  ],
  "platforms": [
    {"category": "منصة اعلانية", "name": "clickadu", "usernameOrEmail": "shamiwoork", "password": "..S", "notes": "", "url": "https://adv.clickadu.com/dashboard"},
    {"category": "منصة اعلانية", "name": "adsterra", "usernameOrEmail": "shamiwoork", "password": "..S", "notes": "تم شحن 100$", "url": "https://beta.partners.adsterra.com/"},
    {"category": "منصة اعلانية", "name": "richads", "usernameOrEmail": "shamiwoork", "password": "..S", "notes": "", "url": "https://my.richads.com/campaigns"},
    {"category": "منصة اعلانية", "name": "rollerads", "usernameOrEmail": "shamiwoork", "password": "..S", "notes": "", "url": "https://my.rollerads.com/"},
    {"category": "PROXY", "name": "dataimpulse", "usernameOrEmail": "kloklop6", "password": "", "notes": "تم الشحن  50$", "url": "https://app.dataimpulse.com/"},
    {"category": "منصة إعلانية (PropellerAds)", "name": "بلوبلر ادس", "usernameOrEmail": "shamiwoork@gmail.com", "password": "..S", "notes": "التوثيق: رقم ن ج", "url": "https://partners.propellerads.com/"}
  ],
  "promo_times": [
    {"windowName": "🏆 النافذة الذهبية الكبرى (ذروة الشراء)", "syriaTime": "01:00 ليلاً حتى 06:00 صباحاً", "usTime": "06:00 مساءً حتى 11:00 ليلاً"},
    {"windowName": "☕ نافذة استراحة الغداء (شراء سريع)", "syriaTime": "07:00 مساءً حتى 09:00 مساءً", "usTime": "12:00 ظهراً حتى 02:00 ظهراً"},
    {"windowName": "🌉 امتداد الساحل الغربي (كاليفورنيا)", "syriaTime": "06:00 صباحاً حتى 08:30 صباحاً", "usTime": "08:00 مساءً حتى 10:30 ليلاً PDT"},
    {"windowName": "💤 الساعات الميتة (احذر تشغيل الإعلانات)", "syriaTime": "08:30 صباحاً حتى 02:00 ظهراً", "usTime": "01:30 ليلاً حتى 07:00 صباحاً"}
  ]
}
''';

// ============================================================================
// 3. مزود الحالة وقاعدة البيانات المحلية (App State & Local Windows Persistence)
// ============================================================================

class AppDataController extends ChangeNotifier {
  List<BeneficiaryModel> beneficiaries = [];
  List<ProductCatalogModel> productsCatalog = [];
  List<CampaignLogModel> campaigns = [];
  List<AmazonAccountModel> amazonAccounts = [];
  List<HistoricalLinkModel> historicalLinks = [];
  List<EmailAccountModel> emails = [];
  List<GoLoginAccountModel> gologinAccounts = [];
  List<ProxyModel> proxies = [];
  List<BankAccountModel> bankAccounts = [];
  List<PlatformAccountModel> platforms = [];
  List<PromoTimeWindowModel> promoTimes = [];
  List<WorkflowStepModel> workflowSteps = [];

  bool isDarkMode = true;
  String lastSavedPath = '';

  AppDataController() {
    _initData();
  }

  File get _localDbFile {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    return File('$home${Platform.pathSeparator}amazon_affiliate_erp_db.json');
  }

  Future<void> _initData() async {
    try {
      final file = _localDbFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        _loadFromJsonMap(jsonDecode(content) as Map<String, dynamic>);
        lastSavedPath = file.path;
        notifyListeners();
        return;
      }
    } catch (_) {}
    resetToFactoryData();
  }

  void _loadFromJsonMap(Map<String, dynamic> map) {
    beneficiaries = ((map['beneficiaries'] ?? []) as List)
        .map((e) => BeneficiaryModel.fromJson(e as Map<String, dynamic>))
        .toList();
    productsCatalog = ((map['products_catalog'] ?? []) as List)
        .map((e) => ProductCatalogModel.fromJson(e as Map<String, dynamic>))
        .toList();
    campaigns = ((map['campaigns'] ?? []) as List)
        .map((e) => CampaignLogModel.fromJson(e as Map<String, dynamic>))
        .toList();
    amazonAccounts = ((map['amazon_accounts'] ?? []) as List)
        .map((e) => AmazonAccountModel.fromJson(e as Map<String, dynamic>))
        .toList();
    historicalLinks = ((map['historical_links'] ?? []) as List)
        .map((e) => HistoricalLinkModel.fromJson(e as Map<String, dynamic>))
        .toList();
    emails = ((map['emails'] ?? []) as List)
        .map((e) => EmailAccountModel.fromJson(e as Map<String, dynamic>))
        .toList();
    gologinAccounts = ((map['gologin'] ?? []) as List)
        .map((e) => GoLoginAccountModel.fromJson(e as Map<String, dynamic>))
        .toList();
    proxies = ((map['proxies'] ?? []) as List)
        .map((e) => ProxyModel.fromJson(e as Map<String, dynamic>))
        .toList();
    bankAccounts = ((map['bank_accounts'] ?? []) as List)
        .map((e) => BankAccountModel.fromJson(e as Map<String, dynamic>))
        .toList();
    platforms = ((map['platforms'] ?? []) as List)
        .map((e) => PlatformAccountModel.fromJson(e as Map<String, dynamic>))
        .toList();
    promoTimes = ((map['promo_times'] ?? []) as List)
        .map((e) => PromoTimeWindowModel.fromJson(e as Map<String, dynamic>))
        .toList();
    workflowSteps = ((map['workflow_steps'] ?? []) as List)
        .map((e) => WorkflowStepModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> toFullJsonMap() => {
        'beneficiaries': beneficiaries.map((e) => e.toJson()).toList(),
        'products_catalog': productsCatalog.map((e) => e.toJson()).toList(),
        'campaigns': campaigns.map((e) => e.toJson()).toList(),
        'amazon_accounts': amazonAccounts.map((e) => e.toJson()).toList(),
        'historical_links': historicalLinks.map((e) => e.toJson()).toList(),
        'emails': emails.map((e) => e.toJson()).toList(),
        'gologin': gologinAccounts.map((e) => e.toJson()).toList(),
        'proxies': proxies.map((e) => e.toJson()).toList(),
        'bank_accounts': bankAccounts.map((e) => e.toJson()).toList(),
        'platforms': platforms.map((e) => e.toJson()).toList(),
        'promo_times': promoTimes.map((e) => e.toJson()).toList(),
        'workflow_steps': workflowSteps.map((e) => e.toJson()).toList(),
      };

  Future<void> saveToDisk() async {
    try {
      final file = _localDbFile;
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(toFullJsonMap()),
      );
      lastSavedPath = file.path;
    } catch (_) {}
    notifyListeners();
  }

  void resetToFactoryData() {
    final map = jsonDecode(kInitialSeedJson) as Map<String, dynamic>;
    _loadFromJsonMap(map);
    saveToDisk();
  }

  void toggleTheme() {
    isDarkMode = !isDarkMode;
    notifyListeners();
  }

  // ------------------ المؤشرات المالية والإحصائية الشاملة ------------------
  double get totalSubscribedCapital =>
      beneficiaries.fold(0.0, (s, b) => s + b.baseCapital);

  double get totalCampaignSpend => campaigns.fold(0.0, (s, c) => s + c.cost);

  double get totalRemainingLiquidity =>
      totalSubscribedCapital - totalCampaignSpend;

  double get totalGrossEarnings =>
      campaigns.fold(0.0, (s, c) => s + c.totalEarnings);

  double get totalNetProfit => campaigns.fold(0.0, (s, c) => s + c.netProfit);

  double get overallRoi =>
      totalCampaignSpend > 0 ? (totalNetProfit / totalCampaignSpend) : 0.0;

  int get totalClicks => campaigns.fold(0, (s, c) => s + c.clicks);
  int get totalOrderedItems => campaigns.fold(0, (s, c) => s + c.orderedItems);
  int get totalShippedItems => campaigns.fold(0, (s, c) => s + c.shippedItems);
  double get totalSalesVolume =>
      campaigns.fold(0.0, (s, c) => s + c.totalRevenue);

  int get activeAmazonCount =>
      amazonAccounts.where((a) => a.status.trim() == 'نشط').length;
  int get bannedAmazonCount =>
      amazonAccounts.where((a) => a.status.trim() == 'محظور').length;

  int get activeTweetsCount {
    int count = 0;
    for (final a in amazonAccounts) {
      if (a.promoStatus1 == 'جاري الترويج' && a.tweetUrl1.isNotEmpty) count++;
      if (a.promoStatus2 == 'جاري الترويج' && a.tweetUrl2.isNotEmpty) count++;
    }
    return count;
  }

  int get activeAdsterraCount => amazonAccounts
      .where(
          (a) => a.promoStatus1 == 'جاري الترويج' && a.adsterraUrl.isNotEmpty)
      .length;

  int get linkedBanksCount => bankAccounts.where((b) => b.isLinked).length;
  int get usedProxiesCount => proxies.where((p) => p.isUsed).length;
  int get completedStepsCount =>
      workflowSteps.where((w) => w.isCompleted).length;

  // حساب إحصائيات مستفيد معين
  Map<String, dynamic> getBeneficiaryMetrics(BeneficiaryModel b) {
    final bCampaigns =
        campaigns.where((c) => c.beneficiary.trim() == b.name.trim()).toList();
    final spent = bCampaigns.fold(0.0, (s, c) => s + c.cost);
    final earnings = bCampaigns.fold(0.0, (s, c) => s + c.totalEarnings);
    final net = bCampaigns.fold(0.0, (s, c) => s + c.netProfit);
    final remaining = b.baseCapital - spent;
    final roi = spent > 0 ? net / spent : 0.0;
    String statusAlert;
    if (b.baseCapital == 0 && spent == 0) {
      statusAlert = '⏳ بانتظار الشحن';
    } else if (remaining <= 0) {
      statusAlert = '⚠️ رصيد منتهي - يلزم الشحن';
    } else if (remaining <= 15) {
      statusAlert = '⚠️ رصيد منخفض';
    } else {
      statusAlert = '✅ رصيد كافٍ';
    }
    return {
      'campaignsCount': bCampaigns.length,
      'spent': spent,
      'earnings': earnings,
      'netProfit': net,
      'remaining': remaining,
      'roi': roi,
      'statusAlert': statusAlert,
    };
  }

  // البحث التلقائي عن بيانات المنتج (مطابق لمعادلة VLOOKUP في الإكسل)
  ProductCatalogModel? findCatalogByProduct(String productName) {
    try {
      return productsCatalog.firstWhere(
        (p) => p.product.trim() == productName.trim(),
      );
    } catch (_) {
      return null;
    }
  }
}

// ============================================================================
// 4. التطبيق الرئيسي والسمات (Main Windows App & Fluent/Material3 Themes)
// ============================================================================

class AmazonAffiliateWindowsApp extends StatefulWidget {
  const AmazonAffiliateWindowsApp({super.key});

  @override
  State<AmazonAffiliateWindowsApp> createState() =>
      _AmazonAffiliateWindowsAppState();
}

class _AmazonAffiliateWindowsAppState extends State<AmazonAffiliateWindowsApp> {
  final AppDataController controller = AppDataController();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final darkScheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFF0EA5E9),
          brightness: Brightness.dark,
          surface: const Color(0xFF0F172A),
          primary: const Color(0xFF38BDF8),
          secondary: const Color(0xFF10B981),
        );
        final lightScheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFF0284C7),
          brightness: Brightness.light,
          surface: const Color(0xFFF8FAFC),
          primary: const Color(0xFF0284C7),
          secondary: const Color(0xFF059669),
        );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'منظومة إدارة أمازون أفلييت والحملات الإعلانية - Windows ERP',
          themeMode: controller.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightScheme,
            scaffoldBackgroundColor: const Color(0xFFF1F5F9),
            fontFamily: 'Segoe UI',
            cardTheme: CardThemeData(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkScheme,
            scaffoldBackgroundColor: const Color(0xFF090D16),
            fontFamily: 'Segoe UI',
            cardTheme: CardThemeData(
              elevation: 0,
              color: const Color(0xFF111827),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFF1E293B)),
              ),
            ),
          ),
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            );
          },
          home: WindowsDesktopShell(controller: controller),
        );
      },
    );
  }
}

// ============================================================================
// 5. الهيكل الرئيسي لسطح المكتب (Windows 11 Desktop Navigation Shell)
// ============================================================================

class NavItemSpec {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String Function(AppDataController) badgeBuilder;

  const NavItemSpec({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.badgeBuilder,
  });
}

class WindowsDesktopShell extends StatefulWidget {
  final AppDataController controller;
  const WindowsDesktopShell({super.key, required this.controller});

  @override
  State<WindowsDesktopShell> createState() => _WindowsDesktopShellState();
}

class _WindowsDesktopShellState extends State<WindowsDesktopShell> {
  int _selectedIndex = 0;
  bool? _sidebarExpansionOverride;

  late final List<NavItemSpec> _navItems = [
    NavItemSpec(
      title: 'التقرير التنفيذي الشامل',
      subtitle: 'نظرة استراتيجية شاملة للمنظومة',
      icon: Icons.dashboard_customize_rounded,
      accent: const Color(0xFF38BDF8),
      badgeBuilder: (c) => '\$${c.totalNetProfit.toStringAsFixed(0)}',
    ),
    NavItemSpec(
      title: 'الأرباح والجرد اليومي',
      subtitle: 'تسجيل الحملات وحساب العائد لحظياً',
      icon: Icons.analytics_rounded,
      accent: const Color(0xFF10B981),
      badgeBuilder: (c) => '${c.campaigns.length}',
    ),
    NavItemSpec(
      title: 'دليل المنتجات والمستفيدين',
      subtitle: 'إدارة رؤوس الأموال والتعبئة التلقائية',
      icon: Icons.account_balance_wallet_rounded,
      accent: const Color(0xFFF59E0B),
      badgeBuilder: (c) => '${c.productsCatalog.length}',
    ),
    NavItemSpec(
      title: 'حسابات أمازون والأرشيف',
      subtitle: 'المتاجر، التغريدات، وروابط الأفلييت',
      icon: Icons.shopping_bag_rounded,
      accent: const Color(0xFFFB923C),
      badgeBuilder: (c) => '${c.activeAmazonCount}/${c.amazonAccounts.length}',
    ),
    NavItemSpec(
      title: 'حسابات البريد (EMAIL)',
      subtitle: 'متابعة الجيميل، التوثيق، والأرقام',
      icon: Icons.alternate_email_rounded,
      accent: const Color(0xFF818CF8),
      badgeBuilder: (c) => '${c.emails.length}',
    ),
    NavItemSpec(
      title: 'حسابات جو لوجن (GoLogin)',
      subtitle: 'إدارة وعزل البروفايلات الرقمية',
      icon: Icons.web_asset_rounded,
      accent: const Color(0xFFA855F7),
      badgeBuilder: (c) => '${c.gologinAccounts.length}',
    ),
    NavItemSpec(
      title: 'إدارة البروكسي (Proxies)',
      subtitle: 'DataImpulse بروكسيات ثابتة حسب الدولة',
      icon: Icons.vpn_key_rounded,
      accent: const Color(0xFF2DD4BF),
      badgeBuilder: (c) => '${c.usedProxiesCount}/${c.proxies.length}',
    ),
    NavItemSpec(
      title: 'الحسابات البنكية (Paysera)',
      subtitle: 'أرقام الآيبان IBAN وربطها بأمازون',
      icon: Icons.account_balance_rounded,
      accent: const Color(0xFF60A5FA),
      badgeBuilder: (c) => '${c.linkedBanksCount}/${c.bankAccounts.length}',
    ),
    NavItemSpec(
      title: 'المنصات وأوقات الترويج',
      subtitle: 'شبكات الإعلانات، بلوبلر، وذروة أمريكا',
      icon: Icons.rocket_launch_rounded,
      accent: const Color(0xFFF43F5E),
      badgeBuilder: (c) => '${c.platforms.length}',
    ),
    NavItemSpec(
      title: 'دليل وخطوات العمل',
      subtitle: 'خطة التشغيل القياسية 21 خطوة',
      icon: Icons.checklist_rtl_rounded,
      accent: const Color(0xFF34D399),
      badgeBuilder: (c) => '${c.completedStepsCount}/${c.workflowSteps.length}',
    ),
    NavItemSpec(
      title: 'استخراج بيانات التقارير',
      subtitle: 'تحليل صور الأرباح والحملات ونسخها للشيت',
      icon: Icons.document_scanner_rounded,
      accent: const Color(0xFF38BDF8),
      badgeBuilder: (c) => 'Gemini',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final theme = Theme.of(context);
    final isDark = c.isDarkMode;
    final isSidebarExpanded =
        _sidebarExpansionOverride ?? MediaQuery.sizeOf(context).width >= 1100;

    return Scaffold(
      body: Row(
        children: [
          // الشريط الجانبي الاحترافي لنظام ويندوز
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: isSidebarExpanded ? 280 : 78,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1322) : Colors.white,
              border: Border(
                left: BorderSide(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Column(
              children: [
                // شعار المنظومة في الأعلى
                Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0EA5E9), Color(0xFF10B981)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.hub_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      if (isSidebarExpanded) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'منظومة أمازون الرقمية',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'متزامن ومترابط بالكامل 🟢',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: theme.colorScheme.secondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                      IconButton(
                        tooltip: isSidebarExpanded
                            ? 'طي القائمة الجانبية'
                            : 'توسيع القائمة الجانبية',
                        icon: Icon(
                          isSidebarExpanded
                              ? Icons.menu_open_rounded
                              : Icons.menu_rounded,
                          size: 20,
                        ),
                        onPressed: () => setState(
                          () => _sidebarExpansionOverride = !isSidebarExpanded,
                        ),
                      ),
                    ],
                  ),
                ),
                // عناصر التنقل
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    itemCount: _navItems.length,
                    itemBuilder: (context, idx) {
                      final item = _navItems[idx];
                      final selected = _selectedIndex == idx;
                      final badge = item.badgeBuilder(c);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(11),
                          onTap: () => setState(() => _selectedIndex = idx),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? item.accent
                                      .withOpacity(isDark ? 0.16 : 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: selected
                                    ? item.accent.withOpacity(0.5)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item.icon,
                                  color: selected
                                      ? item.accent
                                      : theme.colorScheme.onSurface
                                          .withOpacity(0.65),
                                  size: 22,
                                ),
                                if (isSidebarExpanded) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: TextStyle(
                                            fontWeight: selected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontSize: 13.5,
                                            color: selected
                                                ? item.accent
                                                : theme.colorScheme.onSurface,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          item.subtitle,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.55),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: item.accent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      badge,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: item.accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // تذييل الشريط الجانبي (حفظ، تصدير، الوضع الليلي)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  child: isSidebarExpanded
                      ? Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: Icon(
                                      isDark
                                          ? Icons.light_mode_rounded
                                          : Icons.dark_mode_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      isDark ? 'الوضع النهاري' : 'الوضع الليلي',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    onPressed: c.toggleTheme,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  tooltip: 'تصدير / نسخ احتياطي JSON',
                                  icon: const Icon(
                                    Icons.download_rounded,
                                    size: 19,
                                  ),
                                  onPressed: () => _showBackupDialog(context),
                                ),
                                IconButton(
                                  tooltip: 'استعادة البيانات الأصلية من الإكسل',
                                  icon: const Icon(
                                    Icons.restore_rounded,
                                    size: 19,
                                  ),
                                  onPressed: () => _confirmReset(context),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            IconButton(
                              icon: Icon(
                                isDark
                                    ? Icons.light_mode_rounded
                                    : Icons.dark_mode_rounded,
                              ),
                              onPressed: c.toggleTheme,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),

          // مساحة العمل الرئيسية (Main Content Area)
          Expanded(
            child: Column(
              children: [
                _buildTopHeaderBar(context),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      ExecutiveDashboardScreen(
                        controller: c,
                        onNavigate: (i) => setState(() => _selectedIndex = i),
                      ),
                      CampaignsInventoryScreen(controller: c),
                      BeneficiariesAndCatalogScreen(controller: c),
                      AmazonAccountsScreen(controller: c),
                      EmailAccountsScreen(controller: c),
                      GoLoginScreen(controller: c),
                      ProxiesScreen(controller: c),
                      BankAccountsScreen(controller: c),
                      PlatformsAndTimingScreen(controller: c),
                      WorkflowStepsScreen(controller: c),
                      Builder(
                        builder: (ctx) => ReportImageImportScreen(
                          onImportCampaigns: (rows) =>
                              showCampaignImportDialog(ctx, c, rows),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeaderBar(BuildContext context) {
    final c = widget.controller;
    final currentNav = _navItems[_selectedIndex];
    final isDark = c.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1322) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: Row(
              children: [
                Icon(currentNav.icon, color: currentNav.accent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentNav.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        currentNav.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // شريط مؤشرات مالية سريعة في الأعلى دائماً
          _topQuickPill(
            label: 'رأس المال',
            value: '\$${c.totalSubscribedCapital.toStringAsFixed(0)}',
            color: const Color(0xFF38BDF8),
          ),
          _topQuickPill(
            label: 'المصروف',
            value: '\$${c.totalCampaignSpend.toStringAsFixed(2)}',
            color: const Color(0xFFF59E0B),
          ),
          _topQuickPill(
            label: 'إجمالي الأرباح',
            value: '\$${c.totalGrossEarnings.toStringAsFixed(2)}',
            color: const Color(0xFF10B981),
          ),
          _topQuickPill(
            label: 'صافي الربح',
            value: '\$${c.totalNetProfit.toStringAsFixed(2)}',
            color: const Color(0xFF34D399),
          ),
          _topQuickPill(
            label: 'العائد ROI',
            value: '${(c.overallRoi * 100).toStringAsFixed(1)}%',
            color: const Color(0xFFA855F7),
          ),
        ],
      ),
    );
  }

  Widget _topQuickPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showBackupDialog(BuildContext context) {
    final jsonStr = const JsonEncoder.withIndent('  ')
        .convert(widget.controller.toFullJsonMap());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('نسخ احتياطي / تصدير قاعدة البيانات (JSON)'),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'يتم حفظ كافة التعديلات تلقائياً على جهاز الويندوز في المسار:\n${widget.controller.lastSavedPath}',
                style: const TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              Container(
                height: 260,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    jsonStr,
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('نسخ JSON بالكامل'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم نسخ قاعدة البيانات بالكامل إلى الحافظة ✅'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة البيانات الأصلية'),
        content: const Text(
          'هل ترغب في إعادة ضبط كافة الجداول إلى البيانات الأصلية المستخرجة من ملف الإكسل (أمزون عمل 2.xlsx)؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              widget.controller.resetToFactoryData();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تمت استعادة البيانات الأصلية بنجاح ✅'),
                ),
              );
            },
            child: const Text('تأكيد الاستعادة'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// أدوات مساعدة مشتركة للواجهات (Shared UI Helpers)
// ============================================================================

void copyToClipboard(BuildContext context, String text, [String? label]) {
  if (text.trim().isEmpty) return;
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      width: 360,
      content: Text(
        label != null ? 'تم نسخ $label: $text ✅' : 'تم النسخ: $text ✅',
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

Widget buildStatusBadge(String text) {
  Color color = const Color(0xFF38BDF8);
  if (text.contains('نشط') ||
      text.contains('يعمل') ||
      text.contains('كافٍ') ||
      text.contains('رابحة') ||
      text.contains('كرر') ||
      text.contains('بنجاح') ||
      text.contains('ممتازة') ||
      text.contains('نعم')) {
    color = const Color(0xFF10B981);
  } else if (text.contains('محظور') ||
      text.contains('مقفول') ||
      text.contains('إيقاف') ||
      text.contains('منتهي') ||
      text.contains('خسارة')) {
    color = const Color(0xFFF43F5E);
  } else if (text.contains('مراجعة') ||
      text.contains('منخفض') ||
      text.contains('تعديل') ||
      text.contains('انتظار') ||
      text.contains('جاهز')) {
    color = const Color(0xFFF59E0B);
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(
      text.isEmpty ? 'غير محدد' : text,
      style: TextStyle(
        color: color,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class ResponsiveKpiGrid extends StatelessWidget {
  final List<Widget> cards;
  final double minCardWidth;
  final double spacing;

  const ResponsiveKpiGrid({
    super.key,
    required this.cards,
    this.minCardWidth = 230,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = cards.isEmpty
            ? 1
            : (constraints.maxWidth / minCardWidth)
                .floor()
                .clamp(1, cards.length)
                .toInt();
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }
}

class ResponsiveSplit extends StatelessWidget {
  final Widget first;
  final Widget second;
  final double breakpoint;
  final double spacing;

  const ResponsiveSplit({
    super.key,
    required this.first,
    required this.second,
    this.breakpoint = 900,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, SizedBox(height: spacing), second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            SizedBox(width: spacing),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class KpiStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const KpiStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// الشاشة 1: التقرير التنفيذي الشامل (Executive Dashboard Screen)
// ============================================================================

class ExecutiveDashboardScreen extends StatelessWidget {
  final AppDataController controller;
  final void Function(int) onNavigate;

  const ExecutiveDashboardScreen({
    super.key,
    required this.controller,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final bankActivationPct = c.bankAccounts.isNotEmpty
        ? (c.linkedBanksCount / c.bankAccounts.length * 100).toStringAsFixed(1)
        : '0.0';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // صف المؤشرات المالية الـ 4 الكبرى
          ResponsiveKpiGrid(
            cards: [
              KpiStatCard(
                title: '💵 رأس المال الأساسي المكتتب',
                value: '\$${c.totalSubscribedCapital.toStringAsFixed(2)}',
                subtitle:
                    'المصروف: \$${c.totalCampaignSpend.toStringAsFixed(2)} | السيولة: \$${c.totalRemainingLiquidity.toStringAsFixed(2)}',
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFF38BDF8),
                onTap: () => onNavigate(2),
              ),
              KpiStatCard(
                title: '💰 إجمالي الأرباح الإجمالية',
                value: '\$${c.totalGrossEarnings.toStringAsFixed(2)}',
                subtitle:
                    'إجمالي المبيعات: \$${c.totalSalesVolume.toStringAsFixed(2)} (${c.totalShippedItems} مشحون)',
                icon: Icons.monetization_on_rounded,
                color: const Color(0xFF10B981),
                onTap: () => onNavigate(1),
              ),
              KpiStatCard(
                title: '📈 إجمالي صافي الأرباح',
                value: '\$${c.totalNetProfit.toStringAsFixed(2)}',
                subtitle:
                    'بعد خصم تكاليف ${c.campaigns.length} حملة إعلانية مسجلة',
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF34D399),
                onTap: () => onNavigate(1),
              ),
              KpiStatCard(
                title: '📊 معدل العائد الاستثماري (ROI)',
                value: '${(c.overallRoi * 100).toStringAsFixed(1)}%',
                subtitle:
                    'مضاعف الربح: ${c.overallRoi.toStringAsFixed(2)}x من التكلفة',
                icon: Icons.pie_chart_rounded,
                color: const Color(0xFFA855F7),
                onTap: () => onNavigate(1),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // صف مؤشرات البنية التشغيلية الـ 4
          ResponsiveKpiGrid(
            cards: [
              KpiStatCard(
                title: '👥 حسابات أمازون النشطة',
                value: '${c.activeAmazonCount} / ${c.amazonAccounts.length}',
                subtitle:
                    '${c.activeTweetsCount} تغريدة نشطة | ${c.activeAdsterraCount} حملات أدس تيرا',
                icon: Icons.storefront_rounded,
                color: const Color(0xFFFB923C),
                onTap: () => onNavigate(3),
              ),
              KpiStatCard(
                title: '🏦 الحسابات البنكية المفعلة',
                value: '${c.linkedBanksCount} / ${c.bankAccounts.length}',
                subtitle: 'نسبة التفعيل والربط: $bankActivationPct%',
                icon: Icons.account_balance_rounded,
                color: const Color(0xFF60A5FA),
                onTap: () => onNavigate(7),
              ),
              KpiStatCard(
                title: '🌐 أصول البروكسي والمتصفح',
                value: '${c.usedProxiesCount} / ${c.proxies.length}',
                subtitle:
                    'حسابات GoLogin: ${c.gologinAccounts.length} (9 بروفايلات)',
                icon: Icons.language_rounded,
                color: const Color(0xFF2DD4BF),
                onTap: () => onNavigate(6),
              ),
              KpiStatCard(
                title: '🎯 معدل إنجاز خطوات العمل',
                value:
                    '${c.workflowSteps.isEmpty ? 0 : (c.completedStepsCount / c.workflowSteps.length * 100).toStringAsFixed(0)}%',
                subtitle:
                    'أنجز ${c.completedStepsCount} من أصل ${c.workflowSteps.length} خطوة قياسية',
                icon: Icons.task_alt_rounded,
                color: const Color(0xFFF43F5E),
                onTap: () => onNavigate(9),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // جدول أرصدة المستفيدين وأرباحهم جنباً إلى جنب
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.people_alt_rounded,
                        color: Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'أرصدة المستفيدين وتتبع حركة رؤوس الأموال والأرباح',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('إدارة المستفيدين'),
                        onPressed: () => onNavigate(2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 44,
                      dataRowMinHeight: 44,
                      dataRowMaxHeight: 52,
                      columns: const [
                        DataColumn(label: Text('م')),
                        DataColumn(label: Text('المستفيد (رمز الحساب)')),
                        DataColumn(label: Text('رأس المال الأساسي')),
                        DataColumn(label: Text('المصروف')),
                        DataColumn(label: Text('الرصيد المتبقي')),
                        DataColumn(label: Text('حالة الرصيد')),
                        DataColumn(label: Text('عدد الحملات')),
                        DataColumn(label: Text('إجمالي الأرباح')),
                        DataColumn(label: Text('صافي الربح')),
                        DataColumn(label: Text('العائد ROI %')),
                      ],
                      rows: [
                        ...c.beneficiaries.map((b) {
                          final m = c.getBeneficiaryMetrics(b);
                          final net = m['netProfit'] as double;
                          final rem = m['remaining'] as double;
                          final roi = m['roi'] as double;
                          return DataRow(
                            cells: [
                              DataCell(Text('${b.id}')),
                              DataCell(
                                Text(
                                  '${b.name} (${b.accountCodeRange})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text('\$${b.baseCapital.toStringAsFixed(2)}'),
                              ),
                              DataCell(
                                Text(
                                  '\$${(m['spent'] as double).toStringAsFixed(3)}',
                                ),
                              ),
                              DataCell(
                                Text(
                                  '\$${rem.toStringAsFixed(3)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: rem < 0
                                        ? const Color(0xFFF43F5E)
                                        : const Color(0xFF10B981),
                                  ),
                                ),
                              ),
                              DataCell(
                                buildStatusBadge(m['statusAlert'] as String),
                              ),
                              DataCell(Text('${m['campaignsCount']} حملة')),
                              DataCell(
                                Text(
                                  '\$${(m['earnings'] as double).toStringAsFixed(2)}',
                                ),
                              ),
                              DataCell(
                                Text(
                                  '\$${net.toStringAsFixed(3)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: net >= 0
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFF43F5E),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${(roi * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: roi >= 0
                                        ? const Color(0xFF38BDF8)
                                        : const Color(0xFFF43F5E),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                        // صف الإجمالي
                        DataRow(
                          color: WidgetStateProperty.all(
                            const Color(0xFF38BDF8).withOpacity(0.08),
                          ),
                          cells: [
                            const DataCell(
                              Text(
                                'الإجمالي',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${c.beneficiaries.length} مستفيدين',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '\$${c.totalSubscribedCapital.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '\$${c.totalCampaignSpend.toStringAsFixed(3)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '\$${c.totalRemainingLiquidity.toStringAsFixed(3)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                            DataCell(
                              buildStatusBadge(
                                c.totalRemainingLiquidity > 50
                                    ? '✅ السيولة ممتازة'
                                    : '⚠️ رصيد منخفض',
                              ),
                            ),
                            DataCell(
                              Text(
                                '${c.campaigns.length} حملة مسجلة',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '\$${c.totalGrossEarnings.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '\$${c.totalNetProfit.toStringAsFixed(3)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${(c.overallRoi * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF38BDF8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // الرسم البياني للأرباح اليومية + جاهزية المنظومة التقنية
          ResponsiveSplit(
            first: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.bar_chart_rounded,
                          color: Color(0xFF10B981),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'تحليل الأداء اليومي للحملات (إجمالي الأرباح مقابل التكلفة)',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDailyPerformanceBars(context),
                  ],
                ),
              ),
            ),
            second: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.settings_suggest_rounded,
                          color: Color(0xFFA855F7),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'الأصول التقنية والمنصات التشغيلية',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _techAssetTile(
                      title: 'بروكسي ثابت (DataImpulse)',
                      subtitle:
                          '${c.usedProxiesCount} مستخدم / ${c.proxies.length - c.usedProxiesCount} متاح | تم الشحن 50\$',
                      badge: '✅ متصل وجاهز',
                    ),
                    _techAssetTile(
                      title: 'متصفح GoLogin',
                      subtitle:
                          '${c.gologinAccounts.length} حسابات | 9 بروفايلات نشطة (3 دول)',
                      badge: '✅ مهيأ بالكامل',
                    ),
                    _techAssetTile(
                      title: 'حسابات البريد (Gmail)',
                      subtitle:
                          '${c.emails.length} إيميل (${c.emails.where((e) => e.status == "يعمل").length} شغال نظامي)',
                      badge: '⚠️ يتطلب متابعة',
                    ),
                    _techAssetTile(
                      title: 'منصة Adsterra & Clickadu',
                      subtitle:
                          '${c.activeAdsterraCount} حملات نشطة | تم شحن 100\$',
                      badge: '🚀 شغال بكفاءة',
                    ),
                    _techAssetTile(
                      title: 'PropellerAds + RollerAds + RichAds',
                      subtitle: 'شبكات إعلانية رديفة وبوب أندر موثقة',
                      badge: '🟢 استقرار تشغيلي',
                    ),
                  ],
                ),
              ),
            ),
            spacing: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildDailyPerformanceBars(BuildContext context) {
    // تجميع الحملات حسب التاريخ
    final Map<String, Map<String, double>> byDate = {};
    for (final camp in controller.campaigns) {
      if (camp.date.isEmpty) continue;
      byDate.putIfAbsent(
        camp.date,
        () => {'cost': 0.0, 'earnings': 0.0, 'net': 0.0},
      );
      byDate[camp.date]!['cost'] = byDate[camp.date]!['cost']! + camp.cost;
      byDate[camp.date]!['earnings'] =
          byDate[camp.date]!['earnings']! + camp.totalEarnings;
      byDate[camp.date]!['net'] = byDate[camp.date]!['net']! + camp.netProfit;
    }
    final dates = byDate.keys.toList()..sort();
    double maxVal = 1.0;
    for (final v in byDate.values) {
      maxVal = math.max(maxVal, math.max(v['earnings']!, v['cost']!));
    }

    return Column(
      children: dates.map((d) {
        final cost = byDate[d]!['cost']!;
        final earn = byDate[d]!['earnings']!;
        final net = byDate[d]!['net']!;
        final earnRatio = (earn / maxVal).clamp(0.0, 1.0);
        final costRatio = (cost / maxVal).clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                child: Text(
                  d,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Consolas',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: earnRatio,
                              minHeight: 8,
                              backgroundColor: Colors.grey.withOpacity(0.15),
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 68,
                          child: Text(
                            '+\$${earn.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: costRatio,
                              minHeight: 5,
                              backgroundColor: Colors.transparent,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 68,
                          child: Text(
                            '-\$${cost.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 82,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'صافي: \$${net.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: net >= 0
                          ? const Color(0xFF34D399)
                          : const Color(0xFFF43F5E),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _techAssetTile({
    required String title,
    required String subtitle,
    required String badge,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            buildStatusBadge(badge),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// الشاشة 2: الأرباح والجرد اليومي للحملات (Daily Campaigns & Profits Log)
// ============================================================================

class CampaignsInventoryScreen extends StatefulWidget {
  final AppDataController controller;
  const CampaignsInventoryScreen({super.key, required this.controller});

  @override
  State<CampaignsInventoryScreen> createState() =>
      _CampaignsInventoryScreenState();
}

class _CampaignsInventoryScreenState extends State<CampaignsInventoryScreen> {
  String _selectedBeneficiary = 'الكل';
  String _searchQuery = '';
  bool _showDailySummaryView = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final beneficiariesList = [
      'الكل',
      ...{...c.beneficiaries.map((b) => b.name)}
    ];

    final filtered = c.campaigns.where((item) {
      if (_selectedBeneficiary != 'الكل' &&
          item.beneficiary.trim() != _selectedBeneficiary.trim()) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        return item.product.toLowerCase().contains(q) ||
            item.beneficiary.toLowerCase().contains(q) ||
            item.accountCode.toLowerCase().contains(q) ||
            item.date.toLowerCase().contains(q) ||
            item.profile.toLowerCase().contains(q) ||
            item.smartRecommendation.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    final filteredSpend = filtered.fold(0.0, (s, x) => s + x.cost);
    final filteredEarnings = filtered.fold(0.0, (s, x) => s + x.totalEarnings);
    final filteredNet = filtered.fold(0.0, (s, x) => s + x.netProfit);
    final filteredRoi = filteredSpend > 0 ? (filteredNet / filteredSpend) : 0.0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // شريط الفلترة والإضافة
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'بحث بالمنتج، الحساب، التاريخ، التوصية...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  DropdownButtonHideUnderline(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: Colors.grey.withOpacity(0.35)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedBeneficiary,
                        items: beneficiariesList
                            .map(
                              (b) => DropdownMenuItem(
                                value: b,
                                child: Text('المستفيد: $b'),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedBeneficiary = val);
                          }
                        },
                      ),
                    ),
                  ),
                  FilterChip(
                    selected: _showDailySummaryView,
                    label: const Text('عرض الملخص اليومي المجمّع'),
                    avatar: const Icon(Icons.calendar_today_rounded, size: 16),
                    onSelected: (v) =>
                        setState(() => _showDailySummaryView = v),
                  ),
                  // ملخص الفلتر الحالي
                  Text(
                    'النتائج: ${filtered.length} | التكلفة: \$${filteredSpend.toStringAsFixed(2)} | الأرباح: \$${filteredEarnings.toStringAsFixed(2)} | الصافي: \$${filteredNet.toStringAsFixed(2)} (${(filteredRoi * 100).toStringAsFixed(1)}%)',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('تسجيل حملة يومية جديدة'),
                    onPressed: () => _showAddOrEditCampaignDialog(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // الجدول التفصيلي أو الجدول اليومي المجمع
          Expanded(
            child: Card(
              child: _showDailySummaryView
                  ? _buildDailyGroupedTable(filtered)
                  : _buildDetailedCampaignsTable(filtered),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedCampaignsTable(List<CampaignLogModel> list) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 46,
          dataRowMinHeight: 46,
          dataRowMaxHeight: 54,
          columnSpacing: 18,
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('التاريخ')),
            DataColumn(label: Text('المستفيد')),
            DataColumn(label: Text('رمز الحساب')),
            DataColumn(label: Text('المنتج')),
            DataColumn(label: Text('البروفايل')),
            DataColumn(label: Text('الإيميل')),
            DataColumn(label: Text('تكلفة الحملة')),
            DataColumn(label: Text('النقرات')),
            DataColumn(label: Text('الطلبات')),
            DataColumn(label: Text('التحويل CR%')),
            DataColumn(label: Text('المشحون')),
            DataColumn(label: Text('المبيعات')),
            DataColumn(label: Text('العمولة')),
            DataColumn(label: Text('المكافأة')),
            DataColumn(label: Text('الأرباح الكلية')),
            DataColumn(label: Text('صافي الربح')),
            DataColumn(label: Text('العائد ROI%')),
            DataColumn(label: Text('التوصية الذكية والملاحظات')),
            DataColumn(label: Text('إجراءات')),
          ],
          rows: list.map((camp) {
            final net = camp.netProfit;
            final roi = camp.roi;
            return DataRow(
              cells: [
                DataCell(Text('${camp.seq}')),
                DataCell(
                  Text(
                    camp.date,
                    style: const TextStyle(fontFamily: 'Consolas'),
                  ),
                ),
                DataCell(
                  Text(
                    camp.beneficiary,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(buildStatusBadge(camp.accountCode)),
                DataCell(
                  Text(
                    camp.product,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(Text(camp.profile)),
                DataCell(
                  InkWell(
                    onTap: () =>
                        copyToClipboard(context, camp.email, 'الإيميل'),
                    child: Text(
                      camp.email,
                      style: const TextStyle(fontFamily: 'Consolas'),
                    ),
                  ),
                ),
                DataCell(Text('\$${camp.cost.toStringAsFixed(3)}')),
                DataCell(Text('${camp.clicks}')),
                DataCell(Text('${camp.orderedItems}')),
                DataCell(
                  Text('${(camp.conversionRate * 100).toStringAsFixed(1)}%'),
                ),
                DataCell(Text('${camp.shippedItems}')),
                DataCell(Text('\$${camp.totalRevenue.toStringAsFixed(2)}')),
                DataCell(Text('\$${camp.commission.toStringAsFixed(2)}')),
                DataCell(Text('\$${camp.bonus.toStringAsFixed(2)}')),
                DataCell(
                  Text(
                    camp.isPending
                        ? 'قيد التشغيل'
                        : '\$${camp.totalEarnings.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(
                  Text(
                    camp.isPending ? '-' : '\$${net.toStringAsFixed(3)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: net > 0
                          ? const Color(0xFF10B981)
                          : (net < 0 ? const Color(0xFFF43F5E) : Colors.grey),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    roi == null ? '-' : '${(roi * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: (roi ?? 0) >= 0
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFFF43F5E),
                    ),
                  ),
                ),
                DataCell(buildStatusBadge(camp.smartRecommendation)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (camp.adUrl.isNotEmpty)
                        IconButton(
                          tooltip: 'نسخ رابط الإعلان: ${camp.adUrl}',
                          icon: const Icon(Icons.link_rounded, size: 18),
                          onPressed: () => copyToClipboard(
                            context,
                            camp.adUrl,
                            'رابط الإعلان',
                          ),
                        ),
                      IconButton(
                        tooltip: 'تعديل الحملة',
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _showAddOrEditCampaignDialog(context,
                            existing: camp),
                      ),
                      IconButton(
                        tooltip: 'حذف الحملة',
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Color(0xFFF43F5E),
                        ),
                        onPressed: () {
                          widget.controller.campaigns.remove(camp);
                          widget.controller.saveToDisk();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDailyGroupedTable(List<CampaignLogModel> list) {
    final Map<String, List<CampaignLogModel>> byDate = {};
    for (final c in list) {
      byDate.putIfAbsent(c.date, () => []).add(c);
    }
    final sortedDates = byDate.keys.toList()..sort();

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('التاريخ')),
            DataColumn(label: Text('عدد الحملات')),
            DataColumn(label: Text('إجمالي النقرات')),
            DataColumn(label: Text('إجمالي الطلبات')),
            DataColumn(label: Text('إجمالي تكلفة الحملات اليومية')),
            DataColumn(label: Text('إجمالي الأرباح اليومية')),
            DataColumn(label: Text('صافي الربح اليومي')),
            DataColumn(label: Text('نسبة العائد اليومي %')),
            DataColumn(label: Text('التقييم اليومي')),
          ],
          rows: sortedDates.map((d) {
            final items = byDate[d]!;
            final cost = items.fold(0.0, (s, x) => s + x.cost);
            final earn = items.fold(0.0, (s, x) => s + x.totalEarnings);
            final net = earn - cost;
            final roi = cost > 0 ? net / cost : 0.0;
            final clicks = items.fold(0, (s, x) => s + x.clicks);
            final orders = items.fold(0, (s, x) => s + x.orderedItems);

            return DataRow(
              cells: [
                DataCell(
                  Text(
                    d,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Consolas',
                    ),
                  ),
                ),
                DataCell(Text('${items.length} حملات')),
                DataCell(Text('$clicks')),
                DataCell(Text('$orders')),
                DataCell(Text('\$${cost.toStringAsFixed(3)}')),
                DataCell(
                  Text(
                    '\$${earn.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(
                  Text(
                    '\$${net.toStringAsFixed(3)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: net >= 0
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF43F5E),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    cost > 0 ? '${(roi * 100).toStringAsFixed(1)}%' : '-',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(
                  buildStatusBadge(
                    net > 0 ? '🚀 يوم رابح وممتاز' : '🛑 خسارة يومية',
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAddOrEditCampaignDialog(
    BuildContext context, {
    CampaignLogModel? existing,
  }) {
    final c = widget.controller;
    final dateCtrl = TextEditingController(
      text: existing?.date ?? DateTime.now().toIso8601String().split('T').first,
    );
    String selectedProduct = existing?.product ??
        (c.productsCatalog.isNotEmpty ? c.productsCatalog.first.product : '');
    final benefCtrl = TextEditingController(text: existing?.beneficiary ?? '');
    final codeCtrl = TextEditingController(text: existing?.accountCode ?? '');
    final profileCtrl = TextEditingController(text: existing?.profile ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final passCtrl = TextEditingController(text: existing?.password ?? '');
    final adUrlCtrl = TextEditingController(text: existing?.adUrl ?? '');

    final costCtrl = TextEditingController(text: '${existing?.cost ?? 0.0}');
    final clicksCtrl = TextEditingController(text: '${existing?.clicks ?? 0}');
    final ordersCtrl =
        TextEditingController(text: '${existing?.orderedItems ?? 0}');
    final orderedRevCtrl =
        TextEditingController(text: '${existing?.orderedRevenue ?? 0.0}');
    final shippedCtrl =
        TextEditingController(text: '${existing?.shippedItems ?? 0}');
    final returnedCtrl =
        TextEditingController(text: '${existing?.returnedItems ?? 0}');
    final totalRevCtrl =
        TextEditingController(text: '${existing?.totalRevenue ?? 0.0}');
    final commCtrl =
        TextEditingController(text: '${existing?.commission ?? 0.0}');
    final bonusCtrl = TextEditingController(text: '${existing?.bonus ?? 0.0}');
    bool isPending = existing?.isPending ?? false;

    void applyProductAutoFill(String prodName) {
      final match = c.findCatalogByProduct(prodName);
      if (match != null) {
        benefCtrl.text = match.beneficiary;
        codeCtrl.text = match.accountCode;
        profileCtrl.text = match.profile;
        emailCtrl.text = match.email.split('@').first;
        passCtrl.text = match.password;
        adUrlCtrl.text = match.adUrl;
      }
    }

    if (existing == null && selectedProduct.isNotEmpty) {
      applyProductAutoFill(selectedProduct);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            title: Text(
              existing == null
                  ? 'إضافة حملة يومية جديدة (تعبئة تلقائية ذكية)'
                  : 'تعديل بيانات الحملة رقم #${existing.seq}',
            ),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: c.productsCatalog
                                    .any((p) => p.product == selectedProduct)
                                ? selectedProduct
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'اختر المنتج (تعبئة تلقائية)',
                              border: OutlineInputBorder(),
                            ),
                            items: c.productsCatalog
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p.product,
                                    child: Text(
                                      '${p.product} (${p.beneficiary} - ${p.accountCode})',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() {
                                  selectedProduct = val;
                                  applyProductAutoFill(val);
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: dateCtrl,
                            decoration: const InputDecoration(
                              labelText: 'التاريخ (YYYY-MM-DD)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: benefCtrl,
                            decoration: const InputDecoration(
                              labelText: 'المستفيد',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: codeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'رمز الحساب',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: profileCtrl,
                            decoration: const InputDecoration(
                              labelText: 'البروفايل (GoLogin)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: costCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'تكلفة الحملة (\$)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: commCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'عمولات أمازون (\$)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: bonusCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'المكافآت Bonus (\$)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: clicksCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'النقرات (Clicks)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: ordersCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'الطلبات (Ordered)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: shippedCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'المشحونة (Shipped)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: totalRevCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'إجمالي المبيعات (\$)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: isPending,
                      title: const Text(
                        '⏳ الحملة لا تزال قيد التشغيل (بانتظار النتائج)',
                      ),
                      onChanged: (v) =>
                          setModalState(() => isPending = v ?? false),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.save_rounded),
                label: const Text('حفظ الحملة وحساب العائد'),
                onPressed: () {
                  final model = CampaignLogModel(
                    seq: existing?.seq ?? (c.campaigns.length + 1),
                    date: dateCtrl.text.trim(),
                    beneficiary: benefCtrl.text.trim(),
                    accountCode: codeCtrl.text.trim(),
                    product: selectedProduct,
                    email: emailCtrl.text.trim(),
                    cost: double.tryParse(costCtrl.text) ?? 0.0,
                    profile: profileCtrl.text.trim(),
                    password: passCtrl.text.trim(),
                    clicks: int.tryParse(clicksCtrl.text) ?? 0,
                    orderedItems: int.tryParse(ordersCtrl.text) ?? 0,
                    orderedRevenue: double.tryParse(orderedRevCtrl.text) ?? 0.0,
                    shippedItems: int.tryParse(shippedCtrl.text) ?? 0,
                    returnedItems: int.tryParse(returnedCtrl.text) ?? 0,
                    totalRevenue: double.tryParse(totalRevCtrl.text) ?? 0.0,
                    commission: double.tryParse(commCtrl.text) ?? 0.0,
                    bonus: double.tryParse(bonusCtrl.text) ?? 0.0,
                    isPending: isPending,
                    adUrl: adUrlCtrl.text.trim(),
                  );
                  if (existing == null) {
                    c.campaigns.insert(0, model);
                  } else {
                    final idx = c.campaigns.indexOf(existing);
                    if (idx != -1) c.campaigns[idx] = model;
                  }
                  c.saveToDisk();
                  Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// استيراد حملات من تقرير الإعلانات المستخرج إلى سجل الحملات اليومية
// ============================================================================

Future<void> showCampaignImportDialog(
  BuildContext context,
  AppDataController c,
  List<ParsedCampaignRow> rows,
) async {
  final catalog = c.productsCatalog;
  final entries = <_CampaignImportEntry>[];
  for (final row in rows) {
    final index = matchCatalogIndex(row, [
      for (final p in catalog) (product: p.product, accountCode: p.accountCode),
    ]);
    final product = index == null ? null : catalog[index];
    final productName = product?.product ?? row.campaignName;
    final code = product?.accountCode ?? row.accountCode;
    final duplicate = c.campaigns.any(
      (e) =>
          e.date == row.date &&
          e.accountCode == code &&
          e.product == productName,
    );
    entries.add(
      _CampaignImportEntry(
        row: row,
        catalog: product,
        productName: productName,
        accountCode: code,
        isDuplicate: duplicate,
        selected: !duplicate && product != null,
      ),
    );
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('مراجعة الحملات قبل الإضافة'),
          content: SizedBox(
            width: 720,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final e in entries)
                  CheckboxListTile(
                    value: e.selected,
                    onChanged: (v) => setModalState(() => e.selected = v ?? false),
                    title: Text('${e.row.date} • ${e.accountCode} • ${e.productName}'),
                    subtitle: Text(
                      'التكلفة: \$${e.row.cost.toStringAsFixed(3)} • النقرات: ${e.row.clicks}'
                      '${e.isDuplicate ? ' • ⚠️ موجودة مسبقًا' : ''}'
                      '${e.catalog == null ? ' • ⚠️ لم يُعثر على المنتج في الدليل' : ''}',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إضافة المحدد'),
            ),
          ],
        ),
      ),
    ),
  );
  if (confirmed != true) return;

  var added = 0;
  for (final e in entries.where((e) => e.selected)) {
    final p = e.catalog;
    c.campaigns.insert(
      0,
      CampaignLogModel(
        seq: c.campaigns.length + 1,
        date: e.row.date,
        beneficiary: p?.beneficiary ?? '',
        accountCode: e.accountCode,
        product: e.productName,
        email: p?.email ?? '',
        cost: e.row.cost,
        profile: p?.profile ?? '',
        password: p?.password ?? '',
        clicks: e.row.clicks,
        orderedItems: 0,
        orderedRevenue: 0,
        shippedItems: 0,
        returnedItems: 0,
        totalRevenue: 0,
        commission: 0,
        bonus: 0,
        isPending: true,
        adUrl: p?.adUrl ?? '',
      ),
    );
    added++;
  }
  if (added > 0) c.saveToDisk();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تمت إضافة $added حملة إلى الحملات اليومية.')),
    );
  }
}

class _CampaignImportEntry {
  _CampaignImportEntry({
    required this.row,
    required this.catalog,
    required this.productName,
    required this.accountCode,
    required this.isDuplicate,
    required this.selected,
  });

  final ParsedCampaignRow row;
  final ProductCatalogModel? catalog;
  final String productName;
  final String accountCode;
  final bool isDuplicate;
  bool selected;
}

// ============================================================================
// الشاشة 3: دليل المنتجات والمستفيدين (Beneficiaries & Products Control Center)
// ============================================================================

class BeneficiariesAndCatalogScreen extends StatelessWidget {
  final AppDataController controller;
  const BeneficiariesAndCatalogScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // قسم المستفيدين
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.group_work_rounded,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'إدارة المستفيدين المعتمدين ورؤوس الأموال',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.person_add_alt_1_rounded,
                            size: 18),
                        label: const Text('إضافة مستفيد جديد'),
                        onPressed: () => _showBeneficiaryDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('م')),
                        DataColumn(label: Text('اسم المستفيد')),
                        DataColumn(label: Text('رمز الحساب')),
                        DataColumn(label: Text('رأس المال الأساسي')),
                        DataColumn(label: Text('المصروف الفعلي')),
                        DataColumn(label: Text('رأس المال المتبقي')),
                        DataColumn(label: Text('إجمالي الأرباح')),
                        DataColumn(label: Text('صافي الربح')),
                        DataColumn(label: Text('حالة الرصيد والتنبيه')),
                        DataColumn(label: Text('تعديل الرصيد')),
                      ],
                      rows: c.beneficiaries.map((b) {
                        final m = c.getBeneficiaryMetrics(b);
                        return DataRow(
                          cells: [
                            DataCell(Text('${b.id}')),
                            DataCell(
                              Text(
                                b.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(buildStatusBadge(b.accountCodeRange)),
                            DataCell(
                              Text('\$${b.baseCapital.toStringAsFixed(2)}'),
                            ),
                            DataCell(
                              Text(
                                '\$${(m['spent'] as double).toStringAsFixed(3)}',
                              ),
                            ),
                            DataCell(
                              Text(
                                '\$${(m['remaining'] as double).toStringAsFixed(3)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: (m['remaining'] as double) < 0
                                      ? const Color(0xFFF43F5E)
                                      : const Color(0xFF10B981),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '\$${(m['earnings'] as double).toStringAsFixed(2)}',
                              ),
                            ),
                            DataCell(
                              Text(
                                '\$${(m['netProfit'] as double).toStringAsFixed(3)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                            DataCell(
                              buildStatusBadge(m['statusAlert'] as String),
                            ),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 18),
                                onPressed: () => _showBeneficiaryDialog(context,
                                    existing: b),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // قسم دليل المنتجات والحملات المعتمدة
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.inventory_2_rounded,
                        color: Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'دليل الحملات والمنتجات المعتمدة (للقوائم المنسدلة والتعبئة التلقائية)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.add_box_rounded, size: 18),
                        label: const Text('إضافة منتج للدليل'),
                        onPressed: () => _showProductCatalogDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('م')),
                        DataColumn(label: Text('المنتج')),
                        DataColumn(label: Text('المستفيد')),
                        DataColumn(label: Text('رمز الحساب')),
                        DataColumn(label: Text('البروفايل')),
                        DataColumn(label: Text('رأس المال')),
                        DataColumn(label: Text('الإيميل')),
                        DataColumn(label: Text('الباسوورد')),
                        DataColumn(label: Text('رابط الإعلان')),
                        DataColumn(label: Text('إجراءات')),
                      ],
                      rows: c.productsCatalog.map((p) {
                        return DataRow(
                          cells: [
                            DataCell(Text('${p.id}')),
                            DataCell(
                              Text(
                                p.product,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(Text(p.beneficiary)),
                            DataCell(buildStatusBadge(p.accountCode)),
                            DataCell(Text(p.profile)),
                            DataCell(Text('\$${p.capital.toStringAsFixed(0)}')),
                            DataCell(
                              InkWell(
                                onTap: () => copyToClipboard(
                                    context, p.email, 'الإيميل'),
                                child: Text(
                                  p.email,
                                  style:
                                      const TextStyle(fontFamily: 'Consolas'),
                                ),
                              ),
                            ),
                            DataCell(
                              InkWell(
                                onTap: () => copyToClipboard(
                                  context,
                                  p.password,
                                  'الباسوورد',
                                ),
                                child: Text(
                                  p.password,
                                  style:
                                      const TextStyle(fontFamily: 'Consolas'),
                                ),
                              ),
                            ),
                            DataCell(
                              InkWell(
                                onTap: () => copyToClipboard(
                                  context,
                                  p.adUrl,
                                  'رابط الإعلان',
                                ),
                                child: Text(
                                  p.adUrl,
                                  style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontFamily: 'Consolas',
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: Color(0xFFF43F5E),
                                    ),
                                    onPressed: () {
                                      c.productsCatalog.remove(p);
                                      c.saveToDisk();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBeneficiaryDialog(
    BuildContext context, {
    BeneficiaryModel? existing,
  }) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final capCtrl =
        TextEditingController(text: '${existing?.baseCapital ?? 100.0}');
    final codeCtrl =
        TextEditingController(text: existing?.accountCodeRange ?? 'SH-01');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          existing == null ? 'إضافة مستفيد جديد' : 'تعديل رصيد المستفيد',
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم المستفيد',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: capCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'رأس المال الأساسي المضاف (\$)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'رمز الحساب (مثال: SH-01:07)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (existing == null) {
                controller.beneficiaries.add(
                  BeneficiaryModel(
                    id: controller.beneficiaries.length + 1,
                    name: nameCtrl.text.trim(),
                    baseCapital: double.tryParse(capCtrl.text) ?? 0.0,
                    accountCodeRange: codeCtrl.text.trim(),
                  ),
                );
              } else {
                existing.name = nameCtrl.text.trim();
                existing.baseCapital = double.tryParse(capCtrl.text) ?? 0.0;
                existing.accountCodeRange = codeCtrl.text.trim();
              }
              controller.saveToDisk();
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showProductCatalogDialog(BuildContext context) {
    final prodCtrl = TextEditingController();
    final benefCtrl = TextEditingController(text: 'شامي');
    final codeCtrl = TextEditingController(text: 'SH-01');
    final profCtrl = TextEditingController();
    final capCtrl = TextEditingController(text: '100');
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة منتج أو حملة جديدة للدليل'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: prodCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم المنتج / الصنف',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: benefCtrl,
                        decoration: const InputDecoration(
                          labelText: 'المستفيد',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'رمز الحساب',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: profCtrl,
                        decoration: const InputDecoration(
                          labelText: 'البروفايل',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: capCtrl,
                        decoration: const InputDecoration(
                          labelText: 'رأس المال',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'الإيميل',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: passCtrl,
                        decoration: const InputDecoration(
                          labelText: 'الباسوورد',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رابط الإعلان (تغريدة تويتر / ووركر)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              controller.productsCatalog.add(
                ProductCatalogModel(
                  id: controller.productsCatalog.length + 1,
                  product: prodCtrl.text.trim(),
                  beneficiary: benefCtrl.text.trim(),
                  accountCode: codeCtrl.text.trim(),
                  profile: profCtrl.text.trim(),
                  capital: double.tryParse(capCtrl.text) ?? 100.0,
                  email: emailCtrl.text.trim(),
                  password: passCtrl.text.trim(),
                  adUrl: urlCtrl.text.trim(),
                ),
              );
              controller.saveToDisk();
              Navigator.pop(ctx);
            },
            child: const Text('إضافة للدليل'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// الشاشة 4: حسابات أمازون والترويج والأرشيف (Amazon Accounts & Archive Screen)
// ============================================================================

class AmazonAccountsScreen extends StatefulWidget {
  final AppDataController controller;
  const AmazonAccountsScreen({super.key, required this.controller});

  @override
  State<AmazonAccountsScreen> createState() => _AmazonAccountsScreenState();
}

class _AmazonAccountsScreenState extends State<AmazonAccountsScreen> {
  int _tabIndex =
      0; // 0: الكل، 1: النشطة، 2: المحظورة/المؤرشفة، 3: الأرشيف التاريخي

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    List<AmazonAccountModel> list = c.amazonAccounts;
    if (_tabIndex == 1) {
      list = c.amazonAccounts.where((a) => a.status == 'نشط').toList();
    } else if (_tabIndex == 2) {
      list = c.amazonAccounts.where((a) => a.isArchivedOrBanned).toList();
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // بطاقات الإحصاء العلوية لحسابات أمازون
          ResponsiveKpiGrid(
            cards: [
              KpiStatCard(
                title: '📊 إجمالي حسابات أمازون',
                value: '${c.amazonAccounts.length}',
                subtitle: 'موزعة على 4 مستفيدين',
                icon: Icons.shopping_bag_rounded,
                color: const Color(0xFF38BDF8),
              ),
              KpiStatCard(
                title: '🟢 الحسابات النشطة',
                value: '${c.activeAmazonCount}',
                subtitle: 'حسابات ترويجية شغالة',
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF10B981),
              ),
              KpiStatCard(
                title: '⛔ الحسابات المحظورة',
                value: '${c.bannedAmazonCount}',
                subtitle: 'مؤرشفة تلقائياً في سجل الحظر',
                icon: Icons.block_rounded,
                color: const Color(0xFFF43F5E),
              ),
              KpiStatCard(
                title: '🐦 تغريدات وحملات نشطة',
                value: '${c.activeTweetsCount} تغريدة',
                subtitle: '${c.activeAdsterraCount} روابط ووركر Adsterra',
                icon: Icons.rocket_launch_rounded,
                color: const Color(0xFFA855F7),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // أزرار التبويب
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('جميع الحسابات (${c.amazonAccounts.length})'),
                selected: _tabIndex == 0,
                onSelected: (_) => setState(() => _tabIndex = 0),
              ),
              ChoiceChip(
                label: Text('الحسابات النشطة (${c.activeAmazonCount})'),
                selected: _tabIndex == 1,
                onSelected: (_) => setState(() => _tabIndex = 1),
              ),
              ChoiceChip(
                label: Text(
                  'أرشيف الحسابات الملغاة والمحظورة (${c.bannedAmazonCount})',
                ),
                selected: _tabIndex == 2,
                onSelected: (_) => setState(() => _tabIndex = 2),
              ),
              ChoiceChip(
                label: Text(
                  'الأرشيف التاريخي للروابط البديلة (${c.historicalLinks.length})',
                ),
                selected: _tabIndex == 3,
                onSelected: (_) => setState(() => _tabIndex = 3),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: Card(
              child: _tabIndex == 3
                  ? _buildHistoricalLinksTable(c)
                  : _buildAmazonTable(list),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmazonTable(List<AmazonAccountModel> list) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 46,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 58,
          columns: const [
            DataColumn(label: Text('المستفيد')),
            DataColumn(label: Text('الرمز')),
            DataColumn(label: Text('اسم الحساب')),
            DataColumn(label: Text('StoreID')),
            DataColumn(label: Text('الدولة')),
            DataColumn(label: Text('الحالة')),
            DataColumn(label: Text('الصنف 1')),
            DataColumn(label: Text('حالة التغريدة 1')),
            DataColumn(label: Text('رابط تغريدة 1')),
            DataColumn(label: Text('الصنف 2')),
            DataColumn(label: Text('رابط تغريدة 2')),
            DataColumn(label: Text('أفلييت 1')),
            DataColumn(label: Text('رابط ووركر Adsterra')),
            DataColumn(label: Text('الإيميل')),
            DataColumn(label: Text('الباسوورد')),
            DataColumn(label: Text('ملاحظات')),
          ],
          rows: list.map((a) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    a.beneficiary,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(buildStatusBadge(a.code)),
                DataCell(
                  Text(
                    a.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(
                  InkWell(
                    onTap: () => copyToClipboard(context, a.storeId, 'StoreID'),
                    child: Text(
                      a.storeId,
                      style: const TextStyle(fontFamily: 'Consolas'),
                    ),
                  ),
                ),
                DataCell(Text(a.country)),
                DataCell(
                  InkWell(
                    onTap: () {
                      a.status = a.status == 'نشط' ? 'محظور' : 'نشط';
                      widget.controller.saveToDisk();
                    },
                    child: buildStatusBadge(a.status),
                  ),
                ),
                DataCell(Text(a.product1)),
                DataCell(buildStatusBadge(a.promoStatus1)),
                DataCell(
                  a.tweetUrl1.isEmpty
                      ? const Text('-')
                      : TextButton.icon(
                          icon: const Icon(Icons.copy_rounded, size: 15),
                          label: Text(
                            a.tweetUrl1,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () => copyToClipboard(
                            context,
                            a.tweetUrl1,
                            'رابط تغريدة 1',
                          ),
                        ),
                ),
                DataCell(Text(a.product2.isEmpty ? '-' : a.product2)),
                DataCell(
                  a.tweetUrl2.isEmpty
                      ? const Text('-')
                      : TextButton.icon(
                          icon: const Icon(Icons.copy_rounded, size: 15),
                          label: Text(
                            a.tweetUrl2,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () => copyToClipboard(
                            context,
                            a.tweetUrl2,
                            'رابط تغريدة 2',
                          ),
                        ),
                ),
                DataCell(
                  a.affiliateUrl1.isEmpty
                      ? const Text('-')
                      : TextButton.icon(
                          icon: const Icon(Icons.link_rounded, size: 15),
                          label: Text(
                            a.affiliateUrl1,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () => copyToClipboard(
                            context,
                            a.affiliateUrl1,
                            'رابط أفلييت 1',
                          ),
                        ),
                ),
                DataCell(
                  a.adsterraUrl.isEmpty
                      ? const Text('-')
                      : TextButton.icon(
                          icon: const Icon(Icons.public_rounded, size: 15),
                          label: Text(
                            a.adsterraUrl,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () => copyToClipboard(
                            context,
                            a.adsterraUrl,
                            'رابط ووركر Adsterra',
                          ),
                        ),
                ),
                DataCell(
                  InkWell(
                    onTap: () => copyToClipboard(context, a.email, 'الإيميل'),
                    child: Text(
                      a.email,
                      style: const TextStyle(fontFamily: 'Consolas'),
                    ),
                  ),
                ),
                DataCell(
                  InkWell(
                    onTap: () =>
                        copyToClipboard(context, a.password, 'الباسوورد'),
                    child: Text(
                      a.password,
                      style: const TextStyle(fontFamily: 'Consolas'),
                    ),
                  ),
                ),
                DataCell(Text(a.notes)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildHistoricalLinksTable(AppDataController c) {
    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('الأخ المستفيد')),
          DataColumn(label: Text('اسم الحساب')),
          DataColumn(label: Text('الصنف')),
          DataColumn(label: Text('نوع الرابط')),
          DataColumn(label: Text('الرابط المؤرشف')),
          DataColumn(label: Text('الملاحظات')),
        ],
        rows: c.historicalLinks.map((h) {
          return DataRow(
            cells: [
              DataCell(Text(h.beneficiary)),
              DataCell(
                Text(
                  h.accountName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataCell(Text(h.product)),
              DataCell(buildStatusBadge(h.linkType)),
              DataCell(
                InkWell(
                  onTap: () =>
                      copyToClipboard(context, h.url, 'الرابط المؤرشف'),
                  child: Text(
                    h.url,
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontFamily: 'Consolas',
                    ),
                  ),
                ),
              ),
              DataCell(Text(h.notes)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================================
// الشاشة 5: إدارة البريد الإلكتروني (Email Accounts Screen)
// ============================================================================

class EmailAccountsScreen extends StatefulWidget {
  final AppDataController controller;
  const EmailAccountsScreen({super.key, required this.controller});

  @override
  State<EmailAccountsScreen> createState() => _EmailAccountsScreenState();
}

class _EmailAccountsScreenState extends State<EmailAccountsScreen> {
  String _statusFilter = 'الكل';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final workingCount = c.emails.where((e) => e.status == 'يعمل').length;
    final lockedOrReviewCount = c.emails
        .where(
          (e) =>
              e.status.contains('مقفول') ||
              e.status.contains('مراجعة') ||
              e.notes.contains('مقفول'),
        )
        .length;

    final filtered = c.emails.where((e) {
      if (_statusFilter != 'الكل' && e.status != _statusFilter) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        return e.email.toLowerCase().contains(q) ||
            e.gologin.toLowerCase().contains(q) ||
            e.country.toLowerCase().contains(q) ||
            e.notes.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ResponsiveKpiGrid(
            cards: [
              KpiStatCard(
                title: '📊 إجمالي حسابات البريد',
                value: '${c.emails.length}',
                subtitle: 'حسابات Gmail مسجلة في النظام',
                icon: Icons.email_rounded,
                color: const Color(0xFF818CF8),
              ),
              KpiStatCard(
                title: '✅ الحسابات الشغالة',
                value: '$workingCount',
                subtitle: 'جاهزة ومربوطة ببروفايلات GoLogin',
                icon: Icons.mark_email_read_rounded,
                color: const Color(0xFF10B981),
              ),
              KpiStatCard(
                title: '⚠️ مقفول / بحاجة مراجعة',
                value: '$lockedOrReviewCount',
                subtitle: 'حسابات مقفولة على الرقم أو قيد المراجعة',
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFF43F5E),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'ابحث بالإيميل أو الدولة أو الملاحظات...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  ...['الكل', 'يعمل', 'قيد المراجعة', 'مقفول', 'غير محدد'].map(
                    (st) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text(st),
                        selected: _statusFilter == st,
                        onSelected: (_) => setState(() => _statusFilter = st),
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('إضافة حساب بريد'),
                    onPressed: () => _showAddEmailDialog(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('الإيميل (انقر للنسخ)')),
                      DataColumn(label: Text('الباسوورد')),
                      DataColumn(label: Text('حساب GoLogin')),
                      DataColumn(label: Text('إيميل الربط / الاسترداد')),
                      DataColumn(label: Text('التحقق بخطوتين')),
                      DataColumn(label: Text('الحالة')),
                      DataColumn(label: Text('الدولة')),
                      DataColumn(label: Text('الرقم المربوط')),
                      DataColumn(label: Text('الملاحظات')),
                    ],
                    rows: filtered.map((e) {
                      return DataRow(
                        cells: [
                          DataCell(
                            InkWell(
                              onTap: () =>
                                  copyToClipboard(context, e.email, 'الإيميل'),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.copy_rounded, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    e.email,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Consolas',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            InkWell(
                              onTap: () => copyToClipboard(
                                context,
                                e.password,
                                'الباسوورد',
                              ),
                              child: Text(
                                e.password,
                                style: const TextStyle(fontFamily: 'Consolas'),
                              ),
                            ),
                          ),
                          DataCell(Text(e.gologin.isEmpty ? '-' : e.gologin)),
                          DataCell(Text(e.recovery.isEmpty ? '-' : e.recovery)),
                          DataCell(Text(e.twoFa.isEmpty ? '-' : e.twoFa)),
                          DataCell(buildStatusBadge(e.status)),
                          DataCell(Text(e.country.isEmpty ? '-' : e.country)),
                          DataCell(
                            InkWell(
                              onTap: () =>
                                  copyToClipboard(context, e.phone, 'الرقم'),
                              child: Text(
                                e.phone.isEmpty ? '-' : e.phone,
                                style: const TextStyle(fontFamily: 'Consolas'),
                              ),
                            ),
                          ),
                          DataCell(Text(e.notes)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEmailDialog(BuildContext context) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final gologinCtrl = TextEditingController();
    final recCtrl = TextEditingController(text: 'shami313p@gmail.com');
    final countryCtrl = TextEditingController(text: 'فرنسي');
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String status = 'يعمل';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة حساب بريد إلكتروني جديد'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الإيميل',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الباسوورد',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: gologinCtrl,
                        decoration: const InputDecoration(
                          labelText: 'حساب GoLogin',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: countryCtrl,
                        decoration: const InputDecoration(
                          labelText: 'الدولة',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: recCtrl,
                  decoration: const InputDecoration(
                    labelText: 'إيميل الربط / الاسترداد',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الرقم المربوط',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الملاحظات',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              widget.controller.emails.insert(
                0,
                EmailAccountModel(
                  email: emailCtrl.text.trim(),
                  password: passCtrl.text.trim(),
                  gologin: gologinCtrl.text.trim(),
                  recovery: recCtrl.text.trim(),
                  twoFa: '',
                  status: status,
                  notes: notesCtrl.text.trim(),
                  country: countryCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                ),
              );
              widget.controller.saveToDisk();
              Navigator.pop(ctx);
            },
            child: const Text('حفظ الحساب'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// الشاشة 6: حسابات جو لوجن (GoLogin Accounts Screen)
// ============================================================================

class GoLoginScreen extends StatelessWidget {
  final AppDataController controller;
  const GoLoginScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final totalProfiles =
        c.gologinAccounts.fold(0, (s, g) => s + g.registeredProfilesCount);
    final countriesCount =
        c.gologinAccounts.where((g) => g.country.trim().isNotEmpty).length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ResponsiveKpiGrid(
            cards: [
              KpiStatCard(
                title: '📊 إجمالي حسابات GoLogin',
                value: '${c.gologinAccounts.length}',
                subtitle: 'حسابات إدارة المتصفحات المعزولة',
                icon: Icons.web_rounded,
                color: const Color(0xFFA855F7),
              ),
              KpiStatCard(
                title: '💻 البروفايلات المسجلة',
                value: '$totalProfiles',
                subtitle: 'موزعة بواقع 3 بروفايلات لكل حساب نشط',
                icon: Icons.important_devices_rounded,
                color: const Color(0xFF38BDF8),
              ),
              KpiStatCard(
                title: '🌍 الحسابات المحددة بالدولة',
                value: '$countriesCount',
                subtitle: 'فرنسي، أمريكي، ألماني',
                icon: Icons.public_rounded,
                color: const Color(0xFF10B981),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('الحساب')),
                      DataColumn(label: Text('المنصة')),
                      DataColumn(label: Text('الإيميل (انقر للنسخ)')),
                      DataColumn(label: Text('الباسوورد')),
                      DataColumn(label: Text('Profile 1')),
                      DataColumn(label: Text('Profile 2')),
                      DataColumn(label: Text('Profile 3')),
                      DataColumn(label: Text('الدولة')),
                      DataColumn(label: Text('الملاحظات')),
                    ],
                    rows: c.gologinAccounts.map((g) {
                      return DataRow(
                        cells: [
                          DataCell(Text(g.accountType)),
                          DataCell(
                            Text(
                              g.platform,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataCell(
                            InkWell(
                              onTap: () => copyToClipboard(
                                context,
                                g.email,
                                'إيميل GoLogin',
                              ),
                              child: Text(
                                g.email,
                                style: const TextStyle(
                                  fontFamily: 'Consolas',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            InkWell(
                              onTap: () => copyToClipboard(
                                context,
                                g.password,
                                'باسوورد GoLogin',
                              ),
                              child: Text(
                                g.password,
                                style: const TextStyle(fontFamily: 'Consolas'),
                              ),
                            ),
                          ),
                          DataCell(
                            g.profile1.isEmpty
                                ? const Text('-')
                                : buildStatusBadge(g.profile1),
                          ),
                          DataCell(
                            g.profile2.isEmpty
                                ? const Text('-')
                                : buildStatusBadge(g.profile2),
                          ),
                          DataCell(
                            g.profile3.isEmpty
                                ? const Text('-')
                                : buildStatusBadge(g.profile3),
                          ),
                          DataCell(Text(g.country.isEmpty ? '-' : g.country)),
                          DataCell(Text(g.notes)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// الشاشة 7: إدارة البروكسيات (Proxies Screen - DataImpulse)
// ============================================================================

class ProxiesScreen extends StatefulWidget {
  final AppDataController controller;
  const ProxiesScreen({super.key, required this.controller});

  @override
  State<ProxiesScreen> createState() => _ProxiesScreenState();
}

class _ProxiesScreenState extends State<ProxiesScreen> {
  String _countryFilter = 'الكل';

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final countries = [
      'الكل',
      ...{...c.proxies.map((p) => p.country)}
    ];
    final filtered = c.proxies.where((p) {
      if (_countryFilter != 'الكل' && p.country != _countryFilter) return false;
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ResponsiveKpiGrid(
            cards: [
              KpiStatCard(
                title: '🌐 إجمالي البروكسيات المسجلة',
                value: '${c.proxies.length}',
                subtitle: 'DataImpulse Static HTTP Gateways',
                icon: Icons.router_rounded,
                color: const Color(0xFF2DD4BF),
              ),
              KpiStatCard(
                title: '✅ البروكسيات المتاحة',
                value: '${c.proxies.length - c.usedProxiesCount}',
                subtitle: 'جاهزة للربط الفوري على بروفايلات GoLogin',
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF10B981),
              ),
              KpiStatCard(
                title: '🔒 المستخدمة حالياً',
                value: '${c.usedProxiesCount}',
                subtitle: 'انقر على حالة أي بروكسي لتبديل حالة استخدامه',
                icon: Icons.vpn_lock_rounded,
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...countries.map(
                (cnt) => ChoiceChip(
                  label: Text(cnt),
                  selected: _countryFilter == cnt,
                  onSelected: (_) => setState(() => _countryFilter = cnt),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('الدولة')),
                      DataColumn(label: Text('تم استخدامه؟')),
                      DataColumn(label: Text('نوع البورت')),
                      DataColumn(label: Text('البروتوكول')),
                      DataColumn(label: Text('الرابط الكامل للنسخ الفوري')),
                      DataColumn(label: Text('Username')),
                      DataColumn(label: Text('Password')),
                      DataColumn(label: Text('Host')),
                      DataColumn(label: Text('Port')),
                      DataColumn(label: Text('نسخ')),
                    ],
                    rows: filtered.map((p) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              p.country,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataCell(
                            InkWell(
                              onTap: () {
                                p.isUsed = !p.isUsed;
                                c.saveToDisk();
                              },
                              child: buildStatusBadge(
                                p.isUsed ? 'نعم (مستخدم)' : 'متاح للاستخدام',
                              ),
                            ),
                          ),
                          DataCell(Text(p.portType)),
                          DataCell(Text(p.protocol.toUpperCase())),
                          DataCell(
                            SelectableText(
                              p.fullProxyString,
                              style: const TextStyle(
                                fontFamily: 'Consolas',
                                fontSize: 12,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              p.username,
                              style: const TextStyle(fontFamily: 'Consolas'),
                            ),
                          ),
                          DataCell(
                            Text(
                              p.password,
                              style: const TextStyle(fontFamily: 'Consolas'),
                            ),
                          ),
                          DataCell(
                            Text(
                              p.host,
                              style: const TextStyle(fontFamily: 'Consolas'),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${p.port}',
                              style: const TextStyle(
                                fontFamily: 'Consolas',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataCell(
                            FilledButton.tonalIcon(
                              icon: const Icon(Icons.copy_rounded, size: 15),
                              label: const Text('نسخ البروكسي'),
                              onPressed: () => copyToClipboard(
                                context,
                                p.fullProxyString,
                                'البروكسي (${p.country})',
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// الشاشة 8: الحسابات البنكية وربطها مع أمازون (Bank Accounts - Paysera LT)
// ============================================================================

class BankAccountsScreen extends StatefulWidget {
  final AppDataController controller;
  const BankAccountsScreen({super.key, required this.controller});

  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  String _filter = 'الكل';

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final list = c.bankAccounts.where((b) {
      if (_filter == 'مفعلة') return b.isLinked;
      if (_filter == 'جاهزة') return !b.isLinked;
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ResponsiveKpiGrid(
            cards: [
              KpiStatCard(
                title: '🏛️ إجمالي الحسابات البنكية',
                value: '${c.bankAccounts.length}',
                subtitle: 'Paysera LT, UAB (Lithuania IBANs)',
                icon: Icons.account_balance_rounded,
                color: const Color(0xFF60A5FA),
              ),
              KpiStatCard(
                title: '✅ الحسابات المفعلة والمربوطة',
                value: '${c.linkedBanksCount}',
                subtitle: 'مربوطة بحسابات أمازون بنجاح',
                icon: Icons.verified_rounded,
                color: const Color(0xFF10B981),
              ),
              KpiStatCard(
                title: '⏳ جاهز للربط (احتياطي)',
                value: '${c.bankAccounts.length - c.linkedBanksCount}',
                subtitle: 'حسابات آيبان جاهزة للربط مع متاجر جديدة',
                icon: Icons.hourglass_top_rounded,
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('الكل (${c.bankAccounts.length})'),
                selected: _filter == 'الكل',
                onSelected: (_) => setState(() => _filter = 'الكل'),
              ),
              ChoiceChip(
                label: Text('تم الربط بنجاح (${c.linkedBanksCount})'),
                selected: _filter == 'مفعلة',
                onSelected: (_) => setState(() => _filter = 'مفعلة'),
              ),
              ChoiceChip(
                label: Text(
                  'جاهز للربط (${c.bankAccounts.length - c.linkedBanksCount})',
                ),
                selected: _filter == 'جاهزة',
                onSelected: (_) => setState(() => _filter = 'جاهزة'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('رقم الآيبان (IBAN)')),
                      DataColumn(label: Text('اسم المستفيد البنكي')),
                      DataColumn(label: Text('رمز السويفت (BIC)')),
                      DataColumn(label: Text('اسم البنك')),
                      DataColumn(label: Text('عنوان البنك والدولة')),
                      DataColumn(label: Text('حالة الربط')),
                      DataColumn(label: Text('إيميل حساب أمازون')),
                      DataColumn(label: Text('اسم صاحب حساب أمازون')),
                      DataColumn(label: Text('تعديل الربط')),
                    ],
                    rows: list.map((b) {
                      return DataRow(
                        cells: [
                          DataCell(
                            InkWell(
                              onTap: () => copyToClipboard(
                                  context, b.iban, 'رقم الآيبان'),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.copy_rounded, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    b.iban,
                                    style: const TextStyle(
                                      fontFamily: 'Consolas',
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF38BDF8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(Text(b.beneficiaryName)),
                          DataCell(
                            InkWell(
                              onTap: () =>
                                  copyToClipboard(context, b.bic, 'BIC'),
                              child: Text(
                                b.bic,
                                style: const TextStyle(fontFamily: 'Consolas'),
                              ),
                            ),
                          ),
                          DataCell(Text(b.bankName)),
                          DataCell(
                            Text('${b.bankAddress} (${b.postalAndCountry})'),
                          ),
                          DataCell(buildStatusBadge(b.status)),
                          DataCell(
                            Text(
                              b.amazonEmail.isEmpty ? '-' : b.amazonEmail,
                              style: const TextStyle(fontFamily: 'Consolas'),
                            ),
                          ),
                          DataCell(
                            Text(
                              b.amazonAccountName.isEmpty
                                  ? '-'
                                  : b.amazonAccountName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              onPressed: () => _showLinkBankDialog(context, b),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLinkBankDialog(BuildContext context, BankAccountModel bank) {
    final emailCtrl = TextEditingController(text: bank.amazonEmail);
    final nameCtrl = TextEditingController(text: bank.amazonAccountName);
    String status = bank.status;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ربط وتحديث الآيبان: ${bank.iban}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: ['تم الربط بنجاح', 'جاهز للربط'].contains(status)
                    ? status
                    : 'جاهز للربط',
                decoration: const InputDecoration(
                  labelText: 'حالة الربط',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'تم الربط بنجاح',
                    child: Text('تم الربط بنجاح'),
                  ),
                  DropdownMenuItem(
                    value: 'جاهز للربط',
                    child: Text('جاهز للربط'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) status = v;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'إيميل حساب أمازون المربوط',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم صاحب الحساب على أمازون',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              bank.status = status;
              bank.amazonEmail = emailCtrl.text.trim();
              bank.amazonAccountName = nameCtrl.text.trim();
              widget.controller.saveToDisk();
              Navigator.pop(ctx);
            },
            child: const Text('حفظ التعديلات'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// الشاشة 9: المنصات الإعلانية، بلوبلر، وأفضل أوقات الترويج (Platforms & US Peak Hours)
// ============================================================================

class PlatformsAndTimingScreen extends StatelessWidget {
  final AppDataController controller;
  const PlatformsAndTimingScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // جدول المنصات الإعلانية وبلوبلر
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.ads_click_rounded, color: Color(0xFFF43F5E)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'المنصات الإعلانية المعتمدة وحسابات البروكسي وبلوبلر أدس (PropellerAds)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('التصنيف / الحساب')),
                        DataColumn(label: Text('اسم المنصة')),
                        DataColumn(label: Text('اسم المستخدم / الإيميل')),
                        DataColumn(label: Text('الباسوورد')),
                        DataColumn(label: Text('الرصيد / الملاحظات')),
                        DataColumn(label: Text('الرابط المباشر للوحة التحكم')),
                      ],
                      rows: c.platforms.map((p) {
                        return DataRow(
                          cells: [
                            DataCell(buildStatusBadge(p.category)),
                            DataCell(
                              Text(
                                p.name.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              InkWell(
                                onTap: () => copyToClipboard(
                                  context,
                                  p.usernameOrEmail,
                                  'اسم المستخدم',
                                ),
                                child: Text(
                                  p.usernameOrEmail,
                                  style: const TextStyle(
                                    fontFamily: 'Consolas',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              InkWell(
                                onTap: () => copyToClipboard(
                                  context,
                                  p.password,
                                  'الباسوورد',
                                ),
                                child: Text(
                                  p.password.isEmpty ? '-' : p.password,
                                  style:
                                      const TextStyle(fontFamily: 'Consolas'),
                                ),
                              ),
                            ),
                            DataCell(
                              p.notes.isEmpty
                                  ? const Text('جاهز للتشغيل')
                                  : buildStatusBadge(p.notes),
                            ),
                            DataCell(
                              InkWell(
                                onTap: () => copyToClipboard(
                                  context,
                                  p.url,
                                  'رابط المنصة',
                                ),
                                child: Text(
                                  p.url,
                                  style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontFamily: 'Consolas',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          // جدول أفضل أوقات الترويج وسلوك المستهلك الأمريكي
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.access_time_filled_rounded,
                          color: Color(0xFFF59E0B)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'بوصلة التوقيت الذكي: طبيعة وسلوك المستهلك الأمريكي (توقيت دمشق مقابل أمريكا EDT)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 520,
                      childAspectRatio: 2.6,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: c.promoTimes.length,
                    itemBuilder: (context, idx) {
                      final w = c.promoTimes[idx];
                      final isDead = w.windowName.contains('الميتة');
                      final isGolden = w.windowName.contains('الذهبية');
                      final accent = isDead
                          ? const Color(0xFFF43F5E)
                          : (isGolden
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF10B981));

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: accent.withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              w.windowName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.schedule_rounded, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'توقيت سوريا (دمشق): ',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                Text(
                                  w.syriaTime,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.public_rounded, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'التوقيت المحلي في أمريكا: ',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                Text(
                                  w.usTime,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// الشاشة 10: دليل وخطوات العمل الشاملة (21-Step SOP Workflow Checklist)
// ============================================================================

class WorkflowStepsScreen extends StatelessWidget {
  final AppDataController controller;
  const WorkflowStepsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final total = c.workflowSteps.length;
    final done = c.completedStepsCount;
    final pct = total > 0 ? done / total : 0.0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final progressWidth = constraints.maxWidth < 760
                      ? constraints.maxWidth
                      : constraints.maxWidth * 0.48;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: progressWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'نسبة إنجاز خطوات منظومة العمل القياسية: ${(pct * 100).toStringAsFixed(1)}% ($done من $total خطوة)',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 12,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.done_all_rounded, size: 18),
                        label: const Text('تحديد الكل كمكتمل'),
                        onPressed: () {
                          for (final s in c.workflowSteps) {
                            s.isCompleted = true;
                          }
                          c.saveToDisk();
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('تصفير الخطوات لدورة جديدة'),
                        onPressed: () {
                          for (final s in c.workflowSteps) {
                            s.isCompleted = false;
                          }
                          c.saveToDisk();
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: c.workflowSteps.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final step = c.workflowSteps[idx];
                  return CheckboxListTile(
                    value: step.isCompleted,
                    activeColor: const Color(0xFF10B981),
                    onChanged: (val) {
                      step.isCompleted = val ?? false;
                      c.saveToDisk();
                    },
                    secondary: CircleAvatar(
                      backgroundColor: step.isCompleted
                          ? const Color(0xFF10B981).withOpacity(0.2)
                          : const Color(0xFF38BDF8).withOpacity(0.15),
                      child: Text(
                        '${step.stepNumber}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: step.isCompleted
                              ? const Color(0xFF10B981)
                              : const Color(0xFF38BDF8),
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            step.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: step.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        buildStatusBadge(step.stage),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        Expanded(child: Text(step.details)),
                        IconButton(
                          tooltip: 'نسخ التفاصيل / الرابط',
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          onPressed: () => copyToClipboard(
                            context,
                            step.details,
                            step.title,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
