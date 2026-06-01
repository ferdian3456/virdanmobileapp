abstract final class Routes {
  static const root = '/';

  static const authLogin = '/auth/login';
  static const authRegister = '/auth/register';
  static const authVerifyOtp = '/auth/verify-otp';
  static const authVerifyUsername = '/auth/verify-username';
  static const authVerifyPassword = '/auth/verify-password';

  static const onboardingServerChoice = '/onboarding/server-choice';
  static const onboardingCreateServer = '/onboarding/create-server';

  static const appHome = '/app/home';
  static const appExplore = '/app/explore';
  static const appCreate = '/app/create';
  static const appNotifications = '/app/notifications';
  static const appProfile = '/app/profile';

  static const appCreateServer = '/app/create-server';
  static const appJoin = '/join';
  static const appChat = '/chat';
  static const appEditProfile = '/profile/edit';

  static const settings = '/settings';
  static const settingsEmail = '/settings/email';
  static const settingsPassword = '/settings/password';
  static const settingsNotifications = '/settings/notifications';
  static const settingsPrivacy = '/settings/privacy';
  static const settingsHelp = '/settings/help';
  static const settingsTerms = '/settings/terms';
  static const settingsPrivacyPolicy = '/settings/privacy-policy';

  static const devSmoke = '/dev/smoke';

  static String serverDetail(String id) => '/server/$id';
  static String serverSettings(String id) => '/server/$id/settings';
  static String postDetail(String id) => '/posts/$id';
  static String postComments(String id) => '/posts/$id/comments';
  static String exploreFeed(String postId) => '/explore/feed/$postId';
  static String userProfile(String userId) => '/profile/$userId';
}
