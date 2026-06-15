import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/base/local_data_base.dart';
import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/core/utils/helpers/platform/platform_helper.dart';
import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/data/repositories/user_repository.dart';
import 'package:eflutter/presentation/app/cubit/app_cubit.dart';
import 'package:eflutter/presentation/app/navigation/app_router.dart';
import 'package:eflutter/presentation/app/theme/app_theme.dart';
import 'package:eflutter/presentation/app/widgets/app_widget.dart';
import 'package:eflutter/presentation/auth/cubit/auth_cubit.dart';
import 'package:eflutter/presentation/profile/cubit/profile_cubit.dart';
import 'package:eflutter/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  await _clearAuthStorageForNewDevSession();
  final authCubit = getIt<AuthCubit>();
  await [
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    authCubit.init(),
  ].wait;

  configureUrlStrategy();
  final appCubit = getIt<AppCubit>();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: authCubit),
        BlocProvider.value(value: appCubit),
        BlocProvider(
          create: (_) =>
              ProfileCubit(UserRepository(getIt<RemoteDataBase>()), appCubit),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> _clearAuthStorageForNewDevSession() async {
  const devSession = String.fromEnvironment('DEV_AUTH_STORAGE_SESSION');
  if (devSession.isEmpty) return;

  const devSessionKey = 'devAuthStorageSession';
  final prefs = getIt<SharedPreferencesAsync>();
  final previousSession = await prefs.getString(devSessionKey);
  if (previousSession == devSession) return;

  await getIt<LocalDataBase>().clearTokens();
  await prefs.setString(devSessionKey, devSession);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('vi', 'VN')],
      themeMode: ThemeMode.light,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        final MediaQueryData data = MediaQuery.of(context);
        return MediaQuery(
          data: data.copyWith(
            textScaler: TextScaler.noScaling,
            boldText: false,
          ),
          child: AppWidget(child: LoadingWidget(child: child!)),
        );
      },
    );
  }
}
