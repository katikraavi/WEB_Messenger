import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../models/profile_form_state.dart';
import 'profile_form_state_notifier.dart';

/// Family provider for form state based on original profile
/// 
/// T049: Creates a StateNotifierProvider.family that manages form state
/// for editing a specific profile. The family parameter is the original
/// UserProfile being edited, allowing for multiple edit forms in the app.
final profileFormStateProvider = StateNotifierProvider.family<
    ProfileFormStateNotifier,
    ProfileFormState,
    UserProfile>((ref, originalProfile) {
  return ProfileFormStateNotifier(originalProfile);
});

/// Convenience provider to check if form has unsaved changes
/// 
/// Usage: ref.watch(profileFormIsDirtyProvider(originalProfile))
/// Returns true if any field differs from original
final profileFormIsDirtyProvider = Provider.family<bool, UserProfile>((ref, originalProfile) {
  final formState = ref.watch(profileFormStateProvider(originalProfile));
  return formState.isDirty;
});

/// Convenience provider to check if form is loading
/// 
/// Usage: ref.watch(profileFormIsLoadingProvider(originalProfile))
/// Returns true while API call is in progress
final profileFormIsLoadingProvider = Provider.family<bool, UserProfile>((ref, originalProfile) {
  final formState = ref.watch(profileFormStateProvider(originalProfile));
  return formState.isLoading;
});

/// Convenience provider to check if form has errors
/// 
/// Usage: ref.watch(profileFormErrorProvider(originalProfile))
/// Returns error message or null if no error
final profileFormErrorProvider = Provider.family<String?, UserProfile>((ref, originalProfile) {
  final formState = ref.watch(profileFormStateProvider(originalProfile));
  return formState.error?.message;
});

/// Convenience provider to check if Save button should be enabled
/// 
/// Save button enabled when:
/// - Form has unsaved changes (isDirty=true)
/// - Form is not currently loading
/// - No validation errors
final profileFormCanSaveProvider = Provider.family<bool, UserProfile>((ref, originalProfile) {
  final formState = ref.watch(profileFormStateProvider(originalProfile));
  return formState.isDirty && !formState.isLoading && formState.error == null;
});
