// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CornerIQ';

  @override
  String get tagline =>
      'Record the line you rode. Scrub it. Improve every corner.';

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
      'Start a ride and CornerIQ will draw the exact line you took on the street.';

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
    return 'CornerIQ $version is ready (you have $current).';
  }

  @override
  String get update => 'Update';

  @override
  String get later => 'Later';

  @override
  String get onLatest => 'You’re on the latest CornerIQ.';

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
  String get leanHelp => '0° is inferred upright (works with phone in pocket).';

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
    return 'From heading change (lean helps side). $rectas straights · $curvas turns. Tap a turn for entry / apex / exit.';
  }

  @override
  String get roadStretchesEmpty =>
      'Not enough GPS heading change yet to split straights and turns.';

  @override
  String get openDetail => 'open detail';

  @override
  String get brakesHelp =>
      'Inferred from how fast speed falls — not a brake sensor. Tap a hit to jump the playhead.';

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
  String get friends => 'Friends';

  @override
  String get friendsSubtitle =>
      'Closed beta — every rider with the app is on your list.';

  @override
  String get friendsEmpty =>
      'No other riders yet. When a friend installs CornerIQ, they appear here.';

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
}
