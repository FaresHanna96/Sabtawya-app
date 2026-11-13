import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User _user({List<UserIdentity>? identities}) => User(
      id: 'u1',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-11-12T00:00:00Z',
      identities: identities,
    );

UserIdentity _identity() => UserIdentity(
      id: 'u1',
      userId: 'u1',
      identityData: const {},
      identityId: 'i1',
      provider: 'email',
      createdAt: '2026-11-12T00:00:00Z',
      lastSignInAt: '2026-11-12T00:00:00Z',
    );

void main() {
  group('isExistingAccountReply', () {
    test('a stand-in user with no identities means the email is taken', () {
      expect(
          AuthRepository.isExistingAccountReply(_user(identities: [])), isTrue);
    });

    test('a real new user has an email identity', () {
      expect(
          AuthRepository.isExistingAccountReply(
              _user(identities: [_identity()])),
          isFalse);
    });

    test('no user, or identities not sent, is not treated as taken', () {
      expect(AuthRepository.isExistingAccountReply(null), isFalse);
      expect(AuthRepository.isExistingAccountReply(_user()), isFalse);
    });
  });

  group('emailVerdict', () {
    test('accepted, or no answer, is no message', () {
      expect(AuthRepository.emailVerdict({'ok': true}), isNull);
      expect(AuthRepository.emailVerdict(null), isNull);
    });

    test('throwaway inbox', () {
      expect(
        AuthRepository.emailVerdict({'ok': false, 'reason': 'disposable'}),
        AppStrings.emailDisposable,
      );
    });

    test('typo names the likely address', () {
      final message = AuthRepository.emailVerdict({
        'ok': false,
        'reason': 'typo',
        'suggestion': 'mina@gmail.com',
      });
      expect(message, contains('mina@gmail.com'));
    });

    test('anything else is an invalid email', () {
      expect(
        AuthRepository.emailVerdict({'ok': false, 'reason': 'invalid'}),
        AppStrings.invalidEmail,
      );
    });
  });
}
