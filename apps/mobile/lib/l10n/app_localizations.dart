import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('es'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'RiderLab'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In es, this message translates to:
  /// **'Domina cada curva.'**
  String get tagline;

  /// No description provided for @autoPauseToggle.
  ///
  /// In es, this message translates to:
  /// **'Pausa auto'**
  String get autoPauseToggle;

  /// No description provided for @autoPauseToggleHint.
  ///
  /// In es, this message translates to:
  /// **'Pausa y reanuda la grabación al detenerte o moverte'**
  String get autoPauseToggleHint;

  /// No description provided for @startRide.
  ///
  /// In es, this message translates to:
  /// **'Iniciar recorrido'**
  String get startRide;

  /// No description provided for @endRide.
  ///
  /// In es, this message translates to:
  /// **'Terminar recorrido'**
  String get endRide;

  /// No description provided for @recording.
  ///
  /// In es, this message translates to:
  /// **'Grabando'**
  String get recording;

  /// No description provided for @starting.
  ///
  /// In es, this message translates to:
  /// **'Iniciando…'**
  String get starting;

  /// No description provided for @live.
  ///
  /// In es, this message translates to:
  /// **'EN VIVO'**
  String get live;

  /// No description provided for @checkUpdates.
  ///
  /// In es, this message translates to:
  /// **'Buscar actualizaciones'**
  String get checkUpdates;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @spanish.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get spanish;

  /// No description provided for @english.
  ///
  /// In es, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @garage.
  ///
  /// In es, this message translates to:
  /// **'Garaje'**
  String get garage;

  /// No description provided for @yourRides.
  ///
  /// In es, this message translates to:
  /// **'Tus recorridos'**
  String get yourRides;

  /// No description provided for @nameRidesFromMap.
  ///
  /// In es, this message translates to:
  /// **'Nombrar desde el mapa'**
  String get nameRidesFromMap;

  /// No description provided for @nameRidesFromMapHelp.
  ///
  /// In es, this message translates to:
  /// **'Calcula origen y destino con GPS (ej. Tesistán - Zapopan).'**
  String get nameRidesFromMapHelp;

  /// No description provided for @namingRidesProgress.
  ///
  /// In es, this message translates to:
  /// **'Nombrando {done} de {total}…'**
  String namingRidesProgress(int done, int total);

  /// No description provided for @namedRidesDone.
  ///
  /// In es, this message translates to:
  /// **'Se nombraron {count} recorridos.'**
  String namedRidesDone(int count);

  /// No description provided for @rideUntitledHint.
  ///
  /// In es, this message translates to:
  /// **'Origen - destino pendiente'**
  String get rideUntitledHint;

  /// No description provided for @rideNameTitle.
  ///
  /// In es, this message translates to:
  /// **'Nombre del recorrido'**
  String get rideNameTitle;

  /// No description provided for @rideNameHint.
  ///
  /// In es, this message translates to:
  /// **'Tesistán - Zapopan'**
  String get rideNameHint;

  /// No description provided for @rideNameHelp.
  ///
  /// In es, this message translates to:
  /// **'Escribe un nombre o usa el mapa (inicio y fin del GPS).'**
  String get rideNameHelp;

  /// No description provided for @nameFromMap.
  ///
  /// In es, this message translates to:
  /// **'Desde el mapa'**
  String get nameFromMap;

  /// No description provided for @lookingUpPlaces.
  ///
  /// In es, this message translates to:
  /// **'Buscando lugares…'**
  String get lookingUpPlaces;

  /// No description provided for @couldNotResolvePlaces.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron obtener los nombres'**
  String get couldNotResolvePlaces;

  /// No description provided for @rideTitleCleared.
  ///
  /// In es, this message translates to:
  /// **'Nombre borrado'**
  String get rideTitleCleared;

  /// No description provided for @rideNamed.
  ///
  /// In es, this message translates to:
  /// **'Nombrado: {title}'**
  String rideNamed(String title);

  /// No description provided for @renameRide.
  ///
  /// In es, this message translates to:
  /// **'Renombrar'**
  String get renameRide;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @emptyRidesTitle.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay recorridos'**
  String get emptyRidesTitle;

  /// No description provided for @emptyRidesBody.
  ///
  /// In es, this message translates to:
  /// **'Inicia un recorrido y RiderLab dibujará la línea exacta que tomaste en la calle.'**
  String get emptyRidesBody;

  /// No description provided for @unfinishedRide.
  ///
  /// In es, this message translates to:
  /// **'Recorrido sin terminar'**
  String get unfinishedRide;

  /// No description provided for @unfinishedRideBody.
  ///
  /// In es, this message translates to:
  /// **'Empezó {when}. Finalízala para guardar la línea, o descártala.'**
  String unfinishedRideBody(String when);

  /// No description provided for @discard.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get discard;

  /// No description provided for @keepLine.
  ///
  /// In es, this message translates to:
  /// **'Conservar línea'**
  String get keepLine;

  /// No description provided for @updateAvailable.
  ///
  /// In es, this message translates to:
  /// **'Actualización disponible'**
  String get updateAvailable;

  /// No description provided for @updateReady.
  ///
  /// In es, this message translates to:
  /// **'RiderLab {version} está lista (tienes {current}).'**
  String updateReady(String version, String current);

  /// No description provided for @whatsNew.
  ///
  /// In es, this message translates to:
  /// **'Novedades'**
  String get whatsNew;

  /// No description provided for @newVersionBadge.
  ///
  /// In es, this message translates to:
  /// **'NUEVA'**
  String get newVersionBadge;

  /// No description provided for @update.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get update;

  /// No description provided for @later.
  ///
  /// In es, this message translates to:
  /// **'Después'**
  String get later;

  /// No description provided for @onLatest.
  ///
  /// In es, this message translates to:
  /// **'Ya tienes la última RiderLab.'**
  String get onLatest;

  /// No description provided for @downloadingUpdate.
  ///
  /// In es, this message translates to:
  /// **'Descargando actualización'**
  String get downloadingUpdate;

  /// No description provided for @updateFailed.
  ///
  /// In es, this message translates to:
  /// **'Falló la actualización'**
  String get updateFailed;

  /// No description provided for @connecting.
  ///
  /// In es, this message translates to:
  /// **'Conectando…'**
  String get connecting;

  /// No description provided for @close.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get close;

  /// No description provided for @checkingUpdates.
  ///
  /// In es, this message translates to:
  /// **'Buscando actualizaciones…'**
  String get checkingUpdates;

  /// No description provided for @updatePrompt.
  ///
  /// In es, this message translates to:
  /// **'Hay una versión nueva (tienes {current}). ¿Descargar e instalar ahora?'**
  String updatePrompt(String current);

  /// No description provided for @notNow.
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get notNow;

  /// No description provided for @updateCheckFailed.
  ///
  /// In es, this message translates to:
  /// **'Error al buscar actualización: {error}'**
  String updateCheckFailed(String error);

  /// No description provided for @rideLab.
  ///
  /// In es, this message translates to:
  /// **'Lab del ride'**
  String get rideLab;

  /// No description provided for @rideLabSegment.
  ///
  /// In es, this message translates to:
  /// **'Ride Lab · segmento'**
  String get rideLabSegment;

  /// No description provided for @rideNotFound.
  ///
  /// In es, this message translates to:
  /// **'Ruta no encontrada'**
  String get rideNotFound;

  /// No description provided for @collapseHint.
  ///
  /// In es, this message translates to:
  /// **'Toca los encabezados para plegar. El cursor queda abajo.'**
  String get collapseHint;

  /// No description provided for @segmentZoomHint.
  ///
  /// In es, this message translates to:
  /// **'Zoom de segmento — métricas y gráficas solo de este tramo.'**
  String get segmentZoomHint;

  /// No description provided for @sectionSegment.
  ///
  /// In es, this message translates to:
  /// **'Zoom de segmento'**
  String get sectionSegment;

  /// No description provided for @sectionSegmentSub.
  ///
  /// In es, this message translates to:
  /// **'Elige un tramo de carretera'**
  String get sectionSegmentSub;

  /// No description provided for @sectionOverview.
  ///
  /// In es, this message translates to:
  /// **'Resumen'**
  String get sectionOverview;

  /// No description provided for @sectionOverviewSub.
  ///
  /// In es, this message translates to:
  /// **'Puntuación + métricas'**
  String get sectionOverviewSub;

  /// No description provided for @sectionOverviewSubZoom.
  ///
  /// In es, this message translates to:
  /// **'Puntuación + métricas de este segmento'**
  String get sectionOverviewSubZoom;

  /// No description provided for @sectionLean.
  ///
  /// In es, this message translates to:
  /// **'Inclinación'**
  String get sectionLean;

  /// No description provided for @sectionLeanSub.
  ///
  /// In es, this message translates to:
  /// **'Cian izquierda · ámbar derecha'**
  String get sectionLeanSub;

  /// No description provided for @sectionMap.
  ///
  /// In es, this message translates to:
  /// **'Mapa + línea'**
  String get sectionMap;

  /// No description provided for @sectionMapSub.
  ///
  /// In es, this message translates to:
  /// **'Colores de velocidad · frenos'**
  String get sectionMapSub;

  /// No description provided for @sectionRoad.
  ///
  /// In es, this message translates to:
  /// **'Curvas'**
  String get sectionRoad;

  /// No description provided for @sectionRoadSub.
  ///
  /// In es, this message translates to:
  /// **'Por rumbo e inclinación'**
  String get sectionRoadSub;

  /// No description provided for @sectionLoop.
  ///
  /// In es, this message translates to:
  /// **'Vueltas'**
  String get sectionLoop;

  /// No description provided for @sectionLoopSub.
  ///
  /// In es, this message translates to:
  /// **'Detecta o marca A/B en este ride'**
  String get sectionLoopSub;

  /// No description provided for @sectionBrakes.
  ///
  /// In es, this message translates to:
  /// **'Frenado'**
  String get sectionBrakes;

  /// No description provided for @sectionBrakesSub.
  ///
  /// In es, this message translates to:
  /// **'Inferido por caída de velocidad'**
  String get sectionBrakesSub;

  /// No description provided for @sectionCharts.
  ///
  /// In es, this message translates to:
  /// **'Gráficas'**
  String get sectionCharts;

  /// No description provided for @sectionChartsSub.
  ///
  /// In es, this message translates to:
  /// **'Velocidad · lean · GPS'**
  String get sectionChartsSub;

  /// No description provided for @sectionNotes.
  ///
  /// In es, this message translates to:
  /// **'Precisión + notas'**
  String get sectionNotes;

  /// No description provided for @sectionNotesSub.
  ///
  /// In es, this message translates to:
  /// **'Calidad GPS y notas'**
  String get sectionNotesSub;

  /// No description provided for @segment.
  ///
  /// In es, this message translates to:
  /// **'SEGMENTO'**
  String get segment;

  /// No description provided for @segmentZoom.
  ///
  /// In es, this message translates to:
  /// **'ZOOM DE SEGMENTO'**
  String get segmentZoom;

  /// No description provided for @segmentHint.
  ///
  /// In es, this message translates to:
  /// **'Arrastra los controles, luego haz zoom para métricas del tramo.'**
  String get segmentHint;

  /// No description provided for @segmentHintZoomed.
  ///
  /// In es, this message translates to:
  /// **'Mapa y métricas muestran solo este tramo. Ajusta con los controles.'**
  String get segmentHintZoomed;

  /// No description provided for @zoomToSegment.
  ///
  /// In es, this message translates to:
  /// **'Zoom al segmento'**
  String get zoomToSegment;

  /// No description provided for @fullRide.
  ///
  /// In es, this message translates to:
  /// **'Ruta completa'**
  String get fullRide;

  /// No description provided for @playhead.
  ///
  /// In es, this message translates to:
  /// **'CURSOR'**
  String get playhead;

  /// No description provided for @distance.
  ///
  /// In es, this message translates to:
  /// **'Distancia'**
  String get distance;

  /// No description provided for @time.
  ///
  /// In es, this message translates to:
  /// **'Tiempo'**
  String get time;

  /// No description provided for @speed.
  ///
  /// In es, this message translates to:
  /// **'Velocidad'**
  String get speed;

  /// No description provided for @bikeLean.
  ///
  /// In es, this message translates to:
  /// **'Inclinación'**
  String get bikeLean;

  /// No description provided for @calibrating.
  ///
  /// In es, this message translates to:
  /// **'Calibrando…'**
  String get calibrating;

  /// No description provided for @points.
  ///
  /// In es, this message translates to:
  /// **'Puntos'**
  String get points;

  /// No description provided for @maxLR.
  ///
  /// In es, this message translates to:
  /// **'Máx I / D'**
  String get maxLR;

  /// No description provided for @maxSpeed.
  ///
  /// In es, this message translates to:
  /// **'Vel. máx'**
  String get maxSpeed;

  /// No description provided for @duration.
  ///
  /// In es, this message translates to:
  /// **'Duración'**
  String get duration;

  /// No description provided for @speedProfile.
  ///
  /// In es, this message translates to:
  /// **'Perfil de velocidad'**
  String get speedProfile;

  /// No description provided for @leanProfile.
  ///
  /// In es, this message translates to:
  /// **'Inclinación izq / der'**
  String get leanProfile;

  /// No description provided for @gpsPrecision.
  ///
  /// In es, this message translates to:
  /// **'Precisión GPS'**
  String get gpsPrecision;

  /// No description provided for @gpsPrecisionSub.
  ///
  /// In es, this message translates to:
  /// **'Precisión horizontal en metros (menor es mejor)'**
  String get gpsPrecisionSub;

  /// No description provided for @chartSpeedSub.
  ///
  /// In es, this message translates to:
  /// **'Colores de alto contraste. Toca para scrub.'**
  String get chartSpeedSub;

  /// No description provided for @chartSpeedSubZoom.
  ///
  /// In es, this message translates to:
  /// **'Solo velocidad del segmento. Toca para scrub.'**
  String get chartSpeedSubZoom;

  /// No description provided for @leanHelp.
  ///
  /// In es, this message translates to:
  /// **'0° es vertical inferida. Para inclinación precisa, monta el teléfono firme en vertical (pantalla hacia ti) en el tanque o manillar — evita bolsillo suelto o apaisado.'**
  String get leanHelp;

  /// No description provided for @leanPhoneDisclaimer.
  ///
  /// In es, this message translates to:
  /// **'La posición del celular importa: vertical, pantalla hacia ti, montaje fijo. Un bolsillo suelto sesga la inclinación.'**
  String get leanPhoneDisclaimer;

  /// No description provided for @mapHint.
  ///
  /// In es, this message translates to:
  /// **'Toca la línea para mover la moto. Azul→magenta por velocidad. Puntos = frenos.'**
  String get mapHint;

  /// No description provided for @mapHintZoom.
  ///
  /// In es, this message translates to:
  /// **'Toca la línea para mover la moto. Brillante = elegido · tenue = resto.'**
  String get mapHintZoom;

  /// No description provided for @startingRide.
  ///
  /// In es, this message translates to:
  /// **'Iniciando ruta'**
  String get startingRide;

  /// No description provided for @gpsReady.
  ///
  /// In es, this message translates to:
  /// **'GPS listo'**
  String get gpsReady;

  /// No description provided for @gpsWarmHelp.
  ///
  /// In es, this message translates to:
  /// **'Quédate al aire libre con cielo abierto. La grabación empieza cuando el GPS esté lo bastante estable (objetivo ±{meters} m).'**
  String gpsWarmHelp(String meters);

  /// No description provided for @horizontalAccuracy.
  ///
  /// In es, this message translates to:
  /// **'PRECISIÓN HORIZONTAL'**
  String get horizontalAccuracy;

  /// No description provided for @lowerBetter.
  ///
  /// In es, this message translates to:
  /// **'Menor es mejor · listo a ±{meters} m'**
  String lowerBetter(String meters);

  /// No description provided for @couldNotStart.
  ///
  /// In es, this message translates to:
  /// **'No se pudo iniciar la ruta'**
  String get couldNotStart;

  /// No description provided for @tryAgain.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get tryAgain;

  /// No description provided for @back.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get back;

  /// No description provided for @activeMountHelp.
  ///
  /// In es, this message translates to:
  /// **'El 0° se congeló antes de salir. La pantalla puede bloquearse — deja la notificación de grabación activa.'**
  String get activeMountHelp;

  /// No description provided for @curvaTitle.
  ///
  /// In es, this message translates to:
  /// **'Curva #{number}'**
  String curvaTitle(int number);

  /// No description provided for @curveLine.
  ///
  /// In es, this message translates to:
  /// **'Línea de la curva'**
  String get curveLine;

  /// No description provided for @entry.
  ///
  /// In es, this message translates to:
  /// **'Entrada'**
  String get entry;

  /// No description provided for @apex.
  ///
  /// In es, this message translates to:
  /// **'Ápice'**
  String get apex;

  /// No description provided for @exit.
  ///
  /// In es, this message translates to:
  /// **'Salida'**
  String get exit;

  /// No description provided for @brakeToApex.
  ///
  /// In es, this message translates to:
  /// **'Freno a ápice'**
  String get brakeToApex;

  /// No description provided for @accelFromApex.
  ///
  /// In es, this message translates to:
  /// **'Acelera desde ápice'**
  String get accelFromApex;

  /// No description provided for @leanAtApex.
  ///
  /// In es, this message translates to:
  /// **'Lean en ápice'**
  String get leanAtApex;

  /// No description provided for @maxLean.
  ///
  /// In es, this message translates to:
  /// **'Incl. máx'**
  String get maxLean;

  /// No description provided for @leftShort.
  ///
  /// In es, this message translates to:
  /// **'Izq'**
  String get leftShort;

  /// No description provided for @rightShort.
  ///
  /// In es, this message translates to:
  /// **'Der'**
  String get rightShort;

  /// No description provided for @curvaMapLegend.
  ///
  /// In es, this message translates to:
  /// **'E = entrada · A = ápice · S = salida. Línea por velocidad.'**
  String get curvaMapLegend;

  /// No description provided for @curvaCoach.
  ///
  /// In es, this message translates to:
  /// **'Lectura rápida: mira si entras demasiado rápido (mucho freno a A), si el ápice es estable, y si sales acelerando limpio.'**
  String get curvaCoach;

  /// No description provided for @roadStretchesHelp.
  ///
  /// In es, this message translates to:
  /// **'Según rumbo + inclinación. {curvas} curvas. Toca una curva para entrada / ápice / salida — desliza entre curvas.'**
  String roadStretchesHelp(int curvas);

  /// No description provided for @roadStretchesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay suficiente cambio de rumbo GPS para detectar curvas.'**
  String get roadStretchesEmpty;

  /// No description provided for @openDetail.
  ///
  /// In es, this message translates to:
  /// **'abrir detalle'**
  String get openDetail;

  /// No description provided for @brakesHelp.
  ///
  /// In es, this message translates to:
  /// **'Inferido por qué tan rápido cae la velocidad — no es sensor de freno. Toca un golpe para saltar el playhead. El botón de mapa hace zoom a ese freno.'**
  String get brakesHelp;

  /// No description provided for @brakesEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay frenadas claras por GPS. Las paradas fuertes suelen verse como golpes amarillo/naranja/rojo.'**
  String get brakesEmpty;

  /// No description provided for @brakeLight.
  ///
  /// In es, this message translates to:
  /// **'Suave'**
  String get brakeLight;

  /// No description provided for @brakeMedium.
  ///
  /// In es, this message translates to:
  /// **'Medio'**
  String get brakeMedium;

  /// No description provided for @brakeHard.
  ///
  /// In es, this message translates to:
  /// **'Fuerte'**
  String get brakeHard;

  /// No description provided for @brakeAtTime.
  ///
  /// In es, this message translates to:
  /// **'En {time}'**
  String brakeAtTime(String time);

  /// No description provided for @brakeZoomMap.
  ///
  /// In es, this message translates to:
  /// **'Zoom del mapa al freno'**
  String get brakeZoomMap;

  /// No description provided for @noGpsPoints.
  ///
  /// In es, this message translates to:
  /// **'Sin puntos GPS'**
  String get noGpsPoints;

  /// No description provided for @kmh.
  ///
  /// In es, this message translates to:
  /// **'km/h'**
  String get kmh;

  /// No description provided for @recta.
  ///
  /// In es, this message translates to:
  /// **'Recta'**
  String get recta;

  /// No description provided for @curva.
  ///
  /// In es, this message translates to:
  /// **'Curva'**
  String get curva;

  /// No description provided for @curvaIzquierda.
  ///
  /// In es, this message translates to:
  /// **'Curva izquierda'**
  String get curvaIzquierda;

  /// No description provided for @curvaDerecha.
  ///
  /// In es, this message translates to:
  /// **'Curva derecha'**
  String get curvaDerecha;

  /// No description provided for @fullscreenMap.
  ///
  /// In es, this message translates to:
  /// **'Mapa completo'**
  String get fullscreenMap;

  /// No description provided for @fullscreenMapHelp.
  ///
  /// In es, this message translates to:
  /// **'Desplaza y haz zoom libremente. Marca un área o usa el mapa visible, luego carga métricas de ese tramo.'**
  String get fullscreenMapHelp;

  /// No description provided for @selectArea.
  ///
  /// In es, this message translates to:
  /// **'Marcar área'**
  String get selectArea;

  /// No description provided for @selectAreaHint.
  ///
  /// In es, this message translates to:
  /// **'Arrastra un recuadro sobre el tramo'**
  String get selectAreaHint;

  /// No description provided for @selectAreaBody.
  ///
  /// In es, this message translates to:
  /// **'Arrastra en el mapa para marcar un área. El pellizco sigue haciendo zoom.'**
  String get selectAreaBody;

  /// No description provided for @useVisibleArea.
  ///
  /// In es, this message translates to:
  /// **'Usar mapa visible'**
  String get useVisibleArea;

  /// No description provided for @clearArea.
  ///
  /// In es, this message translates to:
  /// **'Limpiar'**
  String get clearArea;

  /// No description provided for @loadAreaMetrics.
  ///
  /// In es, this message translates to:
  /// **'Cargar métricas del área'**
  String get loadAreaMetrics;

  /// No description provided for @areaReady.
  ///
  /// In es, this message translates to:
  /// **'Área lista · {points} puntos GPS. Carga métricas para enfocar el Ride Lab en este tramo.'**
  String areaReady(int points);

  /// No description provided for @zoomIn.
  ///
  /// In es, this message translates to:
  /// **'Acercar'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In es, this message translates to:
  /// **'Alejar'**
  String get zoomOut;

  /// No description provided for @fitRide.
  ///
  /// In es, this message translates to:
  /// **'Ajustar ruta'**
  String get fitRide;

  /// No description provided for @myLocation.
  ///
  /// In es, this message translates to:
  /// **'Mi ubicación'**
  String get myLocation;

  /// No description provided for @openFullscreenMap.
  ///
  /// In es, this message translates to:
  /// **'Abrir mapa completo'**
  String get openFullscreenMap;

  /// No description provided for @mapLayerSpeed.
  ///
  /// In es, this message translates to:
  /// **'Velocidad'**
  String get mapLayerSpeed;

  /// No description provided for @mapLayerRoadKind.
  ///
  /// In es, this message translates to:
  /// **'Curvas'**
  String get mapLayerRoadKind;

  /// No description provided for @mapLayerBrakes.
  ///
  /// In es, this message translates to:
  /// **'Frenos'**
  String get mapLayerBrakes;

  /// No description provided for @mapLayerStartEnd.
  ///
  /// In es, this message translates to:
  /// **'Inicio/fin'**
  String get mapLayerStartEnd;

  /// No description provided for @mapLayerPlayhead.
  ///
  /// In es, this message translates to:
  /// **'Cursor'**
  String get mapLayerPlayhead;

  /// No description provided for @mapLayerLegend.
  ///
  /// In es, this message translates to:
  /// **'Leyenda'**
  String get mapLayerLegend;

  /// No description provided for @friends.
  ///
  /// In es, this message translates to:
  /// **'Amigos'**
  String get friends;

  /// No description provided for @friendsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Beta cerrada — todo quien tenga la app aparece en tu lista.'**
  String get friendsSubtitle;

  /// No description provided for @friendsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay otros riders. Cuando un amigo instale RiderLab, aparecerá aquí.'**
  String get friendsEmpty;

  /// No description provided for @yourName.
  ///
  /// In es, this message translates to:
  /// **'Tu nombre visible'**
  String get yourName;

  /// No description provided for @saveName.
  ///
  /// In es, this message translates to:
  /// **'Guardar nombre'**
  String get saveName;

  /// No description provided for @nameHint.
  ///
  /// In es, this message translates to:
  /// **'Apodo para amigos'**
  String get nameHint;

  /// No description provided for @nameSaved.
  ///
  /// In es, this message translates to:
  /// **'Nombre guardado'**
  String get nameSaved;

  /// No description provided for @compare.
  ///
  /// In es, this message translates to:
  /// **'Comparar'**
  String get compare;

  /// No description provided for @compareTitle.
  ///
  /// In es, this message translates to:
  /// **'Comparar rutas'**
  String get compareTitle;

  /// No description provided for @comparePickPeer.
  ///
  /// In es, this message translates to:
  /// **'Rutas de amigos en la misma zona'**
  String get comparePickPeer;

  /// No description provided for @compareEmpty.
  ///
  /// In es, this message translates to:
  /// **'Ninguna ruta de amigos cubre esta zona todavía.'**
  String get compareEmpty;

  /// No description provided for @compareYou.
  ///
  /// In es, this message translates to:
  /// **'Tú'**
  String get compareYou;

  /// No description provided for @compareLocalTitle.
  ///
  /// In es, this message translates to:
  /// **'Comparar vueltas'**
  String get compareLocalTitle;

  /// No description provided for @compareRouteTitle.
  ///
  /// In es, this message translates to:
  /// **'Comparar · {name}'**
  String compareRouteTitle(String name);

  /// No description provided for @compareLocalHelp.
  ///
  /// In es, this message translates to:
  /// **'Elige una vuelta base y otra para comparar métricas y líneas en el mismo circuito.'**
  String get compareLocalHelp;

  /// No description provided for @compareLocalEmpty.
  ///
  /// In es, this message translates to:
  /// **'Necesitas al menos 2 vueltas completadas en esta ruta. Usa modo Loop o etiqueta rides con la misma ruta.'**
  String get compareLocalEmpty;

  /// No description provided for @compareBaseline.
  ///
  /// In es, this message translates to:
  /// **'Base'**
  String get compareBaseline;

  /// No description provided for @compareChallenger.
  ///
  /// In es, this message translates to:
  /// **'Retador'**
  String get compareChallenger;

  /// No description provided for @compareLocal.
  ///
  /// In es, this message translates to:
  /// **'Comparar vueltas ({count})'**
  String compareLocal(int count);

  /// No description provided for @compareDeltaFaster.
  ///
  /// In es, this message translates to:
  /// **'Retador más rápido por {delta}'**
  String compareDeltaFaster(String delta);

  /// No description provided for @compareDeltaSlower.
  ///
  /// In es, this message translates to:
  /// **'Retador más lento por {delta}'**
  String compareDeltaSlower(String delta);

  /// No description provided for @compareDeltaTie.
  ///
  /// In es, this message translates to:
  /// **'Mismo tiempo'**
  String get compareDeltaTie;

  /// No description provided for @compareLaps.
  ///
  /// In es, this message translates to:
  /// **'Comparar vueltas'**
  String get compareLaps;

  /// No description provided for @compareNeedTwoLaps.
  ///
  /// In es, this message translates to:
  /// **'Marca al menos 2 vueltas en esta ruta para comparar.'**
  String get compareNeedTwoLaps;

  /// No description provided for @lineScore.
  ///
  /// In es, this message translates to:
  /// **'Puntuación de línea'**
  String get lineScore;

  /// No description provided for @avgSpeed.
  ///
  /// In es, this message translates to:
  /// **'Vel. media'**
  String get avgSpeed;

  /// No description provided for @friendRides.
  ///
  /// In es, this message translates to:
  /// **'Rutas compartidas'**
  String get friendRides;

  /// No description provided for @friendRidesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Este rider aún no tiene rutas compartidas.'**
  String get friendRidesEmpty;

  /// No description provided for @syncingRide.
  ///
  /// In es, this message translates to:
  /// **'Compartiendo ruta con amigos…'**
  String get syncingRide;

  /// No description provided for @cloudUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Nube no disponible — revisa conexión y auth anónima.'**
  String get cloudUnavailable;

  /// No description provided for @cloudAnonymousOff.
  ///
  /// In es, this message translates to:
  /// **'Amigos necesita Anonymous activado en la nube de RiderLab (proyecto Supabase CornerIQ):\nDashboard → Authentication → Providers → Anonymous → Enable.\nLuego vuelve a abrir Amigos y desliza para refrescar.'**
  String get cloudAnonymousOff;

  /// No description provided for @routesTitle.
  ///
  /// In es, this message translates to:
  /// **'Rutas'**
  String get routesTitle;

  /// No description provided for @routesHelp.
  ///
  /// In es, this message translates to:
  /// **'Nombra un circuito, compártelo y etiqueta rides para que amigos comparen en la misma ruta.'**
  String get routesHelp;

  /// No description provided for @routesHowTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo se usan las Rutas?'**
  String get routesHowTitle;

  /// No description provided for @routesHowBody.
  ///
  /// In es, this message translates to:
  /// **'1) Crea una ruta con + (ej. «Glorieta norte»).\n2) Abre la ruta → pestaña Loop: detecta vueltas cerradas en rides etiquetados, o marca A/B tú mismo.\n3) Inicia un ride en loop desde un loop guardado — cada vuelta se etiqueta a esta ruta.\n4) O en Ride Lab → Comparte, etiqueta cualquier ride con esta ruta.\n5) Activa «compartida» si quieres que amigos comparen el mismo circuito.'**
  String get routesHowBody;

  /// No description provided for @routesTapHint.
  ///
  /// In es, this message translates to:
  /// **'Toca para vueltas + módulo Loop'**
  String get routesTapHint;

  /// No description provided for @routesLoopReady.
  ///
  /// In es, this message translates to:
  /// **'Loop listo'**
  String get routesLoopReady;

  /// No description provided for @setYourAlias.
  ///
  /// In es, this message translates to:
  /// **'Pon tu alias'**
  String get setYourAlias;

  /// No description provided for @sectionNotesProOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo Pro — precisión GPS y notas'**
  String get sectionNotesProOnly;

  /// No description provided for @proCurvaBannerTitle.
  ///
  /// In es, this message translates to:
  /// **'Detalle de curva · Pro'**
  String get proCurvaBannerTitle;

  /// No description provided for @proCurvaBannerBody.
  ///
  /// In es, this message translates to:
  /// **'Vista previa de 0,5 s. Con Pro ves entrada, ápice, salida y mapa sin bloqueo.'**
  String get proCurvaBannerBody;

  /// No description provided for @proNotesBannerTitle.
  ///
  /// In es, this message translates to:
  /// **'Precisión + notas · Pro'**
  String get proNotesBannerTitle;

  /// No description provided for @proNotesBannerBody.
  ///
  /// In es, this message translates to:
  /// **'Calidad GPS y tips del coach están en CornerIQ Pro.'**
  String get proNotesBannerBody;

  /// No description provided for @proFeatureCurva.
  ///
  /// In es, this message translates to:
  /// **'Detalle completo de curvas (sin banner)'**
  String get proFeatureCurva;

  /// No description provided for @proFeatureNotes.
  ///
  /// In es, this message translates to:
  /// **'Precisión GPS + notas de coach'**
  String get proFeatureNotes;

  /// No description provided for @myRoutes.
  ///
  /// In es, this message translates to:
  /// **'Tus rutas'**
  String get myRoutes;

  /// No description provided for @routesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay rutas — crea una para etiquetar y compartir rides.'**
  String get routesEmpty;

  /// No description provided for @friendRoutes.
  ///
  /// In es, this message translates to:
  /// **'Rutas compartidas de amigos'**
  String get friendRoutes;

  /// No description provided for @friendRoutesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Ningún amigo ha compartido una ruta todavía.'**
  String get friendRoutesEmpty;

  /// No description provided for @createRoute.
  ///
  /// In es, this message translates to:
  /// **'Nueva ruta'**
  String get createRoute;

  /// No description provided for @routeNameHint.
  ///
  /// In es, this message translates to:
  /// **'Nombre (ej. Glorieta norte)'**
  String get routeNameHint;

  /// No description provided for @routeDescHint.
  ///
  /// In es, this message translates to:
  /// **'Notas opcionales'**
  String get routeDescHint;

  /// No description provided for @shareRoute.
  ///
  /// In es, this message translates to:
  /// **'Compartir ruta'**
  String get shareRoute;

  /// No description provided for @shareRouteHelp.
  ///
  /// In es, this message translates to:
  /// **'Los amigos ven este circuito y pueden comparar rides etiquetados.'**
  String get shareRouteHelp;

  /// No description provided for @routeCreated.
  ///
  /// In es, this message translates to:
  /// **'Ruta creada'**
  String get routeCreated;

  /// No description provided for @sharedRoute.
  ///
  /// In es, this message translates to:
  /// **'Compartida'**
  String get sharedRoute;

  /// No description provided for @privateRoute.
  ///
  /// In es, this message translates to:
  /// **'Privada'**
  String get privateRoute;

  /// No description provided for @shareRideTitle.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get shareRideTitle;

  /// No description provided for @shareRideHelp.
  ///
  /// In es, this message translates to:
  /// **'Comparte este recorrido con amigos y opcionalmente asígnalo a un circuito.'**
  String get shareRideHelp;

  /// No description provided for @shareThisRide.
  ///
  /// In es, this message translates to:
  /// **'Compartir este ride'**
  String get shareThisRide;

  /// No description provided for @assignRoute.
  ///
  /// In es, this message translates to:
  /// **'Asignar a ruta'**
  String get assignRoute;

  /// No description provided for @noRouteAssigned.
  ///
  /// In es, this message translates to:
  /// **'Sin ruta'**
  String get noRouteAssigned;

  /// No description provided for @areaNoPoints.
  ///
  /// In es, this message translates to:
  /// **'No hay tramo GPS en esa área — acerca el zoom o dibuja un recuadro más grande.'**
  String get areaNoPoints;

  /// No description provided for @curvaSwipeHint.
  ///
  /// In es, this message translates to:
  /// **'Desliza izquierda / derecha para cambiar de curva.'**
  String get curvaSwipeHint;

  /// No description provided for @curvaOpenMap.
  ///
  /// In es, this message translates to:
  /// **'Mapa completo'**
  String get curvaOpenMap;

  /// No description provided for @curvaZoomLab.
  ///
  /// In es, this message translates to:
  /// **'Zoom Lab'**
  String get curvaZoomLab;

  /// No description provided for @armAutoRide.
  ///
  /// In es, this message translates to:
  /// **'Armar auto-ride'**
  String get armAutoRide;

  /// No description provided for @disarmAutoRide.
  ///
  /// In es, this message translates to:
  /// **'Desarmar auto-ride'**
  String get disarmAutoRide;

  /// No description provided for @waitingForMotion.
  ///
  /// In es, this message translates to:
  /// **'Esperando movimiento…'**
  String get waitingForMotion;

  /// No description provided for @armedBannerBody.
  ///
  /// In es, this message translates to:
  /// **'RiderLab iniciará la grabación sola en cuanto detecte que empiezas a rodar.'**
  String get armedBannerBody;

  /// No description provided for @loopMode.
  ///
  /// In es, this message translates to:
  /// **'Modo Loop'**
  String get loopMode;

  /// No description provided for @pausedLabel.
  ///
  /// In es, this message translates to:
  /// **'PAUSADO'**
  String get pausedLabel;

  /// No description provided for @suggestEndTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Sigues rodando?'**
  String get suggestEndTitle;

  /// No description provided for @suggestEndBody.
  ///
  /// In es, this message translates to:
  /// **'Sin movimiento hace rato. Termina la ruta o sigue rodando.'**
  String get suggestEndBody;

  /// No description provided for @keepRiding.
  ///
  /// In es, this message translates to:
  /// **'Seguir rodando'**
  String get keepRiding;

  /// No description provided for @markLoopInit.
  ///
  /// In es, this message translates to:
  /// **'Marcar inicio de loop'**
  String get markLoopInit;

  /// No description provided for @loopInitSet.
  ///
  /// In es, this message translates to:
  /// **'Inicio marcado'**
  String get loopInitSet;

  /// No description provided for @markLoopEnd.
  ///
  /// In es, this message translates to:
  /// **'Marcar fin de loop'**
  String get markLoopEnd;

  /// No description provided for @markLoopInitHere.
  ///
  /// In es, this message translates to:
  /// **'Marcar A en mi GPS'**
  String get markLoopInitHere;

  /// No description provided for @markLoopEndHere.
  ///
  /// In es, this message translates to:
  /// **'Marcar B en mi GPS'**
  String get markLoopEndHere;

  /// No description provided for @loopOpenMarkMap.
  ///
  /// In es, this message translates to:
  /// **'Mapa: marcar A y B'**
  String get loopOpenMarkMap;

  /// No description provided for @loopMarkMapHint.
  ///
  /// In es, this message translates to:
  /// **'Abre el mapa a pantalla completa, desplázate y toca el punto A (inicio) y el B (fin) de la ruta.'**
  String get loopMarkMapHint;

  /// No description provided for @loopTapPointA.
  ///
  /// In es, this message translates to:
  /// **'Toca el mapa para marcar el punto A (inicio)'**
  String get loopTapPointA;

  /// No description provided for @loopTapPointB.
  ///
  /// In es, this message translates to:
  /// **'Toca el mapa para marcar el punto B (fin)'**
  String get loopTapPointB;

  /// No description provided for @loopPointsReady.
  ///
  /// In es, this message translates to:
  /// **'A y B listos — confirma para armar auto-vuelta'**
  String get loopPointsReady;

  /// No description provided for @loopMarkMapHelp.
  ///
  /// In es, this message translates to:
  /// **'Pan y zoom libres. Primer toque = A, segundo = B. El círculo es la zona de detección de vueltas.'**
  String get loopMarkMapHelp;

  /// No description provided for @loopRemapA.
  ///
  /// In es, this message translates to:
  /// **'Rehacer A'**
  String get loopRemapA;

  /// No description provided for @loopConfirmAb.
  ///
  /// In es, this message translates to:
  /// **'Confirmar A y B'**
  String get loopConfirmAb;

  /// No description provided for @loopArmed.
  ///
  /// In es, this message translates to:
  /// **'Auto-vuelta activada'**
  String get loopArmed;

  /// No description provided for @lapCountLabel.
  ///
  /// In es, this message translates to:
  /// **'Vuelta {count}'**
  String lapCountLabel(int count);

  /// No description provided for @endSession.
  ///
  /// In es, this message translates to:
  /// **'Terminar sesión'**
  String get endSession;

  /// No description provided for @byRawThrottle.
  ///
  /// In es, this message translates to:
  /// **'by RawThrottle'**
  String get byRawThrottle;

  /// No description provided for @pro.
  ///
  /// In es, this message translates to:
  /// **'PRO'**
  String get pro;

  /// No description provided for @free.
  ///
  /// In es, this message translates to:
  /// **'Gratis'**
  String get free;

  /// No description provided for @settings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settings;

  /// No description provided for @proUnlock.
  ///
  /// In es, this message translates to:
  /// **'RiderLab Pro'**
  String get proUnlock;

  /// No description provided for @proUnlockBody.
  ///
  /// In es, this message translates to:
  /// **'Segmenta cualquier tramo, detalle completo de curvas, precisión + notas, frenadas completas y sin anuncios.'**
  String get proUnlockBody;

  /// No description provided for @proFeatureSegment.
  ///
  /// In es, this message translates to:
  /// **'Zoom de segmento — elige cualquier tramo del ride'**
  String get proFeatureSegment;

  /// No description provided for @proFeatureBrakes.
  ///
  /// In es, this message translates to:
  /// **'Detalle completo de frenadas (no solo una vista previa)'**
  String get proFeatureBrakes;

  /// No description provided for @proFeatureNoAds.
  ///
  /// In es, this message translates to:
  /// **'Sin banners publicitarios'**
  String get proFeatureNoAds;

  /// No description provided for @upgradeToPro.
  ///
  /// In es, this message translates to:
  /// **'Pasar a Pro'**
  String get upgradeToPro;

  /// No description provided for @proUnlocked.
  ///
  /// In es, this message translates to:
  /// **'Pro activo'**
  String get proUnlocked;

  /// No description provided for @proToggleDev.
  ///
  /// In es, this message translates to:
  /// **'Pro desbloqueado'**
  String get proToggleDev;

  /// No description provided for @proToggleHelp.
  ///
  /// In es, this message translates to:
  /// **'Desbloqueo temporal hasta conectar la tienda. Apágalo para ver la versión Gratis.'**
  String get proToggleHelp;

  /// No description provided for @brakesProTeaser.
  ///
  /// In es, this message translates to:
  /// **'Mostrando {shown} de {total}. Desbloquea Pro para el historial completo de frenadas.'**
  String brakesProTeaser(int shown, int total);

  /// No description provided for @segmentProLocked.
  ///
  /// In es, this message translates to:
  /// **'Elegir un tramo del ride es una función Pro.'**
  String get segmentProLocked;

  /// No description provided for @adPlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Anuncio'**
  String get adPlaceholder;

  /// No description provided for @removeAdsWithPro.
  ///
  /// In es, this message translates to:
  /// **'Pasa a Pro para quitar anuncios'**
  String get removeAdsWithPro;

  /// No description provided for @routeTabLaps.
  ///
  /// In es, this message translates to:
  /// **'Vueltas'**
  String get routeTabLaps;

  /// No description provided for @routeTabLoop.
  ///
  /// In es, this message translates to:
  /// **'Loop'**
  String get routeTabLoop;

  /// No description provided for @routeLoopModuleHelp.
  ///
  /// In es, this message translates to:
  /// **'Los loops pertenecen a esta ruta. Detecta vueltas cerradas en rides etiquetados, o marca tú el inicio (A) y el fin (B) en el mapa.'**
  String get routeLoopModuleHelp;

  /// No description provided for @routeLoopDefine.
  ///
  /// In es, this message translates to:
  /// **'Marcar A / B'**
  String get routeLoopDefine;

  /// No description provided for @routeLoopDetect.
  ///
  /// In es, this message translates to:
  /// **'Detectar'**
  String get routeLoopDetect;

  /// No description provided for @routeLoopSavedTitle.
  ///
  /// In es, this message translates to:
  /// **'Loops guardados'**
  String get routeLoopSavedTitle;

  /// No description provided for @routeLoopEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay loops — detecta desde rides o marca A y B en el mapa.'**
  String get routeLoopEmpty;

  /// No description provided for @routeLoopDetectedTitle.
  ///
  /// In es, this message translates to:
  /// **'Candidatos detectados'**
  String get routeLoopDetectedTitle;

  /// No description provided for @routeLoopDetectedEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay vueltas cerradas en los rides etiquetados. Rueda el circuito e intenta de nuevo.'**
  String get routeLoopDetectedEmpty;

  /// No description provided for @routeLoopDetectedHint.
  ///
  /// In es, this message translates to:
  /// **'Trayecto cerrado inferido por GPS — guárdalo para auto-vuelta.'**
  String get routeLoopDetectedHint;

  /// No description provided for @routeLoopSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get routeLoopSave;

  /// No description provided for @routeLoopSaved.
  ///
  /// In es, this message translates to:
  /// **'Loop guardado en esta ruta'**
  String get routeLoopSaved;

  /// No description provided for @routeLoopManualName.
  ///
  /// In es, this message translates to:
  /// **'Loop manual'**
  String get routeLoopManualName;

  /// No description provided for @routeLoopPrimary.
  ///
  /// In es, this message translates to:
  /// **'PRINCIPAL'**
  String get routeLoopPrimary;

  /// No description provided for @routeLoopSetPrimary.
  ///
  /// In es, this message translates to:
  /// **'Usar como principal'**
  String get routeLoopSetPrimary;

  /// No description provided for @routeLoopStartRide.
  ///
  /// In es, this message translates to:
  /// **'Iniciar ride en loop'**
  String get routeLoopStartRide;

  /// No description provided for @routeLoopSourceManual.
  ///
  /// In es, this message translates to:
  /// **'A mano'**
  String get routeLoopSourceManual;

  /// No description provided for @routeLoopSourceDetected.
  ///
  /// In es, this message translates to:
  /// **'Detectado'**
  String get routeLoopSourceDetected;

  /// No description provided for @deleteRoute.
  ///
  /// In es, this message translates to:
  /// **'Eliminar ruta'**
  String get deleteRoute;

  /// No description provided for @deleteRouteBody.
  ///
  /// In es, this message translates to:
  /// **'Se borrará esta ruta, sus loops y se desvincularán los rides. Si está compartida, desaparece para todos.'**
  String get deleteRouteBody;

  /// No description provided for @routeDeleted.
  ///
  /// In es, this message translates to:
  /// **'Ruta eliminada'**
  String get routeDeleted;

  /// No description provided for @deleteLoop.
  ///
  /// In es, this message translates to:
  /// **'Eliminar loop'**
  String get deleteLoop;

  /// No description provided for @deleteLoopBody.
  ///
  /// In es, this message translates to:
  /// **'Se elimina este loop. Si era el principal, se quitan también los puntos A/B de la ruta (incl. amigos al sincronizar).'**
  String get deleteLoopBody;

  /// No description provided for @loopDeleted.
  ///
  /// In es, this message translates to:
  /// **'Loop eliminado'**
  String get loopDeleted;

  /// No description provided for @deleteAllLoops.
  ///
  /// In es, this message translates to:
  /// **'Quitar todos los loops'**
  String get deleteAllLoops;

  /// No description provided for @deleteAllLoopsBody.
  ///
  /// In es, this message translates to:
  /// **'Se borran todos los loops de esta ruta y los puntos A/B. Los amigos verán la ruta sin loop al sincronizar.'**
  String get deleteAllLoopsBody;

  /// No description provided for @loopsCleared.
  ///
  /// In es, this message translates to:
  /// **'Loops eliminados'**
  String get loopsCleared;

  /// No description provided for @deleteConfirm.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get deleteConfirm;

  /// No description provided for @deleteRide.
  ///
  /// In es, this message translates to:
  /// **'Eliminar ride'**
  String get deleteRide;

  /// No description provided for @deleteRideBody.
  ///
  /// In es, this message translates to:
  /// **'Se borrará permanentemente el ride y su línea GPS de este teléfono (y de la nube si estaba sincronizado).'**
  String get deleteRideBody;

  /// No description provided for @rideDeleted.
  ///
  /// In es, this message translates to:
  /// **'Ride eliminado'**
  String get rideDeleted;

  /// No description provided for @accountSection.
  ///
  /// In es, this message translates to:
  /// **'Cuenta'**
  String get accountSection;

  /// No description provided for @accountGuest.
  ///
  /// In es, this message translates to:
  /// **'Rider invitado'**
  String get accountGuest;

  /// No description provided for @accountGuestBody.
  ///
  /// In es, this message translates to:
  /// **'Estás en sesión de invitado. Inicia sesión para conservar tu perfil entre dispositivos — tus rides actuales se vinculan cuando es posible.'**
  String get accountGuestBody;

  /// No description provided for @accountSignedIn.
  ///
  /// In es, this message translates to:
  /// **'Sesión iniciada'**
  String get accountSignedIn;

  /// No description provided for @accountSignedInBody.
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta de Google está vinculada. Cerrar sesión vuelve a modo invitado en este teléfono.'**
  String get accountSignedInBody;

  /// No description provided for @signInWith.
  ///
  /// In es, this message translates to:
  /// **'Entrar con {provider}'**
  String signInWith(String provider);

  /// No description provided for @signOut.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get signOut;

  /// No description provided for @accountSignedInSnack.
  ///
  /// In es, this message translates to:
  /// **'Sesión iniciada — perfil sincronizado'**
  String get accountSignedInSnack;

  /// No description provided for @accountSignedOutSnack.
  ///
  /// In es, this message translates to:
  /// **'Sesión cerrada — modo invitado'**
  String get accountSignedOutSnack;

  /// No description provided for @rideLoopHelp.
  ///
  /// In es, this message translates to:
  /// **'Encuentra vueltas cerradas en el GPS de este ride, o marca inicio (A) y fin (B) en el mapa. Al guardar se crea/usa una ruta para auto-vuelta después.'**
  String get rideLoopHelp;

  /// No description provided for @rideLoopEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay loops guardados en la ruta de este ride.'**
  String get rideLoopEmpty;

  /// No description provided for @rideLoopDetectedEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay vuelta cerrada en este ride. Prueba Marcar A / B en el mapa.'**
  String get rideLoopDetectedEmpty;

  /// No description provided for @rideLoopNeedPoints.
  ///
  /// In es, this message translates to:
  /// **'No hay suficientes puntos GPS para marcar un loop.'**
  String get rideLoopNeedPoints;

  /// No description provided for @rideLoopSaveFirst.
  ///
  /// In es, this message translates to:
  /// **'Guarda un loop primero — eso crea la ruta.'**
  String get rideLoopSaveFirst;

  /// No description provided for @rideLoopOpenRoute.
  ///
  /// In es, this message translates to:
  /// **'Abrir ruta (vueltas + loops)'**
  String get rideLoopOpenRoute;

  /// No description provided for @syncCloudRides.
  ///
  /// In es, this message translates to:
  /// **'Sincronizar rides con la nube'**
  String get syncCloudRides;

  /// No description provided for @syncCloudRidesHelp.
  ///
  /// In es, this message translates to:
  /// **'Sube los rides terminados y descarga a este teléfono los rides del Garage y las sesiones de Lean Lab de esta cuenta.'**
  String get syncCloudRidesHelp;

  /// No description provided for @syncCloudRidesDone.
  ///
  /// In es, this message translates to:
  /// **'Subida: {ok} ok, {fail} fallaron'**
  String syncCloudRidesDone(int ok, int fail);

  /// No description provided for @syncCloudRidesPulled.
  ///
  /// In es, this message translates to:
  /// **'Descargados {rides} rides, {lean} Lean Lab'**
  String syncCloudRidesPulled(int rides, int lean);

  /// No description provided for @playStoreUpdatesOnly.
  ///
  /// In es, this message translates to:
  /// **'En esta versión las actualizaciones llegan por Google Play.'**
  String get playStoreUpdatesOnly;

  /// No description provided for @labSection.
  ///
  /// In es, this message translates to:
  /// **'Lab (experimental)'**
  String get labSection;

  /// No description provided for @labAdventureCameraHelp.
  ///
  /// In es, this message translates to:
  /// **'Obturador GoPro opcional sincronizado con rides. Apagado por defecto — no cambia el GPS.'**
  String get labAdventureCameraHelp;

  /// No description provided for @labAdventureCameraEnable.
  ///
  /// In es, this message translates to:
  /// **'Cámara adventure'**
  String get labAdventureCameraEnable;

  /// No description provided for @labAdventureCameraEnableHelp.
  ///
  /// In es, this message translates to:
  /// **'Activa el módulo de cámara lab en este teléfono'**
  String get labAdventureCameraEnableHelp;

  /// No description provided for @labAdventureCameraSyncRide.
  ///
  /// In es, this message translates to:
  /// **'Grabar con el ride'**
  String get labAdventureCameraSyncRide;

  /// No description provided for @labAdventureCameraSyncRideHelp.
  ///
  /// In es, this message translates to:
  /// **'Inicia/detiene con toda la ruta. Si hay zonas de inicio en el mapa, ellas mandan — la cámara espera el punto de inicio.'**
  String get labAdventureCameraSyncRideHelp;

  /// No description provided for @labAdventureCameraSyncPause.
  ///
  /// In es, this message translates to:
  /// **'Seguir pausa auto'**
  String get labAdventureCameraSyncPause;

  /// No description provided for @labAdventureCameraSyncPauseHelp.
  ///
  /// In es, this message translates to:
  /// **'Pausa la cámara mientras la pausa auto de GPS está activa (opcional)'**
  String get labAdventureCameraSyncPauseHelp;

  /// No description provided for @labAdventureCameraBackend.
  ///
  /// In es, this message translates to:
  /// **'Backend'**
  String get labAdventureCameraBackend;

  /// No description provided for @labAdventureCameraBackendGoPro.
  ///
  /// In es, this message translates to:
  /// **'GoPro'**
  String get labAdventureCameraBackendGoPro;

  /// No description provided for @labAdventureCameraBackendSim.
  ///
  /// In es, this message translates to:
  /// **'Simular'**
  String get labAdventureCameraBackendSim;

  /// No description provided for @labAdventureCameraConnect.
  ///
  /// In es, this message translates to:
  /// **'Conectar'**
  String get labAdventureCameraConnect;

  /// No description provided for @labAdventureCameraDisconnect.
  ///
  /// In es, this message translates to:
  /// **'Desconectar'**
  String get labAdventureCameraDisconnect;

  /// No description provided for @labAdventureCameraTestHelp.
  ///
  /// In es, this message translates to:
  /// **'Prueba manual del obturador — sin ride. Conecta primero (o usa Simular).'**
  String get labAdventureCameraTestHelp;

  /// No description provided for @labAdventureCameraTestStart.
  ///
  /// In es, this message translates to:
  /// **'Probar inicio'**
  String get labAdventureCameraTestStart;

  /// No description provided for @labAdventureCameraTestStop.
  ///
  /// In es, this message translates to:
  /// **'Probar parada'**
  String get labAdventureCameraTestStop;

  /// No description provided for @labAdventureCameraTestStartSnack.
  ///
  /// In es, this message translates to:
  /// **'Inicio de cámara disparado'**
  String get labAdventureCameraTestStartSnack;

  /// No description provided for @labAdventureCameraTestStopSnack.
  ///
  /// In es, this message translates to:
  /// **'Parada de cámara disparada'**
  String get labAdventureCameraTestStopSnack;

  /// No description provided for @labAdventureCameraPhaseOff.
  ///
  /// In es, this message translates to:
  /// **'Lab apagado'**
  String get labAdventureCameraPhaseOff;

  /// No description provided for @labAdventureCameraPhaseIdle.
  ///
  /// In es, this message translates to:
  /// **'Inactivo'**
  String get labAdventureCameraPhaseIdle;

  /// No description provided for @labAdventureCameraPhaseScanning.
  ///
  /// In es, this message translates to:
  /// **'Buscando…'**
  String get labAdventureCameraPhaseScanning;

  /// No description provided for @labAdventureCameraPhaseConnecting.
  ///
  /// In es, this message translates to:
  /// **'Conectando…'**
  String get labAdventureCameraPhaseConnecting;

  /// No description provided for @labAdventureCameraPhaseReady.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get labAdventureCameraPhaseReady;

  /// No description provided for @labAdventureCameraPhaseRecording.
  ///
  /// In es, this message translates to:
  /// **'Grabando'**
  String get labAdventureCameraPhaseRecording;

  /// No description provided for @labAdventureCameraPhaseError.
  ///
  /// In es, this message translates to:
  /// **'Error'**
  String get labAdventureCameraPhaseError;

  /// No description provided for @labAdventureCameraZonesEnable.
  ///
  /// In es, this message translates to:
  /// **'Zonas inicio/fin en el mapa'**
  String get labAdventureCameraZonesEnable;

  /// No description provided for @labAdventureCameraZonesEnableHelp.
  ///
  /// In es, this message translates to:
  /// **'Inicia/detiene al entrar en geocercas. Los puntos de inicio controlan la grabación (cámara apagada hasta llegar).'**
  String get labAdventureCameraZonesEnableHelp;

  /// No description provided for @labAdventureCameraZonesEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar zonas de cámara'**
  String get labAdventureCameraZonesEdit;

  /// No description provided for @labAdventureCameraZonesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Sin zonas — toca el mapa para añadir inicio/parada'**
  String get labAdventureCameraZonesEmpty;

  /// No description provided for @labAdventureCameraZonesCount.
  ///
  /// In es, this message translates to:
  /// **'{count} zonas en el mapa'**
  String labAdventureCameraZonesCount(int count);

  /// No description provided for @labAdventureCameraZonesTitle.
  ///
  /// In es, this message translates to:
  /// **'Zonas de cámara'**
  String get labAdventureCameraZonesTitle;

  /// No description provided for @labAdventureCameraZonesHelp.
  ///
  /// In es, this message translates to:
  /// **'Toca para colocar Inicio, luego toca de nuevo para la Parada de ese par. Mantén pulsado un marcador para borrar el par. Una Parada solo actúa después de su Inicio ligado.'**
  String get labAdventureCameraZonesHelp;

  /// No description provided for @labAdventureCameraZonesPlaceStart.
  ///
  /// In es, this message translates to:
  /// **'Siguiente toque: Inicio ▶'**
  String get labAdventureCameraZonesPlaceStart;

  /// No description provided for @labAdventureCameraZonesPlaceStop.
  ///
  /// In es, this message translates to:
  /// **'Siguiente toque: Parada ■ de este par'**
  String get labAdventureCameraZonesPlaceStop;

  /// No description provided for @labAdventureCameraZonesPairs.
  ///
  /// In es, this message translates to:
  /// **'Pares'**
  String get labAdventureCameraZonesPairs;

  /// No description provided for @rideDeckTitle.
  ///
  /// In es, this message translates to:
  /// **'Panel del ride'**
  String get rideDeckTitle;

  /// No description provided for @rideDeckHelp.
  ///
  /// In es, this message translates to:
  /// **'Si va en el bolsillo: toca Guardar en el bolsillo y mételo antes de que acabe la cuenta. Quédate quieto hasta el haptic — no vuelves a tocar. Tanque/manillar: Sostener vertical 4s.'**
  String get rideDeckHelp;

  /// No description provided for @startRideNow.
  ///
  /// In es, this message translates to:
  /// **'Iniciar ride ahora'**
  String get startRideNow;

  /// No description provided for @labAdventureCameraZoneStart.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get labAdventureCameraZoneStart;

  /// No description provided for @labAdventureCameraZoneStop.
  ///
  /// In es, this message translates to:
  /// **'Parada'**
  String get labAdventureCameraZoneStop;

  /// No description provided for @labAdventureCameraZonesClear.
  ///
  /// In es, this message translates to:
  /// **'Borrar todas'**
  String get labAdventureCameraZonesClear;

  /// No description provided for @labAdventureCameraZonesSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar zonas'**
  String get labAdventureCameraZonesSave;

  /// No description provided for @labAdventureCameraAggressive.
  ///
  /// In es, this message translates to:
  /// **'Auto-grabar conducción agresiva'**
  String get labAdventureCameraAggressive;

  /// No description provided for @labAdventureCameraAggressiveHelp.
  ///
  /// In es, this message translates to:
  /// **'Arranca solo a ≥85 km/h con cambios de inclinación constantes; pausa al calmar la inclinación o bajar de velocidad'**
  String get labAdventureCameraAggressiveHelp;

  /// No description provided for @labAdventureCameraGroup.
  ///
  /// In es, this message translates to:
  /// **'Grupo de cámaras'**
  String get labAdventureCameraGroup;

  /// No description provided for @labAdventureCameraGroupHelp.
  ///
  /// In es, this message translates to:
  /// **'Añade varias GoPro — el obturador se envía a todas las cámaras activas a la vez.'**
  String get labAdventureCameraGroupHelp;

  /// No description provided for @labAdventureCameraGroupEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay cámaras en el grupo.'**
  String get labAdventureCameraGroupEmpty;

  /// No description provided for @labAdventureCameraGroupAdd.
  ///
  /// In es, this message translates to:
  /// **'Añadir GoPro'**
  String get labAdventureCameraGroupAdd;

  /// No description provided for @labAdventureCameraGroupRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get labAdventureCameraGroupRemove;

  /// No description provided for @labAdventureCameraGroupScanning.
  ///
  /// In es, this message translates to:
  /// **'Buscando GoPros…'**
  String get labAdventureCameraGroupScanning;

  /// No description provided for @labAdventureCameraGroupNoneFound.
  ///
  /// In es, this message translates to:
  /// **'No hay GoPros nuevas — enciéndelas y abre la tapa lateral.'**
  String get labAdventureCameraGroupNoneFound;

  /// No description provided for @labAdventureCameraGroupPick.
  ///
  /// In es, this message translates to:
  /// **'Añadir al grupo'**
  String get labAdventureCameraGroupPick;

  /// No description provided for @labAdventureCameraGroupSetupHelp.
  ///
  /// In es, this message translates to:
  /// **'Ayuda: varias cámaras'**
  String get labAdventureCameraGroupSetupHelp;

  /// No description provided for @labAdventureCameraGroupSetupBody.
  ///
  /// In es, this message translates to:
  /// **'1. Enciende cada GoPro y abre la tapa lateral (Bluetooth activo).\n2. En el teléfono, permite Bluetooth (y dispositivos cercanos) si lo pide.\n3. Toca Añadir GoPro — espera el escaneo y elige cada cámara.\n4. Déjalas activas en la lista (apaga el interruptor para omitir una).\n5. Toca Conectar para enlazar todo el grupo.\n6. Inicia un ride (o usa zonas del mapa / auto-grabar agresivo) — el obturador arranca/para en todas las cámaras activas.\n7. En la pantalla del ride, CAM 2/2 significa que ambas están grabando.\n\nConsejos: acerca el teléfono a las cámaras en el primer enlace. Si una solo enciende y no graba, Conecta de nuevo y luego inicia el ride. Si una falla, las demás siguen.'**
  String get labAdventureCameraGroupSetupBody;

  /// No description provided for @labAdventureCameraScenariosTitle.
  ///
  /// In es, this message translates to:
  /// **'Setups de prueba'**
  String get labAdventureCameraScenariosTitle;

  /// No description provided for @labAdventureCameraScenarioZonesTitle.
  ///
  /// In es, this message translates to:
  /// **'Solo entre puntos inicio/parada del mapa'**
  String get labAdventureCameraScenarioZonesTitle;

  /// No description provided for @labAdventureCameraScenarioZonesBody.
  ///
  /// In es, this message translates to:
  /// **'ON: Cámara adventure · Zonas inicio/fin en el mapa (coloca Inicio + Parada) · cámaras en el grupo.\nOFF: Grabar con el ride · Auto-grabar conducción agresiva · Seguir pausa auto.\n\nNota: estas son zonas de cámara del Lab — no los puntos A/B de vueltas de la ruta.'**
  String get labAdventureCameraScenarioZonesBody;

  /// No description provided for @labAdventureCameraScenarioZonesApply.
  ///
  /// In es, this message translates to:
  /// **'Aplicar setup solo zonas'**
  String get labAdventureCameraScenarioZonesApply;

  /// No description provided for @labAdventureCameraScenarioAggressiveTitle.
  ///
  /// In es, this message translates to:
  /// **'Solo al empezar conducción divertida / agresiva'**
  String get labAdventureCameraScenarioAggressiveTitle;

  /// No description provided for @labAdventureCameraScenarioAggressiveBody.
  ///
  /// In es, this message translates to:
  /// **'ON: Cámara adventure · Auto-grabar conducción agresiva · cámaras en el grupo.\nOFF: Grabar con el ride · Zonas inicio/fin en el mapa · Seguir pausa auto.'**
  String get labAdventureCameraScenarioAggressiveBody;

  /// No description provided for @labAdventureCameraScenarioAggressiveApply.
  ///
  /// In es, this message translates to:
  /// **'Aplicar setup solo agresivo'**
  String get labAdventureCameraScenarioAggressiveApply;

  /// No description provided for @armAutoNoRouteHint.
  ///
  /// In es, this message translates to:
  /// **'Armado — al moverte se inicia un recorrido en el Garaje.'**
  String get armAutoNoRouteHint;

  /// No description provided for @freezeThenArmHelp.
  ///
  /// In es, this message translates to:
  /// **'Toca ahora y mételo al bolsillo. Quédate quieto hasta el haptic. Luego bloquea la pantalla — al arrancar se inicia el ride. No vuelves a tocar.'**
  String get freezeThenArmHelp;

  /// No description provided for @armAutoRouteArmed.
  ///
  /// In es, this message translates to:
  /// **'Armado — al arrancar se inicia el recorrido'**
  String get armAutoRouteArmed;

  /// No description provided for @armAutoRouteArmedNamed.
  ///
  /// In es, this message translates to:
  /// **'Armado para «{name}» — al arrancar el ride queda en esa ruta'**
  String armAutoRouteArmedNamed(String name);

  /// No description provided for @couldNotLoadRides.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar recorridos: {error}'**
  String couldNotLoadRides(String error);

  /// No description provided for @rodadasTitle.
  ///
  /// In es, this message translates to:
  /// **'Rodadas'**
  String get rodadasTitle;

  /// No description provided for @rodadasHomeSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Crea una rodada · invita · comparte GPS en vivo'**
  String get rodadasHomeSubtitle;

  /// No description provided for @friendsHelp.
  ///
  /// In es, this message translates to:
  /// **'Busca riders, envía solicitudes de amistad e invita amigos aceptados a una rodada.'**
  String get friendsHelp;

  /// No description provided for @findRiders.
  ///
  /// In es, this message translates to:
  /// **'Buscar riders'**
  String get findRiders;

  /// No description provided for @searchByNameHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar por nombre…'**
  String get searchByNameHint;

  /// No description provided for @noRidersFound.
  ///
  /// In es, this message translates to:
  /// **'No se encontraron riders'**
  String get noRidersFound;

  /// No description provided for @friendRequestSent.
  ///
  /// In es, this message translates to:
  /// **'Solicitud enviada a {name}'**
  String friendRequestSent(String name);

  /// No description provided for @addFriend.
  ///
  /// In es, this message translates to:
  /// **'Añadir'**
  String get addFriend;

  /// No description provided for @friendRequests.
  ///
  /// In es, this message translates to:
  /// **'Solicitudes'**
  String get friendRequests;

  /// No description provided for @wantsToBeFriends.
  ///
  /// In es, this message translates to:
  /// **'quiere ser tu amigo'**
  String get wantsToBeFriends;

  /// No description provided for @accept.
  ///
  /// In es, this message translates to:
  /// **'Aceptar'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In es, this message translates to:
  /// **'Rechazar'**
  String get decline;

  /// No description provided for @pendingSent.
  ///
  /// In es, this message translates to:
  /// **'Pendientes enviadas'**
  String get pendingSent;

  /// No description provided for @waitingAcceptance.
  ///
  /// In es, this message translates to:
  /// **'Esperando aceptación'**
  String get waitingAcceptance;

  /// No description provided for @yourFriends.
  ///
  /// In es, this message translates to:
  /// **'Tus amigos'**
  String get yourFriends;

  /// No description provided for @noFriendsYet.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes amigos — busca arriba y envía una solicitud.'**
  String get noFriendsYet;

  /// No description provided for @viewRides.
  ///
  /// In es, this message translates to:
  /// **'Ver recorridos'**
  String get viewRides;

  /// No description provided for @inviteToRodada.
  ///
  /// In es, this message translates to:
  /// **'Invitar a rodada'**
  String get inviteToRodada;

  /// No description provided for @createRodadaFirst.
  ///
  /// In es, this message translates to:
  /// **'Crea una rodada primero'**
  String get createRodadaFirst;

  /// No description provided for @inviteTo.
  ///
  /// In es, this message translates to:
  /// **'Invitar a…'**
  String get inviteTo;

  /// No description provided for @friendInvited.
  ///
  /// In es, this message translates to:
  /// **'{name} invitado'**
  String friendInvited(String name);

  /// No description provided for @scoreLabel.
  ///
  /// In es, this message translates to:
  /// **'Puntaje {score}'**
  String scoreLabel(int score);

  /// No description provided for @joinWithCodeTooltip.
  ///
  /// In es, this message translates to:
  /// **'Unirse con código'**
  String get joinWithCodeTooltip;

  /// No description provided for @createRodadaTooltip.
  ///
  /// In es, this message translates to:
  /// **'Crear rodada'**
  String get createRodadaTooltip;

  /// No description provided for @signInForRodadas.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión para usar Rodadas'**
  String get signInForRodadas;

  /// No description provided for @couldNotLoadRodadas.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar rodadas.\n{error}'**
  String couldNotLoadRodadas(String error);

  /// No description provided for @groupRidesTitle.
  ///
  /// In es, this message translates to:
  /// **'Rodadas en grupo'**
  String get groupRidesTitle;

  /// No description provided for @groupRidesBody.
  ///
  /// In es, this message translates to:
  /// **'Crea una rodada para Tapalpa, Moyahua o donde sea. Invita riders y comparte GPS en vivo, tracks y fotos solo si cada uno lo activa.'**
  String get groupRidesBody;

  /// No description provided for @createRodada.
  ///
  /// In es, this message translates to:
  /// **'Crear rodada'**
  String get createRodada;

  /// No description provided for @joinWithInviteCode.
  ///
  /// In es, this message translates to:
  /// **'Unirse con código de invitación'**
  String get joinWithInviteCode;

  /// No description provided for @joinRodadaTitle.
  ///
  /// In es, this message translates to:
  /// **'Unirse a rodada'**
  String get joinRodadaTitle;

  /// No description provided for @inviteCodeLabel.
  ///
  /// In es, this message translates to:
  /// **'Código de invitación'**
  String get inviteCodeLabel;

  /// No description provided for @inviteCodeHint.
  ///
  /// In es, this message translates to:
  /// **'ej. TAP42A'**
  String get inviteCodeHint;

  /// No description provided for @joinButton.
  ///
  /// In es, this message translates to:
  /// **'Unirse'**
  String get joinButton;

  /// No description provided for @joinFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo unir: {error}'**
  String joinFailed(String error);

  /// No description provided for @timeTbd.
  ///
  /// In es, this message translates to:
  /// **'Hora por definir'**
  String get timeTbd;

  /// No description provided for @rodadaRidersCount.
  ///
  /// In es, this message translates to:
  /// **'{count} riders'**
  String rodadaRidersCount(int count);

  /// No description provided for @newRodada.
  ///
  /// In es, this message translates to:
  /// **'Nueva rodada'**
  String get newRodada;

  /// No description provided for @rodadaCreateButton.
  ///
  /// In es, this message translates to:
  /// **'Crear'**
  String get rodadaCreateButton;

  /// No description provided for @rodadaTitleLabel.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get rodadaTitleLabel;

  /// No description provided for @rodadaTitleHint.
  ///
  /// In es, this message translates to:
  /// **'Tapalpa sábado'**
  String get rodadaTitleHint;

  /// No description provided for @rodadaDestinationLabel.
  ///
  /// In es, this message translates to:
  /// **'Destino'**
  String get rodadaDestinationLabel;

  /// No description provided for @rodadaDestinationHint.
  ///
  /// In es, this message translates to:
  /// **'Tapalpa / Moyahua / …'**
  String get rodadaDestinationHint;

  /// No description provided for @rodadaNotesLabel.
  ///
  /// In es, this message translates to:
  /// **'Notas'**
  String get rodadaNotesLabel;

  /// No description provided for @rodadaNotesHint.
  ///
  /// In es, this message translates to:
  /// **'Punto de encuentro en Shell, casco blanco…'**
  String get rodadaNotesHint;

  /// No description provided for @rodadaStartsAt.
  ///
  /// In es, this message translates to:
  /// **'Empieza'**
  String get rodadaStartsAt;

  /// No description provided for @rodadaPickDateTime.
  ///
  /// In es, this message translates to:
  /// **'Elegir fecha y hora'**
  String get rodadaPickDateTime;

  /// No description provided for @meetupPin.
  ///
  /// In es, this message translates to:
  /// **'Pin de encuentro'**
  String get meetupPin;

  /// No description provided for @useMyGps.
  ///
  /// In es, this message translates to:
  /// **'Usar mi GPS'**
  String get useMyGps;

  /// No description provided for @clearPin.
  ///
  /// In es, this message translates to:
  /// **'Borrar'**
  String get clearPin;

  /// No description provided for @meetupMapHelp.
  ///
  /// In es, this message translates to:
  /// **'Toca el mapa para fijar el punto de encuentro. GPS en vivo y fotos quedan apagados hasta que cada rider lo active.'**
  String get meetupMapHelp;

  /// No description provided for @titleRequired.
  ///
  /// In es, this message translates to:
  /// **'El título es obligatorio'**
  String get titleRequired;

  /// No description provided for @locationFailed.
  ///
  /// In es, this message translates to:
  /// **'Falló la ubicación: {error}'**
  String locationFailed(String error);

  /// No description provided for @rodadaFallback.
  ///
  /// In es, this message translates to:
  /// **'Rodada'**
  String get rodadaFallback;

  /// No description provided for @copyInviteCode.
  ///
  /// In es, this message translates to:
  /// **'Copiar código de invitación'**
  String get copyInviteCode;

  /// No description provided for @inviteCodeCopied.
  ///
  /// In es, this message translates to:
  /// **'Código {code} copiado'**
  String inviteCodeCopied(String code);

  /// No description provided for @markAsLive.
  ///
  /// In es, this message translates to:
  /// **'Marcar EN VIVO'**
  String get markAsLive;

  /// No description provided for @markAsOpen.
  ///
  /// In es, this message translates to:
  /// **'Marcar abierta'**
  String get markAsOpen;

  /// No description provided for @endRodada.
  ///
  /// In es, this message translates to:
  /// **'Terminar rodada'**
  String get endRodada;

  /// No description provided for @inviteFriend.
  ///
  /// In es, this message translates to:
  /// **'Invitar amigo'**
  String get inviteFriend;

  /// No description provided for @rodadaTabOverview.
  ///
  /// In es, this message translates to:
  /// **'Resumen'**
  String get rodadaTabOverview;

  /// No description provided for @rodadaTabLive.
  ///
  /// In es, this message translates to:
  /// **'En vivo'**
  String get rodadaTabLive;

  /// No description provided for @rodadaTabRides.
  ///
  /// In es, this message translates to:
  /// **'Recorridos'**
  String get rodadaTabRides;

  /// No description provided for @rodadaTabPhotos.
  ///
  /// In es, this message translates to:
  /// **'Fotos'**
  String get rodadaTabPhotos;

  /// No description provided for @rodadaTabRadio.
  ///
  /// In es, this message translates to:
  /// **'Radio'**
  String get rodadaTabRadio;

  /// No description provided for @rodadaNotFound.
  ///
  /// In es, this message translates to:
  /// **'Rodada no encontrada'**
  String get rodadaNotFound;

  /// No description provided for @rodadaStatusChanged.
  ///
  /// In es, this message translates to:
  /// **'Estado → {status}'**
  String rodadaStatusChanged(String status);

  /// No description provided for @noFriendsToInvite.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay amigos para invitar.'**
  String get noFriendsToInvite;

  /// No description provided for @inviteSent.
  ///
  /// In es, this message translates to:
  /// **'Invitación enviada'**
  String get inviteSent;

  /// No description provided for @rodadaCodeBanner.
  ///
  /// In es, this message translates to:
  /// **'código {code}'**
  String rodadaCodeBanner(String code);

  /// No description provided for @meetup.
  ///
  /// In es, this message translates to:
  /// **'Encuentro'**
  String get meetup;

  /// No description provided for @yourSharing.
  ///
  /// In es, this message translates to:
  /// **'Tu compartición'**
  String get yourSharing;

  /// No description provided for @sharingDefaultsHelp.
  ///
  /// In es, this message translates to:
  /// **'Apagado por defecto. Si lo activas, envía ubicación cada 5 minutos durante la rodada (reintenta cada 1 minuto si falla).'**
  String get sharingDefaultsHelp;

  /// No description provided for @notRodadaMember.
  ///
  /// In es, this message translates to:
  /// **'No eres miembro.'**
  String get notRodadaMember;

  /// No description provided for @shareLocationOnRoute.
  ///
  /// In es, this message translates to:
  /// **'Compartir ubicación en ruta'**
  String get shareLocationOnRoute;

  /// No description provided for @shareLocationEvery5Min.
  ///
  /// In es, this message translates to:
  /// **'Cada 5 min mientras la rodada está abierta/en vivo'**
  String get shareLocationEvery5Min;

  /// No description provided for @shareTrackAfterRides.
  ///
  /// In es, this message translates to:
  /// **'Compartir mi track después de recorridos'**
  String get shareTrackAfterRides;

  /// No description provided for @rodadaRiders.
  ///
  /// In es, this message translates to:
  /// **'Riders'**
  String get rodadaRiders;

  /// No description provided for @noMembersYet.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay miembros'**
  String get noMembersYet;

  /// No description provided for @rsvpGoing.
  ///
  /// In es, this message translates to:
  /// **'voy'**
  String get rsvpGoing;

  /// No description provided for @rsvpMaybe.
  ///
  /// In es, this message translates to:
  /// **'tal vez'**
  String get rsvpMaybe;

  /// No description provided for @rsvpDeclined.
  ///
  /// In es, this message translates to:
  /// **'no voy'**
  String get rsvpDeclined;

  /// No description provided for @memberLiveOn.
  ///
  /// In es, this message translates to:
  /// **'vivo activo'**
  String get memberLiveOn;

  /// No description provided for @memberTrackOn.
  ///
  /// In es, this message translates to:
  /// **'track activo'**
  String get memberTrackOn;

  /// No description provided for @sharingLocationBanner.
  ///
  /// In es, this message translates to:
  /// **'Compartiendo ubicación cada 5 min (reintento 1 min si falla)'**
  String get sharingLocationBanner;

  /// No description provided for @liveMapViewOnly.
  ///
  /// In es, this message translates to:
  /// **'Mapa en vivo solo lectura. Activa compartir en Resumen.'**
  String get liveMapViewOnly;

  /// No description provided for @shareLive.
  ///
  /// In es, this message translates to:
  /// **'Compartir en vivo'**
  String get shareLive;

  /// No description provided for @noLiveRidersYet.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay riders en vivo. Los que opten aparecen aquí (~5 s).'**
  String get noLiveRidersYet;

  /// No description provided for @addStop.
  ///
  /// In es, this message translates to:
  /// **'Añadir parada'**
  String get addStop;

  /// No description provided for @stopFab.
  ///
  /// In es, this message translates to:
  /// **'Parada'**
  String get stopFab;

  /// No description provided for @stopTitleLabel.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get stopTitleLabel;

  /// No description provided for @dropAtMyGps.
  ///
  /// In es, this message translates to:
  /// **'Soltar en mi GPS'**
  String get dropAtMyGps;

  /// No description provided for @gasBreakDefault.
  ///
  /// In es, this message translates to:
  /// **'Gas / descanso'**
  String get gasBreakDefault;

  /// No description provided for @stopDefault.
  ///
  /// In es, this message translates to:
  /// **'Parada'**
  String get stopDefault;

  /// No description provided for @sharedTracksHelp.
  ///
  /// In es, this message translates to:
  /// **'Tracks compartidos de miembros que lo activaron. El GPS denso queda en cada teléfono.'**
  String get sharedTracksHelp;

  /// No description provided for @linkMyRide.
  ///
  /// In es, this message translates to:
  /// **'Vincular mi recorrido'**
  String get linkMyRide;

  /// No description provided for @noSharedRidesYet.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay recorridos compartidos'**
  String get noSharedRidesYet;

  /// No description provided for @noCompletedRidesToLink.
  ///
  /// In es, this message translates to:
  /// **'No hay recorridos terminados para vincular'**
  String get noCompletedRidesToLink;

  /// No description provided for @syncRideFirst.
  ///
  /// In es, this message translates to:
  /// **'Sincroniza el recorrido primero e inténtalo de nuevo'**
  String get syncRideFirst;

  /// No description provided for @rideLinkedToRodada.
  ///
  /// In es, this message translates to:
  /// **'Recorrido vinculado a esta rodada'**
  String get rideLinkedToRodada;

  /// No description provided for @noTrackPoints.
  ///
  /// In es, this message translates to:
  /// **'Sin puntos de track'**
  String get noTrackPoints;

  /// No description provided for @radioAllGood.
  ///
  /// In es, this message translates to:
  /// **'Todo bien'**
  String get radioAllGood;

  /// No description provided for @radioStoppingFiveMin.
  ///
  /// In es, this message translates to:
  /// **'Parando 5 min'**
  String get radioStoppingFiveMin;

  /// No description provided for @radioNeedHelp.
  ///
  /// In es, this message translates to:
  /// **'Necesito ayuda'**
  String get radioNeedHelp;

  /// No description provided for @noMessagesYet.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay mensajes'**
  String get noMessagesYet;

  /// No description provided for @shortRadioMessageHint.
  ///
  /// In es, this message translates to:
  /// **'Mensaje corto de radio…'**
  String get shortRadioMessageHint;

  /// No description provided for @safetyTag.
  ///
  /// In es, this message translates to:
  /// **'SEGURIDAD'**
  String get safetyTag;

  /// No description provided for @riderFallback.
  ///
  /// In es, this message translates to:
  /// **'Rider'**
  String get riderFallback;

  /// No description provided for @photosAlbumHelp.
  ///
  /// In es, this message translates to:
  /// **'El álbum carga solo miniaturas. La imagen completa se abre al tocar y se libera al cerrar.'**
  String get photosAlbumHelp;

  /// No description provided for @photoAdd.
  ///
  /// In es, this message translates to:
  /// **'Añadir'**
  String get photoAdd;

  /// No description provided for @noPhotosYet.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay fotos'**
  String get noPhotosYet;

  /// No description provided for @photoUploaded.
  ///
  /// In es, this message translates to:
  /// **'Foto subida'**
  String get photoUploaded;

  /// No description provided for @photoTitle.
  ///
  /// In es, this message translates to:
  /// **'Foto'**
  String get photoTitle;

  /// No description provided for @skillCoach.
  ///
  /// In es, this message translates to:
  /// **'Coach de habilidad'**
  String get skillCoach;

  /// No description provided for @skillCurvasRated.
  ///
  /// In es, this message translates to:
  /// **'{count} curvas calificadas · huellas para comparar'**
  String skillCurvasRated(int count);

  /// No description provided for @improveNextRide.
  ///
  /// In es, this message translates to:
  /// **'Mejorar el próximo recorrido'**
  String get improveNextRide;

  /// No description provided for @openCornerLab.
  ///
  /// In es, this message translates to:
  /// **'Abrir corner lab'**
  String get openCornerLab;

  /// No description provided for @skillTipNoCurvas.
  ///
  /// In es, this message translates to:
  /// **'No se detectaron curvas sólidas — recorre una sección sinuosa para tener una base.'**
  String get skillTipNoCurvas;

  /// No description provided for @skillTipEntryHot.
  ///
  /// In es, this message translates to:
  /// **'Entrada caliente ({entry}→{apex} km/h). Frena antes del tip-in.'**
  String skillTipEntryHot(String entry, String apex);

  /// No description provided for @skillTipModerateSpeedDrop.
  ///
  /// In es, this message translates to:
  /// **'Caída moderada de velocidad al apex — trail brake un poco más.'**
  String get skillTipModerateSpeedDrop;

  /// No description provided for @skillTipLittleSpeedScrub.
  ///
  /// In es, this message translates to:
  /// **'Poca reducción de velocidad — confirma que no llevas demasiada en mitad de curva.'**
  String get skillTipLittleSpeedScrub;

  /// No description provided for @skillTipWeakExitDrive.
  ///
  /// In es, this message translates to:
  /// **'Salida débil — abre gas antes cuando la inclinación empiece a bajar.'**
  String get skillTipWeakExitDrive;

  /// No description provided for @skillTipPeakLeanNotAtApex.
  ///
  /// In es, this message translates to:
  /// **'Inclinación máxima no en el apex — inclina antes para estar listo en el apex.'**
  String get skillTipPeakLeanNotAtApex;

  /// No description provided for @skillTipLowLeanBigHeading.
  ///
  /// In es, this message translates to:
  /// **'Gran cambio de rumbo con poca inclinación — revisa el sensor o inclínate más.'**
  String get skillTipLowLeanBigHeading;

  /// No description provided for @skillTipSolidCorner.
  ///
  /// In es, this message translates to:
  /// **'Curva sólida — mantén este ritmo de entrada/apex.'**
  String get skillTipSolidCorner;

  /// No description provided for @skillHighlightBest.
  ///
  /// In es, this message translates to:
  /// **'Mejor: {label} · {score}/100'**
  String skillHighlightBest(String label, int score);

  /// No description provided for @skillHighlightMedian.
  ///
  /// In es, this message translates to:
  /// **'Puntaje mediano de curvas {score}/100'**
  String skillHighlightMedian(int score);

  /// No description provided for @skillTipDrillRepeat.
  ///
  /// In es, this message translates to:
  /// **'Práctica: repite una {label} similar y frena 10–15 m antes.'**
  String skillTipDrillRepeat(String label);

  /// No description provided for @performanceLabel.
  ///
  /// In es, this message translates to:
  /// **'RENDIMIENTO'**
  String get performanceLabel;

  /// No description provided for @statRides.
  ///
  /// In es, this message translates to:
  /// **'Recorridos'**
  String get statRides;

  /// No description provided for @statDistance.
  ///
  /// In es, this message translates to:
  /// **'Distancia'**
  String get statDistance;

  /// No description provided for @statTopSpeed.
  ///
  /// In es, this message translates to:
  /// **'Vel. máx.'**
  String get statTopSpeed;

  /// No description provided for @statPeakLean.
  ///
  /// In es, this message translates to:
  /// **'Inclinación'**
  String get statPeakLean;

  /// No description provided for @rideDiscarded.
  ///
  /// In es, this message translates to:
  /// **'Descartado'**
  String get rideDiscarded;

  /// No description provided for @gpsQualitySparseTip.
  ///
  /// In es, this message translates to:
  /// **'GPS escaso — deja la notificación de grabación y evita límites de batería.'**
  String get gpsQualitySparseTip;

  /// No description provided for @gpsQualityFairTip.
  ///
  /// In es, this message translates to:
  /// **'GPS ~{meters} m — la línea sirve, pero un poco suave.'**
  String gpsQualityFairTip(String meters);

  /// No description provided for @gpsQualityWeakTip.
  ///
  /// In es, this message translates to:
  /// **'GPS débil (~{meters} m) — fija mejor el teléfono y rueda al aire libre.'**
  String gpsQualityWeakTip(String meters);

  /// No description provided for @gpsRateHz.
  ///
  /// In es, this message translates to:
  /// **'{hz} Hz'**
  String gpsRateHz(String hz);

  /// No description provided for @pressure.
  ///
  /// In es, this message translates to:
  /// **'Presión'**
  String get pressure;

  /// No description provided for @pressureChartSub.
  ///
  /// In es, this message translates to:
  /// **'Barómetro a lo largo del recorrido (hPa)'**
  String get pressureChartSub;

  /// No description provided for @skillLabTitle.
  ///
  /// In es, this message translates to:
  /// **'Lab de técnica'**
  String get skillLabTitle;

  /// No description provided for @skillLabTapHint.
  ///
  /// In es, this message translates to:
  /// **'Toca para ver errores y cómo mejorar'**
  String get skillLabTapHint;

  /// No description provided for @skillLabTapHintEmpty.
  ///
  /// In es, this message translates to:
  /// **'Toca para tips tras un tramo sinuoso'**
  String get skillLabTapHintEmpty;

  /// No description provided for @skillLabFocusTitle.
  ///
  /// In es, this message translates to:
  /// **'Dónde mejorar'**
  String get skillLabFocusTitle;

  /// No description provided for @skillLabFocusHelp.
  ///
  /// In es, this message translates to:
  /// **'Primero las curvas con peor puntaje. Las barras son entrada → ápice → salida. Toca Repetir para ver inclinación, freno y velocidad — y comparar la misma sección de curva con un amigo.'**
  String get skillLabFocusHelp;

  /// No description provided for @bikeSection.
  ///
  /// In es, this message translates to:
  /// **'Mi moto'**
  String get bikeSection;

  /// No description provided for @bikeSelect.
  ///
  /// In es, this message translates to:
  /// **'Elige tu moto'**
  String get bikeSelect;

  /// No description provided for @bikeSelectHelp.
  ///
  /// In es, this message translates to:
  /// **'Catálogo Triumph — se usa en Lean Lab y contexto de recorridos'**
  String get bikeSelectHelp;

  /// No description provided for @bikePickerTitle.
  ///
  /// In es, this message translates to:
  /// **'Garage'**
  String get bikePickerTitle;

  /// No description provided for @bikePickerHelp.
  ///
  /// In es, this message translates to:
  /// **'Elige la Triumph que ruedas. Etiqueta Lean Lab y datos de entrenamiento.'**
  String get bikePickerHelp;

  /// No description provided for @bikeClear.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get bikeClear;

  /// No description provided for @bikeFamilyNaked.
  ///
  /// In es, this message translates to:
  /// **'Naked'**
  String get bikeFamilyNaked;

  /// No description provided for @bikeFamilyAdventure.
  ///
  /// In es, this message translates to:
  /// **'Adventure'**
  String get bikeFamilyAdventure;

  /// No description provided for @bikeFamilyClassic.
  ///
  /// In es, this message translates to:
  /// **'Clásica'**
  String get bikeFamilyClassic;

  /// No description provided for @bikeFamilySport.
  ///
  /// In es, this message translates to:
  /// **'Sport'**
  String get bikeFamilySport;

  /// No description provided for @bikeFamilyCruiser.
  ///
  /// In es, this message translates to:
  /// **'Cruiser'**
  String get bikeFamilyCruiser;

  /// No description provided for @bikeFamilyOther.
  ///
  /// In es, this message translates to:
  /// **'Otra'**
  String get bikeFamilyOther;

  /// No description provided for @leanLabHomeCta.
  ///
  /// In es, this message translates to:
  /// **'Lab de inclinación — Bugambilias'**
  String get leanLabHomeCta;

  /// No description provided for @leanLabTitle.
  ///
  /// In es, this message translates to:
  /// **'Lab de inclinación'**
  String get leanLabTitle;

  /// No description provided for @leanLabIntro.
  ///
  /// In es, this message translates to:
  /// **'Protocolo para pilots en Bugambilias — ambos sentidos, con elevación. Calibra vertical, rueda y etiqueta curvas para pulir el lean.'**
  String get leanLabIntro;

  /// No description provided for @leanLabCircuitName.
  ///
  /// In es, this message translates to:
  /// **'Circuito Bugambilias'**
  String get leanLabCircuitName;

  /// No description provided for @leanLabCircuitHelp.
  ///
  /// In es, this message translates to:
  /// **'Plaza Panorámica Bugambilias · ambos sentidos · abrir en Maps'**
  String get leanLabCircuitHelp;

  /// No description provided for @leanLabProgress.
  ///
  /// In es, this message translates to:
  /// **'{labeled} de {total} sesiones etiquetadas'**
  String leanLabProgress(int labeled, int total);

  /// No description provided for @leanLabProtocols.
  ///
  /// In es, this message translates to:
  /// **'Protocolos'**
  String get leanLabProtocols;

  /// No description provided for @leanLabProtoOutbound.
  ///
  /// In es, this message translates to:
  /// **'Base de ida'**
  String get leanLabProtoOutbound;

  /// No description provided for @leanLabProtoOutboundHelp.
  ///
  /// In es, this message translates to:
  /// **'Hacia la plaza, mount al centro. Captura lean en subida/bajada.'**
  String get leanLabProtoOutboundHelp;

  /// No description provided for @leanLabProtoReturn.
  ///
  /// In es, this message translates to:
  /// **'Base de regreso'**
  String get leanLabProtoReturn;

  /// No description provided for @leanLabProtoReturnHelp.
  ///
  /// In es, this message translates to:
  /// **'Sentido contrario, mount al centro. Mismas curvas, lados invertidos.'**
  String get leanLabProtoReturnHelp;

  /// No description provided for @leanLabProtoPocket.
  ///
  /// In es, this message translates to:
  /// **'Mount A/B — bolsillo'**
  String get leanLabProtoPocket;

  /// No description provided for @leanLabProtoPocketHelp.
  ///
  /// In es, this message translates to:
  /// **'Mismo circuito con teléfono en bolsillo para aprender el sesgo del mount.'**
  String get leanLabProtoPocketHelp;

  /// No description provided for @leanLabProtoFree.
  ///
  /// In es, this message translates to:
  /// **'Vuelta libre Lean Lab'**
  String get leanLabProtoFree;

  /// No description provided for @leanLabProtoFreeHelp.
  ///
  /// In es, this message translates to:
  /// **'Cualquier sentido en este circuito con calib + etiquetas de curva.'**
  String get leanLabProtoFreeHelp;

  /// No description provided for @leanLabStartProtocol.
  ///
  /// In es, this message translates to:
  /// **'Preparar y rodar'**
  String get leanLabStartProtocol;

  /// No description provided for @leanLabNeedsLabels.
  ///
  /// In es, this message translates to:
  /// **'Faltan etiquetas de curva'**
  String get leanLabNeedsLabels;

  /// No description provided for @leanLabElevationSummary.
  ///
  /// In es, this message translates to:
  /// **'↑{climb} m · ↓{descent} m'**
  String leanLabElevationSummary(String climb, String descent);

  /// No description provided for @leanLabPrepTitle.
  ///
  /// In es, this message translates to:
  /// **'Prep Lean Lab'**
  String get leanLabPrepTitle;

  /// No description provided for @leanLabPrepHelp.
  ///
  /// In es, this message translates to:
  /// **'Elige mount y pose. Congela g0 con el teléfono ya en ese mount — los sensores eligen roll o pitch. Luego arranca la vuelta.'**
  String get leanLabPrepHelp;

  /// No description provided for @leanLabPoseQ.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo va el teléfono?'**
  String get leanLabPoseQ;

  /// No description provided for @leanLabPoseScreenOut.
  ///
  /// In es, this message translates to:
  /// **'Vertical · pantalla afuera'**
  String get leanLabPoseScreenOut;

  /// No description provided for @leanLabPoseScreenIn.
  ///
  /// In es, this message translates to:
  /// **'Vertical · pantalla adentro'**
  String get leanLabPoseScreenIn;

  /// No description provided for @leanLabPoseLandscape.
  ///
  /// In es, this message translates to:
  /// **'Horizontal'**
  String get leanLabPoseLandscape;

  /// No description provided for @leanLabDirectionQ.
  ///
  /// In es, this message translates to:
  /// **'¿Dirección en Bugambilias?'**
  String get leanLabDirectionQ;

  /// No description provided for @leanLabDirectionOutbound.
  ///
  /// In es, this message translates to:
  /// **'Ida (a la plaza)'**
  String get leanLabDirectionOutbound;

  /// No description provided for @leanLabDirectionReturn.
  ///
  /// In es, this message translates to:
  /// **'Regreso'**
  String get leanLabDirectionReturn;

  /// No description provided for @leanLabCalibTitle.
  ///
  /// In es, this message translates to:
  /// **'Calibración vertical'**
  String get leanLabCalibTitle;

  /// No description provided for @leanLabCalibHelp.
  ///
  /// In es, this message translates to:
  /// **'Moto vertical, teléfono ya montado. Sin tocarlo, 4 segundos — congela gravedad (g0). El vector lean debe quedar cerca de 0°.'**
  String get leanLabCalibHelp;

  /// No description provided for @leanLabCalibHold.
  ///
  /// In es, this message translates to:
  /// **'Sostener vertical 4s'**
  String get leanLabCalibHold;

  /// No description provided for @leanLabCalibHolding.
  ///
  /// In es, this message translates to:
  /// **'Quédate quieto…'**
  String get leanLabCalibHolding;

  /// No description provided for @leanLabCalibPocket.
  ///
  /// In es, this message translates to:
  /// **'Guardar en el bolsillo'**
  String get leanLabCalibPocket;

  /// No description provided for @leanLabCalibPocketHelp.
  ///
  /// In es, this message translates to:
  /// **'Siéntate vertical en la moto. Toca, mételo del todo antes de que acabe la cuenta. Quédate quieto hasta el haptic — no congeles en la mano.'**
  String get leanLabCalibPocketHelp;

  /// No description provided for @leanLabCalibPocketCountdown.
  ///
  /// In es, this message translates to:
  /// **'Mételo ahora · {n}s'**
  String leanLabCalibPocketCountdown(int n);

  /// No description provided for @leanLabCalibPocketSettle.
  ///
  /// In es, this message translates to:
  /// **'Quédate quieto…'**
  String get leanLabCalibPocketSettle;

  /// No description provided for @leanLabCalibPocketCapture.
  ///
  /// In es, this message translates to:
  /// **'Capturando 0°…'**
  String get leanLabCalibPocketCapture;

  /// No description provided for @leanLabCalibPocketFail.
  ///
  /// In es, this message translates to:
  /// **'No se quedó quieto. Sácalo y reintenta.'**
  String get leanLabCalibPocketFail;

  /// No description provided for @leanLabFreezeRedo.
  ///
  /// In es, this message translates to:
  /// **'El teléfono ya va {n}° de vertical. Repite el freeze con la moto de verdad derecha.'**
  String leanLabFreezeRedo(String n);

  /// No description provided for @leanLabRawNeutral.
  ///
  /// In es, this message translates to:
  /// **'Ángulo crudo del teléfono'**
  String get leanLabRawNeutral;

  /// No description provided for @leanLabFrozenNeutral.
  ///
  /// In es, this message translates to:
  /// **'Neutro congelado'**
  String get leanLabFrozenNeutral;

  /// No description provided for @leanLabStartRide.
  ///
  /// In es, this message translates to:
  /// **'Iniciar recorrido Lean Lab'**
  String get leanLabStartRide;

  /// No description provided for @leanLabReviewTitle.
  ///
  /// In es, this message translates to:
  /// **'Etiquetar inclinación'**
  String get leanLabReviewTitle;

  /// No description provided for @leanLabReviewHelp.
  ///
  /// In es, this message translates to:
  /// **'En cada curva: ¿el lean de la app se sintió alto, bien o bajo? Se muestra la pendiente para corregir sesgo de subida/bajada.'**
  String get leanLabReviewHelp;

  /// No description provided for @leanLabReviewHelpMax.
  ///
  /// In es, this message translates to:
  /// **'El lean máximo de la curva queda fijo arriba. Reproduce la curva para ver lean y mapa; salta al pico cuando quieras.'**
  String get leanLabReviewHelpMax;

  /// No description provided for @leanLabMaxLean.
  ///
  /// In es, this message translates to:
  /// **'Lean máximo'**
  String get leanLabMaxLean;

  /// No description provided for @leanLabJumpToMax.
  ///
  /// In es, this message translates to:
  /// **'Ir al lean máximo'**
  String get leanLabJumpToMax;

  /// No description provided for @leanLabLiveLean.
  ///
  /// In es, this message translates to:
  /// **'Lean en vivo'**
  String get leanLabLiveLean;

  /// No description provided for @leanLabAtPeak.
  ///
  /// In es, this message translates to:
  /// **'en el pico'**
  String get leanLabAtPeak;

  /// No description provided for @leanLabMaxLeanGps.
  ///
  /// In es, this message translates to:
  /// **'GPS donde ocurrió el lean máximo'**
  String get leanLabMaxLeanGps;

  /// No description provided for @leanLabMaxLeanGpsA.
  ///
  /// In es, this message translates to:
  /// **'A · {lat}, {lng}'**
  String leanLabMaxLeanGpsA(String lat, String lng);

  /// No description provided for @leanLabMaxLeanGpsB.
  ///
  /// In es, this message translates to:
  /// **'B · {lat}, {lng}'**
  String leanLabMaxLeanGpsB(String lat, String lng);

  /// No description provided for @leanLabSideLeft.
  ///
  /// In es, this message translates to:
  /// **'izquierda'**
  String get leanLabSideLeft;

  /// No description provided for @leanLabSideRight.
  ///
  /// In es, this message translates to:
  /// **'derecha'**
  String get leanLabSideRight;

  /// No description provided for @leanLabNoCorners.
  ///
  /// In es, this message translates to:
  /// **'No hay curvas detectadas para etiquetar en este recorrido.'**
  String get leanLabNoCorners;

  /// No description provided for @leanLabNoTrackPoints.
  ///
  /// In es, this message translates to:
  /// **'Este recorrido casi no tiene GPS en el teléfono. Abre Ajustes → Sincronizar rides con la nube (misma cuenta Google) y vuelve a intentar.'**
  String get leanLabNoTrackPoints;

  /// No description provided for @leanLabNoLeanData.
  ///
  /// In es, this message translates to:
  /// **'El GPS está, pero faltan muestras de inclinación — no se pueden etiquetar curvas. Sincroniza de nuevo o graba la vuelta con el teléfono bien fijado.'**
  String get leanLabNoLeanData;

  /// No description provided for @leanLabAppLean.
  ///
  /// In es, this message translates to:
  /// **'Lean app'**
  String get leanLabAppLean;

  /// No description provided for @leanLabGrade.
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get leanLabGrade;

  /// No description provided for @leanLabBiasQ.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo se sintió el lean de la app en el ápice?'**
  String get leanLabBiasQ;

  /// No description provided for @leanLabBiasAppHigh.
  ///
  /// In es, this message translates to:
  /// **'App muy alto'**
  String get leanLabBiasAppHigh;

  /// No description provided for @leanLabBiasOk.
  ///
  /// In es, this message translates to:
  /// **'Se sintió bien'**
  String get leanLabBiasOk;

  /// No description provided for @leanLabBiasAppLow.
  ///
  /// In es, this message translates to:
  /// **'App muy bajo'**
  String get leanLabBiasAppLow;

  /// No description provided for @leanLabBiasUnsure.
  ///
  /// In es, this message translates to:
  /// **'No estoy seguro'**
  String get leanLabBiasUnsure;

  /// No description provided for @leanLabTrendClimbing.
  ///
  /// In es, this message translates to:
  /// **'subiendo'**
  String get leanLabTrendClimbing;

  /// No description provided for @leanLabTrendDescending.
  ///
  /// In es, this message translates to:
  /// **'bajando'**
  String get leanLabTrendDescending;

  /// No description provided for @leanLabTrendFlat.
  ///
  /// In es, this message translates to:
  /// **'plano'**
  String get leanLabTrendFlat;

  /// No description provided for @leanLabSaveLabels.
  ///
  /// In es, this message translates to:
  /// **'Guardar etiquetas'**
  String get leanLabSaveLabels;

  /// No description provided for @leanLabSettingsTile.
  ///
  /// In es, this message translates to:
  /// **'Lab de inclinación (pilots)'**
  String get leanLabSettingsTile;

  /// No description provided for @leanLabSettingsHelp.
  ///
  /// In es, this message translates to:
  /// **'Protocolo Bugambilias · calib · elevación · verdad de curvas'**
  String get leanLabSettingsHelp;

  /// No description provided for @leanImuLabTitle.
  ///
  /// In es, this message translates to:
  /// **'Lab IMU de inclinación'**
  String get leanImuLabTitle;

  /// No description provided for @leanImuLabIntro.
  ///
  /// In es, this message translates to:
  /// **'El mismo motor que producción. Congela vertical en el mount real, luego inclina — bike lean es la magnitud vectorial con el signo del canal ganador. El banner muestra pose (Vertical / Landscape / Flat) y el ganador.'**
  String get leanImuLabIntro;

  /// No description provided for @leanImuLabSettingsTile.
  ///
  /// In es, this message translates to:
  /// **'Sensores IMU de lean'**
  String get leanImuLabSettingsTile;

  /// No description provided for @leanImuLabSettingsHelp.
  ///
  /// In es, this message translates to:
  /// **'Estudia accel / gyro / mag / baro y el motor de lean según el mount'**
  String get leanImuLabSettingsHelp;

  /// No description provided for @leanImuLabFreeze.
  ///
  /// In es, this message translates to:
  /// **'Congelar vertical'**
  String get leanImuLabFreeze;

  /// No description provided for @leanImuLabReset.
  ///
  /// In es, this message translates to:
  /// **'Reset'**
  String get leanImuLabReset;

  /// No description provided for @leanImuLabFrozenHint.
  ///
  /// In es, this message translates to:
  /// **'g0 está congelado. Bike lean debe ser ~0°. Inclina en cualquier dirección — el vector es el ángulo, el ganador da izquierda/derecha.'**
  String get leanImuLabFrozenHint;

  /// No description provided for @leanImuLabAnglesTitle.
  ///
  /// In es, this message translates to:
  /// **'Candidatos de ángulo'**
  String get leanImuLabAnglesTitle;

  /// No description provided for @leanImuLabAnglesHelp.
  ///
  /// In es, this message translates to:
  /// **'Bike lean = producción. Vector = ángulo 3D desde el freeze. Roll sigue el lean si el teléfono está vertical; pitch si está plano. Fused = gyro + accel. Old App lean es la fórmula de eje más cercano que retiramos.'**
  String get leanImuLabAnglesHelp;

  /// No description provided for @leanImuLabHistoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Últimos ~8 s'**
  String get leanImuLabHistoryTitle;

  /// No description provided for @leanImuLabVectorsTitle.
  ///
  /// In es, this message translates to:
  /// **'Capacidades crudas'**
  String get leanImuLabVectorsTitle;

  /// No description provided for @leanImuLabNextTitle.
  ///
  /// In es, this message translates to:
  /// **'Cómo leer esto para producción'**
  String get leanImuLabNextTitle;

  /// No description provided for @leanImuLabNextHelp.
  ///
  /// In es, this message translates to:
  /// **'Pared: vector a ~3° de un clinómetro, cualquier pose. Vertical: bike lean sigue fused roll. Plano: sigue pitch/vector. Si se mueve en el bolsillo: el banner cambia de pose en unos segundos. Mag (heading) es extra, no es lean de la moto.'**
  String get leanImuLabNextHelp;

  /// No description provided for @leanLabPastSessions.
  ///
  /// In es, this message translates to:
  /// **'Sesiones anteriores'**
  String get leanLabPastSessions;

  /// No description provided for @leanLabSessionDetailTitle.
  ///
  /// In es, this message translates to:
  /// **'Sesión Lean Lab'**
  String get leanLabSessionDetailTitle;

  /// No description provided for @leanLabSessionMissing.
  ///
  /// In es, this message translates to:
  /// **'No se encontró esta sesión de Lean Lab.'**
  String get leanLabSessionMissing;

  /// No description provided for @leanLabMeasuresTitle.
  ///
  /// In es, this message translates to:
  /// **'Medidas'**
  String get leanLabMeasuresTitle;

  /// No description provided for @leanLabCornerMeasures.
  ///
  /// In es, this message translates to:
  /// **'Lean máximo por curva'**
  String get leanLabCornerMeasures;

  /// No description provided for @leanLabCoverage.
  ///
  /// In es, this message translates to:
  /// **'Cobertura del circuito'**
  String get leanLabCoverage;

  /// No description provided for @leanLabCornersCount.
  ///
  /// In es, this message translates to:
  /// **'Curvas etiquetadas'**
  String get leanLabCornersCount;

  /// No description provided for @leanLabLabeledCount.
  ///
  /// In es, this message translates to:
  /// **'{count} curvas etiquetadas'**
  String leanLabLabeledCount(int count);

  /// No description provided for @leanLabEditConfigTitle.
  ///
  /// In es, this message translates to:
  /// **'Corregir configuración'**
  String get leanLabEditConfigTitle;

  /// No description provided for @leanLabEditConfigHelp.
  ///
  /// In es, this message translates to:
  /// **'Corrige ida/vuelta, mount o pose si te equivocaste — los números de lean no cambian; las etiquetas se quedan hasta que las vuelvas a guardar.'**
  String get leanLabEditConfigHelp;

  /// No description provided for @leanLabSaveConfig.
  ///
  /// In es, this message translates to:
  /// **'Guardar configuración'**
  String get leanLabSaveConfig;

  /// No description provided for @leanLabConfigSaved.
  ///
  /// In es, this message translates to:
  /// **'Configuración guardada'**
  String get leanLabConfigSaved;

  /// No description provided for @leanLabRelabelCorners.
  ///
  /// In es, this message translates to:
  /// **'Revisar / actualizar etiquetas'**
  String get leanLabRelabelCorners;

  /// No description provided for @leanLabOpenRide.
  ///
  /// In es, this message translates to:
  /// **'Abrir mapa del recorrido'**
  String get leanLabOpenRide;

  /// No description provided for @skillReplayTitle.
  ///
  /// In es, this message translates to:
  /// **'Repetición de curva'**
  String get skillReplayTitle;

  /// No description provided for @skillReplayHelp.
  ///
  /// In es, this message translates to:
  /// **'Mira cómo se rodó este tramo — inclinación, freno y velocidad van con el cursor en el mapa.'**
  String get skillReplayHelp;

  /// No description provided for @skillReplayCompareHelp.
  ///
  /// In es, this message translates to:
  /// **'Ambas líneas se recortan al mismo tramo de carretera. Los cursores avanzan por distancia en la curva para comparar la línea, no el reloj.'**
  String get skillReplayCompareHelp;

  /// No description provided for @skillReplayCompareWith.
  ///
  /// In es, this message translates to:
  /// **'Comparar con un amigo'**
  String get skillReplayCompareWith;

  /// No description provided for @skillReplayNoPeerMatch.
  ///
  /// In es, this message translates to:
  /// **'Este amigo no pasó por la misma sección de la curva.'**
  String get skillReplayNoPeerMatch;

  /// No description provided for @skillReplayAlignedSection.
  ///
  /// In es, this message translates to:
  /// **'Misma sección de curva para ambos (coinciden en el corredor).'**
  String get skillReplayAlignedSection;

  /// No description provided for @skillReplaySameSection.
  ///
  /// In es, this message translates to:
  /// **'misma sección · sincronizado por distancia'**
  String get skillReplaySameSection;

  /// No description provided for @skillReplay.
  ///
  /// In es, this message translates to:
  /// **'Repetir'**
  String get skillReplay;

  /// No description provided for @compareSharedSectionHelp.
  ///
  /// In es, this message translates to:
  /// **'Continua = tú · punteada = otro. Las líneas se separan un poco y se recortan al tramo compartido para ver ambas.'**
  String get compareSharedSectionHelp;

  /// No description provided for @compareTrackUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No hay puntos de track para este recorrido.'**
  String get compareTrackUnavailable;

  /// No description provided for @compareOneTrackOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo una de las dos rutas tiene puntos suficientes para dibujar.'**
  String get compareOneTrackOnly;

  /// No description provided for @play.
  ///
  /// In es, this message translates to:
  /// **'Reproducir'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In es, this message translates to:
  /// **'Pausa'**
  String get pause;

  /// No description provided for @restart.
  ///
  /// In es, this message translates to:
  /// **'Reiniciar'**
  String get restart;

  /// No description provided for @loopReplay.
  ///
  /// In es, this message translates to:
  /// **'Bucle'**
  String get loopReplay;

  /// No description provided for @brake.
  ///
  /// In es, this message translates to:
  /// **'Freno'**
  String get brake;

  /// No description provided for @engineLabelTitle.
  ///
  /// In es, this message translates to:
  /// **'Ayuda a entrenar RiderLab'**
  String get engineLabelTitle;

  /// No description provided for @engineLabelIntro.
  ///
  /// In es, this message translates to:
  /// **'Solo beta — unos toques tras cada recorrido enseñan inclinación, curvas y frenos. Puedes omitir.'**
  String get engineLabelIntro;

  /// No description provided for @engineLabelSkip.
  ///
  /// In es, this message translates to:
  /// **'Omitir'**
  String get engineLabelSkip;

  /// No description provided for @engineLabelSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar respuestas'**
  String get engineLabelSave;

  /// No description provided for @engineLabelMountQ.
  ///
  /// In es, this message translates to:
  /// **'¿Dónde iba el teléfono en este recorrido?'**
  String get engineLabelMountQ;

  /// No description provided for @engineLabelMountCenter.
  ///
  /// In es, this message translates to:
  /// **'Base (tanque / manillar)'**
  String get engineLabelMountCenter;

  /// No description provided for @engineLabelMountLeftPocket.
  ///
  /// In es, this message translates to:
  /// **'Bolsillo izquierdo'**
  String get engineLabelMountLeftPocket;

  /// No description provided for @engineLabelMountRightPocket.
  ///
  /// In es, this message translates to:
  /// **'Bolsillo derecho'**
  String get engineLabelMountRightPocket;

  /// No description provided for @engineLabelMountOther.
  ///
  /// In es, this message translates to:
  /// **'Otro / suelto'**
  String get engineLabelMountOther;

  /// No description provided for @engineLabelLeanQ.
  ///
  /// In es, this message translates to:
  /// **'¿La inclinación se sintió bien?'**
  String get engineLabelLeanQ;

  /// No description provided for @engineLabelLeanGood.
  ///
  /// In es, this message translates to:
  /// **'Se sintió bien'**
  String get engineLabelLeanGood;

  /// No description provided for @engineLabelLeanLeftHigh.
  ///
  /// In es, this message translates to:
  /// **'Izquierda se veía alta'**
  String get engineLabelLeanLeftHigh;

  /// No description provided for @engineLabelLeanRightHigh.
  ///
  /// In es, this message translates to:
  /// **'Derecha se veía alta'**
  String get engineLabelLeanRightHigh;

  /// No description provided for @engineLabelLeanBothOff.
  ///
  /// In es, this message translates to:
  /// **'Ambos lados mal'**
  String get engineLabelLeanBothOff;

  /// No description provided for @engineLabelLeanUnsure.
  ///
  /// In es, this message translates to:
  /// **'No sé'**
  String get engineLabelLeanUnsure;

  /// No description provided for @engineLabelBrakeQ.
  ///
  /// In es, this message translates to:
  /// **'¿Los frenos detectados se vieron bien?'**
  String get engineLabelBrakeQ;

  /// No description provided for @engineLabelBrakeGood.
  ///
  /// In es, this message translates to:
  /// **'Se sintió bien'**
  String get engineLabelBrakeGood;

  /// No description provided for @engineLabelBrakeTooMany.
  ///
  /// In es, this message translates to:
  /// **'Demasiados / falsos'**
  String get engineLabelBrakeTooMany;

  /// No description provided for @engineLabelBrakeTooFew.
  ///
  /// In es, this message translates to:
  /// **'Faltaron frenos reales'**
  String get engineLabelBrakeTooFew;

  /// No description provided for @engineLabelBrakeUnsure.
  ///
  /// In es, this message translates to:
  /// **'No sé'**
  String get engineLabelBrakeUnsure;

  /// No description provided for @engineLabelContextQ.
  ///
  /// In es, this message translates to:
  /// **'¿Qué tipo de recorrido fue?'**
  String get engineLabelContextQ;

  /// No description provided for @engineLabelContextStreet.
  ///
  /// In es, this message translates to:
  /// **'Ciudad'**
  String get engineLabelContextStreet;

  /// No description provided for @engineLabelContextMountain.
  ///
  /// In es, this message translates to:
  /// **'Montaña'**
  String get engineLabelContextMountain;

  /// No description provided for @engineLabelContextTrack.
  ///
  /// In es, this message translates to:
  /// **'Pista'**
  String get engineLabelContextTrack;

  /// No description provided for @engineLabelContextCommute.
  ///
  /// In es, this message translates to:
  /// **'Traslado'**
  String get engineLabelContextCommute;

  /// No description provided for @engineLabelContextOther.
  ///
  /// In es, this message translates to:
  /// **'Otro'**
  String get engineLabelContextOther;

  /// No description provided for @gpsCheckingPermission.
  ///
  /// In es, this message translates to:
  /// **'Comprobando permiso de ubicación…'**
  String get gpsCheckingPermission;

  /// No description provided for @gpsPreparing.
  ///
  /// In es, this message translates to:
  /// **'Preparando GPS de alta precisión…'**
  String get gpsPreparing;

  /// No description provided for @gpsLookingSatellites.
  ///
  /// In es, this message translates to:
  /// **'Buscando satélites…'**
  String get gpsLookingSatellites;

  /// No description provided for @gpsWarming.
  ///
  /// In es, this message translates to:
  /// **'Calentando GPS…'**
  String get gpsWarming;

  /// No description provided for @gpsWarmingAcc.
  ///
  /// In es, this message translates to:
  /// **'Calentando GPS (±{meters} m)…'**
  String gpsWarmingAcc(String meters);

  /// No description provided for @gpsReadyAcc.
  ///
  /// In es, this message translates to:
  /// **'GPS listo (±{meters} m)'**
  String gpsReadyAcc(String meters);

  /// No description provided for @gpsStartWithAcc.
  ///
  /// In es, this message translates to:
  /// **'Arrancando con ±{meters} m — mantén el cielo abierto'**
  String gpsStartWithAcc(String meters);

  /// No description provided for @gpsStartKeepSky.
  ///
  /// In es, this message translates to:
  /// **'Arrancando — mantén el cielo abierto para mejor señal'**
  String get gpsStartKeepSky;

  /// No description provided for @gpsRollingNextLap.
  ///
  /// In es, this message translates to:
  /// **'Rodando hacia la siguiente vuelta…'**
  String get gpsRollingNextLap;

  /// No description provided for @locationServicesOff.
  ///
  /// In es, this message translates to:
  /// **'Activa la ubicación para grabar tu línea.'**
  String get locationServicesOff;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In es, this message translates to:
  /// **'Se necesita permiso de ubicación para dibujar tu línea.'**
  String get locationPermissionDenied;

  /// No description provided for @locationPermissionDeniedForever.
  ///
  /// In es, this message translates to:
  /// **'Activa la ubicación en Ajustes e inténtalo de nuevo.'**
  String get locationPermissionDeniedForever;

  /// No description provided for @leanAtPlayhead.
  ///
  /// In es, this message translates to:
  /// **'En el cursor · offset neutral {degrees}°'**
  String leanAtPlayhead(String degrees);

  /// No description provided for @scrubPointMeta.
  ///
  /// In es, this message translates to:
  /// **'Punto {index}/{total}  ·  {speed}  ·  incl. '**
  String scrubPointMeta(int index, int total, String speed);

  /// No description provided for @scrubGpsMeta.
  ///
  /// In es, this message translates to:
  /// **'  ·  GPS {meters} m'**
  String scrubGpsMeta(String meters);

  /// No description provided for @shareVisibilityHelp.
  ///
  /// In es, this message translates to:
  /// **'Elige quién puede ver este recorrido. Los amigos deben aceptar tu solicitud primero.'**
  String get shareVisibilityHelp;

  /// No description provided for @speedLegendScale.
  ///
  /// In es, this message translates to:
  /// **'azul→lima→amarillo→rojo→magenta'**
  String get speedLegendScale;

  /// No description provided for @brakePeakDecel.
  ///
  /// In es, this message translates to:
  /// **'pico {value} m/s²'**
  String brakePeakDecel(String value);

  /// No description provided for @curvaMetaTurnLean.
  ///
  /// In es, this message translates to:
  /// **'giro {turn}° · incl. {lean}°'**
  String curvaMetaTurnLean(String turn, String lean);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
