import 'package:flutter/material.dart';
import '../theme.dart';

/// Shows a "are you sure?" dialog before a destructive delete. Returns true
/// only if the person explicitly confirmed.
Future<bool> confirmDelete(BuildContext context, {required String itemLabel}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Delete this item?'),
      content: Text('Remove "$itemLabel"? This can\'t be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}
