import 'package:flutter/material.dart';

/// Reusable yes/no confirmation for destructive or hard-to-reverse
/// actions (disable a record, discard unsaved changes, etc.) across ERP
/// modules. Returns `true` only if the user tapped the confirm action.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool isDestructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        isDestructive
            ? FilledButton.tonal(
                style: FilledButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmLabel),
              )
            : FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmLabel),
              ),
      ],
    ),
  );
  return confirmed ?? false;
}
