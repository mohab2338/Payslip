import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/reference_category.dart';
import '../models/reference_good.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/confirm_dialog.dart';

class GoodsReferenceScreen extends StatefulWidget {
  const GoodsReferenceScreen({super.key});

  @override
  State<GoodsReferenceScreen> createState() => _GoodsReferenceScreenState();
}

class _GoodsReferenceScreenState extends State<GoodsReferenceScreen> {
  static final _currency =
      NumberFormat.currency(symbol: 'E£', decimalDigits: 2);
  String? _selectedCategoryId;

  Future<void> _addCategory(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add category'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Category name'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter a category name'
                : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('Add category'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && context.mounted) {
      await context.read<AppState>().addReferenceCategory(name);
    }
  }

  Future<void> _editCategories(
      BuildContext context, List<ReferenceCategory> categories) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                      child: Text('Categories',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600))),
                  IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              if (categories.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('No categories yet.',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              else
                ...categories.map((category) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.category_outlined),
                      title: Text(category.name),
                    )),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _addCategory(context);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add category'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editGood(
    BuildContext context,
    List<ReferenceCategory> categories,
    List<String> allShops, {
    ReferenceGood? good,
  }) async {
    final nameController = TextEditingController(text: good?.name ?? '');
    final categoryController = ValueNotifier<String?>(good?.categoryId);
    final formKey = GlobalKey<FormState>();
    final shopNames = <String>{...allShops, ...?good?.shopPrices.keys}.toList()
      ..sort();
    final shopControllers = <String, TextEditingController>{
      for (final shop in shopNames)
        shop: TextEditingController(
            text: good?.shopPrices[shop]?.toString() ?? ''),
    };
    final newShopController = TextEditingController();
    final prices = <String, double>{...?good?.shopPrices};
    StateSetter? refreshDialog;

    void addShop() {
      final shop = newShopController.text.trim();
      if (shop.isEmpty ||
          shopControllers.keys.any(
              (existing) => existing.toLowerCase() == shop.toLowerCase())) {
        return;
      }
      refreshDialog?.call(() {
        shopControllers[shop] = TextEditingController();
        newShopController.clear();
      });
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          refreshDialog = setDialogState;
          return AlertDialog(
            title: Text(good == null ? 'Add good' : 'Edit good'),
            content: SizedBox(
              width: 520,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        decoration:
                            const InputDecoration(labelText: 'Good name'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter a good name'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<String?>(
                        valueListenable: categoryController,
                        builder: (context, selected, _) =>
                            DropdownButtonFormField<String>(
                          initialValue: selected,
                          decoration:
                              const InputDecoration(labelText: 'Category'),
                          items: categories
                              .map((category) => DropdownMenuItem(
                                    value: category.id,
                                    child: Text(category.name),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              categoryController.value = value,
                          validator: (value) =>
                              value == null ? 'Choose a category' : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Shop prices',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 8),
                      if (shopControllers.isEmpty)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Add at least one shop and its price.',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ),
                      ...shopControllers.entries.map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Text(entry.key,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis)),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 130,
                                  child: TextFormField(
                                    controller: entry.value,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: const InputDecoration(
                                        labelText: 'Price', prefixText: 'E£ '),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return null;
                                      }
                                        final parsed = double.tryParse(value.trim());
                                      return parsed == null || parsed <= 0
                                          ? 'Enter valid price'
                                          : null;
                                    },
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove shop price',
                                  onPressed: () => setDialogState(() {
                                    shopControllers
                                        .remove(entry.key)
                                        ?.dispose();
                                    prices.remove(entry.key);
                                  }),
                                  icon: const Icon(Icons.remove_circle_outline,
                                      color: AppColors.danger),
                                ),
                              ],
                            ),
                          )),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: newShopController,
                              textCapitalization: TextCapitalization.words,
                              decoration:
                                  const InputDecoration(labelText: 'New shop'),
                              onSubmitted: (_) => addShop(),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Add shop',
                            onPressed: addShop,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  final enteredPrices = shopControllers.values
                      .where((controller) => controller.text.trim().isNotEmpty)
                      .toList();
                  if (enteredPrices.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                          content: Text('Add a price for at least one shop.')),
                    );
                    return;
                  }
                  for (final entry in shopControllers.entries) {
                    final value = entry.value.text.trim();
                    if (value.isEmpty) {
                      prices.remove(entry.key);
                    } else {
                      prices[entry.key] = double.parse(value);
                    }
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Save good'),
              ),
            ],
          );
        },
      ),
    );

    void disposeControllers() {
      nameController.dispose();
      categoryController.dispose();
      newShopController.dispose();
      for (final controller in shopControllers.values) {
        controller.dispose();
      }
    }

    if (result == true && context.mounted && categoryController.value != null) {
      await context.read<AppState>().saveReferenceGood(
            id: good?.id,
            name: nameController.text,
            categoryId: categoryController.value!,
            shopPrices: prices,
          );
    }
    disposeControllers();
  }

  Future<void> _removeGood(BuildContext context, ReferenceGood good) async {
    if (await confirmDelete(context, itemLabel: good.name) && context.mounted) {
      await context.read<AppState>().removeReferenceGood(good.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goods price reference'),
        actions: [
          IconButton(
            tooltip: 'Manage categories',
            icon: const Icon(Icons.category_outlined),
            onPressed: () => _manageCategories(context),
          ),
          IconButton(
            tooltip: 'Add good',
            icon: const Icon(Icons.add),
            onPressed: () => _openAddGood(context),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<ReferenceCategory>>(
          stream: state.watchReferenceCategories(),
          builder: (context, categoriesSnapshot) {
            if (categoriesSnapshot.hasError)
              return const Center(child: Text('Could not load categories.'));
            if (!categoriesSnapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final categories = categoriesSnapshot.data!;
            if (_selectedCategoryId != null &&
                !categories
                    .any((category) => category.id == _selectedCategoryId)) {
              _selectedCategoryId = null;
            }
            return StreamBuilder<List<ReferenceGood>>(
              stream: state.watchReferenceGoods(),
              builder: (context, goodsSnapshot) {
                if (goodsSnapshot.hasError)
                  return const Center(child: Text('Could not load goods.'));
                if (!goodsSnapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final goods = goodsSnapshot.data!;
                final visibleGoods = _selectedCategoryId == null
                    ? goods
                    : goods
                        .where((good) => good.categoryId == _selectedCategoryId)
                        .toList();
                final shops = goods
                    .expand((good) => good.shopPrices.keys)
                    .toSet()
                    .toList()
                  ..sort();
                final categoryOrder = {
                  for (var i = 0; i < categories.length; i++)
                    categories[i].id: i
                };
                visibleGoods.sort((a, b) {
                  final categoryCompare = (categoryOrder[a.categoryId] ?? 999)
                      .compareTo(categoryOrder[b.categoryId] ?? 999);
                  return categoryCompare != 0
                      ? categoryCompare
                      : a.name.toLowerCase().compareTo(b.name.toLowerCase());
                });

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          const Text('Show:',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              initialValue: _selectedCategoryId,
                              decoration: const InputDecoration(
                                  isDense: true, labelText: 'Category'),
                              items: [
                                const DropdownMenuItem<String?>(
                                    value: null, child: Text('All categories')),
                                ...categories.map((category) =>
                                    DropdownMenuItem<String?>(
                                        value: category.id,
                                        child: Text(category.name))),
                              ],
                              onChanged: (value) =>
                                  setState(() => _selectedCategoryId = value),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: categories.isEmpty
                          ? _emptyCategories()
                          : visibleGoods.isEmpty
                              ? _emptyGoods()
                              : _goodsTable(categories, visibleGoods, shops),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _emptyCategories() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.category_outlined,
                  size: 42, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              const Text('Add a category before adding goods.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                  onPressed: () => _addCategory(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add category')),
            ],
          ),
        ),
      );

  Widget _emptyGoods() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 42, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(
                  _selectedCategoryId == null
                      ? 'No goods saved yet.'
                      : 'No goods in this category yet.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                  onPressed: () => _openAddGood(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add good')),
            ],
          ),
        ),
      );

  Widget _goodsTable(List<ReferenceCategory> categories,
      List<ReferenceGood> goods, List<String> shops) {
    final grouped = <String, List<ReferenceGood>>{};
    for (final good in goods) {
      grouped.putIfAbsent(good.categoryId, () => []).add(good);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const nameColumnWidth = 170.0;
        const cheapestColumnWidth = 170.0;
        const shopColumnWidth = 128.0;
        final minWidth = nameColumnWidth +
            cheapestColumnWidth +
            shops.length * shopColumnWidth;
        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: minWidth < constraints.maxWidth - 32
                  ? constraints.maxWidth - 32
                  : minWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _tableRow(
                    height: 48,
                    color: AppColors.primary,
                    children: [
                      _cell('Good', nameColumnWidth, header: true),
                      ...shops.map(
                          (shop) => _cell(shop, shopColumnWidth, header: true)),
                      _cell('Best price', cheapestColumnWidth, header: true),
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final category in categories.where((category) =>
                            grouped.containsKey(category.id))) ...[
                          Container(
                            height: 38,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            color: AppColors.accentLight,
                            child: Text(category.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accent)),
                          ),
                          for (final good in grouped[category.id]!)
                            _goodRow(good, shops, nameColumnWidth,
                                shopColumnWidth, cheapestColumnWidth),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _goodRow(ReferenceGood good, List<String> shops, double nameWidth,
      double shopWidth, double bestWidth) {
    final cheapestShop = good.cheapestShop;
    final cheapestPrice = good.cheapestPrice;
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: () => _openEditGood(context, good),
        onLongPress: () => _removeGood(context, good),
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider))),
          child: Row(
            children: [
              SizedBox(
                width: nameWidth,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    Expanded(
                        child: Text(good.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600))),
                    PopupMenuButton<String>(
                      tooltip: 'Good options',
                      onSelected: (action) {
                        if (action == 'edit') _openEditGood(context, good);
                        if (action == 'delete') _removeGood(context, good);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit good')),
                        PopupMenuItem(
                            value: 'delete', child: Text('Delete good')),
                      ],
                    ),
                  ]),
                ),
              ),
              ...shops.map((shop) => _cell(
                    good.shopPrices[shop] == null
                        ? '—'
                        : _currency.format(good.shopPrices[shop]),
                    shopWidth,
                    alignEnd: true,
                  )),
              SizedBox(
                width: bestWidth,
                child: Container(
                  margin: const EdgeInsets.all(5),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(10)),
                  child: cheapestShop == null
                      ? const Text('—')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cheapestShop,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.accent)),
                            Text(_currency.format(cheapestPrice),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableRow(
          {required double height,
          required Color color,
          required List<Widget> children}) =>
      Container(
        height: height,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(12)),
        child: Row(children: children),
      );

  Widget _cell(String text, double width,
          {bool header = false, bool alignEnd = false}) =>
      SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              color: header ? Colors.white : AppColors.textPrimary,
              fontWeight: header ? FontWeight.w700 : FontWeight.w500,
              fontSize: header ? 12 : 13,
            ),
          ),
        ),
      );

  Future<void> _manageCategories(BuildContext context) async {
    final state = context.read<AppState>();
    final categories = await state.watchReferenceCategories().first;
    if (!context.mounted) return;
    await _editCategories(context, categories);
  }

  Future<void> _openAddGood(BuildContext context) async {
    final state = context.read<AppState>();
    final categories = await state.watchReferenceCategories().first;
    final goods = await state.watchReferenceGoods().first;
    final shops = goods.expand((good) => good.shopPrices.keys).toSet().toList()
      ..sort();
    if (context.mounted && categories.isNotEmpty) {
      await _editGood(context, categories, shops);
    } else if (context.mounted) {
      await _addCategory(context);
    }
  }

  Future<void> _openEditGood(BuildContext context, ReferenceGood good) async {
    final state = context.read<AppState>();
    final categories = await state.watchReferenceCategories().first;
    final goods = await state.watchReferenceGoods().first;
    final shops =
        goods.expand((entry) => entry.shopPrices.keys).toSet().toList()..sort();
    if (!context.mounted) return;
    await _editGood(context, categories, shops, good: good);
  }
}
