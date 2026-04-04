import 'package:flutter/material.dart';

/// Shown when [MaterialApp.onGenerateRoute] receives an unknown name.
/// Does not run auth/splash logic (unlike routing to [SplashScreen]).
class UnknownRouteScreen extends StatelessWidget {
  final String? routeName;

  const UnknownRouteScreen({super.key, this.routeName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (routeName != null && routeName!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  routeName!,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacementNamed('/home');
                  }
                },
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
