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
  /// **'Iniciar ruta'**
  String get startRide;

  /// No description provided for @endRide.
  ///
  /// In es, this message translates to:
  /// **'Terminar ruta'**
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
  /// **'Tus rutas'**
  String get yourRides;

  /// No description provided for @emptyRidesTitle.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay rutas'**
  String get emptyRidesTitle;

  /// No description provided for @emptyRidesBody.
  ///
  /// In es, this message translates to:
  /// **'Inicia una ruta y RiderLab dibujará la línea exacta que tomaste en la calle.'**
  String get emptyRidesBody;

  /// No description provided for @unfinishedRide.
  ///
  /// In es, this message translates to:
  /// **'Ruta sin terminar'**
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
  /// **'Ride Lab'**
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
  /// **'Toca los encabezados para plegar. El playhead queda abajo.'**
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
  /// **'Rectas y curvas'**
  String get sectionRoad;

  /// No description provided for @sectionRoadSub.
  ///
  /// In es, this message translates to:
  /// **'Por cambio de rumbo'**
  String get sectionRoadSub;

  /// No description provided for @sectionLoop.
  ///
  /// In es, this message translates to:
  /// **'Loop'**
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
  /// **'PLAYHEAD'**
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
  /// **'Monta firme (vertical, pantalla hacia ti). Deja la notificación de grabación activa — la pantalla puede bloquearse.'**
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
  /// **'Lean máx'**
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
  /// **'Según rumbo + inclinación. {rectas} rectas · {curvas} curvas. Toca una curva para entrada / ápice / salida — desliza entre curvas.'**
  String roadStretchesHelp(int rectas, int curvas);

  /// No description provided for @roadStretchesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay suficiente cambio de rumbo GPS para separar rectas y curvas.'**
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
  /// **'Playhead'**
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
  /// **'Compartir y ruta'**
  String get shareRideTitle;

  /// No description provided for @shareRideHelp.
  ///
  /// In es, this message translates to:
  /// **'Comparte este ride con amigos y opcionalmente asígnalo a un circuito.'**
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
  /// **'Zoom Ride Lab'**
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
  /// **'Manual'**
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
  /// **'Subir rides a la nube'**
  String get syncCloudRides;

  /// No description provided for @syncCloudRidesHelp.
  ///
  /// In es, this message translates to:
  /// **'Guarda métricas (velocidad, lean, line score, GPS) de todos los rides terminados en tu cuenta.'**
  String get syncCloudRidesHelp;

  /// No description provided for @syncCloudRidesDone.
  ///
  /// In es, this message translates to:
  /// **'Nube: {ok} ok, {fail} fallaron'**
  String syncCloudRidesDone(int ok, int fail);

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
  /// **'Conecta las cámaras aquí antes de salir. Inicia el ride cuando estés listo — el GPS empieza entonces.'**
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
  /// **'Armado sin ruta — el ride irá al Garage, no a Vueltas. Ábrelo desde una ruta o crea una primero.'**
  String get armAutoNoRouteHint;

  /// No description provided for @armAutoRouteArmed.
  ///
  /// In es, this message translates to:
  /// **'Armado — al arrancar se guarda en tu última ruta'**
  String get armAutoRouteArmed;

  /// No description provided for @armAutoRouteArmedNamed.
  ///
  /// In es, this message translates to:
  /// **'Armado para «{name}» — al arrancar el ride queda en esa ruta'**
  String armAutoRouteArmedNamed(String name);
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
