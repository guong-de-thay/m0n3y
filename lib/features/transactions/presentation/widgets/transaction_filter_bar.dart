import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/utils/year_month.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/providers/data_providers.dart';
import '../../domain/transaction_formatters.dart';
import '../../providers/transactions_provider.dart';

/// Thanh lọc đa chiều và nút thêm giao dịch mới.
class TransactionFilterBar extends ConsumerStatefulWidget {
  const TransactionFilterBar({super.key, required this.onAddPressed});

  final VoidCallback onAddPressed;

  @override
  ConsumerState<TransactionFilterBar> createState() =>
      _TransactionFilterBarState();
}

class _TransactionFilterBarState extends ConsumerState<TransactionFilterBar> {
  late final TextEditingController _keywordController;

  @override
  void initState() {
    super.initState();
    final initialKeyword = ref.read(transactionFilterProvider).keyword ?? '';
    _keywordController = TextEditingController(text: initialKeyword);
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final filter = ref.read(transactionFilterProvider);
    final initialDate = (isFrom ? filter.from : filter.to) ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: isFrom ? 'Chọn từ ngày' : 'Chọn đến ngày',
    );
    if (picked == null) return;

    final notifier = ref.read(transactionFilterProvider.notifier);
    final normalized = dateOnly(picked);
    if (isFrom) {
      notifier.setFrom(normalized);
    } else {
      notifier.setTo(normalized);
    }
  }

  void _clearAll() {
    _keywordController.clear();
    ref.read(transactionFilterProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(transactionFilterProvider);
    final categoriesAsync = ref.watch(categoriesProvider(filter.type));
    final notifier = ref.read(transactionFilterProvider.notifier);

    final categories = categoriesAsync.asData?.value ?? const <CategoryRow>[];
    final validCategoryId = categories.any((c) => c.id == filter.categoryId)
        ? filter.categoryId
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 240,
            child: TextField(
              controller: _keywordController,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Tìm theo ghi chú...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _keywordController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Xóa từ khóa',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _keywordController.clear();
                          notifier.setKeyword(null);
                          setState(() {});
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                notifier.setKeyword(value);
                setState(() {});
              },
            ),
          ),
          _DropdownBox<TxType?>(
            label: 'Loại',
            value: filter.type,
            items: const [
              DropdownMenuItem<TxType?>(value: null, child: Text('Tất cả')),
              DropdownMenuItem<TxType?>(
                value: TxType.income,
                child: Text('Thu'),
              ),
              DropdownMenuItem<TxType?>(
                value: TxType.expense,
                child: Text('Chi'),
              ),
            ],
            onChanged: notifier.setType,
          ),
          _DropdownBox<int?>(
            label: 'Danh mục',
            value: validCategoryId,
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Tất cả danh mục'),
              ),
              for (final cat in categories)
                DropdownMenuItem<int?>(
                  value: cat.id,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Color(cat.colorHex),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(cat.name),
                    ],
                  ),
                ),
            ],
            onChanged: notifier.setCategoryId,
          ),
          _DateFilterButton(
            label: filter.from == null
                ? 'Từ ngày'
                : 'Từ: ${formatDate(filter.from!)}',
            hasValue: filter.from != null,
            onPressed: () => _pickDate(isFrom: true),
            onClear: filter.from == null ? null : () => notifier.setFrom(null),
          ),
          _DateFilterButton(
            label: filter.to == null
                ? 'Đến ngày'
                : 'Đến: ${formatDate(filter.to!)}',
            hasValue: filter.to != null,
            onPressed: () => _pickDate(isFrom: false),
            onClear: filter.to == null ? null : () => notifier.setTo(null),
          ),
          if (!filter.isEmpty)
            TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Xóa lọc'),
            ),
          FilledButton.icon(
            onPressed: widget.onAddPressed,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Thêm giao dịch'),
          ),
        ],
      ),
    );
  }
}

class _DropdownBox<T> extends StatelessWidget {
  const _DropdownBox({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          hint: Text(label),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton({
    required this.label,
    required this.hasValue,
    required this.onPressed,
    this.onClear,
  });

  final String label;
  final bool hasValue;
  final VoidCallback onPressed;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(label),
        ),
        if (hasValue && onClear != null)
          IconButton(
            tooltip: 'Bỏ ngày',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 16),
            onPressed: onClear,
          ),
      ],
    );
  }
}
