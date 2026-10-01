import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/note_item.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/confirm_dialog.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  Future<void> _editNote(BuildContext context, NoteItem? note) async {
    final titleController = TextEditingController(text: note?.title ?? '');
    final bodyController = TextEditingController(text: note?.body ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(note == null ? 'Add note' : 'Edit note'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Enter a title' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: bodyController,
                  minLines: 4,
                  maxLines: 8,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Write your note',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(
                  dialogContext,
                  (titleController.text.trim(), bodyController.text.trim()),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    titleController.dispose();
    bodyController.dispose();

    if (result == null || !context.mounted) return;
    final now = DateTime.now();
    final savedNote = NoteItem(
      id: note?.id ?? now.microsecondsSinceEpoch.toString(),
      title: result.$1,
      body: result.$2,
      createdAt: note?.createdAt ?? now,
      updatedAt: now,
    );
    await context.read<AppState>().saveNote(savedNote);
  }

  Future<void> _deleteNote(BuildContext context, NoteItem note) async {
    if (await confirmDelete(context, itemLabel: note.title) && context.mounted) {
      await context.read<AppState>().removeNote(note.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editNote(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Add note'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<NoteItem>>(
          stream: state.watchNotes(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Could not load notes. Please try again.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final notes = snapshot.data!;
            if (notes.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No notes yet. Tap “Add note” to write your first one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sticky_note_2_outlined, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _editNote(context, note),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(note.title,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                if (note.body.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    note.body,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                ],
                                const SizedBox(height: 5),
                                Text(
                                  'Updated ${DateFormat.yMMMd().add_jm().format(note.updatedAt)}',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit note',
                        onPressed: () => _editNote(context, note),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                      IconButton(
                        tooltip: 'Delete note',
                        onPressed: () => _deleteNote(context, note),
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: AppColors.danger),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
