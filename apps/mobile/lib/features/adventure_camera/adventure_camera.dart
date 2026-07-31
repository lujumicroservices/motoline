/// Experimental adventure-camera integration (GoPro BLE shutter, etc.).
///
/// Kept separate from core ride GPS/lean recording — enable from Settings → Lab.
library;

export 'adventure_camera_hub.dart';
export 'adventure_camera_prefs.dart';
export 'camera_controller.dart';
export 'models/adventure_camera_status.dart';
export 'noop_camera_controller.dart';
export 'providers/adventure_camera_providers.dart';
export 'simulated_camera_controller.dart';
export 'widgets/adventure_camera_lifecycle_binder.dart';
export 'widgets/adventure_camera_settings_section.dart';
export 'widgets/adventure_camera_status_chip.dart';
