// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'RiderLab';

  @override
  String get tagline => 'Own every corner.';

  @override
  String get autoPauseToggle => 'Auto pause';

  @override
  String get autoPauseToggleHint =>
      'Pause and resume recording when you stop or roll again';

  @override
  String get startRide => 'Start ride';

  @override
  String get endRide => 'End ride';

  @override
  String get recording => 'Recording';

  @override
  String get starting => 'Starting…';

  @override
  String get live => 'LIVE';

  @override
  String get checkUpdates => 'Check for updates';

  @override
  String get language => 'Language';

  @override
  String get spanish => 'Español';

  @override
  String get english => 'English';

  @override
  String get garage => 'Garage';

  @override
  String get yourRides => 'Your rides';

  @override
  String get nameRidesFromMap => 'Name from map';

  @override
  String get nameRidesFromMapHelp =>
      'Calculate origin and destination from GPS (e.g. Tesistán - Zapopan).';

  @override
  String namingRidesProgress(int done, int total) {
    return 'Naming $done of $total…';
  }

  @override
  String namedRidesDone(int count) {
    return 'Named $count rides.';
  }

  @override
  String get rideUntitledHint => 'Origin - destination pending';

  @override
  String get rideNameTitle => 'Ride name';

  @override
  String get rideNameHint => 'Tesistán - Zapopan';

  @override
  String get rideNameHelp => 'Type a name, or use the map (GPS start and end).';

  @override
  String get nameFromMap => 'From map';

  @override
  String get lookingUpPlaces => 'Looking up places…';

  @override
  String get couldNotResolvePlaces => 'Could not resolve place names';

  @override
  String get rideTitleCleared => 'Title cleared';

  @override
  String rideNamed(String title) {
    return 'Named: $title';
  }

  @override
  String get renameRide => 'Rename';

  @override
  String get cancel => 'Cancel';

  @override
  String get emptyRidesTitle => 'No rides yet';

  @override
  String get emptyRidesBody =>
      'Start a ride and RiderLab will draw the exact line you took on the street.';

  @override
  String get unfinishedRide => 'Unfinished ride found';

  @override
  String unfinishedRideBody(String when) {
    return 'Started $when. Finalize it to keep the line, or discard.';
  }

  @override
  String get discard => 'Discard';

  @override
  String get keepLine => 'Keep line';

  @override
  String get updateAvailable => 'Update available';

  @override
  String updateReady(String version, String current) {
    return 'RiderLab $version is ready (you have $current).';
  }

  @override
  String get whatsNew => 'What\'s new';

  @override
  String get newVersionBadge => 'NEW';

  @override
  String get update => 'Update';

  @override
  String get later => 'Later';

  @override
  String get onLatest => 'You’re on the latest RiderLab.';

  @override
  String get downloadingUpdate => 'Downloading update';

  @override
  String get updateFailed => 'Update failed';

  @override
  String get connecting => 'Connecting…';

  @override
  String get close => 'Close';

  @override
  String get checkingUpdates => 'Checking for updates…';

  @override
  String updatePrompt(String current) {
    return 'A newer build is available (you have $current). Download and install now?';
  }

  @override
  String get notNow => 'Not now';

  @override
  String updateCheckFailed(String error) {
    return 'Update check failed: $error';
  }

  @override
  String get rideLab => 'Ride lab';

  @override
  String get rideLabSegment => 'Ride lab · segment';

  @override
  String get rideNotFound => 'Ride not found';

  @override
  String get collapseHint =>
      'Tap section headers to collapse. Playhead stays pinned at the bottom.';

  @override
  String get segmentZoomHint =>
      'Segment zoom — metrics and charts are for this stretch only.';

  @override
  String get sectionSegment => 'Segment zoom';

  @override
  String get sectionSegmentSub => 'Pick a stretch of road';

  @override
  String get sectionOverview => 'Overview';

  @override
  String get sectionOverviewSub => 'Score + ride metrics';

  @override
  String get sectionOverviewSubZoom => 'Score + metrics for this segment';

  @override
  String get sectionLean => 'Lean';

  @override
  String get sectionLeanSub => 'Cyan left · amber right';

  @override
  String get sectionMap => 'Map + line';

  @override
  String get sectionMapSub => 'Speed colors · brake dots';

  @override
  String get sectionRoad => 'Turns';

  @override
  String get sectionRoadSub => 'From heading change + lean';

  @override
  String get sectionLoop => 'Loop';

  @override
  String get sectionLoopSub => 'Detect or mark A/B on this ride';

  @override
  String get sectionBrakes => 'Braking';

  @override
  String get sectionBrakesSub => 'Inferred from speed drop';

  @override
  String get sectionCharts => 'Charts';

  @override
  String get sectionChartsSub => 'Speed · lean · GPS';

  @override
  String get sectionNotes => 'Precision + notes';

  @override
  String get sectionNotesSub => 'GPS quality and coach notes';

  @override
  String get segment => 'SEGMENT';

  @override
  String get segmentZoom => 'SEGMENT ZOOM';

  @override
  String get segmentHint =>
      'Drag handles to pick a stretch, then zoom in for piece metrics.';

  @override
  String get segmentHintZoomed =>
      'Map + metrics show this stretch only. Drag handles to refine.';

  @override
  String get zoomToSegment => 'Zoom to segment';

  @override
  String get fullRide => 'Full ride';

  @override
  String get playhead => 'PLAYHEAD';

  @override
  String get distance => 'Distance';

  @override
  String get time => 'Time';

  @override
  String get speed => 'Speed';

  @override
  String get bikeLean => 'Bike lean';

  @override
  String get calibrating => 'Calibrating…';

  @override
  String get points => 'Points';

  @override
  String get maxLR => 'Max L / R';

  @override
  String get maxSpeed => 'Max speed';

  @override
  String get duration => 'Duration';

  @override
  String get speedProfile => 'Speed profile';

  @override
  String get leanProfile => 'Lean left / right';

  @override
  String get gpsPrecision => 'GPS precision';

  @override
  String get gpsPrecisionSub =>
      'Horizontal accuracy in meters (lower is better)';

  @override
  String get chartSpeedSub => 'High-contrast speed colors. Tap to scrub.';

  @override
  String get chartSpeedSubZoom => 'Segment speed only. Tap to scrub.';

  @override
  String get leanHelp =>
      '0° is inferred upright. For accurate lean, mount the phone firmly in portrait (screen toward you) on the tank or bars — avoid a loose pocket or landscape.';

  @override
  String get leanPhoneDisclaimer =>
      'Phone position matters: portrait, screen facing you, fixed mount. A loose pocket skews incline readings.';

  @override
  String get mapHint =>
      'Tap the line to move the bike. Blue→magenta by speed. Dots = brakes.';

  @override
  String get mapHintZoom =>
      'Tap the line to move the bike. Bright = selected · dim = rest.';

  @override
  String get startingRide => 'Starting ride';

  @override
  String get gpsReady => 'GPS ready';

  @override
  String gpsWarmHelp(String meters) {
    return 'Stay outdoors with a clear sky view. Recording starts when GPS is warm enough (target ±$meters m).';
  }

  @override
  String get horizontalAccuracy => 'HORIZONTAL ACCURACY';

  @override
  String lowerBetter(String meters) {
    return 'Lower is better · ready at ±$meters m';
  }

  @override
  String get couldNotStart => 'Couldn’t start ride';

  @override
  String get tryAgain => 'Try again';

  @override
  String get back => 'Back';

  @override
  String get activeMountHelp =>
      'Mount firmly (portrait, screen toward you). Leave the recording notification on — screen can lock.';

  @override
  String curvaTitle(int number) {
    return 'Turn #$number';
  }

  @override
  String get curveLine => 'Corner line';

  @override
  String get entry => 'Entry';

  @override
  String get apex => 'Apex';

  @override
  String get exit => 'Exit';

  @override
  String get brakeToApex => 'Brake to apex';

  @override
  String get accelFromApex => 'Accel from apex';

  @override
  String get leanAtApex => 'Lean at apex';

  @override
  String get maxLean => 'Max lean';

  @override
  String get leftShort => 'L';

  @override
  String get rightShort => 'R';

  @override
  String get curvaMapLegend =>
      'E = entry · A = apex · X = exit. Line colored by speed.';

  @override
  String get curvaCoach =>
      'Quick read: check if you entered too hot (big brake to A), if the apex is stable, and if you exit accelerating cleanly.';

  @override
  String roadStretchesHelp(int curvas) {
    return 'From heading change + lean. $curvas turns. Tap a turn for entry / apex / exit — swipe between turns.';
  }

  @override
  String get roadStretchesEmpty =>
      'Not enough GPS heading change yet to detect turns.';

  @override
  String get openDetail => 'open detail';

  @override
  String get brakesHelp =>
      'Inferred from how fast speed falls — not a brake sensor. Tap a hit to jump the playhead. Map button zooms to that brake.';

  @override
  String get brakesEmpty =>
      'No clear brake pulses from GPS speed. Harder stops outdoors usually show as yellow/orange/red hits.';

  @override
  String get brakeLight => 'Light';

  @override
  String get brakeMedium => 'Medium';

  @override
  String get brakeHard => 'Hard';

  @override
  String brakeAtTime(String time) {
    return 'At $time';
  }

  @override
  String get brakeZoomMap => 'Zoom map to brake';

  @override
  String get noGpsPoints => 'No GPS points';

  @override
  String get kmh => 'km/h';

  @override
  String get recta => 'Straight';

  @override
  String get curva => 'Turn';

  @override
  String get curvaIzquierda => 'Left turn';

  @override
  String get curvaDerecha => 'Right turn';

  @override
  String get fullscreenMap => 'Full map';

  @override
  String get fullscreenMapHelp =>
      'Pan and zoom freely. Mark an area or use the visible map, then load metrics for that stretch.';

  @override
  String get selectArea => 'Select area';

  @override
  String get selectAreaHint => 'Drag a box over the stretch you want';

  @override
  String get selectAreaBody =>
      'Drag on the map to mark an area. Pinch still zooms.';

  @override
  String get useVisibleArea => 'Use visible map';

  @override
  String get clearArea => 'Clear';

  @override
  String get loadAreaMetrics => 'Load metrics for area';

  @override
  String areaReady(int points) {
    return 'Area ready · $points GPS points. Load metrics to focus Ride Lab on this stretch.';
  }

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get fitRide => 'Fit ride';

  @override
  String get myLocation => 'My location';

  @override
  String get openFullscreenMap => 'Open full map';

  @override
  String get mapLayerSpeed => 'Speed';

  @override
  String get mapLayerRoadKind => 'Turns';

  @override
  String get mapLayerBrakes => 'Brakes';

  @override
  String get mapLayerStartEnd => 'Start/end';

  @override
  String get mapLayerPlayhead => 'Playhead';

  @override
  String get mapLayerLegend => 'Legend';

  @override
  String get friends => 'Friends';

  @override
  String get friendsSubtitle =>
      'Closed beta — every rider with the app is on your list.';

  @override
  String get friendsEmpty =>
      'No other riders yet. When a friend installs RiderLab, they appear here.';

  @override
  String get yourName => 'Your display name';

  @override
  String get saveName => 'Save name';

  @override
  String get nameHint => 'Nickname for friends';

  @override
  String get nameSaved => 'Name saved';

  @override
  String get compare => 'Compare';

  @override
  String get compareTitle => 'Compare rides';

  @override
  String get comparePickPeer => 'Friend rides in the same area';

  @override
  String get compareEmpty => 'No friend rides cover this area yet.';

  @override
  String get compareYou => 'You';

  @override
  String get compareLocalTitle => 'Compare laps';

  @override
  String compareRouteTitle(String name) {
    return 'Compare · $name';
  }

  @override
  String get compareLocalHelp =>
      'Pick a baseline lap and a challenger to compare metrics and lines on this circuit.';

  @override
  String get compareLocalEmpty =>
      'You need at least 2 completed laps on this route. Use Loop mode or tag rides with the same route.';

  @override
  String get compareBaseline => 'Baseline';

  @override
  String get compareChallenger => 'Challenger';

  @override
  String compareLocal(int count) {
    return 'Compare laps ($count)';
  }

  @override
  String compareDeltaFaster(String delta) {
    return 'Challenger faster by $delta';
  }

  @override
  String compareDeltaSlower(String delta) {
    return 'Challenger slower by $delta';
  }

  @override
  String get compareDeltaTie => 'Same time';

  @override
  String get compareLaps => 'Compare laps';

  @override
  String get compareNeedTwoLaps =>
      'Tag at least 2 laps on this route to compare.';

  @override
  String get lineScore => 'Line score';

  @override
  String get avgSpeed => 'Avg speed';

  @override
  String get friendRides => 'Shared rides';

  @override
  String get friendRidesEmpty => 'This rider has no shared rides yet.';

  @override
  String get syncingRide => 'Sharing ride with friends…';

  @override
  String get cloudUnavailable =>
      'Cloud not available — check connection and Anonymous auth.';

  @override
  String get cloudAnonymousOff =>
      'Friends need Anonymous sign-in enabled in the RiderLab cloud (Supabase project CornerIQ):\nDashboard → Authentication → Providers → Anonymous → Enable.\nThen reopen Amigos and pull to refresh.';

  @override
  String get routesTitle => 'Routes';

  @override
  String get routesHelp =>
      'Name a circuit, share it, and tag rides so friends can compare on the same route.';

  @override
  String get routesHowTitle => 'How do Routes work?';

  @override
  String get routesHowBody =>
      '1) Create a route with + (e.g. “North roundabout”).\n2) Open the route → Loop tab: detect closed loops from tagged rides, or mark A/B yourself.\n3) Start a loop ride from a saved loop — each lap is tagged to this route.\n4) Or in Ride Lab → Share, tag any ride with this route.\n5) Turn sharing on if friends should compare on this circuit.';

  @override
  String get routesTapHint => 'Tap for laps + Loop module';

  @override
  String get routesLoopReady => 'Loop ready';

  @override
  String get setYourAlias => 'Set your alias';

  @override
  String get sectionNotesProOnly => 'Pro only — GPS precision and notes';

  @override
  String get proCurvaBannerTitle => 'Corner detail · Pro';

  @override
  String get proCurvaBannerBody =>
      '0.5 s preview. Pro unlocks entry, apex, exit, and map with no lock.';

  @override
  String get proNotesBannerTitle => 'Precision + notes · Pro';

  @override
  String get proNotesBannerBody =>
      'GPS quality and coach tips stay in CornerIQ Pro.';

  @override
  String get proFeatureCurva => 'Full corner detail (no banner)';

  @override
  String get proFeatureNotes => 'GPS precision + coach notes';

  @override
  String get myRoutes => 'Your routes';

  @override
  String get routesEmpty =>
      'No routes yet — create one to tag and share rides.';

  @override
  String get friendRoutes => 'Friends’ shared routes';

  @override
  String get friendRoutesEmpty => 'No shared routes from friends yet.';

  @override
  String get createRoute => 'New route';

  @override
  String get routeNameHint => 'Route name (e.g. Glorieta norte)';

  @override
  String get routeDescHint => 'Optional notes';

  @override
  String get shareRoute => 'Share route';

  @override
  String get shareRouteHelp =>
      'Friends can see this circuit and compare tagged rides.';

  @override
  String get routeCreated => 'Route created';

  @override
  String get sharedRoute => 'Shared';

  @override
  String get privateRoute => 'Private';

  @override
  String get shareRideTitle => 'Share';

  @override
  String get shareRideHelp =>
      'Share this ride with friends and optionally tag a named circuit.';

  @override
  String get shareThisRide => 'Share this ride';

  @override
  String get assignRoute => 'Assign to route';

  @override
  String get noRouteAssigned => 'No route';

  @override
  String get areaNoPoints =>
      'No GPS stretch found in that area — zoom in or draw a larger box.';

  @override
  String get curvaSwipeHint => 'Swipe left / right to move between turns.';

  @override
  String get curvaOpenMap => 'Full map';

  @override
  String get curvaZoomLab => 'Zoom Ride Lab';

  @override
  String get armAutoRide => 'Arm auto-ride';

  @override
  String get disarmAutoRide => 'Disarm auto-ride';

  @override
  String get waitingForMotion => 'Waiting for motion…';

  @override
  String get armedBannerBody =>
      'RiderLab will start recording on its own once it detects you\'ve started riding.';

  @override
  String get loopMode => 'Loop mode';

  @override
  String get pausedLabel => 'PAUSED';

  @override
  String get suggestEndTitle => 'Still riding?';

  @override
  String get suggestEndBody =>
      'No movement for a while. End the ride or keep riding.';

  @override
  String get keepRiding => 'Keep riding';

  @override
  String get markLoopInit => 'Mark loop init';

  @override
  String get loopInitSet => 'Init marked';

  @override
  String get markLoopEnd => 'Mark loop end';

  @override
  String get markLoopInitHere => 'Mark A at my GPS';

  @override
  String get markLoopEndHere => 'Mark B at my GPS';

  @override
  String get loopOpenMarkMap => 'Map: mark A and B';

  @override
  String get loopMarkMapHint =>
      'Open the fullscreen map, pan freely, then tap point A (start) and B (end) of the route.';

  @override
  String get loopTapPointA => 'Tap the map to mark point A (start)';

  @override
  String get loopTapPointB => 'Tap the map to mark point B (end)';

  @override
  String get loopPointsReady => 'A and B ready — confirm to arm auto-lap';

  @override
  String get loopMarkMapHelp =>
      'Free pan and zoom. First tap = A, second = B. The circle is the lap detection zone.';

  @override
  String get loopRemapA => 'Redo A';

  @override
  String get loopConfirmAb => 'Confirm A and B';

  @override
  String get loopArmed => 'Auto-lap armed';

  @override
  String lapCountLabel(int count) {
    return 'Lap $count';
  }

  @override
  String get endSession => 'End session';

  @override
  String get byRawThrottle => 'by RawThrottle';

  @override
  String get pro => 'PRO';

  @override
  String get free => 'Free';

  @override
  String get settings => 'Settings';

  @override
  String get proUnlock => 'RiderLab Pro';

  @override
  String get proUnlockBody =>
      'Segment any stretch, full corner detail, precision notes, full brakes, and no ads.';

  @override
  String get proFeatureSegment =>
      'Segment zoom — select any sub-portion of the ride';

  @override
  String get proFeatureBrakes => 'Full braking details (not just a preview)';

  @override
  String get proFeatureNoAds => 'No advertising banners';

  @override
  String get upgradeToPro => 'Upgrade to Pro';

  @override
  String get proUnlocked => 'Pro is active';

  @override
  String get proToggleDev => 'Pro unlocked';

  @override
  String get proToggleHelp =>
      'Temporary unlock until store billing is wired. Turn off to preview Free.';

  @override
  String brakesProTeaser(int shown, int total) {
    return 'Showing $shown of $total. Unlock Pro for the full braking list.';
  }

  @override
  String get segmentProLocked =>
      'Selecting a sub-portion of the ride is a Pro feature.';

  @override
  String get adPlaceholder => 'Ad';

  @override
  String get removeAdsWithPro => 'Upgrade to Pro to remove ads';

  @override
  String get routeTabLaps => 'Laps';

  @override
  String get routeTabLoop => 'Loop';

  @override
  String get routeLoopModuleHelp =>
      'Loops belong to this route. Detect closed loops from tagged rides, or mark start (A) and end (B) yourself on the map.';

  @override
  String get routeLoopDefine => 'Mark A / B';

  @override
  String get routeLoopDetect => 'Detect';

  @override
  String get routeLoopSavedTitle => 'Saved loops';

  @override
  String get routeLoopEmpty =>
      'No loops yet — detect from rides or mark A and B on the map.';

  @override
  String get routeLoopDetectedTitle => 'Detected candidates';

  @override
  String get routeLoopDetectedEmpty =>
      'No closed loops found on tagged rides yet. Ride the circuit and try again.';

  @override
  String get routeLoopDetectedHint =>
      'Closed path inferred from GPS — save to use for auto-lap.';

  @override
  String get routeLoopSave => 'Save';

  @override
  String get routeLoopSaved => 'Loop saved on this route';

  @override
  String get routeLoopManualName => 'Manual loop';

  @override
  String get routeLoopPrimary => 'PRIMARY';

  @override
  String get routeLoopSetPrimary => 'Set as primary';

  @override
  String get routeLoopStartRide => 'Start loop ride';

  @override
  String get routeLoopSourceManual => 'Manual';

  @override
  String get routeLoopSourceDetected => 'Detected';

  @override
  String get deleteRoute => 'Delete route';

  @override
  String get deleteRouteBody =>
      'This removes the route, its loops, and untags rides. If shared, it disappears for everyone.';

  @override
  String get routeDeleted => 'Route deleted';

  @override
  String get deleteLoop => 'Delete loop';

  @override
  String get deleteLoopBody =>
      'Removes this loop. If it was primary, A/B markers on the route are cleared too (friends see that on sync).';

  @override
  String get loopDeleted => 'Loop deleted';

  @override
  String get deleteAllLoops => 'Remove all loops';

  @override
  String get deleteAllLoopsBody =>
      'Deletes every loop on this route and clears A/B markers. Friends get a loop-free route on sync.';

  @override
  String get loopsCleared => 'Loops cleared';

  @override
  String get deleteConfirm => 'Delete';

  @override
  String get deleteRide => 'Delete ride';

  @override
  String get deleteRideBody =>
      'This permanently removes the ride and its GPS line from this phone (and the cloud if synced).';

  @override
  String get rideDeleted => 'Ride deleted';

  @override
  String get accountSection => 'Account';

  @override
  String get accountGuest => 'Guest rider';

  @override
  String get accountGuestBody =>
      'You\'re on a guest session. Sign in to keep your profile across devices — your current rides stay linked when possible.';

  @override
  String get accountSignedIn => 'Signed in';

  @override
  String get accountSignedInBody =>
      'Your Google account is linked. Sign out returns you to a guest session on this phone.';

  @override
  String signInWith(String provider) {
    return 'Sign in with $provider';
  }

  @override
  String get signOut => 'Sign out';

  @override
  String get accountSignedInSnack => 'Signed in — profile synced';

  @override
  String get accountSignedOutSnack => 'Signed out — back to guest mode';

  @override
  String get rideLoopHelp =>
      'Find closed loops on this ride’s GPS, or mark start (A) and end (B) on the map. Saving creates/uses a route so you can run auto-lap later.';

  @override
  String get rideLoopEmpty => 'No loops saved for this ride’s route yet.';

  @override
  String get rideLoopDetectedEmpty =>
      'No closed loop found on this ride. Try Mark A / B on the map.';

  @override
  String get rideLoopNeedPoints => 'Not enough GPS points to mark a loop.';

  @override
  String get rideLoopSaveFirst => 'Save a loop first — that creates the route.';

  @override
  String get rideLoopOpenRoute => 'Open route (laps + loops)';

  @override
  String get syncCloudRides => 'Upload rides to cloud';

  @override
  String get syncCloudRidesHelp =>
      'Persists metrics (speed, lean, line score, GPS) for every completed ride on your account.';

  @override
  String syncCloudRidesDone(int ok, int fail) {
    return 'Cloud: $ok ok, $fail failed';
  }

  @override
  String get playStoreUpdatesOnly =>
      'Updates install from Google Play for this build.';

  @override
  String get labSection => 'Lab (experimental)';

  @override
  String get labAdventureCameraHelp =>
      'Optional GoPro shutter synced to rides. Off by default — does not change GPS recording.';

  @override
  String get labAdventureCameraEnable => 'Adventure camera';

  @override
  String get labAdventureCameraEnableHelp =>
      'Enable the camera lab module on this phone';

  @override
  String get labAdventureCameraSyncRide => 'Record with ride';

  @override
  String get labAdventureCameraSyncRideHelp =>
      'Start/stop with the whole ride. If map start zones are set, they override start — camera waits for the start point.';

  @override
  String get labAdventureCameraSyncPause => 'Follow auto-pause';

  @override
  String get labAdventureCameraSyncPauseHelp =>
      'Stop the camera while GPS auto-pause is active (optional)';

  @override
  String get labAdventureCameraBackend => 'Backend';

  @override
  String get labAdventureCameraBackendGoPro => 'GoPro';

  @override
  String get labAdventureCameraBackendSim => 'Simulate';

  @override
  String get labAdventureCameraConnect => 'Connect';

  @override
  String get labAdventureCameraDisconnect => 'Disconnect';

  @override
  String get labAdventureCameraTestHelp =>
      'Manual shutter test — no ride required. Connect first (or use Simulate).';

  @override
  String get labAdventureCameraTestStart => 'Test start';

  @override
  String get labAdventureCameraTestStop => 'Test stop';

  @override
  String get labAdventureCameraTestStartSnack => 'Camera start triggered';

  @override
  String get labAdventureCameraTestStopSnack => 'Camera stop triggered';

  @override
  String get labAdventureCameraPhaseOff => 'Lab off';

  @override
  String get labAdventureCameraPhaseIdle => 'Idle';

  @override
  String get labAdventureCameraPhaseScanning => 'Scanning…';

  @override
  String get labAdventureCameraPhaseConnecting => 'Connecting…';

  @override
  String get labAdventureCameraPhaseReady => 'Ready';

  @override
  String get labAdventureCameraPhaseRecording => 'Recording';

  @override
  String get labAdventureCameraPhaseError => 'Error';

  @override
  String get labAdventureCameraZonesEnable => 'Map start/stop zones';

  @override
  String get labAdventureCameraZonesEnableHelp =>
      'Start/stop when you enter map geofences. Start points gate recording (camera stays off until you reach one).';

  @override
  String get labAdventureCameraZonesEdit => 'Edit camera zones';

  @override
  String get labAdventureCameraZonesEmpty =>
      'No zones yet — tap the map to add start/stop points';

  @override
  String labAdventureCameraZonesCount(int count) {
    return '$count zones on the map';
  }

  @override
  String get labAdventureCameraZonesTitle => 'Camera zones';

  @override
  String get labAdventureCameraZonesHelp =>
      'Tap to place Start, then tap again for that Start’s Stop partner. Long-press a marker to remove the whole pair. A Stop only works after its linked Start was hit.';

  @override
  String get labAdventureCameraZonesPlaceStart => 'Next tap: Start ▶';

  @override
  String get labAdventureCameraZonesPlaceStop =>
      'Next tap: Stop ■ for this pair';

  @override
  String get labAdventureCameraZonesPairs => 'Pairs';

  @override
  String get rideDeckTitle => 'Ride deck';

  @override
  String get rideDeckHelp =>
      'Connect cameras here before you roll. Start the ride when you’re ready — GPS recording begins then.';

  @override
  String get startRideNow => 'Start ride now';

  @override
  String get labAdventureCameraZoneStart => 'Start';

  @override
  String get labAdventureCameraZoneStop => 'Stop';

  @override
  String get labAdventureCameraZonesClear => 'Clear all';

  @override
  String get labAdventureCameraZonesSave => 'Save zones';

  @override
  String get labAdventureCameraAggressive => 'Aggressive riding auto-record';

  @override
  String get labAdventureCameraAggressiveHelp =>
      'Starts only at ≥85 km/h with constant lean changes; pauses when lean settles or speed drops';

  @override
  String get labAdventureCameraGroup => 'Camera group';

  @override
  String get labAdventureCameraGroupHelp =>
      'Add multiple GoPros — shutter commands go to every enabled camera at once.';

  @override
  String get labAdventureCameraGroupEmpty => 'No cameras in the group yet.';

  @override
  String get labAdventureCameraGroupAdd => 'Add GoPro';

  @override
  String get labAdventureCameraGroupRemove => 'Remove';

  @override
  String get labAdventureCameraGroupScanning => 'Scanning for GoPros…';

  @override
  String get labAdventureCameraGroupNoneFound =>
      'No new GoPros found — power on and open the side door.';

  @override
  String get labAdventureCameraGroupPick => 'Add to group';

  @override
  String get labAdventureCameraGroupSetupHelp => 'Multi-camera setup help';

  @override
  String get labAdventureCameraGroupSetupBody =>
      '1. Power on each GoPro and open the side door (Bluetooth on).\n2. On the phone, allow Bluetooth (and nearby devices) if asked.\n3. Tap Add GoPro — wait for the scan, then pick each camera.\n4. Leave cameras enabled in the list (toggle off to skip one).\n5. Tap Connect so RiderLab links the whole group.\n6. Start a ride (or use map zones / aggressive auto-record) — shutter starts/stops on every enabled camera.\n7. On the ride screen, CAM 2/2 means both cameras are recording.\n\nTips: keep phones close to the cameras for the first link. If a camera only wakes but does not record, Connect again, then start the ride. One failed camera does not stop the others.';

  @override
  String get labAdventureCameraScenariosTitle => 'Test setups';

  @override
  String get labAdventureCameraScenarioZonesTitle =>
      'Only between map start/stop points';

  @override
  String get labAdventureCameraScenarioZonesBody =>
      'ON: Adventure camera · Map start/stop zones (place Start + Stop on the map) · cameras in the group.\nOFF: Record with ride · Aggressive riding auto-record · Follow auto-pause.\n\nNote: these are Lab camera zones — not the route A/B lap points.';

  @override
  String get labAdventureCameraScenarioZonesApply => 'Apply zone-only setup';

  @override
  String get labAdventureCameraScenarioAggressiveTitle =>
      'Only when fun / aggressive riding starts';

  @override
  String get labAdventureCameraScenarioAggressiveBody =>
      'ON: Adventure camera · Aggressive riding auto-record · cameras in the group.\nOFF: Record with ride · Map start/stop zones · Follow auto-pause.';

  @override
  String get labAdventureCameraScenarioAggressiveApply =>
      'Apply aggressive-only setup';

  @override
  String get armAutoNoRouteHint =>
      'Armed — when you roll, a ride starts in Garage.';

  @override
  String get armAutoRouteArmed => 'Armed — rolling starts the ride';

  @override
  String armAutoRouteArmedNamed(String name) {
    return 'Armed for “$name” — the ride will be saved on that route';
  }

  @override
  String couldNotLoadRides(String error) {
    return 'Could not load rides: $error';
  }

  @override
  String get rodadasTitle => 'Rodadas';

  @override
  String get rodadasHomeSubtitle =>
      'Create a group ride · invite · share live GPS';

  @override
  String get friendsHelp =>
      'Search riders, send friend requests, and invite accepted friends to a rodada.';

  @override
  String get findRiders => 'Find riders';

  @override
  String get searchByNameHint => 'Search by name…';

  @override
  String get noRidersFound => 'No riders found';

  @override
  String friendRequestSent(String name) {
    return 'Friend request sent to $name';
  }

  @override
  String get addFriend => 'Add';

  @override
  String get friendRequests => 'Requests';

  @override
  String get wantsToBeFriends => 'wants to be friends';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get pendingSent => 'Pending sent';

  @override
  String get waitingAcceptance => 'Waiting for acceptance';

  @override
  String get yourFriends => 'Your friends';

  @override
  String get noFriendsYet =>
      'No friends yet — search above and send a request.';

  @override
  String get viewRides => 'View rides';

  @override
  String get inviteToRodada => 'Invite to rodada';

  @override
  String get createRodadaFirst => 'Create a rodada first';

  @override
  String get inviteTo => 'Invite to…';

  @override
  String friendInvited(String name) {
    return '$name invited';
  }

  @override
  String scoreLabel(int score) {
    return 'Score $score';
  }

  @override
  String get joinWithCodeTooltip => 'Join with code';

  @override
  String get createRodadaTooltip => 'Create rodada';

  @override
  String get signInForRodadas => 'Sign in to use Rodadas';

  @override
  String couldNotLoadRodadas(String error) {
    return 'Could not load rodadas.\n$error';
  }

  @override
  String get groupRidesTitle => 'Group rides';

  @override
  String get groupRidesBody =>
      'Create a rodada for Tapalpa, Moyahua, or anywhere. Invite riders, then share live GPS, tracks, and photos only when you opt in.';

  @override
  String get createRodada => 'Create rodada';

  @override
  String get joinWithInviteCode => 'Join with invite code';

  @override
  String get joinRodadaTitle => 'Join rodada';

  @override
  String get inviteCodeLabel => 'Invite code';

  @override
  String get inviteCodeHint => 'e.g. TAP42A';

  @override
  String get joinButton => 'Join';

  @override
  String joinFailed(String error) {
    return 'Join failed: $error';
  }

  @override
  String get timeTbd => 'Time TBD';

  @override
  String rodadaRidersCount(int count) {
    return '$count riders';
  }

  @override
  String get newRodada => 'New rodada';

  @override
  String get rodadaCreateButton => 'Create';

  @override
  String get rodadaTitleLabel => 'Title';

  @override
  String get rodadaTitleHint => 'Tapalpa Saturday';

  @override
  String get rodadaDestinationLabel => 'Destination';

  @override
  String get rodadaDestinationHint => 'Tapalpa / Moyahua / …';

  @override
  String get rodadaNotesLabel => 'Notes';

  @override
  String get rodadaNotesHint => 'Meetup at Shell, white helmet…';

  @override
  String get rodadaStartsAt => 'Starts at';

  @override
  String get rodadaPickDateTime => 'Pick date & time';

  @override
  String get meetupPin => 'Meetup pin';

  @override
  String get useMyGps => 'Use my GPS';

  @override
  String get clearPin => 'Clear';

  @override
  String get meetupMapHelp =>
      'Tap the map to set the meetup. Live GPS and photos stay off until each rider opts in.';

  @override
  String get titleRequired => 'Title is required';

  @override
  String locationFailed(String error) {
    return 'Location failed: $error';
  }

  @override
  String get rodadaFallback => 'Rodada';

  @override
  String get copyInviteCode => 'Copy invite code';

  @override
  String inviteCodeCopied(String code) {
    return 'Code $code copied';
  }

  @override
  String get markAsLive => 'Mark as LIVE';

  @override
  String get markAsOpen => 'Mark as open';

  @override
  String get endRodada => 'End rodada';

  @override
  String get inviteFriend => 'Invite friend';

  @override
  String get rodadaTabOverview => 'Overview';

  @override
  String get rodadaTabLive => 'Live';

  @override
  String get rodadaTabRides => 'Rides';

  @override
  String get rodadaTabPhotos => 'Photos';

  @override
  String get rodadaTabRadio => 'Radio';

  @override
  String get rodadaNotFound => 'Rodada not found';

  @override
  String rodadaStatusChanged(String status) {
    return 'Status → $status';
  }

  @override
  String get noFriendsToInvite => 'No friends to invite yet.';

  @override
  String get inviteSent => 'Invite sent';

  @override
  String rodadaCodeBanner(String code) {
    return 'code $code';
  }

  @override
  String get meetup => 'Meetup';

  @override
  String get yourSharing => 'Your sharing';

  @override
  String get sharingDefaultsHelp =>
      'Off by default. When on, location pings every 5 minutes for the whole rodada (retries every 1 minute if a ping fails).';

  @override
  String get notRodadaMember => 'You are not a member.';

  @override
  String get shareLocationOnRoute => 'Share location on route';

  @override
  String get shareLocationEvery5Min => 'Every 5 min while rodada is open/live';

  @override
  String get shareTrackAfterRides => 'Share my track after rides';

  @override
  String get rodadaRiders => 'Riders';

  @override
  String get noMembersYet => 'No members yet';

  @override
  String get rsvpGoing => 'going';

  @override
  String get rsvpMaybe => 'maybe';

  @override
  String get rsvpDeclined => 'declined';

  @override
  String get memberLiveOn => 'live on';

  @override
  String get memberTrackOn => 'track on';

  @override
  String get sharingLocationBanner =>
      'Sharing location every 5 min (retry 1 min if fail)';

  @override
  String get liveMapViewOnly =>
      'Live map is view-only. Enable sharing in Overview.';

  @override
  String get shareLive => 'Share live';

  @override
  String get noLiveRidersYet =>
      'No live riders yet. Opt-in riders appear here (~5s).';

  @override
  String get addStop => 'Add stop';

  @override
  String get stopFab => 'Stop';

  @override
  String get stopTitleLabel => 'Title';

  @override
  String get dropAtMyGps => 'Drop at my GPS';

  @override
  String get gasBreakDefault => 'Gas / break';

  @override
  String get stopDefault => 'Stop';

  @override
  String get sharedTracksHelp =>
      'Shared tracks from members who opted in. Dense GPS stays on each phone.';

  @override
  String get linkMyRide => 'Link my ride';

  @override
  String get noSharedRidesYet => 'No shared rides yet';

  @override
  String get noCompletedRidesToLink => 'No completed rides to link';

  @override
  String get syncRideFirst => 'Sync the ride first, then try again';

  @override
  String get rideLinkedToRodada => 'Ride linked to this rodada';

  @override
  String get noTrackPoints => 'No track points';

  @override
  String get radioAllGood => 'All good';

  @override
  String get radioStoppingFiveMin => 'Stopping 5 min';

  @override
  String get radioNeedHelp => 'Need help';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get shortRadioMessageHint => 'Short radio message…';

  @override
  String get safetyTag => 'SAFETY';

  @override
  String get riderFallback => 'Rider';

  @override
  String get photosAlbumHelp =>
      'Album loads thumbs only. Full image opens on tap and frees when closed.';

  @override
  String get photoAdd => 'Add';

  @override
  String get noPhotosYet => 'No photos yet';

  @override
  String get photoUploaded => 'Photo uploaded';

  @override
  String get photoTitle => 'Photo';

  @override
  String get skillCoach => 'Skill coach';

  @override
  String skillCurvasRated(int count) {
    return '$count curvas rated · fingerprints for peer compare';
  }

  @override
  String get improveNextRide => 'Improve next ride';

  @override
  String get openCornerLab => 'Open corner lab';

  @override
  String get skillTipNoCurvas =>
      'No solid curvas detected — ride a twisty section to build a baseline.';

  @override
  String skillTipEntryHot(String entry, String apex) {
    return 'Entry hot ($entry→$apex km/h). Brake earlier before tip-in.';
  }

  @override
  String get skillTipModerateSpeedDrop =>
      'Moderate speed drop to apex — trail brake a touch longer.';

  @override
  String get skillTipLittleSpeedScrub =>
      'Little speed scrub — confirm you are not carrying too much mid-corner.';

  @override
  String get skillTipWeakExitDrive =>
      'Weak exit drive — open throttle sooner once lean starts falling.';

  @override
  String get skillTipPeakLeanNotAtApex =>
      'Peak lean not at apex — tip in earlier so the bike is set at the apex.';

  @override
  String get skillTipLowLeanBigHeading =>
      'Big heading change with low lean — check sensor mount or commit more.';

  @override
  String get skillTipSolidCorner =>
      'Solid corner — keep this entry/apex rhythm.';

  @override
  String skillHighlightBest(String label, int score) {
    return 'Best: $label · $score/100';
  }

  @override
  String skillHighlightMedian(int score) {
    return 'Median corner score $score/100';
  }

  @override
  String skillTipDrillRepeat(String label) {
    return 'Drill: repeat a similar $label and brake 10–15 m earlier.';
  }

  @override
  String get performanceLabel => 'PERFORMANCE';

  @override
  String get statRides => 'Rides';

  @override
  String get statDistance => 'Distance';

  @override
  String get statTopSpeed => 'Top speed';

  @override
  String get statPeakLean => 'Peak lean';

  @override
  String get rideDiscarded => 'Discarded';

  @override
  String get gpsQualitySparseTip =>
      'Sparse GPS — keep the recording notification on and avoid battery limits.';

  @override
  String gpsQualityFairTip(String meters) {
    return 'GPS ~$meters m — line is usable but a bit soft.';
  }

  @override
  String gpsQualityWeakTip(String meters) {
    return 'Weak GPS (~$meters m) — remount the phone and try again outdoors.';
  }

  @override
  String get skillLabTitle => 'Skill lab';

  @override
  String get skillLabTapHint => 'Tap to see mistakes and how to improve';

  @override
  String get skillLabTapHintEmpty => 'Tap for tips after a twisty ride';

  @override
  String get skillLabFocusTitle => 'Where to improve';

  @override
  String get skillLabFocusHelp =>
      'Lowest-scoring turns first. Bars show entry → apex → exit speed. Tap Replay to watch lean, brake, and speed — and compare the same corner section with a friend.';

  @override
  String get bikeSection => 'My bike';

  @override
  String get bikeSelect => 'Select your bike';

  @override
  String get bikeSelectHelp =>
      'Triumph catalog — used for Lean Lab and ride context';

  @override
  String get bikePickerTitle => 'Garage';

  @override
  String get bikePickerHelp =>
      'Pick the Triumph you ride. This tags Lean Lab and training labels.';

  @override
  String get bikeClear => 'Clear';

  @override
  String get bikeFamilyNaked => 'Naked';

  @override
  String get bikeFamilyAdventure => 'Adventure';

  @override
  String get bikeFamilyClassic => 'Classic';

  @override
  String get bikeFamilySport => 'Sport';

  @override
  String get bikeFamilyCruiser => 'Cruiser';

  @override
  String get bikeFamilyOther => 'Other';

  @override
  String get leanLabHomeCta => 'Lean Lab — Bugambilias';

  @override
  String get leanLabTitle => 'Lean Lab';

  @override
  String get leanLabIntro =>
      'Pilot protocol for Bugambilias — both directions, with elevation. Calibrate upright, ride, then label corners so we can polish lean.';

  @override
  String get leanLabCircuitName => 'Bugambilias circuit';

  @override
  String get leanLabCircuitHelp =>
      'Plaza Panorámica Bugambilias · both directions · open in Maps';

  @override
  String leanLabProgress(int labeled, int total) {
    return '$labeled of $total sessions labeled';
  }

  @override
  String get leanLabProtocols => 'Protocols';

  @override
  String get leanLabProtoOutbound => 'Baseline outbound';

  @override
  String get leanLabProtoOutboundHelp =>
      'Toward the plaza, center mount. Capture climb/descend lean.';

  @override
  String get leanLabProtoReturn => 'Baseline return';

  @override
  String get leanLabProtoReturnHelp =>
      'Opposite direction, center mount. Same corners, mirrored sides.';

  @override
  String get leanLabProtoPocket => 'Mount A/B — pocket';

  @override
  String get leanLabProtoPocketHelp =>
      'Same circuit with phone in pocket to learn mount bias.';

  @override
  String get leanLabProtoFree => 'Free Lean Lab lap';

  @override
  String get leanLabProtoFreeHelp =>
      'Any direction on this circuit with calib + corner labels.';

  @override
  String get leanLabStartProtocol => 'Prepare & ride';

  @override
  String get leanLabNeedsLabels => 'Needs corner labels';

  @override
  String leanLabElevationSummary(String climb, String descent) {
    return '↑$climb m · ↓$descent m';
  }

  @override
  String get leanLabPrepTitle => 'Lean Lab prep';

  @override
  String get leanLabPrepHelp =>
      'Set mount and pose, hold the bike upright to freeze neutral, then start the lap.';

  @override
  String get leanLabPoseQ => 'How is the phone oriented?';

  @override
  String get leanLabPoseScreenOut => 'Portrait · screen out';

  @override
  String get leanLabPoseScreenIn => 'Portrait · screen in';

  @override
  String get leanLabPoseLandscape => 'Landscape';

  @override
  String get leanLabDirectionQ => 'Direction on Bugambilias?';

  @override
  String get leanLabDirectionOutbound => 'Outbound (to plaza)';

  @override
  String get leanLabDirectionReturn => 'Return';

  @override
  String get leanLabCalibTitle => 'Upright calibration';

  @override
  String get leanLabCalibHelp =>
      'Stand still, bike upright, phone fixed. Hold 4 seconds — this freezes 0° lean for the whole ride.';

  @override
  String get leanLabCalibHold => 'Hold upright 4s';

  @override
  String get leanLabCalibHolding => 'Hold still…';

  @override
  String get leanLabRawNeutral => 'Raw phone angle';

  @override
  String get leanLabFrozenNeutral => 'Frozen neutral';

  @override
  String get leanLabStartRide => 'Start Lean Lab ride';

  @override
  String get leanLabReviewTitle => 'Label lean corners';

  @override
  String get leanLabReviewHelp =>
      'For each corner: was the app lean high, OK, or low? Grade (elevation) is shown so we can fix climb/descent bias.';

  @override
  String get leanLabReviewHelpMax =>
      'Max lean for the curve stays fixed at the top. Play the corner to watch lean and the map move; jump to the peak when you want.';

  @override
  String get leanLabMaxLean => 'Max lean';

  @override
  String get leanLabJumpToMax => 'Jump to max lean';

  @override
  String get leanLabLiveLean => 'Live lean';

  @override
  String get leanLabAtPeak => 'at peak';

  @override
  String get leanLabMaxLeanGps => 'GPS where max lean happened';

  @override
  String leanLabMaxLeanGpsA(String lat, String lng) {
    return 'A · $lat, $lng';
  }

  @override
  String leanLabMaxLeanGpsB(String lat, String lng) {
    return 'B · $lat, $lng';
  }

  @override
  String get leanLabSideLeft => 'left';

  @override
  String get leanLabSideRight => 'right';

  @override
  String get leanLabNoCorners => 'No corners detected on this ride to label.';

  @override
  String get leanLabAppLean => 'App lean';

  @override
  String get leanLabGrade => 'Grade';

  @override
  String get leanLabBiasQ => 'How did the app lean feel at apex?';

  @override
  String get leanLabBiasAppHigh => 'App too high';

  @override
  String get leanLabBiasOk => 'Felt right';

  @override
  String get leanLabBiasAppLow => 'App too low';

  @override
  String get leanLabBiasUnsure => 'Not sure';

  @override
  String get leanLabTrendClimbing => 'climbing';

  @override
  String get leanLabTrendDescending => 'descending';

  @override
  String get leanLabTrendFlat => 'flat';

  @override
  String get leanLabSaveLabels => 'Save corner labels';

  @override
  String get leanLabSettingsTile => 'Lean Lab (pilots)';

  @override
  String get leanLabSettingsHelp =>
      'Bugambilias protocol · calib · elevation · corner ground truth';

  @override
  String get skillReplayTitle => 'Corner replay';

  @override
  String get skillReplayHelp =>
      'Watch how this stretch was ridden — lean, braking, and speed move with the map playhead.';

  @override
  String get skillReplayCompareHelp =>
      'Both lines are cropped to the same road section. Playheads advance by distance along the corner so you compare the line, not the clock.';

  @override
  String get skillReplayCompareWith => 'Compare with a friend';

  @override
  String get skillReplayNoPeerMatch =>
      'This friend did not cover the same corner section.';

  @override
  String get skillReplayAlignedSection =>
      'Same corner section for both riders (corridor match).';

  @override
  String get skillReplaySameSection => 'same section · path-synced';

  @override
  String get skillReplay => 'Replay';

  @override
  String get compareSharedSectionHelp =>
      'Solid = you · dashed = other. Lines are offset slightly and cropped to shared road so both stay visible.';

  @override
  String get compareTrackUnavailable =>
      'Track points unavailable for this ride.';

  @override
  String get compareOneTrackOnly => 'Only one track has enough points to draw.';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get restart => 'Restart';

  @override
  String get loopReplay => 'Loop';

  @override
  String get brake => 'Brake';

  @override
  String get engineLabelTitle => 'Help train RiderLab';

  @override
  String get engineLabelIntro =>
      'Beta only — a few taps after each ride teach lean, curves, and brakes. Skip anytime.';

  @override
  String get engineLabelSkip => 'Skip';

  @override
  String get engineLabelSave => 'Save answers';

  @override
  String get engineLabelMountQ => 'Where was the phone on this ride?';

  @override
  String get engineLabelMountCenter => 'Mount (tank / bars)';

  @override
  String get engineLabelMountLeftPocket => 'Left pocket';

  @override
  String get engineLabelMountRightPocket => 'Right pocket';

  @override
  String get engineLabelMountOther => 'Other / loose';

  @override
  String get engineLabelLeanQ => 'Did the lean / incline feel right?';

  @override
  String get engineLabelLeanGood => 'Felt right';

  @override
  String get engineLabelLeanLeftHigh => 'Left looked too high';

  @override
  String get engineLabelLeanRightHigh => 'Right looked too high';

  @override
  String get engineLabelLeanBothOff => 'Both sides off';

  @override
  String get engineLabelLeanUnsure => 'Not sure';

  @override
  String get engineLabelBrakeQ => 'Did the brake marks look right?';

  @override
  String get engineLabelBrakeGood => 'Felt right';

  @override
  String get engineLabelBrakeTooMany => 'Too many / fake brakes';

  @override
  String get engineLabelBrakeTooFew => 'Missed real brakes';

  @override
  String get engineLabelBrakeUnsure => 'Not sure';

  @override
  String get engineLabelContextQ => 'What kind of ride was this?';

  @override
  String get engineLabelContextStreet => 'Street';

  @override
  String get engineLabelContextMountain => 'Mountain';

  @override
  String get engineLabelContextTrack => 'Track';

  @override
  String get engineLabelContextCommute => 'Commute';

  @override
  String get engineLabelContextOther => 'Other';

  @override
  String get gpsCheckingPermission => 'Checking location permission…';

  @override
  String get gpsPreparing => 'Preparing high-precision GPS…';

  @override
  String get gpsLookingSatellites => 'Looking for satellites…';

  @override
  String get gpsWarming => 'Warming GPS…';

  @override
  String gpsWarmingAcc(String meters) {
    return 'Warming GPS (±$meters m)…';
  }

  @override
  String gpsReadyAcc(String meters) {
    return 'GPS ready (±$meters m)';
  }

  @override
  String gpsStartWithAcc(String meters) {
    return 'Starting with ±$meters m — keep sky view open';
  }

  @override
  String get gpsStartKeepSky =>
      'Starting — keep sky view open for a better lock';

  @override
  String get gpsRollingNextLap => 'Rolling to next lap…';

  @override
  String get locationServicesOff =>
      'Turn on location services to record your line.';

  @override
  String get locationPermissionDenied =>
      'Location permission is required to draw your pilot line.';

  @override
  String get locationPermissionDeniedForever =>
      'Enable location in Settings, then try again.';

  @override
  String leanAtPlayhead(String degrees) {
    return 'At playhead · neutral offset $degrees°';
  }

  @override
  String scrubPointMeta(int index, int total, String speed) {
    return 'Point $index/$total  ·  $speed  ·  lean ';
  }

  @override
  String scrubGpsMeta(String meters) {
    return '  ·  GPS $meters m';
  }

  @override
  String get shareVisibilityHelp =>
      'Choose who can see this ride. Friends must accept your request first.';

  @override
  String get speedLegendScale => 'blue→lime→yellow→red→magenta';

  @override
  String brakePeakDecel(String value) {
    return 'peak $value m/s²';
  }

  @override
  String curvaMetaTurnLean(String turn, String lean) {
    return 'turn $turn° · lean $lean°';
  }
}
