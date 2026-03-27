import 'package:flutter/material.dart';
import '../services/poll_service.dart';

/// Screen that lets a group admin create a new poll.
///
/// Requires:
/// - [groupId]: the group chat this poll belongs to.
/// - [token]: current user's auth JWT.
/// - [baseUrl]: backend base URL (e.g. `http://localhost:8081`).
///
/// On success the route is popped with the newly created poll id (String).
class CreatePollScreen extends StatefulWidget {
  final String groupId;
  final String token;
  final String baseUrl;

  const CreatePollScreen({
    super.key,
    required this.groupId,
    required this.token,
    required this.baseUrl,
  });

  @override
  State<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePollScreen> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();

  /// Option text controllers — always at least 2, at most 10.
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _isAnonymous = false;
  DateTime? _closesAt;
  bool _isSubmitting = false;

  late final PollServiceClient _pollService;

  @override
  void initState() {
    super.initState();
    _pollService = PollServiceClient(baseUrl: widget.baseUrl);
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 10) return;
    setState(() => _optionControllers.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (!mounted) return;
    setState(() {
      _closesAt = time == null
          ? picked
          : DateTime(
              picked.year, picked.month, picked.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    try {
      final pollId = await _pollService.createPoll(
        token: widget.token,
        groupId: widget.groupId,
        question: _questionController.text.trim(),
        options: options,
        isAnonymous: _isAnonymous,
        closesAt: _closesAt,
      );
      if (mounted) Navigator.pop(context, pollId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create poll: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Poll')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Question field
            TextFormField(
              controller: _questionController,
              decoration: const InputDecoration(
                labelText: 'Question',
                hintText: 'What do you want to ask?',
                border: OutlineInputBorder(),
              ),
              maxLength: 300,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Question is required';
                }
                if (v.trim().length < 3) {
                  return 'Question must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Options
            const Text(
              'Options (2–10)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ..._optionControllers.asMap().entries.map((entry) {
              final i = entry.key;
              final ctrl = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: ctrl,
                        decoration: InputDecoration(
                          labelText: 'Option ${i + 1}',
                          border: const OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: i < 2
                            ? (v) => (v == null || v.trim().isEmpty)
                                ? 'Option ${i + 1} is required'
                                : null
                            : null,
                      ),
                    ),
                    if (_optionControllers.length > 2)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => _removeOption(i),
                        tooltip: 'Remove option',
                      ),
                  ],
                ),
              );
            }),
            if (_optionControllers.length < 10)
              TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add),
                label: const Text('Add option'),
              ),
            const SizedBox(height: 16),

            // Anonymous toggle
            SwitchListTile(
              title: const Text('Anonymous votes'),
              subtitle: const Text('Voter names will be hidden'),
              value: _isAnonymous,
              onChanged: (v) => setState(() => _isAnonymous = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),

            // Optional deadline
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Deadline (optional)'),
              subtitle: Text(
                _closesAt != null
                    ? '${_closesAt!.toLocal()}'.split('.').first
                    : 'No deadline',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_closesAt != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _closesAt = null),
                      tooltip: 'Remove deadline',
                    ),
                  TextButton(
                    onPressed: _pickDeadline,
                    child: const Text('Set'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Create button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Poll'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
