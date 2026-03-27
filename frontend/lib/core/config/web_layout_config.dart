import 'package:flutter/material.dart';

/// Layout constants for responsive web design and split-pane features.
///
/// All width values are in logical pixels (dp).
/// Follows Material Design 3 responsive guidelines.
class WebLayoutConfig {
  WebLayoutConfig._();

  // ========== BREAKPOINTS ==========
  /// Mobile/tablet breakpoint (small screens)
  static const double kSmallBreakpoint = 600.0;

  /// Tablet breakpoint (medium screens)
  static const double kMediumBreakpoint = 840.0;

  /// Desktop breakpoint for dual-pane layout
  static const double kDualPaneBreakpoint = 1200.0;

  /// Large desktop breakpoint
  static const double kLargeBreakpoint = 1600.0;

  // ========== CONTENT WIDTHS ==========
  /// Maximum width for single-column page content (Material Design standard)
  static const double kPageMaxWidth = 1088.0;

  /// Maximum width for two-column layouts (sidebar + content)
  static const double kDualColumnMaxWidth = 1600.0;

  /// Maximum width for chat/messaging dual-pane layout
  static const double kChatPaneMaxWidth = 1600.0;

  // ========== SIDEBAR & PANE WIDTHS ==========
  /// Standard web sidebar width
  static const double kWebSidebarWidth = 320.0;

  /// Minimum width of each chat pane inside the dual-pane layout
  static const double kMinSidebarWidth = 400.0;

  /// Preferred content pane width for optimal readability
  static const double kPreferredContentWidth = 800.0;

  // ========== FLEX RATIOS ==========
  /// `Expanded` flex value for the left pane (equal weighting)
  static const int kLeftPaneFlex = 1;

  /// `Expanded` flex value for the right pane (equal weighting)
  static const int kRightPaneFlex = 1;

  // ========== HELPERS ==========
  
  /// Returns true when the screen is wide enough for dual-pane mode
  static bool isDualPaneMode(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= kDualPaneBreakpoint;
  }

  /// Returns true when on a large desktop screen (1600+)
  static bool isLargeScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= kLargeBreakpoint;
  }

  /// Returns true when on a tablet or desktop
  static bool isTabletOrLarger(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= kMediumBreakpoint;
  }

  /// Get horizontal padding based on screen width
  static double getHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < kSmallBreakpoint) return 12.0;
    if (width < kMediumBreakpoint) return 16.0;
    return 24.0;
  }

  /// Get max width for page content based on screen size
  static double getPageMaxWidth(BuildContext context) {
    if (isLargeScreen(context)) {
      return kDualColumnMaxWidth;
    }
    if (isDualPaneMode(context)) {
      return kPageMaxWidth;
    }
    return double.infinity; // Full width on mobile
  }
}
