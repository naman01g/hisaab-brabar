import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/firebase_auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final authService = FirebaseAuthService();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLogin = true;
  bool isLoading = false;
  bool obscurePassword = true;

  String? errorMessage;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (!email.contains('@') || !email.contains('.')) {
      setState(() => errorMessage = 'Enter a valid email address.');
      return;
    }

    if (password.length < 6) {
      setState(() => errorMessage = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      if (isLogin) {
        await authService.signIn(email: email, password: password);
      } else {
        await authService.register(email: email, password: password);
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => errorMessage = _authError(error.code));
    } catch (_) {
      if (!mounted) return;
      setState(() => errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await authService.signInWithGoogle();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => errorMessage = _authError(error.code));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Google sign-in failed or was cancelled. Try again.';
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _authError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase.';
      case 'network-request-failed':
        return 'Check your internet connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  Widget _inputField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool password = false,
  }) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      keyboardType: keyboardType,
      obscureText: password && obscurePassword,
      autocorrect: false,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      prefix: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Icon(icon, color: AppColors.textSecondary),
      ),
      suffix: password
          ? CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(40, 40),
              onPressed: () {
                setState(() => obscurePassword = !obscurePassword);
              },
              child: Icon(
                obscurePassword ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                color: AppColors.textSecondary,
                size: 19,
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  CupertinoIcons.person_2,
                  size: 66,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Hisaab Brabar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isLogin
                      ? 'Welcome back! Sign in to continue.'
                      : 'Create an account and start splitting.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 36),
                Text(
                  isLogin ? 'Sign In' : 'Create Account',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),

                _inputField(
                  controller: emailController,
                  placeholder: 'Email address',
                  icon: CupertinoIcons.mail,
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 14),

                _inputField(
                  controller: passwordController,
                  placeholder: 'Password',
                  icon: CupertinoIcons.lock,
                  password: true,
                ),

                if (errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(14),
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const CupertinoActivityIndicator(
                          color: CupertinoColors.white,
                        )
                      : Text(isLogin ? 'Sign In' : 'Create Account'),
                ),

                const SizedBox(height: 12),

                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: isLoading ? null : _googleSignIn,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.globe,
                          color: AppColors.textPrimary,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Continue with Google',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                CupertinoButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          setState(() {
                            isLogin = !isLogin;
                            errorMessage = null;
                          });
                        },
                  child: Text(
                    isLogin
                        ? "Don't have an account? Register"
                        : 'Already have an account? Sign In',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
