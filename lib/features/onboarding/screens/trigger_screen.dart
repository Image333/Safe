import 'package:flutter/material.dart';
import '../../../core/router/app_router.dart';

class TriggerScreen extends StatelessWidget {
	const TriggerScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Déclencheur')),
			body: const Center(child: Text('Trigger screen (placeholder)')),
			floatingActionButton: FloatingActionButton(
				onPressed: () => Navigator.pushNamed(context, AppRouter.pin),
				child: const Icon(Icons.arrow_forward),
			),
		);
	}
}

