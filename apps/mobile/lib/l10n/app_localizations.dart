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
  /// **'CornerIQ'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In es, this message translates to:
  /// **'Graba la línea que rodaste. Revísala. Mejora cada curva.'**
  String get tagline;

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
  /// **'Inicia una ruta y CornerIQ dibujará la línea exacta que tomaste en la calle.'**
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
  /// **'CornerIQ {version} está lista (tienes {current}).'**
  String updateReady(String version, String current);

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
  /// **'Ya tienes la última CornerIQ.'**
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
  /// **'0° es vertical inferida (sirve con el teléfono en el bolsillo).'**
  String get leanHelp;

  /// No description provided for @mapHint.
  ///
  /// In es, this message translates to:
  /// **'Azul→magenta según velocidad. Puntos = frenos inferidos.'**
  String get mapHint;

  /// No description provided for @mapHintZoom.
  ///
  /// In es, this message translates to:
  /// **'Brillante = tramo elegido · tenue = resto. Puntos = frenos.'**
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
  /// **'Según cambio de rumbo (el lean ayuda al lado). {rectas} rectas · {curvas} curvas. Toca una curva para ver entrada / ápice / salida.'**
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
  /// **'Inferido por qué tan rápido cae la velocidad — no es sensor de freno. Toca un golpe para saltar el playhead.'**
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

  /// No description provided for @openFullscreenMap.
  ///
  /// In es, this message translates to:
  /// **'Abrir mapa completo'**
  String get openFullscreenMap;

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
  /// **'Aún no hay otros riders. Cuando un amigo instale CornerIQ, aparecerá aquí.'**
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
