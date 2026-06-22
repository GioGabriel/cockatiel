---
inclusion: fileMatch
fileMatchPattern: "mobile/**/*_page.dart,mobile/**/widgets/**/*.dart"
---

# Flutter Widget Patterns (loaded when working on UI files)

## Widget Structure Template

```dart
class MyFeaturePage extends StatefulWidget {
  const MyFeaturePage({super.key});

  @override
  State<MyFeaturePage> createState() => _MyFeaturePageState();
}

class _MyFeaturePageState extends State<MyFeaturePage> {
  // 1. State variables (private, final where possible)
  // 2. Lifecycle methods (initState, dispose)
  // 3. Build method
  // 4. Private helper build methods (_buildSection)

  @override
  void dispose() {
    // ALWAYS dispose controllers, timers, subscriptions
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      // Use theme tokens, not hardcoded values
    );
  }
}
```

## Common Patterns

### Loading + Error + Content (tristate)

```dart
if (_isLoading) return const _ShimmerPlaceholder();
if (_error != null) return _ErrorCard(message: _error!, onRetry: _load);
return _buildContent();
```

### Safe async setState

```dart
Future<void> _loadData() async {
  setState(() => _isLoading = true);
  try {
    final data = await _apiClient.fetchSomething();
    if (!mounted) return;
    setState(() { _data = data; _isLoading = false; });
  } catch (e) {
    if (!mounted) return;
    setState(() { _error = e.toString(); _isLoading = false; });
  }
}
```

### Reusable card pattern

```dart
Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(body, style: theme.textTheme.bodyMedium),
      ],
    ),
  ),
)
```

## Anti-Patterns to Avoid

- `Container()` for spacing → use `SizedBox(height: X)`
- `Color(0xFF...)` inline → use `colors.primary`, `colors.secondary`
- `TextStyle(fontSize: 18)` inline → use `theme.textTheme.titleMedium`
- `MediaQuery.of(context).size.width * 0.9` → use `LayoutBuilder` or constrained width
- Building entire list in Column → use `ListView.builder`
- Nested Columns inside SingleChildScrollView → use `CustomScrollView` with slivers
