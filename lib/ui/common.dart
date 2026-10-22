import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../data/models.dart';

class ErrorPanel extends StatelessWidget {
  const ErrorPanel(this.error, {super.key, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(errorText(error), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    ),
  );
}

void showError(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(errorText(error))));

class PageList<T> extends StatefulWidget {
  const PageList({
    super.key,
    required this.load,
    required this.item,
    required this.empty,
  });
  final Future<PageData<T>> Function(int page) load;
  final Widget Function(T item, VoidCallback refresh) item;
  final String empty;
  @override
  State<PageList<T>> createState() => _PageListState<T>();
}

class _PageListState<T> extends State<PageList<T>> {
  late Future<PageData<T>> _future;
  int _page = 0;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _future = _fetch(_page);
  }

  Future<PageData<T>> _fetch(int page) async {
    final request = ++_request;
    final data = await widget.load(page);
    if (request != _request) return data;
    if (data.items.isEmpty && page > 0 && page * data.size >= data.total) {
      final last = data.total == 0 ? 0 : (data.total - 1) ~/ data.size;
      final result = await widget.load(last);
      if (mounted && request == _request) _page = last;
      return result;
    }
    return data;
  }

  void _load([int? page]) {
    setState(() {
      _page = page ?? _page;
      _future = _fetch(_page);
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PageData<T>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: ErrorPanel(snapshot.error!, onRetry: () => _load()),
        );
      }
      final page = snapshot.data!;
      return RefreshIndicator(
        onRefresh: () async {
          _load();
          await _future.catchError((Object _) => page);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (page.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.empty,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => _load(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Làm mới'),
                    ),
                  ],
                ),
              ),
            ...page.items.map((item) => widget.item(item, () => _load())),
            const SizedBox(height: 12),
            if (page.total > 0)
              Text(
                'Trang ${page.page + 1} · Tổng ${page.total}',
                textAlign: TextAlign.center,
              ),
            if (page.total > page.size)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _page > 0 ? () => _load(_page - 1) : null,
                    child: const Text('Trước'),
                  ),
                  TextButton(
                    onPressed: !page.last ? () => _load(_page + 1) : null,
                    child: const Text('Sau'),
                  ),
                  IconButton(
                    onPressed: () => _load(),
                    tooltip: 'Làm mới',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );
}

class DetailView<T> extends StatefulWidget {
  const DetailView({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(T value) builder;
  @override
  State<DetailView<T>> createState() => _DetailViewState<T>();
}

class _DetailViewState<T> extends State<DetailView<T>> {
  late Future<T> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: ErrorPanel(
            snapshot.error!,
            onRetry: () => setState(() => _future = widget.load()),
          ),
        );
      }
      return widget.builder(snapshot.data as T);
    },
  );
}

String? requiredText(String? value, {int min = 1, int max = 100}) {
  final text = value?.trim() ?? '';
  return text.length < min || text.length > max
      ? 'Nhập từ $min đến $max ký tự.'
      : null;
}

String? emailError(String? value) =>
    value == null ||
        value.length > 100 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
    ? 'Email chưa hợp lệ.'
    : null;
String? phoneError(String? value) =>
    value != null &&
        value.isNotEmpty &&
        !RegExp(r'^[0-9+]{9,15}$').hasMatch(value)
    ? 'Số điện thoại gồm 9–15 chữ số hoặc dấu +.'
    : null;
