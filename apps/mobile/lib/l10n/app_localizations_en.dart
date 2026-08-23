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
  String get tagline => 'Ride every corner better.';

  @override
  String get autoPauseToggle => 'Pause when I stop';

  @override
  String get autoPauseToggleHint =>
      'Recording pauses when you stop and starts again when you roll.';

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
      'Names the ride from where you started and finished (e.g. Tesistán - Zapopan).';

  @override
  String namingRidesProgress(int done, int total) {
    return 'Naming $done of $total…';
  }

  @override
  String namedRidesDone(int count) {
    return 'Named $count rides.';
  }

  @override
  String get rideUntitledHint => 'Start - finish not named yet';

  @override
  String get rideNameTitle => 'Ride name';

  @override
  String get rideNameHint => 'Tesistán - Zapopan';

  @override
  String get rideNameHelp =>
      'Type a name, or use the map from GPS start and finish.';

  @override
  String get nameFromMap => 'From map';

  @override
  String get lookingUpPlaces => 'Looking up places…';

  @override
  String get couldNotResolvePlaces => 'Couldn\'t find those place names';

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
      'Start a ride and RiderLab will draw the line you took on the street.';

  @override
  String get unfinishedRide => 'Unfinished ride found';

  @override
  String unfinishedRideBody(String when) {
    return 'Started $when. Finish it to save the line, or throw it away.';
  }

  @override
  String get discard => 'Discard';

  @override
  String get keepLine => 'Save line';

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
  String get onLatest => 'You already have the latest RiderLab.';

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
    return 'A newer version is ready (you have $current). Download and install now?';
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
  String get rideLabSegment => 'Ride lab · this stretch';

  @override
  String get rideNotFound => 'Ride not found';

  @override
  String get collapseHint =>
      'Tap a section title to hide it. The marker stays at the bottom.';

  @override
  String get segmentZoomHint =>
      'This stretch only — numbers and charts are just for this part of the ride.';

  @override
  String get sectionSegment => 'This stretch';

  @override
  String get sectionSegmentSub => 'Pick part of the ride';

  @override
  String get sectionOverview => 'Overview';

  @override
  String get sectionOverviewSub => 'Score and ride numbers';

  @override
  String get sectionOverviewSubZoom => 'Score and numbers for this stretch';

  @override
  String get sectionLean => 'Lean';

  @override
  String get sectionLeanSub => 'Blue left · yellow right';

  @override
  String get sectionMap => 'Map + line';

  @override
  String get sectionMapSub => 'Color = speed · dots = brakes';

  @override
  String get sectionRoad => 'Turns';

  @override
  String get sectionRoadSub => 'Found from turning and lean';

  @override
  String get sectionLoop => 'Laps';

  @override
  String get sectionLoopSub => 'Find laps or mark start and finish';

  @override
  String get sectionBrakes => 'Braking';

  @override
  String get sectionBrakesSub =>
      'Strongest first · zoom the map to see a stretch';

  @override
  String get sectionBrakesSubZoom => 'Brakes on this stretch, in order';

  @override
  String get sectionCharts => 'Charts';

  @override
  String get sectionChartsSub => 'Speed · lean · GPS';

  @override
  String get sectionNotes => 'Precision + notes';

  @override
  String get sectionNotesSub => 'GPS quality and notes';

  @override
  String get segment => 'STRETCH';

  @override
  String get segmentZoom => 'THIS STRETCH';

  @override
  String get segmentHint =>
      'Drag the handles to pick part of the ride, then zoom in.';

  @override
  String get segmentHintZoomed =>
      'Map and numbers show only this stretch. Drag the handles to change it.';

  @override
  String get zoomToSegment => 'Zoom to this stretch';

  @override
  String get fullRide => 'Full ride';

  @override
  String get playhead => 'MARKER';

  @override
  String get distance => 'Distance';

  @override
  String get time => 'Time';

  @override
  String get speed => 'Speed';

  @override
  String get bikeLean => 'Bike lean';

  @override
  String get calibrating => 'Setting 0°…';

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
      'How accurate GPS is, in meters (smaller is better)';

  @override
  String get chartSpeedSub => 'Colors show speed. Tap to move along the ride.';

  @override
  String get chartSpeedSubZoom =>
      'Speed for this stretch only. Tap to move along it.';

  @override
  String get leanHelp =>
      '0° is upright. For a good reading, fix the phone on the tank or bars, screen toward you. A loose pocket throws the number off.';

  @override
  String get leanPhoneDisclaimer =>
      'How you carry the phone matters: upright, screen toward you, firmly held. A loose pocket makes lean look wrong.';

  @override
  String get mapHint =>
      'Tap the line to move the bike. Color is speed. Dots are brakes.';

  @override
  String get mapHintZoom =>
      'Tap the line to move the bike. Bright = this stretch · dim = the rest.';

  @override
  String get startingRide => 'Starting ride';

  @override
  String get gpsReady => 'GPS ready';

  @override
  String gpsWarmHelp(String meters) {
    return 'Stay outside with a clear view of the sky. Recording starts when GPS is good enough (about ±$meters m).';
  }

  @override
  String get horizontalAccuracy => 'GPS ACCURACY';

  @override
  String lowerBetter(String meters) {
    return 'Smaller is better · ready at ±$meters m';
  }

  @override
  String get couldNotStart => 'Couldn’t start ride';

  @override
  String get tryAgain => 'Try again';

  @override
  String get back => 'Back';

  @override
  String get activeMountHelp =>
      '0° is already saved. You can lock the screen — leave the recording notification on.';

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
  String get brakeToApex => 'Brake to the tightest point';

  @override
  String get accelFromApex => 'Gas after the tightest point';

  @override
  String get leanAtApex => 'Lean at the tightest point';

  @override
  String get maxLean => 'Max lean';

  @override
  String get leftShort => 'L';

  @override
  String get rightShort => 'R';

  @override
  String get curvaMapLegend =>
      'E = entry · A = tightest point · X = exit. Line color is speed.';

  @override
  String get curvaCoach =>
      'Quick check: did you come in too fast (lots of brake before A), was the middle of the turn steady, and did you exit on the gas?';

  @override
  String roadStretchesHelp(int curvas) {
    return 'Turns found from steering and lean. $curvas turns. Tap one to see entry, middle, and exit — swipe to the next.';
  }

  @override
  String get roadStretchesEmpty =>
      'Not enough turning on GPS yet to find corners.';

  @override
  String get openDetail => 'open detail';

  @override
  String get brakesHelp =>
      'Guessed from how fast speed drops — not a brake sensor. Strongest first. Tap a mark to jump there. Zoom the map to see more on a stretch.';

  @override
  String get brakesHelpZoom =>
      'Brakes on this stretch, in time order. Tap a mark to jump there.';

  @override
  String get brakesEmpty =>
      'No clear brakes from GPS speed. Hard stops usually show as yellow, orange, or red marks.';

  @override
  String get brakesEmptyZoom => 'No clear brakes on this stretch.';

  @override
  String brakesMoreOverview(int count) {
    return '$count more on this ride. Zoom the map to see the rest of a stretch.';
  }

  @override
  String brakesMoreInStretch(int count) {
    return '$count more in this stretch.';
  }

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
      'Move and zoom freely. Draw a box or use what’s on screen, then load numbers for that stretch.';

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
  String get loadAreaMetrics => 'Load numbers for this area';

  @override
  String areaReady(int points) {
    return 'Area ready · $points GPS points. Load numbers to focus Ride lab on this stretch.';
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
  String get myLocationUnavailable => 'Couldn\'t find your location.';

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
  String get mapLayerPlayhead => 'Marker';

  @override
  String get mapLayerLegend => 'Legend';

  @override
  String get mapLayerGpsGaps => 'GPS gaps';

  @override
  String get friends => 'Friends';

  @override
  String get friendsSubtitle =>
      'Closed group — anyone with the app shows up here.';

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
      'Pick a first lap and a second lap to compare times and lines on this circuit.';

  @override
  String get compareLocalEmpty =>
      'You need at least 2 finished laps on this route. Use lap mode or tag rides with the same route.';

  @override
  String get compareBaseline => 'Baseline';

  @override
  String get compareChallenger => 'Second lap';

  @override
  String compareLocal(int count) {
    return 'Compare laps ($count)';
  }

  @override
  String compareDeltaFaster(String delta) {
    return 'Second lap faster by $delta';
  }

  @override
  String compareDeltaSlower(String delta) {
    return 'Second lap slower by $delta';
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
      'Can\'t reach the cloud — check your internet and try again.';

  @override
  String get cloudAnonymousOff =>
      'Friends need sign-in turned on in RiderLab cloud. Ask the person who set up the app, then open Friends again and pull to refresh.';

  @override
  String get routesTitle => 'Routes';

  @override
  String get routesHelp =>
      'Name a circuit, share it, and tag rides so friends can compare on the same road.';

  @override
  String get routesHowTitle => 'How do routes work?';

  @override
  String get routesHowBody =>
      '1) Create a route with + (e.g. “North roundabout”).\n2) Open the route → Laps tab: find closed laps from tagged rides, or mark start (A) and finish (B) yourself.\n3) Start a lap ride from a saved lap — each lap is saved on this route.\n4) Or in Ride lab → Share, tag any ride with this route.\n5) Turn sharing on if friends should compare on this circuit.';

  @override
  String get routesTapHint => 'Tap for laps';

  @override
  String get routesLoopReady => 'Lap ready';

  @override
  String get setYourAlias => 'Set your alias';

  @override
  String get sectionNotesProOnly => 'Pro only — GPS precision and notes';

  @override
  String get proCurvaBannerTitle => 'Corner detail · Pro';

  @override
  String get proCurvaBannerBody =>
      '0.5 s preview. Pro unlocks entry, middle, exit, and the map with no lock.';

  @override
  String get proNotesBannerTitle => 'Precision + notes · Pro';

  @override
  String get proNotesBannerBody =>
      'GPS quality and riding tips stay in RiderLab Pro.';

  @override
  String get proFeatureCurva => 'Full corner detail (no banner)';

  @override
  String get proFeatureNotes => 'GPS accuracy + riding notes';

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
  String get armAutoRide => 'Start when I roll';

  @override
  String get disarmAutoRide => 'Cancel auto-start';

  @override
  String get waitingForMotion => 'Waiting for motion…';

  @override
  String get armedBannerBody =>
      'RiderLab will start recording by itself when you start moving.';

  @override
  String get armedSessionTitle => 'Armed route';

  @override
  String get armedSessionOpen => 'Open session';

  @override
  String get armedSessionMinimize => 'Minimize';

  @override
  String get armedSessionWatchRecording => 'Open recording';

  @override
  String get armedSessionEndArm => 'End armed session';

  @override
  String get armedSessionStretchesEmpty =>
      'No stretches yet. They\'ll show up here when you start rolling.';

  @override
  String armedSessionStretchN(int n) {
    return 'Stretch $n';
  }

  @override
  String get armedSessionWaitingHelp =>
      'GPS is ready. Recording starts by itself when you move.';

  @override
  String get armedSessionLiveHelp =>
      'Recording. You can leave this screen — the ride keeps going.';

  @override
  String get loopMode => 'Lap mode';

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
  String get markLoopInit => 'Mark lap start';

  @override
  String get loopInitSet => 'Init marked';

  @override
  String get markLoopEnd => 'Mark lap finish';

  @override
  String get markLoopInitHere => 'Mark A at my GPS';

  @override
  String get markLoopEndHere => 'Mark B at my GPS';

  @override
  String get loopOpenMarkMap => 'Map: mark A and B';

  @override
  String get loopMarkMapHint =>
      'Open the full map, move around, then tap A (start) and B (finish).';

  @override
  String get loopTapPointA => 'Tap the map to mark point A (start)';

  @override
  String get loopTapPointB => 'Tap the map to mark point B (end)';

  @override
  String get loopPointsReady =>
      'A and B are set — confirm to start counting laps';

  @override
  String get loopMarkMapHelp =>
      'Move and zoom freely. First tap = A, second = B. The circle is where a lap is counted.';

  @override
  String get loopRemapA => 'Redo A';

  @override
  String get loopConfirmAb => 'Confirm A and B';

  @override
  String get loopArmed => 'Ready to count laps';

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
      'Pick any stretch, full corner detail, GPS notes, full brakes, and no ads.';

  @override
  String get proFeatureSegment => 'Zoom any part of the ride';

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
      'Temporary unlock until store billing is ready. Turn off to see the free version.';

  @override
  String brakesProTeaser(int shown, int total) {
    return 'Showing $shown of $total. Unlock Pro for the full brake list.';
  }

  @override
  String get segmentProLocked => 'Picking part of the ride is a Pro feature.';

  @override
  String get adPlaceholder => 'Ad';

  @override
  String get removeAdsWithPro => 'Upgrade to Pro to remove ads';

  @override
  String get routeTabLaps => 'Laps';

  @override
  String get routeTabLoop => 'Laps';

  @override
  String get routeLoopModuleHelp =>
      'Laps belong to this route. Find closed laps from tagged rides, or mark start (A) and finish (B) on the map yourself.';

  @override
  String get routeLoopDefine => 'Mark A / B';

  @override
  String get routeLoopDetect => 'Detect';

  @override
  String get routeLoopSavedTitle => 'Saved laps';

  @override
  String get routeLoopEmpty =>
      'No laps yet — find them from rides or mark A and B on the map.';

  @override
  String get routeLoopDetectedTitle => 'Possible laps';

  @override
  String get routeLoopDetectedEmpty =>
      'No closed laps found on tagged rides yet. Ride the circuit and try again.';

  @override
  String get routeLoopDetectedHint =>
      'Closed path from GPS — save it to count laps automatically.';

  @override
  String get routeLoopSave => 'Save';

  @override
  String get routeLoopSaved => 'Lap saved on this route';

  @override
  String get routeLoopManualName => 'Manual lap';

  @override
  String get routeLoopPrimary => 'PRIMARY';

  @override
  String get routeLoopSetPrimary => 'Set as primary';

  @override
  String get routeLoopStartRide => 'Start lap ride';

  @override
  String get routeLoopSourceManual => 'Manual';

  @override
  String get routeLoopSourceDetected => 'Detected';

  @override
  String get deleteRoute => 'Delete route';

  @override
  String get deleteRouteBody =>
      'This removes the route, its laps, and untags rides. If shared, it disappears for everyone.';

  @override
  String get routeDeleted => 'Route deleted';

  @override
  String get deleteLoop => 'Delete lap';

  @override
  String get deleteLoopBody =>
      'Removes this lap. If it was the main one, A/B marks on the route are cleared too (friends see that when they sync).';

  @override
  String get loopDeleted => 'Lap deleted';

  @override
  String get deleteAllLoops => 'Remove all laps';

  @override
  String get deleteAllLoopsBody =>
      'Deletes every lap on this route and clears A/B marks. Friends get a lap-free route when they sync.';

  @override
  String get loopsCleared => 'Laps cleared';

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
      'You\'re a guest. Sign in to keep your profile on other phones — your rides stay linked when we can.';

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
  String get impersonateTitle => 'View as rider';

  @override
  String get impersonateTile => 'View as another rider';

  @override
  String get impersonateHelp =>
      'Cloud session becomes that rider (rodadas, friends, cloud rides). This phone’s Garage stays yours. Don’t record or Sync. Exit restores your account.';

  @override
  String get impersonateSearchHint => 'Name, email, or user id';

  @override
  String get impersonateEmpty => 'No riders match.';

  @override
  String get impersonateStart => 'View as them';

  @override
  String get impersonateExit => 'Exit';

  @override
  String impersonateBanner(String name) {
    return 'Viewing as $name';
  }

  @override
  String get impersonateConfirmTitle => 'Switch cloud session?';

  @override
  String impersonateConfirmBody(String name) {
    return 'This phone will act as $name in the cloud until you exit. Local Garage and GPS recording stay yours and stay blocked.';
  }

  @override
  String get impersonateFailed => 'Could not switch account.';

  @override
  String get impersonateUnknown => 'another rider';

  @override
  String get impersonateNoRide =>
      'Recording is off while viewing as another rider.';

  @override
  String get impersonateNoSync =>
      'Cloud sync is off while viewing as another rider.';

  @override
  String get rideLoopHelp =>
      'Find closed laps on this ride’s GPS, or mark start (A) and finish (B) on the map. Saving creates or uses a route so you can count laps later.';

  @override
  String get rideLoopEmpty => 'No laps saved for this ride’s route yet.';

  @override
  String get rideLoopDetectedEmpty =>
      'No closed lap found on this ride. Try Mark A / B on the map.';

  @override
  String get rideLoopNeedPoints => 'Not enough GPS points to mark a lap.';

  @override
  String get rideLoopSaveFirst => 'Save a lap first — that creates the route.';

  @override
  String get rideLoopOpenRoute => 'Open route (laps)';

  @override
  String get syncCloudRides => 'Sync rides with cloud';

  @override
  String get syncCloudRidesHelp =>
      'Upload finished rides, then download this account’s garage rides and Lean lab sessions onto this phone.';

  @override
  String syncCloudRidesDone(int ok, int fail) {
    return 'Upload: $ok ok, $fail failed';
  }

  @override
  String syncCloudRidesPulled(int rides, int lean) {
    return 'Downloaded $rides rides, $lean Lean Lab';
  }

  @override
  String get playStoreUpdatesOnly =>
      'Updates install from Google Play for this build.';

  @override
  String get labSection => 'Lab (try-out)';

  @override
  String get labAdventureCameraHelp =>
      'Optional GoPro shutter with the ride. Off by default — GPS recording does not change.';

  @override
  String get labAdventureCameraEnable => 'Adventure camera';

  @override
  String get labAdventureCameraEnableHelp =>
      'Turn on the camera tools on this phone';

  @override
  String get labAdventureCameraSyncRide => 'Record with ride';

  @override
  String get labAdventureCameraSyncRideHelp =>
      'Start and stop with the whole ride. If map start points are set, the camera waits until you reach one.';

  @override
  String get labAdventureCameraSyncPause => 'Follow auto-pause';

  @override
  String get labAdventureCameraSyncPauseHelp =>
      'Stop the camera while auto-pause is on (optional)';

  @override
  String get labAdventureCameraBackend => 'Camera type';

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
      'Test the shutter by hand — no ride needed. Connect first (or use Simulate).';

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
  String get labAdventureCameraZonesEnable => 'Start/stop on the map';

  @override
  String get labAdventureCameraZonesEnableHelp =>
      'Start and stop when you enter map zones. The camera stays off until you reach a start point.';

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
      'Tap to place Start, then tap again for that Start’s Stop. Long-press a pin to remove the pair. A Stop only works after its Start was hit.';

  @override
  String get labAdventureCameraZonesPlaceStart => 'Next tap: Start ▶';

  @override
  String get labAdventureCameraZonesPlaceStop =>
      'Next tap: Stop ■ for this pair';

  @override
  String get labAdventureCameraZonesPairs => 'Pairs';

  @override
  String get rideDeckTitle => 'Start ride';

  @override
  String get rideDeckHelp =>
      'Tap once, put the phone in a pocket or on the tank, stay still. When you feel a buzz and beep, 0° is saved and the ride starts — you won’t tap again.';

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
      'Ready — when you roll, a ride starts in the garage.';

  @override
  String get freezeThenArmHelp =>
      'Tap once, put the phone in place, stay still. A buzz and beep means 0° is saved. Then lock the screen — rolling starts the ride. You won’t tap again.';

  @override
  String get armAutoRouteArmed => 'Ready — rolling starts the ride';

  @override
  String armAutoRouteArmedNamed(String name) {
    return 'Ready for “$name” — the ride will be saved on that route';
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
  String get familyCircleTitle => 'Family circle';

  @override
  String get familyCircleHomeTile =>
      'People who can see you’re OK while riding';

  @override
  String get familyCircleHelp =>
      'Add contacts here. The link is created while recording or on a Rodada (Live). You can resend it to more people without breaking earlier links.';

  @override
  String get familyHowToShareTitle => 'How to send the link';

  @override
  String get familyHowToShareSteps =>
      '1) On Record or on a Rodada (Live tab).\n2) Tap the share icon.\n3) Pick contacts — the same link works for everyone.\n\nPack “Share live” is separate: only riders with the app.';

  @override
  String get familyShareNeedsRide =>
      'Start a recording or open a Rodada first. Then you can share the family link.';

  @override
  String get familyShareFromCircle => 'Share link now';

  @override
  String get familyRodadaTipTitle => 'Family link?';

  @override
  String get familyRodadaTipBody =>
      'Pack = rodada map in the app. Family without the app = share from Live (same link can be resent).';

  @override
  String get familyRodadaTipCta => 'Open family circle';

  @override
  String get familyAppBarShareTooltip => 'Notify family';

  @override
  String get familyAddContact => 'Add contact';

  @override
  String get familyContactLabel => 'Name';

  @override
  String get familyContactLabelHint => 'Mom / Ana / …';

  @override
  String get familyOptionalFriend => 'Optional: link a RiderLab friend';

  @override
  String get familyNoFriendsYet =>
      'No friends yet — you can still add a name and share the link.';

  @override
  String get familySaveContact => 'Save';

  @override
  String get familyMyCircle => 'My circle';

  @override
  String get familyCircleEmpty =>
      'No contacts yet. Add someone before your next ride.';

  @override
  String get familyLinkOnlyContact => 'Gets the share link (no app account)';

  @override
  String get familyAppContact => 'Can also watch in the app';

  @override
  String get familyWatchingNow => 'Riding now';

  @override
  String get familyNoActiveWatches =>
      'Nobody in your circle is sharing a ride right now.';

  @override
  String get familyTapToWatch => 'Tap to open map';

  @override
  String get familyRiderFallback => 'Rider';

  @override
  String get familyNotifyToggle => 'Notify family';

  @override
  String get familyNotifyHelp =>
      'Creates a link and opens the share sheet so you can send it (they don’t need the app).';

  @override
  String get familyNotifyHelpRodada =>
      'Notify family/friends outside the pack. You can resend the same link to more people.';

  @override
  String get familyNotifyStart => 'Share';

  @override
  String get familyWatchActive => 'Family can see you';

  @override
  String get familyWatchStop => 'Stop';

  @override
  String get familyOk => 'All good';

  @override
  String get familyStopped => 'Stopped';

  @override
  String get familySos => 'Need help';

  @override
  String get familyShareLink => 'Resend link';

  @override
  String get familyShareAgain => 'Send to another';

  @override
  String get familyShareAgainHint =>
      'You can send the same link to more people; earlier recipients keep working.';

  @override
  String get familyRotateLink => 'New link';

  @override
  String get familyRotateLinkTitle => 'Invalidate previous links?';

  @override
  String get familyRotateLinkBody =>
      'Creates a new link. Anyone with the old one will lose access. Use this if the link leaked.';

  @override
  String get familyRotateLinkConfirm => 'Invalidate and share';

  @override
  String get familyShareNeedsSignIn => 'Sign in to share with family.';

  @override
  String get familyShareSubject => 'RiderLab — I’m riding';

  @override
  String familyShareMessage(String url) {
    return 'I’m on a ride. Open this link to see my last location (not 911):\n$url';
  }

  @override
  String familyLastSeen(String when) {
    return 'Last signal $when';
  }

  @override
  String familyNoSignalSince(String when) {
    return 'No signal · last at $when';
  }

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
  String get rodadaItinerary => 'Itinerary';

  @override
  String get rodadaPinStart => 'Start';

  @override
  String get rodadaPinFinish => 'Finish';

  @override
  String get rodadaPinStop => 'Stop';

  @override
  String get rodadaPinUnset => 'Not set';

  @override
  String rodadaStopN(int n) {
    return 'Stop $n';
  }

  @override
  String get rodadaItineraryHelp =>
      'Search or tap the map to mark start, finish, or stops. Live GPS and photos stay off until each rider opts in.';

  @override
  String get routePrefTolls => 'Tolls';

  @override
  String get routePrefHighway => 'Highway';

  @override
  String get routePrefStreet => 'Street';

  @override
  String get routePrefOffroad => 'Off-road';

  @override
  String get routeSearchHint => 'Search a place, town, or address…';

  @override
  String routeSummaryKmEta(String distance, String eta) {
    return '$distance · $eta';
  }

  @override
  String get routeFailedFallback =>
      'Could not follow roads — showing a straight line.';

  @override
  String get offRouteBanner => 'Off route';

  @override
  String get routeRouting => 'Routing…';

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
  String get rodadaInviteShare => 'Share invitation';

  @override
  String get rodadaInviteShareHint =>
      'Share a summary on WhatsApp or another app.';

  @override
  String rodadaInviteShareSubject(String title) {
    return 'Rodada: $title';
  }

  @override
  String rodadaInviteShareWhen(String when) {
    return 'When: $when';
  }

  @override
  String rodadaInviteShareWhere(String place) {
    return 'Where: $place';
  }

  @override
  String rodadaInviteShareRoute(String summary) {
    return 'Route: $summary';
  }

  @override
  String rodadaInviteShareHost(String name) {
    return 'Host: $name';
  }

  @override
  String rodadaInviteShareRiders(int count, String names) {
    return 'Riders ($count): $names';
  }

  @override
  String rodadaInviteShareRidersMore(int count, String names, int extra) {
    return 'Riders ($count): $names +$extra';
  }

  @override
  String rodadaInviteShareStops(String names) {
    return 'Stops: $names';
  }

  @override
  String rodadaInviteShareNotes(String notes) {
    return 'Notes: $notes';
  }

  @override
  String rodadaInviteShareMeetup(String url) {
    return 'Meetup: $url';
  }

  @override
  String rodadaInviteShareFinish(String url) {
    return 'Finish: $url';
  }

  @override
  String rodadaInviteShareCode(String code) {
    return 'Join in RiderLab with code $code';
  }

  @override
  String get rodadaInviteShareHow => 'Rodadas → Join with invite code';

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
  String get inviteFriend => 'Invite friends';

  @override
  String get leaveRodada => 'Leave rodada';

  @override
  String get leaveRodadaConfirmTitle => 'Leave this rodada?';

  @override
  String get leaveRodadaConfirmBody =>
      'It will leave your list. The host is not removed.';

  @override
  String get leaveRodadaDone => 'You left the rodada';

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
  String get inviteFriends => 'Invite friends';

  @override
  String get rodadaInviteChip => 'Invite';

  @override
  String rodadaInviteBanner(String title) {
    return 'You were invited to $title';
  }

  @override
  String get rsvpPending => 'pending';

  @override
  String get rsvpAccept => 'Accept';

  @override
  String get rsvpDecline => 'Decline';

  @override
  String get inviteSent => 'Invite sent';

  @override
  String get inviteAlreadyMember => 'Already on this rodada';

  @override
  String get inviteSentNoToken =>
      'Invited in the app. That phone has no notification token yet — ask them to open RiderLab signed in.';

  @override
  String inviteSentPushFailed(String reason) {
    return 'Invited in the app, but the notification failed: $reason';
  }

  @override
  String invitePushAllOk(int count) {
    return '$count notifications sent';
  }

  @override
  String invitePushSummary(int ok, int failed, String reason) {
    return 'Invited in the app. Notifications: $ok sent, $failed failed ($reason)';
  }

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
      'Off until you turn it on. Then your location is sent every 5 minutes for the whole group ride (tries again every 1 minute if a send fails).';

  @override
  String get notRodadaMember => 'You are not a member.';

  @override
  String get shareLocationOnRoute => 'Share location on route';

  @override
  String get shareLocationEvery5Min => 'Every 5 min while rodada is open/live';

  @override
  String get shareTrackAfterRides => 'Share my line after rides';

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
  String liveRiderLastSeen(String name, String when) {
    return '$name · $when';
  }

  @override
  String liveRiderNoSignal(String name, String when) {
    return '$name · No signal · $when';
  }

  @override
  String get liveSeenJustNow => 'just now';

  @override
  String liveSeenMinutesAgo(int minutes) {
    return '$minutes min ago';
  }

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
      'Lines from riders who turned sharing on. Detailed GPS stays on each phone.';

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
  String photosUploaded(int count) {
    return '$count photos uploaded';
  }

  @override
  String get photoTitle => 'Photo';

  @override
  String get photoNeedsActiveRide =>
      'Start a ride to pin the photo to the route';

  @override
  String get photoLinkedToRoute => 'Photo linked to the route';

  @override
  String get photoCaptureTooltip => 'Rodada photo';

  @override
  String get photoTake => 'Camera';

  @override
  String get photoImportFromRoll => 'From camera roll';

  @override
  String get photoImportTitle => 'Photos from this ride';

  @override
  String get photoImportHelp =>
      'We found these camera-roll photos from your route. Nothing uploads until you confirm.';

  @override
  String get photoImportSkip => 'Skip';

  @override
  String photoImportConfirm(int count) {
    return 'Link $count photos';
  }

  @override
  String get reelTitle => 'Rodada reel';

  @override
  String get reelDone => 'Done';

  @override
  String get reelBuilding => 'Building your reel…';

  @override
  String get reelRetry => 'Regenerate';

  @override
  String get reelShare => 'Share';

  @override
  String get reelHookSub => 'Lean';

  @override
  String get reelCurvesLabel => 'Corners';

  @override
  String get reelRidersLabel => 'Riders';

  @override
  String get reelEndQuestion => 'How far did you lean?';

  @override
  String get reelCta => 'Record your line on RiderLab';

  @override
  String get reelGenerate => 'Make reel';

  @override
  String get reelOverviewCta => 'Share the rodada reel';

  @override
  String get reelLengthShort => 'Short';

  @override
  String get reelLengthStandard => 'Reels';

  @override
  String get reelLengthLong => 'Full';

  @override
  String get reelLengthHint => 'Choose how long the video runs';

  @override
  String reelLengthSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String reelLengthCap(int pauses, int photos) {
    return 'Up to $pauses stops · $photos photos';
  }

  @override
  String reelStopLabel(int n) {
    return 'Stop $n';
  }

  @override
  String get reelOnRoute => 'On the road';

  @override
  String get reelNoStops => 'No long stops on this route';

  @override
  String reelPhotoCount(int count) {
    return '$count photos';
  }

  @override
  String get reelAddToStop => 'Add photo';

  @override
  String get skillCoach => 'Riding tips';

  @override
  String skillCurvasRated(int count) {
    return '$count corners scored · good for comparing with friends';
  }

  @override
  String get improveNextRide => 'Improve next ride';

  @override
  String get openCornerLab => 'Open corner lab';

  @override
  String get skillTipNoCurvas =>
      'No solid corners found — ride a twisty stretch so we have something to go on.';

  @override
  String skillTipEntryHot(String entry, String apex) {
    return 'Came in hot ($entry→$apex km/h). Brake earlier before you lean.';
  }

  @override
  String get skillTipModerateSpeedDrop =>
      'Speed drop to the middle is OK — brake a little longer as you lean in.';

  @override
  String get skillTipLittleSpeedScrub =>
      'Speed barely dropped — check you’re not carrying too much in the middle of the turn.';

  @override
  String get skillTipWeakExitDrive =>
      'Weak exit — open the gas sooner once the bike starts standing up.';

  @override
  String get skillTipPeakLeanNotAtApex =>
      'Most lean wasn’t at the tightest point — lean in earlier so you’re set in the middle.';

  @override
  String get skillTipLowLeanBigHeading =>
      'A lot of turning with little lean — check the phone is firmly held, or lean more.';

  @override
  String get skillTipSolidCorner =>
      'Solid corner — keep this entry and middle rhythm.';

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
  String gpsRateHz(String hz) {
    return '$hz Hz';
  }

  @override
  String get imuAzurePending => 'IMU upload pending';

  @override
  String get imuAzureUploading => 'Uploading IMU…';

  @override
  String get imuAzureUploaded => 'IMU on Azure';

  @override
  String get imuAzureFailed => 'IMU upload failed';

  @override
  String get imuAzureRetry => 'Retry IMU upload';

  @override
  String get pressure => 'Pressure';

  @override
  String get pressureChartSub => 'Barometer reading along the ride (hPa)';

  @override
  String get skillLabTitle => 'Skill lab';

  @override
  String get skillLabTapHint => 'Tap to see mistakes and how to fix them';

  @override
  String get skillLabTapHintEmpty => 'Tap for tips after a twisty ride';

  @override
  String get skillLabFocusTitle => 'Where to improve';

  @override
  String get skillLabFocusHelp =>
      'Worst-scoring turns first. Bars show entry → middle → exit speed. Tap Replay to watch lean, brake, and speed — and compare the same corner with a friend.';

  @override
  String get bikeSection => 'My bike';

  @override
  String get bikeSelect => 'Select your bike';

  @override
  String get bikeSelectHelp => 'Used for Lean lab and your rides';

  @override
  String get bikePickerTitle => 'Garage';

  @override
  String get bikePickerHelp => 'Brand, then year, then model.';

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
  String get bikeFamilyOffroad => 'Off-road';

  @override
  String get bikeFamilyOther => 'Other';

  @override
  String get bikeSearchHint => 'Search model or year';

  @override
  String get bikeStepMake => 'Brand';

  @override
  String get bikeStepYear => 'Year';

  @override
  String get bikeStepModel => 'Model';

  @override
  String get bikeSearchMake => 'Search brand';

  @override
  String get bikeSearchYear => 'Search year';

  @override
  String get bikeSearchModel => 'Search model';

  @override
  String get bikePopularMakes => 'Popular';

  @override
  String get bikeAllMakes => 'All brands';

  @override
  String get bikeCustomModel => 'Other model…';

  @override
  String get bikeCustomModelHint => 'Type the model name';

  @override
  String get leanLabHomeCta => 'Lean Lab — Bugambilias';

  @override
  String get leanLabTitle => 'Lean Lab';

  @override
  String get labsSectionTitle => 'Tests / new features';

  @override
  String get labsSectionHelp =>
      'Experimental tools. Not part of the daily ride flow.';

  @override
  String get pushDiagnosticsTitle => 'Last notification send';

  @override
  String get pushDiagnosticsEmpty => 'No notification send recorded yet.';

  @override
  String get pushDiagnosticsCopied => 'Notification log copied';

  @override
  String get leanLabIntro =>
      'Bugambilias both ways, with hills. Set 0° with the bike upright, ride, then mark corners so we can improve lean.';

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
      'Toward the plaza, phone in the usual place. Captures lean on climbs and descents.';

  @override
  String get leanLabProtoReturn => 'Baseline return';

  @override
  String get leanLabProtoReturnHelp =>
      'The other way, same phone place. Same corners, opposite sides.';

  @override
  String get leanLabProtoPocket => 'Phone in pocket';

  @override
  String get leanLabProtoPocketHelp =>
      'Same circuit with the phone in a pocket, to see how that changes lean.';

  @override
  String get leanLabProtoFree => 'Free Lean Lab lap';

  @override
  String get leanLabProtoFreeHelp =>
      'Any direction on this circuit. Set 0°, then mark corners.';

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
      'Phone already on the tank mount or tank bag. Save 0° with the bike standing straight, then start the lap.';

  @override
  String get leanLabPoseQ => 'How is the phone sitting?';

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
  String get leanLabCalibTitle => 'Save upright (0°)';

  @override
  String get leanLabCalibHelp =>
      'Bike standing straight, phone already in place. Hands off for 4 seconds — this saves 0°. Lean should stay near 0°.';

  @override
  String get leanLabCalibHold => 'Hold upright 4s';

  @override
  String get leanLabCalibHolding => 'Hold still…';

  @override
  String get leanLabCalibPocket => 'Save in pocket';

  @override
  String get leanLabCalibPocketHelp =>
      'Tap, put the phone fully in the pocket, stay still. A buzz and beep means 0° is saved and the ride started — don’t save 0° in your hand.';

  @override
  String leanLabCalibPocketCountdown(int n) {
    return 'Pocket it now · ${n}s';
  }

  @override
  String get leanLabCalibPocketSettle => 'Stay still…';

  @override
  String get leanLabCalibPocketCapture => 'Capturing 0°…';

  @override
  String get leanLabCalibPocketFail =>
      'It didn’t stay still. Put it back and try again.';

  @override
  String leanLabFreezeRedo(String n) {
    return 'The phone is already $n° from upright. Save 0° again with the bike truly standing straight.';
  }

  @override
  String get leanLabRawNeutral => 'Phone angle';

  @override
  String get leanLabFrozenNeutral => '0° saved';

  @override
  String get leanLabStartRide => 'Start Lean Lab ride';

  @override
  String get leanLabReviewTitle => 'Label lean corners';

  @override
  String get leanLabReviewHelp =>
      'For each corner: was the app lean high, OK, or low? Hill grade is shown so we can fix climb and descent.';

  @override
  String get leanLabReviewHelpMax =>
      'Max lean for the corner stays at the top. Play to watch lean and the map; jump to the peak when you want.';

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
  String get leanLabNoTrackPoints =>
      'This ride has almost no GPS track on the phone. Open Settings → Sync rides with cloud (same Google account), then try again.';

  @override
  String get leanLabNoLeanData =>
      'This ride’s GPS is here, but lean sensor samples are missing — so corners can’t be labeled. Re-sync the ride, or record the lap again with the phone firmly mounted.';

  @override
  String get leanLabAppLean => 'App lean';

  @override
  String get leanLabGrade => 'Grade';

  @override
  String get leanLabBiasQ =>
      'How did the app lean feel in the middle of the turn?';

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
  String get leanLabSettingsTile => 'Lean lab (test)';

  @override
  String get leanLabSettingsHelp =>
      'Bugambilias sessions · save 0° · hills · mark corners';

  @override
  String get leanImuLabTitle => 'IMU lean lab';

  @override
  String get leanImuLabIntro =>
      'Same lean as the ride. Save 0° with the phone in its real place, then lean. The banner shows how the phone sits.';

  @override
  String get leanImuLabSettingsTile => 'IMU lean sensors';

  @override
  String get leanImuLabSettingsHelp => 'Watch sensors and how lean is measured';

  @override
  String get leanImuLabFreeze => 'Save 0° now';

  @override
  String get leanImuLabReset => 'Reset';

  @override
  String get leanImuLabFrozenHint =>
      '0° is saved. Lean should be about 0° now. Tilt any way — the number is the angle, left or right comes from how the phone sits.';

  @override
  String get leanImuLabAnglesTitle => 'Angle candidates';

  @override
  String get leanImuLabAnglesHelp =>
      'Bike lean (red) follows the winning fused channel (same motion as purple/blue), capped by the vector clinometer (green). Green can move on any tip from 0°; red tracks bike-lean motion for this pose — without square-wave flips.';

  @override
  String get leanImuLabHistoryTitle => 'Last ~8 s';

  @override
  String get leanImuLabStartRecord => 'Record chart';

  @override
  String get leanImuLabStopRecord => 'Stop';

  @override
  String get leanImuLabExportCsv => 'Export CSV';

  @override
  String leanImuLabRecordingHint(int count) {
    return 'Recording… $count samples (send the CSV after Export)';
  }

  @override
  String leanImuLabExportDone(String path) {
    return 'Share sheet opened for $path — pick Drive, WhatsApp, or Files';
  }

  @override
  String get leanImuLabVectorsTitle => 'Raw capabilities';

  @override
  String get leanImuLabNextTitle => 'How to read this for production';

  @override
  String get leanImuLabNextHelp =>
      'Wall test: within about 3° of a real inclinometer, any position. Upright phone: lean follows roll. Flat phone: lean follows pitch. If the phone slips in a pocket, the banner changes in a few seconds.';

  @override
  String get leanLabPastSessions => 'Past sessions';

  @override
  String get leanLabSessionDetailTitle => 'Lean Lab session';

  @override
  String get leanLabSessionMissing => 'This Lean Lab session was not found.';

  @override
  String get leanLabMeasuresTitle => 'Measures';

  @override
  String get leanLabCornerMeasures => 'Corner max lean';

  @override
  String get leanLabCoverage => 'Circuit coverage';

  @override
  String get leanLabCornersCount => 'Labeled corners';

  @override
  String leanLabLabeledCount(int count) {
    return '$count corners labeled';
  }

  @override
  String get leanLabEditConfigTitle => 'Fix session setup';

  @override
  String get leanLabEditConfigHelp =>
      'Fix outbound/return, phone place, or position if you set them wrong — lean numbers stay the same; labels stay until you save them again.';

  @override
  String get leanLabSaveConfig => 'Save setup';

  @override
  String get leanLabConfigSaved => 'Session setup saved';

  @override
  String get leanLabRelabelCorners => 'Review / update corner labels';

  @override
  String get leanLabOpenRide => 'Open ride map';

  @override
  String get skillReplayTitle => 'Corner replay';

  @override
  String get skillReplayHelp =>
      'Watch how this stretch was ridden — lean, braking, and speed move with the map marker.';

  @override
  String get skillReplayCompareHelp =>
      'Both lines are cut to the same stretch of road. Markers move by distance along the corner so you compare the line, not the clock.';

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
      'A few taps after each ride help teach lean, corners, and brakes. Skip anytime.';

  @override
  String get engineLabelSkip => 'Skip';

  @override
  String get engineLabelSave => 'Save answers';

  @override
  String get engineLabelMountQ => 'Where was the phone on this ride?';

  @override
  String get engineLabelMountCenter => 'On the bike (tank / bars)';

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
  String get gpsPreparing => 'Getting a better GPS lock…';

  @override
  String get gpsLookingSatellites => 'Looking for satellites…';

  @override
  String get gpsWarming => 'Waiting for a better GPS lock…';

  @override
  String gpsWarmingAcc(String meters) {
    return 'Waiting for GPS (±$meters m)…';
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
      'Location permission is needed to draw your line.';

  @override
  String get locationPermissionDeniedForever =>
      'Enable location in Settings, then try again.';

  @override
  String leanAtPlayhead(String degrees) {
    return 'At marker · 0° offset $degrees°';
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
