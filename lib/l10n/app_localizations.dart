import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'Party Hub'**
  String get appName;

  /// No description provided for @home.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get home;

  /// No description provided for @messages.
  ///
  /// In ar, this message translates to:
  /// **'الرسائل'**
  String get messages;

  /// No description provided for @ranking.
  ///
  /// In ar, this message translates to:
  /// **'الترتيب'**
  String get ranking;

  /// No description provided for @profile.
  ///
  /// In ar, this message translates to:
  /// **'الملف الشخصي'**
  String get profile;

  /// No description provided for @createRoom.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء غرفة'**
  String get createRoom;

  /// No description provided for @search.
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get search;

  /// No description provided for @login.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @register.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب'**
  String get register;

  /// No description provided for @phoneNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get phoneNumber;

  /// No description provided for @password.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get password;

  /// No description provided for @confirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @edit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @send.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get send;

  /// No description provided for @close.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get close;

  /// No description provided for @back.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get back;

  /// No description provided for @next.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get next;

  /// No description provided for @done.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get done;

  /// No description provided for @loading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحميل...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In ar, this message translates to:
  /// **'خطأ'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @noInternet.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال بالإنترنت'**
  String get noInternet;

  /// No description provided for @welcome.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً بك في Party Hub'**
  String get welcome;

  /// No description provided for @liveRooms.
  ///
  /// In ar, this message translates to:
  /// **'الغرف الحية'**
  String get liveRooms;

  /// No description provided for @popular.
  ///
  /// In ar, this message translates to:
  /// **'الأكثر شعبية'**
  String get popular;

  /// No description provided for @newest.
  ///
  /// In ar, this message translates to:
  /// **'الأحدث'**
  String get newest;

  /// No description provided for @nearby.
  ///
  /// In ar, this message translates to:
  /// **'القريبة'**
  String get nearby;

  /// No description provided for @gaming.
  ///
  /// In ar, this message translates to:
  /// **'ألعاب'**
  String get gaming;

  /// No description provided for @music.
  ///
  /// In ar, this message translates to:
  /// **'موسيقى'**
  String get music;

  /// No description provided for @all.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get all;

  /// No description provided for @online.
  ///
  /// In ar, this message translates to:
  /// **'متصل'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In ar, this message translates to:
  /// **'غير متصل'**
  String get offline;

  /// No description provided for @followers.
  ///
  /// In ar, this message translates to:
  /// **'المتابعون'**
  String get followers;

  /// No description provided for @following.
  ///
  /// In ar, this message translates to:
  /// **'يتابع'**
  String get following;

  /// No description provided for @friends.
  ///
  /// In ar, this message translates to:
  /// **'الأصدقاء'**
  String get friends;

  /// No description provided for @coins.
  ///
  /// In ar, this message translates to:
  /// **'عملات'**
  String get coins;

  /// No description provided for @diamonds.
  ///
  /// In ar, this message translates to:
  /// **'ألماس'**
  String get diamonds;

  /// No description provided for @gifts.
  ///
  /// In ar, this message translates to:
  /// **'الهدايا'**
  String get gifts;

  /// No description provided for @wallet.
  ///
  /// In ar, this message translates to:
  /// **'المحفظة'**
  String get wallet;

  /// No description provided for @vip.
  ///
  /// In ar, this message translates to:
  /// **'VIP'**
  String get vip;

  /// No description provided for @level.
  ///
  /// In ar, this message translates to:
  /// **'المستوى'**
  String get level;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @notifications.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get notifications;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get language;

  /// No description provided for @arabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In ar, this message translates to:
  /// **'الإنجليزية'**
  String get english;

  /// No description provided for @darkMode.
  ///
  /// In ar, this message translates to:
  /// **'الوضع الداكن'**
  String get darkMode;

  /// No description provided for @privacyPolicy.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In ar, this message translates to:
  /// **'شروط الخدمة'**
  String get termsOfService;

  /// No description provided for @version.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار'**
  String get version;

  /// No description provided for @mic.
  ///
  /// In ar, this message translates to:
  /// **'الميكروفون'**
  String get mic;

  /// No description provided for @mute.
  ///
  /// In ar, this message translates to:
  /// **'كتم الصوت'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الكتم'**
  String get unmute;

  /// No description provided for @seats.
  ///
  /// In ar, this message translates to:
  /// **'المقاعد'**
  String get seats;

  /// No description provided for @host.
  ///
  /// In ar, this message translates to:
  /// **'المضيف'**
  String get host;

  /// No description provided for @kick.
  ///
  /// In ar, this message translates to:
  /// **'طرد'**
  String get kick;

  /// No description provided for @ban.
  ///
  /// In ar, this message translates to:
  /// **'حظر'**
  String get ban;

  /// No description provided for @report.
  ///
  /// In ar, this message translates to:
  /// **'إبلاغ'**
  String get report;

  /// No description provided for @block.
  ///
  /// In ar, this message translates to:
  /// **'حظر المستخدم'**
  String get block;

  /// No description provided for @follow.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get follow;

  /// No description provided for @unfollow.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء المتابعة'**
  String get unfollow;

  /// No description provided for @sendGift.
  ///
  /// In ar, this message translates to:
  /// **'إرسال هدية'**
  String get sendGift;

  /// No description provided for @sendMessage.
  ///
  /// In ar, this message translates to:
  /// **'إرسال رسالة'**
  String get sendMessage;

  /// No description provided for @roomName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الغرفة'**
  String get roomName;

  /// No description provided for @roomPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة مرور الغرفة'**
  String get roomPassword;

  /// No description provided for @enterRoom.
  ///
  /// In ar, this message translates to:
  /// **'الدخول للغرفة'**
  String get enterRoom;

  /// No description provided for @leaveRoom.
  ///
  /// In ar, this message translates to:
  /// **'مغادرة الغرفة'**
  String get leaveRoom;

  /// No description provided for @endRoom.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء الغرفة'**
  String get endRoom;

  /// No description provided for @typeMessage.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالة...'**
  String get typeMessage;

  /// No description provided for @noRoomsFound.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد غرف متاحة'**
  String get noRoomsFound;

  /// No description provided for @noMessagesYet.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رسائل بعد'**
  String get noMessagesYet;

  /// No description provided for @partyTime.
  ///
  /// In ar, this message translates to:
  /// **'وقت الحفلة!'**
  String get partyTime;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
