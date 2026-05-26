import 'package:flutter/material.dart';
import '../../../core/router/app_router.dart';

class ContactsScreen extends StatelessWidget {
	const ContactsScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Contacts')),
			body: const Center(child: Text('Contacts screen (placeholder)')),
			floatingActionButton: FloatingActionButton(
				onPressed: () => Navigator.pushNamed(context, AppRouter.trigger),
				child: const Icon(Icons.arrow_forward),
			),
		);
	}
}

