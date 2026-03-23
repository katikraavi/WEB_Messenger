import 'package:flutter/material.dart';

/// Layout constants for the web split-pane (dual-chat) feature.
///
/// All width values are in logical pixels (dp).
class WebLayoutConfig {
  WebLayoutConfig._();

  /// Minimum total screen width at which dual-pane mode activates.
  static const double kDualPaneBreakpoint = 900.0;

  /// Minimum width of each chat pane inside the dual-pane layout.
  static const double kMinSidebarWidth = 400.0;

  /// `Expanded` flex value for the left pane (equal weighting).
  static const int kLeftPaneFlex = 1;

  /// `Expanded` flex value for the right pane (equal weighting).
  static const int kRightPaneFlex = 1;

  /// Returns true when the screen is wide enough for dual-pane mode.
  static bool isDualPaneMode(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= kDualPaneBreakpoint;
  }
}
