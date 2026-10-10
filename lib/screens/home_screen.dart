import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/expense_item.dart';
import '../models/spending_category.dart';
import '../models/month_data.dart';
import '../models/purchase_group.dart';
import '../theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/spend_ring.dart';
import '../widgets/stat_card.dart';
import 'add_item_screen.dart';
import 'history_screen.dart';
import 'savings_overview_screen.dart';
import 'settings_screen.dart';
import 'notes_screen.dart';
import 'goals_screen.dart';
import 'category_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static final _currency = NumberFormat.currency(symbol: 'E£', decimalDigits: 2);
  bool _selectionMode = false;
  final Set<String> _selectedItemIds = {};

  static const _categoryPalettes = [
    (Color(0xFFB42318), Color(0xFFFDE3E1), Color(0xFFF17D6C)),
    (Color(0xFFB7791F), Color(0xFFFFF3C4), Color(0xFFE9C76A)),
    (Color(0xFF0F7A52), Color(0xFFDCFCE7), Color(0xFF5CC989)),
    (Color(0xFF1565C0), Color(0xFFE3F2FD), Color(0xFF78B6F8)),
    (Color(0xFF1E2A78), Color(0xFFE0E7FF), Color(0xFF8AA2FF)),
    (Color(0xFFB61E5D), Color(0xFFFCE7F3), Color(0xFFF28AC3)),
    (Color(0xFF5B39A6), Color(0xFFEDE7FF), Color(0xFFB29DFF)),
  ];

  IconData _iconForCategoryName(String name) {
    final value = name.toLowerCase();
    if (value.contains('food') || value.contains('grocer') || value.contains('restaurant')) {
      return Icons.restaurant_outlined;
    }
    if (value.contains('transport') || value.contains('car') || value.contains('fuel')) {
      return Icons.directions_car_outlined;
    }
    if (value.contains('shop') || value.contains('cloth') || value.contains('clothing')) {
      return Icons.shopping_bag_outlined;
    }
    if (value.contains('health') || value.contains('medical') || value.contains('pharmacy')) {
      return Icons.favorite_border;
    }
    if (value.contains('home') || value.contains('house') || value.contains('rent')) {
      return Icons.home_outlined;
    }
    if (value.contains('bill') || value.contains('utility') || value.contains('electric')) {
      return Icons.receipt_long_outlined;
    }
    if (value.contains('entertain') || value.contains('movie') || value.contains('game')) {
      return Icons.movie_outlined;
    }
    if (value.contains('education') || value.contains('school') || value.contains('book')) {
      return Icons.school_outlined;
    }
    if (value.contains('travel') || value.contains('flight') || value.contains('holiday')) {
      return Icons.flight_outlined;
    }
    if (value.contains('pet')) return Icons.pets_outlined;
    if (value.contains('gift')) return Icons.card_giftcard_outlined;
    if (value.contains('phone') || value.contains('internet') || value.contains('mobile')) {
      return Icons.wifi_outlined;
    }
    return Icons.category_outlined;
  }

  (Color, Color, Color) _paletteForCategory(int index) =>
      _categoryPalettes[index % _categoryPalettes.length];

  Future<void> _addBudgetCategory(BuildContext context, {SpendingCategory? category}) async {
    final month = context.read<AppState>().currentMonth;
    final otherBudgets = month?.categories
            .where((entry) => entry.id != category?.id)
            .fold(0.0, (sum, entry) => sum + entry.budgetAmount) ??
        0.0;
    final maxBudget = (month?.allowedToSpend ?? 0) - otherBudgets;
    final nameController = TextEditingController(text: category?.name ?? '');
    final budgetController = TextEditingController(
      text: category?.budgetAmount.toStringAsFixed(2) ?? '',
    );
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<(String, double)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(category == null ? 'Add spending category' : 'Edit spending category'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Category name'),
                validator: (value) => value == null || value.trim().isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: budgetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Allowed amount',
                  prefixText: 'E£ ',
                  helperText:
                      'Available to assign: ${_currency.format(maxBudget < 0 ? 0 : maxBudget)}',
                ),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');
                  if (amount == null || amount <= 0) return 'Enter a valid amount';
                  if (amount > maxBudget) return 'Cannot exceed the remaining allowed spending';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, (nameController.text.trim(), double.parse(budgetController.text.trim())));
              }
            },
            child: Text(category == null ? 'Add category' : 'Save changes'),
          ),
        ],
      ),
    );
    nameController.dispose();
    budgetController.dispose();
    if (result != null && context.mounted) {
      final appState = context.read<AppState>();
      if (category == null) {
        await appState.addSpendingCategory(result.$1, result.$2);
      } else {
        await appState.updateSpendingCategory(SpendingCategory(
          id: category.id,
          name: result.$1,
          budgetAmount: result.$2,
        ));
      }
    }
  }

  Future<void> _deleteBudgetCategory(BuildContext context, SpendingCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${category.name}?'),
        content: const Text('Purchases in this category will become uncategorized.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AppState>().removeSpendingCategory(category.id);
    }
  }

  Future<void> _createPurchaseGroup(BuildContext context) async {
    if (_selectedItemIds.isEmpty) return;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Name this purchase group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Group name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('Create group'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && context.mounted) {
      await context.read<AppState>().createPurchaseGroup(name, Set<String>.from(_selectedItemIds));
      setState(() {
        _selectedItemIds.clear();
        _selectionMode = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final month = state.currentMonth;

    if (month == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final selectedTotal = month.items
        .where((item) => _selectedItemIds.contains(item.id))
        .fold(0.0, (sum, item) => sum + item.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Our Life'),
        actions: [
          IconButton(
            tooltip: _selectionMode ? 'Finish selecting purchases' : 'Select purchases',
            icon: Icon(_selectionMode ? Icons.close : Icons.checklist),
            onPressed: () => setState(() {
              _selectionMode = !_selectionMode;
              if (!_selectionMode) _selectedItemIds.clear();
            }),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) {
              final page = value == 'goals' ? const GoalsScreen() : const NotesScreen();
              Navigator.push(context, MaterialPageRoute(builder: (_) => page));
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'goals',
                child: ListTile(
                  leading: Icon(Icons.flag_outlined),
                  title: Text('Our goals'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'notes',
                child: ListTile(
                  leading: Icon(Icons.sticky_note_2_outlined),
                  title: Text('Notes'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_outlined),
            tooltip: 'Savings overview',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SavingsOverviewScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddItemScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add purchase'),
            ),
      bottomNavigationBar: _selectionMode
          ? SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selected total',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_currency.format(selectedTotal)}  ·  ${_selectedItemIds.length} items',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _selectedItemIds.isEmpty ? null : () => _createPurchaseGroup(context),
                      icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                      label: const Text('Group'),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => state.loadForCurrentUser(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              Text(
                'Cycle starting ${DateFormat.yMMMd().format(month.periodStart)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),

              // Hero tile: ring + "allowed to spend" figure, on dark purple.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    SpendRing(percentage: month.spentPercentage, size: 84, onDark: true),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Allowed to spend',
                            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currency.format(month.allowedToSpend),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_currency.format(month.totalSpent)} spent so far',
                            style: TextStyle(color: AppColors.primaryLight, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Salary (filled green) + Saved (white), side by side.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Salary',
                        value: _currency.format(month.salary),
                        fillColor: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        label: 'Saved',
                        value: _currency.format(month.savingGoal),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Remaining, full-width row tile.
              StatCard(
                label: 'Remaining',
                value: _currency.format(month.remaining),
                valueColor: month.remaining < 0 ? AppColors.danger : AppColors.textPrimary,
                row: true,
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text('Spending categories',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  TextButton.icon(
                    onPressed: () => _addBudgetCategory(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add part'),
                  ),
                ],
              ),
              if (month.categories.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Create budget parts to divide your allowed spending.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (int index = 0; index < month.categories.length; index++)
                      LongPressDraggable<SpendingCategory>(
                        data: month.categories[index],
                        delay: const Duration(milliseconds: 150),
                        feedback: Material(
                          color: Colors.transparent,
                          child: Transform.scale(
                            scale: 1.02,
                            child: SizedBox(
                              width: (MediaQuery.of(context).size.width - 68) / 2,
                              child: _buildCategoryCard(
                                context,
                                month,
                                month.categories[index],
                                index,
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.35,
                          child: _buildCategoryCard(
                            context,
                            month,
                            month.categories[index],
                            index,
                          ),
                        ),
                        child: DragTarget<SpendingCategory>(
                          onAcceptWithDetails: (details) {
                            final draggedId = details.data.id;
                            final targetId = month.categories[index].id;
                            if (draggedId == targetId) return;
                            final oldIndex = month.categories.indexWhere((category) => category.id == draggedId);
                            final newIndex = month.categories.indexWhere((category) => category.id == targetId);
                            if (oldIndex >= 0 && newIndex >= 0) {
                              context.read<AppState>().reorderSpendingCategories(oldIndex, newIndex);
                            }
                          },
                          builder: (context, candidateData, rejectedData) {
                            return _buildCategoryCard(
                              context,
                              month,
                              month.categories[index],
                              index,
                            );
                          },
                        ),
                      ),
                  ],
                ),

              if (month.purchaseGroups.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Purchase groups',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...month.purchaseGroups.map(
                  (group) => _buildPurchaseGroupCard(context, state, month, group),
                ),
              ],

              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text('Purchases this cycle',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  if (_selectionMode)
                    Text('${_selectedItemIds.length} selected',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 10),

              if (month.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No purchases yet. Tap "Add purchase" to log one.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              else
                ...month.items.reversed.map((item) => Dismissible(
                      key: ValueKey(item.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => confirmDelete(context, itemLabel: item.title),
                      onDismissed: (_) {
                        _selectedItemIds.remove(item.id);
                        state.removeExpenseItem(item);
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.delete_outline, color: AppColors.danger),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F8F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            if (_selectionMode)
                              Checkbox(
                                value: _selectedItemIds.contains(item.id),
                                onChanged: (selected) => setState(() {
                                  if (selected == true) {
                                    _selectedItemIds.add(item.id);
                                  } else {
                                    _selectedItemIds.remove(item.id);
                                  }
                                }),
                              ),
                              _purchaseIcon(month, item),
                              const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat.yMMMd().add_jm().format(item.date),
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  if (item.note.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.note,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Text(
                              _currency.format(item.amount),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            IconButton(
                              tooltip: 'Edit purchase',
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(width: 36, height: 40),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.edit_outlined, size: 19),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => AddItemScreen(item: item)),
                              ),
                            ),
                            IconButton(
                              tooltip: item.note.isEmpty ? 'Add note' : 'Edit note',
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(width: 36, height: 40),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.note_add_outlined, size: 19),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddItemScreen(item: item, noteOnly: true),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    MonthData month,
    SpendingCategory category,
    int index, {
    Key? key,
  }) {
    final categoryItems = month.items
        .where((ExpenseItem item) => item.categoryId == category.id)
        .toList();
    final spent = categoryItems.fold(0.0, (sum, item) => sum + item.amount);
    final left = category.budgetAmount - spent;
    final palette = _paletteForCategory(index);
    final progress = category.budgetAmount <= 0
        ? 0.0
        : (spent / category.budgetAmount).clamp(0.0, 1.0).toDouble();
    final cardWidth = (MediaQuery.of(context).size.width - 68) / 2;
    return SizedBox(
      key: key,
      width: cardWidth,
      child: Container(
        decoration: BoxDecoration(color: palette.$1, borderRadius: BorderRadius.circular(22)),
        child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CategoryDetailScreen(month: month, category: category)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_iconForCategoryName(category.name), color: palette.$2, size: 21),
                  const Spacer(),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    iconSize: 19,
                    icon: Icon(Icons.more_horiz, color: palette.$2),
                    onSelected: (action) {
                      if (action == 'edit') _addBudgetCategory(context, category: category);
                      if (action == 'delete') _deleteBudgetCategory(context, category);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit category')),
                      PopupMenuItem(value: 'delete', child: Text('Delete category')),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '${_currency.format(spent)} of ${_currency.format(category.budgetAmount)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.$2, fontSize: 11),
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: Colors.black.withOpacity(0.18),
                  color: palette.$3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${categoryItems.length} items · ${_currency.format(left)} left',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.$2.withOpacity(0.95), fontSize: 10),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _purchaseIcon(MonthData month, ExpenseItem item) {
    final categoryIndex = month.categories.indexWhere((category) => category.id == item.categoryId);
    if (categoryIndex < 0) {
      return const CircleAvatar(
        radius: 21,
        backgroundColor: Color(0xFFE4F3EF),
        child: Icon(Icons.shopping_bag_outlined, size: 20, color: AppColors.accent),
      );
    }
    final category = month.categories[categoryIndex];
    final palette = _paletteForCategory(categoryIndex);
    return CircleAvatar(
      radius: 21,
      backgroundColor: palette.$2.withOpacity(0.42),
      child: Icon(_iconForCategoryName(category.name), size: 20, color: palette.$1),
    );
  }

  Widget _buildPurchaseGroupCard(
    BuildContext context,
    AppState state,
    MonthData month,
    PurchaseGroup group,
  ) {
    final groupedItems = month.items
        .where((ExpenseItem item) => item.groupId == group.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = groupedItems.fold(0.0, (sum, item) => sum + item.amount);
    return Dismissible(
      key: ValueKey('purchase-group-${group.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDelete(context, itemLabel: group.name),
      onDismissed: (_) => state.removePurchaseGroup(group.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: const Icon(Icons.folder_outlined, color: AppColors.primary),
        title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${groupedItems.length} purchases'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_currency.format(total), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more),
          ],
        ),
        children: groupedItems.isEmpty
            ? [const ListTile(title: Text('No purchases in this group.'))]
            : groupedItems
                .map((item) => ListTile(
                      dense: true,
                      title: Text(item.title),
                      trailing: Text(_currency.format(item.amount)),
                    ))
                .toList(),
        ),
      ),
    );
  }
}
