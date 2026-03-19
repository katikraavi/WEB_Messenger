import 'package:flutter/material.dart';

/// Message input box widget (T041, T044, T078)
/// 
/// Provides text input field with send button for composing messages
/// 
/// Features:
/// - Text input with auto-focus
/// - Send button that disables when empty
/// - Loading state during send
/// - Character counter (optional)
/// - Typing indicator detection (T044: 100ms debounce with 3s refresh)
/// - Media attachment buttons (T078)
class MessageInputBox extends StatefulWidget {
  final Function(String) onSend;
  final bool isLoading;
  final VoidCallback? onAttachmentTap;
  final VoidCallback? onImageTap; // Callback for image attachment (T078)
  final VoidCallback? onVideoTap; // Callback for video attachment (T078)
  final int maxLength;
  final TextEditingController? controller;
  
  /// Callback when user starts typing (called once per typing session)
  final VoidCallback? onTypingStart;
  
  /// Callback when user stops typing (called on blur or send)
  final VoidCallback? onTypingStop;
  
  /// Callback to refresh typing indicator every 3 seconds while typing
  final VoidCallback? onTypingRefresh;

  const MessageInputBox({
    Key? key,
    required this.onSend,
    this.isLoading = false,
    this.onAttachmentTap,
    this.onImageTap,
    this.onVideoTap,
    this.maxLength = 5000,
    this.controller,
    this.onTypingStart,
    this.onTypingStop,
    this.onTypingRefresh,
  }) : super(key: key);

  @override
  State<MessageInputBox> createState() => _MessageInputBoxState();
}

class _MessageInputBoxState extends State<MessageInputBox> {
  late TextEditingController _controller;
  bool _isEmpty = true;
  
  // Typing detection (T044)
  bool _isCurrentlyTyping = false;
  Future<void>? _typingDebounceTimer;
  Future<void>? _typingRefreshTimer;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_updateIsEmpty);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    _typingDebounceTimer?.ignore();
    _typingRefreshTimer?.ignore();
    super.dispose();
  }

  void _updateIsEmpty() {
    setState(() {
      _isEmpty = _controller.text.isEmpty;
    });
    
    // Handle typing detection (T044)
    _handleTypingDetection();
  }
  
  /// Handle typing detection with 100ms debounce and 3s refresh (T044)
  void _handleTypingDetection() {
    // Cancel existing debounce timer
    _typingDebounceTimer?.ignore();
    
    if (_controller.text.isEmpty) {
      // Text is empty - stop typing
      if (_isCurrentlyTyping) {
        _isCurrentlyTyping = false;
        widget.onTypingStop?.call();
        _typingRefreshTimer?.ignore();
      }
      return;
    }
    
    // Text is not empty - debounce for 100ms
    _typingDebounceTimer = Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      
      // After debounce, check if we need to send typing.start
      if (!_isCurrentlyTyping) {
        _isCurrentlyTyping = true;
        widget.onTypingStart?.call();
        
        // Refresh typing indicator every 3 seconds while typing
        _scheduleTypingRefresh();
      }
    });
  }
  
  /// Schedule typing refresh every 3 seconds
  void _scheduleTypingRefresh() {
    _typingRefreshTimer?.ignore();
    _typingRefreshTimer = Future.delayed(const Duration(seconds: 3), () {
      if (!mounted || !_isCurrentlyTyping) return;
      
      // Still typing - send refresh
      widget.onTypingRefresh?.call();
      
      // Schedule next refresh
      _scheduleTypingRefresh();
    });
  }
  
  /// Call when input field loses focus
  void _handleInputBlur() {
    if (_isCurrentlyTyping) {
      _isCurrentlyTyping = false;
      widget.onTypingStop?.call();
      _typingRefreshTimer?.ignore();
    }
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !widget.isLoading) {
      // Stop typing when sending
      if (_isCurrentlyTyping) {
        _isCurrentlyTyping = false;
        widget.onTypingStop?.call();
        _typingRefreshTimer?.ignore();
      }
      
      widget.onSend(text);
      _controller.clear();
      _updateIsEmpty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          // Image attachment button (T078)
          if (widget.onImageTap != null)
            IconButton(
              icon: Icon(Icons.image),
              onPressed: widget.isLoading ? null : widget.onImageTap,
              tooltip: 'Attach image',
            ),

          // Video attachment button (T078)
          if (widget.onVideoTap != null)
            IconButton(
              icon: Icon(Icons.videocam),
              onPressed: widget.isLoading ? null : widget.onVideoTap,
              tooltip: 'Attach video',
            ),

          // Message input field
          Expanded(
            child: Focus(
              onFocusChange: (isFocused) {
                if (isFocused) {
                  // Focus - could start typing
                } else {
                  // Blur - stop typing
                  _handleInputBlur();
                }
              },
              child: TextField(
                controller: _controller,
                enabled: !widget.isLoading,
                maxLength: widget.maxLength,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  counterText: '', // Hide char counter (can be shown if needed)
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          ),

          SizedBox(width: 8),

          // Send button
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _isEmpty || widget.isLoading
                  ? Colors.grey.shade300
                  : Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isEmpty || widget.isLoading ? null : _handleSend,
                customBorder: CircleBorder(),
                child: widget.isLoading
                    ? Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.blue),
                        ),
                      )
                    : Icon(
                        Icons.send,
                        color: _isEmpty ? Colors.grey : Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
