import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_strings.dart';

/// Turns backend errors into Arabic messages a servant can act on.
///
/// Row level security rejections surface as Postgres error 42501 or an empty
/// result, so they are mapped to a clear "no permission" message rather than a
/// raw SQL string.
class AppFailure implements Exception {
  AppFailure(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => message;

  static AppFailure from(Object error) {
    if (error is AppFailure) return error;

    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login credentials')) {
        return AppFailure(AppStrings.invalidCredentials,
            code: error.statusCode);
      }
      if (message.contains('already registered') ||
          message.contains('user already exists')) {
        return AppFailure(AppStrings.emailAlreadyUsed, code: error.statusCode);
      }
      if (message.contains('email not confirmed')) {
        return AppFailure(
          'لم يتم تأكيد البريد الإلكتروني بعد.',
          code: error.statusCode,
        );
      }
      return AppFailure(error.message, code: error.statusCode, cause: error);
    }

    if (error is StorageException) {
      final message = error.message.toLowerCase();
      if (message.contains('maximum allowed size')) {
        return AppFailure(AppStrings.photoTooLarge, code: error.statusCode);
      }
      if (message.contains('mime type')) {
        return AppFailure(
          AppStrings.photoTypeNotSupported,
          code: error.statusCode,
        );
      }
      // A storage policy rejection arrives as 403 rather than 42501.
      if (error.statusCode == '403' || message.contains('unauthorized')) {
        return AppFailure(AppStrings.noPermission, code: error.statusCode);
      }
      return AppFailure(error.message, code: error.statusCode, cause: error);
    }

    if (error is PostgrestException) {
      switch (error.code) {
        case '42501': // insufficient_privilege, i.e. an RLS policy said no
          return AppFailure(AppStrings.noPermission, code: error.code);
        case '23505': // unique_violation
          if (error.message.contains('class_servants_one_class')) {
            return AppFailure(AppStrings.servantOneClass, code: error.code);
          }
          return AppFailure('هذه البيانات موجودة بالفعل.', code: error.code);
        case '23503': // foreign_key_violation
          return AppFailure(
            'لا يمكن إتمام العملية لوجود بيانات مرتبطة.',
            code: error.code,
          );
        case '23514': // check_violation, raised by our integrity triggers
          return AppFailure(error.message, code: error.code);
      }
      // Our triggers raise Arabic messages, so they are safe to show as-is.
      return AppFailure(error.message, code: error.code, cause: error);
    }

    return AppFailure(AppStrings.somethingWentWrong, cause: error);
  }
}
