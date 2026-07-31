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
  String get tagline => 'Entry. Apex. Exit. Own every corner.';

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
  String get sectionRoad => 'Straights & turns';

  @override
  String get sectionRoadSub => 'From heading change';

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
  String get mapHint => 'Blue→magenta by speed. Dots = inferred brakes.';

  @override
  String get mapHintZoom =>
      'Bright = selected stretch · dim = rest. Dots = brakes.';

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
  String roadStretchesHelp(int rectas, int curvas) {
    return 'From heading change + lean. $rectas straights · $curvas turns. Tap a turn for entry / apex / exit — swipe between turns.';
  }

  @override
  String get roadStretchesEmpty =>
      'Not enough GPS heading change yet to split straights and turns.';

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
  String get shareRideTitle => 'Share & route';

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
}
