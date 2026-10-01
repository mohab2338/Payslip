import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense_item.dart';
import '../services/app_state.dart';

class AddItemScreen extends StatefulWidget {
  final ExpenseItem? item;
  final bool noteOnly;

  const AddItemScreen({super.key, this.item, this.noteOnly = false});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _titleCtrl.text = item.title;
      _amountCtrl.text = item.amount.toStringAsFixed(2);
      _noteCtrl.text = item.note;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final state = context.read<AppState>();
    if (widget.item == null) {
      await state.addExpenseItem(
        _titleCtrl.text.trim(),
        double.parse(_amountCtrl.text),
        note: _noteCtrl.text.trim(),
      );
    } else {
      await state.updateExpenseItem(widget.item!.copyWith(
        title: widget.noteOnly ? null : _titleCtrl.text.trim(),
        amount: widget.noteOnly ? null : double.parse(_amountCtrl.text),
        note: _noteCtrl.text.trim(),
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.noteOnly ? 'Purchase note' : widget.item == null ? 'Add purchase' : 'Edit purchase'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.noteOnly) TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'What did you buy?',
                    prefixIcon: Icon(Icons.shopping_bag_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                if (!widget.noteOnly) const SizedBox(height: 14),
                if (!widget.noteOnly) TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: 'E£ ',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                if (!widget.noteOnly) const SizedBox(height: 14),
                TextFormField(
                  controller: _noteCtrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(widget.noteOnly ? 'Save note' : widget.item == null ? 'Save purchase' : 'Save changes'),
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
