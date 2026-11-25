import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/utils/year_month.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/models/transaction_models.dart';
import '../../../../data/providers/data_providers.dart';
import '../../domain/transaction_formatters.dart';
import '../../providers/transactions_provider.dart';

/// Mở hộp thoại thêm mới hoặc chỉnh sửa giao dịch.
Future<bool?> showTransactionFormDialog(
  BuildContext context, {
  TransactionWithCategory? initial,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => TransactionFormDialog(initial: initial),
  );
}

/// Mở hộp thoại xác nhận xóa giao dịch.
Future<bool?> showDeleteTransactionDialog(
  BuildContext context,
  TransactionWithCategory item,
) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Xóa giao dịch?'),
      content: Text(
        'Bạn có chắc muốn xóa khoản ${formatTxType(item.transaction.type).toLowerCase()} '
        '${formatVnd(item.transaction.amount)} (${item.category.name}) '
        'ngày ${formatDate(item.transaction.transactionDate)}?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Xóa'),
        ),
      ],
    ),
  );
}

class TransactionFormDialog extends ConsumerStatefulWidget {
  const TransactionFormDialog({super.key, this.initial});

  final TransactionWithCategory? initial;

  @override
  ConsumerState<TransactionFormDialog> createState() =>
      _TransactionFormDialogState();
}

class _TransactionFormDialogState extends ConsumerState<TransactionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TxType _type;
  late DateTime _transactionDate;
  int? _categoryId;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late bool _isNotable;

  bool _isSaving = false;
  String? _submitError;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.initial?.transaction;
    _type = tx?.type ?? TxType.expense;
    _transactionDate = dateOnly(tx?.transactionDate ?? DateTime.now());
    _categoryId = tx?.categoryId;
    _amountController = TextEditingController(
      text: tx == null ? '' : tx.amount.toString(),
    );
    _noteController = TextEditingController(text: tx?.note ?? '');
    _isNotable = tx?.isNotable ?? false;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Chọn ngày giao dịch',
    );
    if (picked == null) return;
    setState(() => _transactionDate = dateOnly(picked));
  }

  Future<void> _submit(List<CategoryRow> categories) async {
    setState(() => _submitError = null);

    if (!_formKey.currentState!.validate()) return;

    final selectedCategoryId = _resolveCategoryId(categories);
    if (selectedCategoryId == null) {
      setState(() => _submitError = 'Vui lòng chọn danh mục.');
      return;
    }

    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(
        () => _submitError = 'Số tiền phải là số nguyên dương lớn hơn 0.',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final existing = widget.initial?.transaction;
      final payload = NewTransaction(
        transactionDate: dateOnly(_transactionDate),
        type: _type,
        categoryId: selectedCategoryId,
        amount: amount,
        note: _noteController.text.trim(),
        isNotable: _isNotable,
        source: existing?.source ?? TxSource.manual,
        syncBatchId: existing?.syncBatchId,
        merchantName: existing?.merchantName,
        receiptImagePath: existing?.receiptImagePath,
        externalRef: existing?.externalRef,
      );

      final actions = ref.read(transactionActionsProvider);
      if (_isEditing) {
        await actions.update(existing!.id, payload);
      } else {
        await actions.add(payload);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _submitError =
            'Không thể lưu giao dịch. Vui lòng kiểm tra lại dữ liệu.';
      });
    }
  }

  int? _resolveCategoryId(List<CategoryRow> categories) {
    if (categories.isEmpty) return null;
    if (_categoryId != null && categories.any((c) => c.id == _categoryId)) {
      return _categoryId;
    }
    return categories.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesProvider(_type));
    final categories = categoriesAsync.asData?.value ?? const <CategoryRow>[];
    final effectiveCategoryId = _resolveCategoryId(categories);

    return AlertDialog(
      title: Text(_isEditing ? 'Sửa giao dịch' : 'Thêm giao dịch'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<TxType>(
                  segments: const [
                    ButtonSegment<TxType>(
                      value: TxType.expense,
                      label: Text('Chi'),
                      icon: Icon(Icons.arrow_upward, size: 16),
                    ),
                    ButtonSegment<TxType>(
                      value: TxType.income,
                      label: Text('Thu'),
                      icon: Icon(Icons.arrow_downward, size: 16),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: _isSaving
                      ? null
                      : (selection) {
                          final nextType = selection.first;
                          if (nextType == _type) return;
                          setState(() {
                            _type = nextType;
                            _categoryId = null;
                          });
                        },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _isSaving ? null : _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Ngày giao dịch',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                    child: Text(formatDate(_transactionDate)),
                  ),
                ),
                const SizedBox(height: 16),
                if (categoriesAsync.isLoading)
                  const LinearProgressIndicator()
                else if (categoriesAsync.hasError)
                  Text(
                    'Không tải được danh sách danh mục.',
                    style: TextStyle(color: theme.colorScheme.error),
                  )
                else
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Danh mục',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: effectiveCategoryId,
                        isExpanded: true,
                        items: [
                          for (final cat in categories)
                            DropdownMenuItem<int>(
                              value: cat.id,
                              child: Row(
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
                        onChanged: _isSaving
                            ? null
                            : (value) => setState(() => _categoryId = value),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Số tiền (VNĐ)',
                    hintText: 'Ví dụ: 65000',
                    suffixText: '₫',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final raw = value?.trim() ?? '';
                    if (raw.isEmpty) return 'Vui lòng nhập số tiền.';
                    final parsed = int.tryParse(raw);
                    if (parsed == null || parsed <= 0) {
                      return 'Số tiền phải là số nguyên dương lớn hơn 0.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteController,
                  enabled: !_isSaving,
                  maxLines: 3,
                  minLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    hintText: 'Nhập nội dung chi tiết (không bắt buộc)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _isNotable,
                  onChanged: _isSaving
                      ? null
                      : (v) => setState(() => _isNotable = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Đánh dấu đáng chú ý (Visual Notes)'),
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _submitError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : () => _submit(categories),
          child: Text(_isSaving ? 'Đang lưu...' : 'Lưu'),
        ),
      ],
    );
  }
}
