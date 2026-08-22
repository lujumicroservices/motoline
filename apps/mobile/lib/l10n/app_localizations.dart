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
  /// **'Mejora en cada curva.'**
  String get tagline;

  /// No description provided for @autoPauseToggle.
  ///
  /// In es, this message translates to:
  /// **'Pausar al parar'**
  String get autoPauseToggle;

  /// No description provided for @autoPauseToggleHint.
  ///
  /// In es, this message translates to:
  /// **'La grabación se pausa cuando paras y sigue cuando vuelves a rodar.'**
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
  /// **'Pone el nombre según dónde empezaste y terminaste (ej. Tesistán - Zapopan).'**
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
  /// **'Inicio - fin aún sin nombre'**
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
  /// **'No se encontraron esos lugares'**
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
  /// **'Inicia un recorrido y RiderLab dibuja la línea que tomaste en la calle.'**
  String get emptyRidesBody;

  /// No description provided for @unfinishedRide.
  ///
  /// In es, this message translates to:
  /// **'Recorrido sin terminar'**
  String get unfinishedRide;

  /// No description provided for @unfinishedRideBody.
  ///
  /// In es, this message translates to:
  /// **'Empezó {when}. Termínalo para guardar la línea, o bórralo.'**
  String unfinishedRideBody(String when);

  /// No description provided for @discard.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get discard;

  /// No description provided for @keepLine.
  ///
  /// In es, this message translates to:
  /// **'Guardar línea'**
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
  /// **'Lab del recorrido'**
  String get rideLab;

  /// No description provided for @rideLabSegment.
  ///
  /// In es, this message translates to:
  /// **'Lab del recorrido · este tramo'**
  String get rideLabSegment;

  /// No description provided for @rideNotFound.
  ///
  /// In es, this message translates to:
  /// **'Recorrido no encontrado'**
  String get rideNotFound;

  /// No description provided for @collapseHint.
  ///
  /// In es, this message translates to:
  /// **'Toca un título para ocultarlo. El marcador se queda abajo.'**
  String get collapseHint;

  /// No description provided for @segmentZoomHint.
  ///
  /// In es, this message translates to:
  /// **'Solo este tramo — números y gráficas son de esta parte del recorrido.'**
  String get segmentZoomHint;

  /// No description provided for @sectionSegment.
  ///
  /// In es, this message translates to:
  /// **'Este tramo'**
  String get sectionSegment;

  /// No description provided for @sectionSegmentSub.
  ///
  /// In es, this message translates to:
  /// **'Elige una parte del recorrido'**
  String get sectionSegmentSub;

  /// No description provided for @sectionOverview.
  ///
  /// In es, this message translates to:
  /// **'Resumen'**
  String get sectionOverview;

  /// No description provided for @sectionOverviewSub.
  ///
  /// In es, this message translates to:
  /// **'Puntaje y números del recorrido'**
  String get sectionOverviewSub;

  /// No description provided for @sectionOverviewSubZoom.
  ///
  /// In es, this message translates to:
  /// **'Puntaje y números de este tramo'**
  String get sectionOverviewSubZoom;

  /// No description provided for @sectionLean.
  ///
  /// In es, this message translates to:
  /// **'Inclinación'**
  String get sectionLean;

  /// No description provided for @sectionLeanSub.
  ///
  /// In es, this message translates to:
  /// **'Azul izquierda · amarillo derecha'**
  String get sectionLeanSub;

  /// No description provided for @sectionMap.
  ///
  /// In es, this message translates to:
  /// **'Mapa + línea'**
  String get sectionMap;

  /// No description provided for @sectionMapSub.
  ///
  /// In es, this message translates to:
  /// **'Color = velocidad · puntos = frenos'**
  String get sectionMapSub;

  /// No description provided for @sectionRoad.
  ///
  /// In es, this message translates to:
  /// **'Curvas'**
  String get sectionRoad;

  /// No description provided for @sectionRoadSub.
  ///
  /// In es, this message translates to:
  /// **'Por el giro y la inclinación'**
  String get sectionRoadSub;

  /// No description provided for @sectionLoop.
  ///
  /// In es, this message translates to:
  /// **'Vueltas'**
  String get sectionLoop;

  /// No description provided for @sectionLoopSub.
  ///
  /// In es, this message translates to:
  /// **'Encuentra vueltas o marca inicio y fin'**
  String get sectionLoopSub;

  /// No description provided for @sectionBrakes.
  ///
  /// In es, this message translates to:
  /// **'Frenado'**
  String get sectionBrakes;

  /// No description provided for @sectionBrakesSub.
  ///
  /// In es, this message translates to:
  /// **'Se calcula por qué tan rápido bajas de velocidad'**
  String get sectionBrakesSub;

  /// No description provided for @sectionCharts.
  ///
  /// In es, this message translates to:
  /// **'Gráficas'**
  String get sectionCharts;

  /// No description provided for @sectionChartsSub.
  ///
  /// In es, this message translates to:
  /// **'Velocidad · inclinación · GPS'**
  String get sectionChartsSub;

  /// No description provided for @sectionNotes.
  ///
  /// In es, this message translates to:
  /// **'Precisión + notas'**
  String get sectionNotes;

  /// No description provided for @sectionNotesSub.
  ///
  /// In es, this message translates to:
  /// **'Calidad del GPS y notas'**
  String get sectionNotesSub;

  /// No description provided for @segment.
  ///
  /// In es, this message translates to:
  /// **'TRAMO'**
  String get segment;

  /// No description provided for @segmentZoom.
  ///
  /// In es, this message translates to:
  /// **'ESTE TRAMO'**
  String get segmentZoom;

  /// No description provided for @segmentHint.
  ///
  /// In es, this message translates to:
  /// **'Arrastra los controles para elegir un tramo y luego acércalo.'**
  String get segmentHint;

  /// No description provided for @segmentHintZoomed.
  ///
  /// In es, this message translates to:
  /// **'El mapa y los números muestran solo este tramo. Arrastra para cambiarlo.'**
  String get segmentHintZoomed;

  /// No description provided for @zoomToSegment.
  ///
  /// In es, this message translates to:
  /// **'Acercar a este tramo'**
  String get zoomToSegment;

  /// No description provided for @fullRide.
  ///
  /// In es, this message translates to:
  /// **'Recorrido completo'**
  String get fullRide;

  /// No description provided for @playhead.
  ///
  /// In es, this message translates to:
  /// **'MARCADOR'**
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
  /// **'Guardando 0°…'**
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
  /// **'Qué tan preciso está el GPS, en metros (más bajo es mejor)'**
  String get gpsPrecisionSub;

  /// No description provided for @chartSpeedSub.
  ///
  /// In es, this message translates to:
  /// **'Los colores son la velocidad. Toca para moverte en el recorrido.'**
  String get chartSpeedSub;

  /// No description provided for @chartSpeedSubZoom.
  ///
  /// In es, this message translates to:
  /// **'Solo la velocidad de este tramo. Toca para moverte.'**
  String get chartSpeedSubZoom;

  /// No description provided for @leanHelp.
  ///
  /// In es, this message translates to:
  /// **'0° es la moto derecha. Para que salga bien, fija el teléfono en el tanque o el manubrio, pantalla hacia ti. Un bolsillo suelto tira el número.'**
  String get leanHelp;

  /// No description provided for @leanPhoneDisclaimer.
  ///
  /// In es, this message translates to:
  /// **'Cómo llevas el teléfono importa: derecho, pantalla hacia ti, bien sujeto. Un bolsillo suelto hace ver mal la inclinación.'**
  String get leanPhoneDisclaimer;

  /// No description provided for @mapHint.
  ///
  /// In es, this message translates to:
  /// **'Toca la línea para mover la moto. El color es la velocidad. Los puntos son frenos.'**
  String get mapHint;

  /// No description provided for @mapHintZoom.
  ///
  /// In es, this message translates to:
  /// **'Toca la línea para mover la moto. Brillante = este tramo · tenue = el resto.'**
  String get mapHintZoom;

  /// No description provided for @startingRide.
  ///
  /// In es, this message translates to:
  /// **'Iniciando recorrido'**
  String get startingRide;

  /// No description provided for @gpsReady.
  ///
  /// In es, this message translates to:
  /// **'GPS listo'**
  String get gpsReady;

  /// No description provided for @gpsWarmHelp.
  ///
  /// In es, this message translates to:
  /// **'Quédate afuera con cielo abierto. La grabación empieza cuando el GPS esté suficientemente bien (cerca de ±{meters} m).'**
  String gpsWarmHelp(String meters);

  /// No description provided for @horizontalAccuracy.
  ///
  /// In es, this message translates to:
  /// **'PRECISIÓN GPS'**
  String get horizontalAccuracy;

  /// No description provided for @lowerBetter.
  ///
  /// In es, this message translates to:
  /// **'Menor es mejor · listo a ±{meters} m'**
  String lowerBetter(String meters);

  /// No description provided for @couldNotStart.
  ///
  /// In es, this message translates to:
  /// **'No se pudo iniciar el recorrido'**
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
  /// **'El 0° ya está guardado. Puedes bloquear la pantalla — deja la notificación de grabación encendida.'**
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
  /// **'Punto más cerrado'**
  String get apex;

  /// No description provided for @exit.
  ///
  /// In es, this message translates to:
  /// **'Salida'**
  String get exit;

  /// No description provided for @brakeToApex.
  ///
  /// In es, this message translates to:
  /// **'Freno al punto más cerrado'**
  String get brakeToApex;

  /// No description provided for @accelFromApex.
  ///
  /// In es, this message translates to:
  /// **'Acelera después del punto más cerrado'**
  String get accelFromApex;

  /// No description provided for @leanAtApex.
  ///
  /// In es, this message translates to:
  /// **'Inclinación en el punto más cerrado'**
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
  /// **'E = entrada · A = punto más cerrado · S = salida. El color es la velocidad.'**
  String get curvaMapLegend;

  /// No description provided for @curvaCoach.
  ///
  /// In es, this message translates to:
  /// **'Revisa rápido: si entraste muy rápido (mucho freno antes de A), si el centro de la curva iba estable y si saliste acelerando limpio.'**
  String get curvaCoach;

  /// No description provided for @roadStretchesHelp.
  ///
  /// In es, this message translates to:
  /// **'Curvas según el giro y la inclinación. {curvas} curvas. Toca una para ver entrada, centro y salida — desliza para la siguiente.'**
  String roadStretchesHelp(int curvas);

  /// No description provided for @roadStretchesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay suficiente giro en el GPS para detectar curvas.'**
  String get roadStretchesEmpty;

  /// No description provided for @openDetail.
  ///
  /// In es, this message translates to:
  /// **'abrir detalle'**
  String get openDetail;

  /// No description provided for @brakesHelp.
  ///
  /// In es, this message translates to:
  /// **'Se calcula por qué tan rápido baja la velocidad — no es un sensor de freno. Toca una marca para ir ahí. El botón del mapa acerca ese freno.'**
  String get brakesHelp;

  /// No description provided for @brakesEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay frenadas claras por GPS. Las paradas fuertes suelen verse amarillo, naranja o rojo.'**
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
  /// **'Mueve y acerca el mapa. Dibuja un recuadro o usa lo que se ve, y luego carga los números de ese tramo.'**
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
  /// **'Cargar números de esta área'**
  String get loadAreaMetrics;

  /// No description provided for @areaReady.
  ///
  /// In es, this message translates to:
  /// **'Área lista · {points} puntos GPS. Carga los números para ver este tramo en el lab.'**
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
  /// **'Ajustar recorrido'**
  String get fitRide;

  /// No description provided for @myLocation.
  ///
  /// In es, this message translates to:
  /// **'Mi ubicación'**
  String get myLocation;

  /// No description provided for @myLocationUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No se pudo obtener tu ubicación.'**
  String get myLocationUnavailable;

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
  /// **'Marcador'**
  String get mapLayerPlayhead;

  /// No description provided for @mapLayerLegend.
  ///
  /// In es, this message translates to:
  /// **'Leyenda'**
  String get mapLayerLegend;

  /// No description provided for @mapLayerGpsGaps.
  ///
  /// In es, this message translates to:
  /// **'Huecos GPS'**
  String get mapLayerGpsGaps;

  /// No description provided for @friends.
  ///
  /// In es, this message translates to:
  /// **'Amigos'**
  String get friends;

  /// No description provided for @friendsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Grupo cerrado — quien tenga la app aparece aquí.'**
  String get friendsSubtitle;

  /// No description provided for @friendsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay otros riders. Cuando un amigo instale RiderLab, aparece aquí.'**
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
  /// **'Comparar recorridos'**
  String get compareTitle;

  /// No description provided for @comparePickPeer.
  ///
  /// In es, this message translates to:
  /// **'Recorridos de amigos en la misma zona'**
  String get comparePickPeer;

  /// No description provided for @compareEmpty.
  ///
  /// In es, this message translates to:
  /// **'Ningún recorrido de amigos cubre esta zona todavía.'**
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
  /// **'Elige una primera vuelta y una segunda para comparar tiempos y líneas en el mismo circuito.'**
  String get compareLocalHelp;

  /// No description provided for @compareLocalEmpty.
  ///
  /// In es, this message translates to:
  /// **'Necesitas al menos 2 vueltas terminadas en esta ruta. Usa el modo vueltas o marca recorridos con la misma ruta.'**
  String get compareLocalEmpty;

  /// No description provided for @compareBaseline.
  ///
  /// In es, this message translates to:
  /// **'Base'**
  String get compareBaseline;

  /// No description provided for @compareChallenger.
  ///
  /// In es, this message translates to:
  /// **'Segunda vuelta'**
  String get compareChallenger;

  /// No description provided for @compareLocal.
  ///
  /// In es, this message translates to:
  /// **'Comparar vueltas ({count})'**
  String compareLocal(int count);

  /// No description provided for @compareDeltaFaster.
  ///
  /// In es, this message translates to:
  /// **'La segunda vuelta es más rápida por {delta}'**
  String compareDeltaFaster(String delta);

  /// No description provided for @compareDeltaSlower.
  ///
  /// In es, this message translates to:
  /// **'La segunda vuelta es más lenta por {delta}'**
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
  /// **'Recorridos compartidos'**
  String get friendRides;

  /// No description provided for @friendRidesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Este rider aún no tiene recorridos compartidos.'**
  String get friendRidesEmpty;

  /// No description provided for @syncingRide.
  ///
  /// In es, this message translates to:
  /// **'Compartiendo el recorrido con amigos…'**
  String get syncingRide;

  /// No description provided for @cloudUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No hay conexión con la nube — revisa internet e inténtalo de nuevo.'**
  String get cloudUnavailable;

  /// No description provided for @cloudAnonymousOff.
  ///
  /// In es, this message translates to:
  /// **'Amigos necesita el inicio de sesión activado en la nube de RiderLab. Pregunta a quien configuró la app, luego abre Amigos otra vez y desliza para actualizar.'**
  String get cloudAnonymousOff;

  /// No description provided for @routesTitle.
  ///
  /// In es, this message translates to:
  /// **'Rutas'**
  String get routesTitle;

  /// No description provided for @routesHelp.
  ///
  /// In es, this message translates to:
  /// **'Nombra un circuito, compártelo y marca recorridos para que los amigos comparen en el mismo camino.'**
  String get routesHelp;

  /// No description provided for @routesHowTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo se usan las rutas?'**
  String get routesHowTitle;

  /// No description provided for @routesHowBody.
  ///
  /// In es, this message translates to:
  /// **'1) Crea una ruta con + (ej. «Glorieta norte»).\n2) Abre la ruta → pestaña Vueltas: encuentra vueltas cerradas en recorridos marcados, o marca tú el inicio (A) y el fin (B).\n3) Inicia un recorrido de vueltas desde una vuelta guardada — cada vuelta se guarda en esta ruta.\n4) O en el lab del recorrido → Compartir, marca cualquier recorrido con esta ruta.\n5) Activa «compartida» si quieres que los amigos comparen el mismo circuito.'**
  String get routesHowBody;

  /// No description provided for @routesTapHint.
  ///
  /// In es, this message translates to:
  /// **'Toca para ver vueltas'**
  String get routesTapHint;

  /// No description provided for @routesLoopReady.
  ///
  /// In es, this message translates to:
  /// **'Vuelta lista'**
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
  /// **'Vista previa de 0,5 s. Con Pro ves entrada, centro, salida y el mapa sin bloqueo.'**
  String get proCurvaBannerBody;

  /// No description provided for @proNotesBannerTitle.
  ///
  /// In es, this message translates to:
  /// **'Precisión + notas · Pro'**
  String get proNotesBannerTitle;

  /// No description provided for @proNotesBannerBody.
  ///
  /// In es, this message translates to:
  /// **'La calidad del GPS y los tips de manejo están en RiderLab Pro.'**
  String get proNotesBannerBody;

  /// No description provided for @proFeatureCurva.
  ///
  /// In es, this message translates to:
  /// **'Detalle completo de curvas (sin banner)'**
  String get proFeatureCurva;

  /// No description provided for @proFeatureNotes.
  ///
  /// In es, this message translates to:
  /// **'Precisión GPS + notas de manejo'**
  String get proFeatureNotes;

  /// No description provided for @myRoutes.
  ///
  /// In es, this message translates to:
  /// **'Tus rutas'**
  String get myRoutes;

  /// No description provided for @routesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay rutas — crea una para marcar y compartir recorridos.'**
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
  /// **'Los amigos ven este circuito y pueden comparar recorridos marcados.'**
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
  /// **'Compartir este recorrido'**
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
  /// **'Empezar al rodar'**
  String get armAutoRide;

  /// No description provided for @disarmAutoRide.
  ///
  /// In es, this message translates to:
  /// **'Cancelar arranque auto'**
  String get disarmAutoRide;

  /// No description provided for @waitingForMotion.
  ///
  /// In es, this message translates to:
  /// **'Esperando movimiento…'**
  String get waitingForMotion;

  /// No description provided for @armedBannerBody.
  ///
  /// In es, this message translates to:
  /// **'RiderLab empieza a grabar sola cuando te empiezas a mover.'**
  String get armedBannerBody;

  /// No description provided for @armedSessionTitle.
  ///
  /// In es, this message translates to:
  /// **'Ruta armada'**
  String get armedSessionTitle;

  /// No description provided for @armedSessionOpen.
  ///
  /// In es, this message translates to:
  /// **'Ver sesión'**
  String get armedSessionOpen;

  /// No description provided for @armedSessionMinimize.
  ///
  /// In es, this message translates to:
  /// **'Minimizar'**
  String get armedSessionMinimize;

  /// No description provided for @armedSessionWatchRecording.
  ///
  /// In es, this message translates to:
  /// **'Ver grabación'**
  String get armedSessionWatchRecording;

  /// No description provided for @armedSessionEndArm.
  ///
  /// In es, this message translates to:
  /// **'Terminar armado'**
  String get armedSessionEndArm;

  /// No description provided for @armedSessionStretchesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay tramos. Cuando empieces a rodar, aparecerán aquí.'**
  String get armedSessionStretchesEmpty;

  /// No description provided for @armedSessionStretchN.
  ///
  /// In es, this message translates to:
  /// **'Tramo {n}'**
  String armedSessionStretchN(int n);

  /// No description provided for @armedSessionWaitingHelp.
  ///
  /// In es, this message translates to:
  /// **'GPS listo. La grabación arranca sola al moverte.'**
  String get armedSessionWaitingHelp;

  /// No description provided for @armedSessionLiveHelp.
  ///
  /// In es, this message translates to:
  /// **'Grabando. Puedes salir de esta pantalla; el recorrido sigue.'**
  String get armedSessionLiveHelp;

  /// No description provided for @loopMode.
  ///
  /// In es, this message translates to:
  /// **'Modo vueltas'**
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
  /// **'Sin movimiento hace rato. Termina el recorrido o sigue rodando.'**
  String get suggestEndBody;

  /// No description provided for @keepRiding.
  ///
  /// In es, this message translates to:
  /// **'Seguir rodando'**
  String get keepRiding;

  /// No description provided for @markLoopInit.
  ///
  /// In es, this message translates to:
  /// **'Marcar inicio de vuelta'**
  String get markLoopInit;

  /// No description provided for @loopInitSet.
  ///
  /// In es, this message translates to:
  /// **'Inicio marcado'**
  String get loopInitSet;

  /// No description provided for @markLoopEnd.
  ///
  /// In es, this message translates to:
  /// **'Marcar fin de vuelta'**
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
  /// **'Abre el mapa completo, muévelo y toca el punto A (inicio) y el B (fin).'**
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
  /// **'A y B listos — confirma para contar vueltas'**
  String get loopPointsReady;

  /// No description provided for @loopMarkMapHelp.
  ///
  /// In es, this message translates to:
  /// **'Mueve y acerca el mapa. Primer toque = A, segundo = B. El círculo es donde se cuenta la vuelta.'**
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
  /// **'Listo para contar vueltas'**
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
  /// **'Elige cualquier tramo, detalle completo de curvas, notas de GPS, frenadas completas y sin anuncios.'**
  String get proUnlockBody;

  /// No description provided for @proFeatureSegment.
  ///
  /// In es, this message translates to:
  /// **'Acercar cualquier parte del recorrido'**
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
  /// **'Desbloqueo temporal hasta conectar la tienda. Apágalo para ver la versión gratis.'**
  String get proToggleHelp;

  /// No description provided for @brakesProTeaser.
  ///
  /// In es, this message translates to:
  /// **'Mostrando {shown} de {total}. Desbloquea Pro para el historial completo de frenadas.'**
  String brakesProTeaser(int shown, int total);

  /// No description provided for @segmentProLocked.
  ///
  /// In es, this message translates to:
  /// **'Elegir un tramo del recorrido es una función Pro.'**
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
  /// **'Vueltas'**
  String get routeTabLoop;

  /// No description provided for @routeLoopModuleHelp.
  ///
  /// In es, this message translates to:
  /// **'Las vueltas pertenecen a esta ruta. Encuentra vueltas cerradas en recorridos marcados, o marca tú el inicio (A) y el fin (B) en el mapa.'**
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
  /// **'Vueltas guardadas'**
  String get routeLoopSavedTitle;

  /// No description provided for @routeLoopEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay vueltas — encuéntralas en recorridos o marca A y B en el mapa.'**
  String get routeLoopEmpty;

  /// No description provided for @routeLoopDetectedTitle.
  ///
  /// In es, this message translates to:
  /// **'Vueltas posibles'**
  String get routeLoopDetectedTitle;

  /// No description provided for @routeLoopDetectedEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay vueltas cerradas en los recorridos marcados. Rueda el circuito e inténtalo de nuevo.'**
  String get routeLoopDetectedEmpty;

  /// No description provided for @routeLoopDetectedHint.
  ///
  /// In es, this message translates to:
  /// **'Camino cerrado según el GPS — guárdalo para que cuente las vueltas solo.'**
  String get routeLoopDetectedHint;

  /// No description provided for @routeLoopSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get routeLoopSave;

  /// No description provided for @routeLoopSaved.
  ///
  /// In es, this message translates to:
  /// **'Vuelta guardada en esta ruta'**
  String get routeLoopSaved;

  /// No description provided for @routeLoopManualName.
  ///
  /// In es, this message translates to:
  /// **'Vuelta a mano'**
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
  /// **'Iniciar recorrido de vueltas'**
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
  /// **'Se borra esta ruta, sus vueltas y se desmarcan los recorridos. Si está compartida, desaparece para todos.'**
  String get deleteRouteBody;

  /// No description provided for @routeDeleted.
  ///
  /// In es, this message translates to:
  /// **'Ruta eliminada'**
  String get routeDeleted;

  /// No description provided for @deleteLoop.
  ///
  /// In es, this message translates to:
  /// **'Eliminar vuelta'**
  String get deleteLoop;

  /// No description provided for @deleteLoopBody.
  ///
  /// In es, this message translates to:
  /// **'Se elimina esta vuelta. Si era la principal, también se quitan los puntos A/B de la ruta (los amigos lo ven al sincronizar).'**
  String get deleteLoopBody;

  /// No description provided for @loopDeleted.
  ///
  /// In es, this message translates to:
  /// **'Vuelta eliminada'**
  String get loopDeleted;

  /// No description provided for @deleteAllLoops.
  ///
  /// In es, this message translates to:
  /// **'Quitar todas las vueltas'**
  String get deleteAllLoops;

  /// No description provided for @deleteAllLoopsBody.
  ///
  /// In es, this message translates to:
  /// **'Se borran todas las vueltas de esta ruta y los puntos A/B. Los amigos verán la ruta sin vueltas al sincronizar.'**
  String get deleteAllLoopsBody;

  /// No description provided for @loopsCleared.
  ///
  /// In es, this message translates to:
  /// **'Vueltas eliminadas'**
  String get loopsCleared;

  /// No description provided for @deleteConfirm.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get deleteConfirm;

  /// No description provided for @deleteRide.
  ///
  /// In es, this message translates to:
  /// **'Eliminar recorrido'**
  String get deleteRide;

  /// No description provided for @deleteRideBody.
  ///
  /// In es, this message translates to:
  /// **'Se borra el recorrido y su línea GPS de este teléfono (y de la nube si estaba sincronizado).'**
  String get deleteRideBody;

  /// No description provided for @rideDeleted.
  ///
  /// In es, this message translates to:
  /// **'Recorrido eliminado'**
  String get rideDeleted;

  /// No description provided for @accountSection.
  ///
  /// In es, this message translates to:
  /// **'Cuenta'**
  String get accountSection;

  /// No description provided for @accountGuest.
  ///
  /// In es, this message translates to:
  /// **'Invitado'**
  String get accountGuest;

  /// No description provided for @accountGuestBody.
  ///
  /// In es, this message translates to:
  /// **'Estás como invitado. Inicia sesión para guardar tu perfil en otros teléfonos — tus recorridos se vinculan cuando se puede.'**
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
  /// **'Encuentra vueltas cerradas en el GPS de este recorrido, o marca inicio (A) y fin (B) en el mapa. Al guardar se crea o usa una ruta para contar vueltas después.'**
  String get rideLoopHelp;

  /// No description provided for @rideLoopEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay vueltas guardadas en la ruta de este recorrido.'**
  String get rideLoopEmpty;

  /// No description provided for @rideLoopDetectedEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay vuelta cerrada en este recorrido. Prueba Marcar A / B en el mapa.'**
  String get rideLoopDetectedEmpty;

  /// No description provided for @rideLoopNeedPoints.
  ///
  /// In es, this message translates to:
  /// **'No hay suficientes puntos GPS para marcar una vuelta.'**
  String get rideLoopNeedPoints;

  /// No description provided for @rideLoopSaveFirst.
  ///
  /// In es, this message translates to:
  /// **'Guarda una vuelta primero — eso crea la ruta.'**
  String get rideLoopSaveFirst;

  /// No description provided for @rideLoopOpenRoute.
  ///
  /// In es, this message translates to:
  /// **'Abrir ruta (vueltas)'**
  String get rideLoopOpenRoute;

  /// No description provided for @syncCloudRides.
  ///
  /// In es, this message translates to:
  /// **'Sincronizar recorridos con la nube'**
  String get syncCloudRides;

  /// No description provided for @syncCloudRidesHelp.
  ///
  /// In es, this message translates to:
  /// **'Sube los recorridos terminados y descarga a este teléfono los del garaje y las sesiones de Lab de inclinación de esta cuenta.'**
  String get syncCloudRidesHelp;

  /// No description provided for @syncCloudRidesDone.
  ///
  /// In es, this message translates to:
  /// **'Subida: {ok} ok, {fail} fallaron'**
  String syncCloudRidesDone(int ok, int fail);

  /// No description provided for @syncCloudRidesPulled.
  ///
  /// In es, this message translates to:
  /// **'Descargados {rides} recorridos, {lean} Lab de inclinación'**
  String syncCloudRidesPulled(int rides, int lean);

  /// No description provided for @playStoreUpdatesOnly.
  ///
  /// In es, this message translates to:
  /// **'En esta versión las actualizaciones llegan por Google Play.'**
  String get playStoreUpdatesOnly;

  /// No description provided for @labSection.
  ///
  /// In es, this message translates to:
  /// **'Lab (pruebas)'**
  String get labSection;

  /// No description provided for @labAdventureCameraHelp.
  ///
  /// In es, this message translates to:
  /// **'GoPro opcional junto con el recorrido. Apagada por defecto — el GPS no cambia.'**
  String get labAdventureCameraHelp;

  /// No description provided for @labAdventureCameraEnable.
  ///
  /// In es, this message translates to:
  /// **'Cámara de aventura'**
  String get labAdventureCameraEnable;

  /// No description provided for @labAdventureCameraEnableHelp.
  ///
  /// In es, this message translates to:
  /// **'Activa las herramientas de cámara en este teléfono'**
  String get labAdventureCameraEnableHelp;

  /// No description provided for @labAdventureCameraSyncRide.
  ///
  /// In es, this message translates to:
  /// **'Grabar con el recorrido'**
  String get labAdventureCameraSyncRide;

  /// No description provided for @labAdventureCameraSyncRideHelp.
  ///
  /// In es, this message translates to:
  /// **'Inicia y para con todo el recorrido. Si hay puntos de inicio en el mapa, la cámara espera hasta llegar a uno.'**
  String get labAdventureCameraSyncRideHelp;

  /// No description provided for @labAdventureCameraSyncPause.
  ///
  /// In es, this message translates to:
  /// **'Seguir la pausa auto'**
  String get labAdventureCameraSyncPause;

  /// No description provided for @labAdventureCameraSyncPauseHelp.
  ///
  /// In es, this message translates to:
  /// **'Para la cámara mientras la pausa auto del GPS está activa (opcional)'**
  String get labAdventureCameraSyncPauseHelp;

  /// No description provided for @labAdventureCameraBackend.
  ///
  /// In es, this message translates to:
  /// **'Tipo de cámara'**
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
  /// **'Prueba el disparo a mano — no hace falta un recorrido. Conecta primero (o usa Simular).'**
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
  /// **'Inicio/parada en el mapa'**
  String get labAdventureCameraZonesEnable;

  /// No description provided for @labAdventureCameraZonesEnableHelp.
  ///
  /// In es, this message translates to:
  /// **'Inicia y para al entrar en zonas del mapa. La cámara se queda apagada hasta el punto de inicio.'**
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
  /// **'Iniciar recorrido'**
  String get rideDeckTitle;

  /// No description provided for @rideDeckHelp.
  ///
  /// In es, this message translates to:
  /// **'Toca una vez, pon el teléfono en el bolsillo o en el tanque, quédate quieto. Cuando sientas vibrar y un beep, el 0° quedó guardado y el recorrido arranca — no vuelves a tocar.'**
  String get rideDeckHelp;

  /// No description provided for @startRideNow.
  ///
  /// In es, this message translates to:
  /// **'Iniciar recorrido ahora'**
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
  /// **'1. Enciende cada GoPro y abre la tapa lateral (Bluetooth activo).\n2. En el teléfono, permite Bluetooth (y dispositivos cercanos) si lo pide.\n3. Toca Añadir GoPro — espera el escaneo y elige cada cámara.\n4. Déjalas activas en la lista (apaga el interruptor para omitir una).\n5. Toca Conectar para enlazar todo el grupo.\n6. Inicia un recorrido (o usa zonas del mapa / auto-grabar agresivo) — el disparo arranca/para en todas las cámaras activas.\n7. En la pantalla del recorrido, CAM 2/2 significa que ambas están grabando.\n\nConsejos: acerca el teléfono a las cámaras en el primer enlace. Si una solo enciende y no graba, Conecta de nuevo y luego inicia el recorrido. Si una falla, las demás siguen.'**
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
  /// **'ON: Cámara de aventura · Zonas inicio/fin en el mapa (coloca Inicio + Parada) · cámaras en el grupo.\nOFF: Grabar con el recorrido · Auto-grabar conducción agresiva · Seguir pausa auto.\n\nNota: estas son zonas de cámara del Lab — no los puntos A/B de vueltas de la ruta.'**
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
  /// **'ON: Cámara de aventura · Auto-grabar conducción agresiva · cámaras en el grupo.\nOFF: Grabar con el recorrido · Zonas inicio/fin en el mapa · Seguir pausa auto.'**
  String get labAdventureCameraScenarioAggressiveBody;

  /// No description provided for @labAdventureCameraScenarioAggressiveApply.
  ///
  /// In es, this message translates to:
  /// **'Aplicar setup solo agresivo'**
  String get labAdventureCameraScenarioAggressiveApply;

  /// No description provided for @armAutoNoRouteHint.
  ///
  /// In es, this message translates to:
  /// **'Listo — al rodar se inicia un recorrido en el garaje.'**
  String get armAutoNoRouteHint;

  /// No description provided for @freezeThenArmHelp.
  ///
  /// In es, this message translates to:
  /// **'Toca una vez, coloca el teléfono, quédate quieto. Un vibrar y un beep confirman que el 0° quedó guardado. Luego bloquea la pantalla — al arrancar se inicia el recorrido. No vuelves a tocar.'**
  String get freezeThenArmHelp;

  /// No description provided for @armAutoRouteArmed.
  ///
  /// In es, this message translates to:
  /// **'Listo — al arrancar se inicia el recorrido'**
  String get armAutoRouteArmed;

  /// No description provided for @armAutoRouteArmedNamed.
  ///
  /// In es, this message translates to:
  /// **'Listo para «{name}» — el recorrido se guarda en esa ruta'**
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

  /// No description provided for @familyCircleTitle.
  ///
  /// In es, this message translates to:
  /// **'Círculo familiar'**
  String get familyCircleTitle;

  /// No description provided for @familyCircleHomeTile.
  ///
  /// In es, this message translates to:
  /// **'Quién puede saber que estás bien al rodar'**
  String get familyCircleHomeTile;

  /// No description provided for @familyCircleHelp.
  ///
  /// In es, this message translates to:
  /// **'Agrega contactos aquí. El link se genera al Grabar o en una Rodada (En vivo). Puedes reenviarlo a más personas sin romper los anteriores.'**
  String get familyCircleHelp;

  /// No description provided for @familyHowToShareTitle.
  ///
  /// In es, this message translates to:
  /// **'Cómo mandar el link'**
  String get familyHowToShareTitle;

  /// No description provided for @familyHowToShareSteps.
  ///
  /// In es, this message translates to:
  /// **'1) En Grabar o en una Rodada (pestaña En vivo).\n2) Toca el icono de compartir.\n3) Elige contactos — el mismo link sirve para todos.\n\n«Compartir en vivo» del pack es aparte: solo riders con la app.'**
  String get familyHowToShareSteps;

  /// No description provided for @familyShareNeedsRide.
  ///
  /// In es, this message translates to:
  /// **'Primero inicia una grabación o abre una Rodada. Luego aparece el botón para compartir el link.'**
  String get familyShareNeedsRide;

  /// No description provided for @familyShareFromCircle.
  ///
  /// In es, this message translates to:
  /// **'Compartir link ahora'**
  String get familyShareFromCircle;

  /// No description provided for @familyRodadaTipTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Link para familia?'**
  String get familyRodadaTipTitle;

  /// No description provided for @familyRodadaTipBody.
  ///
  /// In es, this message translates to:
  /// **'Pack = mapa de la rodada en la app. Familia sin app = compartir desde En vivo (mismo link se puede reenviar).'**
  String get familyRodadaTipBody;

  /// No description provided for @familyRodadaTipCta.
  ///
  /// In es, this message translates to:
  /// **'Ver círculo familiar'**
  String get familyRodadaTipCta;

  /// No description provided for @familyAppBarShareTooltip.
  ///
  /// In es, this message translates to:
  /// **'Avisar a familia'**
  String get familyAppBarShareTooltip;

  /// No description provided for @familyAddContact.
  ///
  /// In es, this message translates to:
  /// **'Agregar contacto'**
  String get familyAddContact;

  /// No description provided for @familyContactLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get familyContactLabel;

  /// No description provided for @familyContactLabelHint.
  ///
  /// In es, this message translates to:
  /// **'Mamá / Ana / …'**
  String get familyContactLabelHint;

  /// No description provided for @familyOptionalFriend.
  ///
  /// In es, this message translates to:
  /// **'Opcional: vincular un amigo de RiderLab'**
  String get familyOptionalFriend;

  /// No description provided for @familyNoFriendsYet.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay amigos — puedes poner un nombre y compartir el link.'**
  String get familyNoFriendsYet;

  /// No description provided for @familySaveContact.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get familySaveContact;

  /// No description provided for @familyMyCircle.
  ///
  /// In es, this message translates to:
  /// **'Mi círculo'**
  String get familyMyCircle;

  /// No description provided for @familyCircleEmpty.
  ///
  /// In es, this message translates to:
  /// **'Sin contactos. Agrega a alguien antes de la próxima salida.'**
  String get familyCircleEmpty;

  /// No description provided for @familyLinkOnlyContact.
  ///
  /// In es, this message translates to:
  /// **'Recibe el link (sin cuenta en la app)'**
  String get familyLinkOnlyContact;

  /// No description provided for @familyAppContact.
  ///
  /// In es, this message translates to:
  /// **'También puede ver en la app'**
  String get familyAppContact;

  /// No description provided for @familyWatchingNow.
  ///
  /// In es, this message translates to:
  /// **'Rodando ahora'**
  String get familyWatchingNow;

  /// No description provided for @familyNoActiveWatches.
  ///
  /// In es, this message translates to:
  /// **'Nadie de tu círculo está compartiendo una salida ahora.'**
  String get familyNoActiveWatches;

  /// No description provided for @familyTapToWatch.
  ///
  /// In es, this message translates to:
  /// **'Toca para abrir el mapa'**
  String get familyTapToWatch;

  /// No description provided for @familyRiderFallback.
  ///
  /// In es, this message translates to:
  /// **'Rider'**
  String get familyRiderFallback;

  /// No description provided for @familyNotifyToggle.
  ///
  /// In es, this message translates to:
  /// **'Avisar a familia'**
  String get familyNotifyToggle;

  /// No description provided for @familyNotifyHelp.
  ///
  /// In es, this message translates to:
  /// **'Genera un link y abre el menú de compartir para mandárselo a tu familiar (no necesitan la app).'**
  String get familyNotifyHelp;

  /// No description provided for @familyNotifyHelpRodada.
  ///
  /// In es, this message translates to:
  /// **'Avisa a familia/amigos fuera del pack. Puedes reenviar el mismo link a más personas.'**
  String get familyNotifyHelpRodada;

  /// No description provided for @familyNotifyStart.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get familyNotifyStart;

  /// No description provided for @familyWatchActive.
  ///
  /// In es, this message translates to:
  /// **'Familia puede verte'**
  String get familyWatchActive;

  /// No description provided for @familyWatchStop.
  ///
  /// In es, this message translates to:
  /// **'Parar'**
  String get familyWatchStop;

  /// No description provided for @familyOk.
  ///
  /// In es, this message translates to:
  /// **'Todo bien'**
  String get familyOk;

  /// No description provided for @familyStopped.
  ///
  /// In es, this message translates to:
  /// **'Me detuve'**
  String get familyStopped;

  /// No description provided for @familySos.
  ///
  /// In es, this message translates to:
  /// **'Necesito ayuda'**
  String get familySos;

  /// No description provided for @familyShareLink.
  ///
  /// In es, this message translates to:
  /// **'Reenviar link'**
  String get familyShareLink;

  /// No description provided for @familyShareAgain.
  ///
  /// In es, this message translates to:
  /// **'Enviar a otro'**
  String get familyShareAgain;

  /// No description provided for @familyShareAgainHint.
  ///
  /// In es, this message translates to:
  /// **'Puedes mandar el mismo link a más personas; los anteriores siguen funcionando.'**
  String get familyShareAgainHint;

  /// No description provided for @familyRotateLink.
  ///
  /// In es, this message translates to:
  /// **'Nuevo link'**
  String get familyRotateLink;

  /// No description provided for @familyRotateLinkTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Invalidar links anteriores?'**
  String get familyRotateLinkTitle;

  /// No description provided for @familyRotateLinkBody.
  ///
  /// In es, this message translates to:
  /// **'Se crea un link nuevo. Quien tenga el anterior dejará de ver tu ubicación. Úsalo si el link se filtró.'**
  String get familyRotateLinkBody;

  /// No description provided for @familyRotateLinkConfirm.
  ///
  /// In es, this message translates to:
  /// **'Invalidar y compartir'**
  String get familyRotateLinkConfirm;

  /// No description provided for @familyShareNeedsSignIn.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión para compartir con familia.'**
  String get familyShareNeedsSignIn;

  /// No description provided for @familyShareSubject.
  ///
  /// In es, this message translates to:
  /// **'RiderLab — estoy rodando'**
  String get familyShareSubject;

  /// No description provided for @familyShareMessage.
  ///
  /// In es, this message translates to:
  /// **'Estoy en una salida. Abre este link para ver mi última ubicación (no es 911):\n{url}'**
  String familyShareMessage(String url);

  /// No description provided for @familyLastSeen.
  ///
  /// In es, this message translates to:
  /// **'Última señal {when}'**
  String familyLastSeen(String when);

  /// No description provided for @familyNoSignalSince.
  ///
  /// In es, this message translates to:
  /// **'Sin señal · última a las {when}'**
  String familyNoSignalSince(String when);

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
  /// **'Crea una rodada para Tapalpa, Moyahua o donde sea. Invita riders y comparte GPS en vivo, líneas y fotos solo si cada uno lo activa.'**
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

  /// No description provided for @rodadaItinerary.
  ///
  /// In es, this message translates to:
  /// **'Itinerario'**
  String get rodadaItinerary;

  /// No description provided for @rodadaPinStart.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get rodadaPinStart;

  /// No description provided for @rodadaPinFinish.
  ///
  /// In es, this message translates to:
  /// **'Fin'**
  String get rodadaPinFinish;

  /// No description provided for @rodadaPinStop.
  ///
  /// In es, this message translates to:
  /// **'Parada'**
  String get rodadaPinStop;

  /// No description provided for @rodadaPinUnset.
  ///
  /// In es, this message translates to:
  /// **'Sin marcar'**
  String get rodadaPinUnset;

  /// No description provided for @rodadaStopN.
  ///
  /// In es, this message translates to:
  /// **'Parada {n}'**
  String rodadaStopN(int n);

  /// No description provided for @rodadaItineraryHelp.
  ///
  /// In es, this message translates to:
  /// **'Busca o toca el mapa para marcar inicio, fin o paradas. GPS en vivo y fotos quedan apagados hasta que cada rider lo active.'**
  String get rodadaItineraryHelp;

  /// No description provided for @routePrefTolls.
  ///
  /// In es, this message translates to:
  /// **'Casetas'**
  String get routePrefTolls;

  /// No description provided for @routePrefHighway.
  ///
  /// In es, this message translates to:
  /// **'Autopista'**
  String get routePrefHighway;

  /// No description provided for @routePrefStreet.
  ///
  /// In es, this message translates to:
  /// **'Calle'**
  String get routePrefStreet;

  /// No description provided for @routePrefOffroad.
  ///
  /// In es, this message translates to:
  /// **'Terracería'**
  String get routePrefOffroad;

  /// No description provided for @routeSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Busca un lugar, pueblo o dirección…'**
  String get routeSearchHint;

  /// No description provided for @routeSummaryKmEta.
  ///
  /// In es, this message translates to:
  /// **'{distance} · {eta}'**
  String routeSummaryKmEta(String distance, String eta);

  /// No description provided for @routeFailedFallback.
  ///
  /// In es, this message translates to:
  /// **'No se pudo seguir las carreteras — se muestra línea recta.'**
  String get routeFailedFallback;

  /// No description provided for @offRouteBanner.
  ///
  /// In es, this message translates to:
  /// **'Fuera de ruta'**
  String get offRouteBanner;

  /// No description provided for @routeRouting.
  ///
  /// In es, this message translates to:
  /// **'Trazando ruta…'**
  String get routeRouting;

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
  /// **'Invitar amigos'**
  String get inviteFriend;

  /// No description provided for @leaveRodada.
  ///
  /// In es, this message translates to:
  /// **'Salir de la rodada'**
  String get leaveRodada;

  /// No description provided for @leaveRodadaConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Salir de esta rodada?'**
  String get leaveRodadaConfirmTitle;

  /// No description provided for @leaveRodadaConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'Dejarás de verla en tu lista. El anfitrión no se borra.'**
  String get leaveRodadaConfirmBody;

  /// No description provided for @leaveRodadaDone.
  ///
  /// In es, this message translates to:
  /// **'Saliste de la rodada'**
  String get leaveRodadaDone;

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

  /// No description provided for @inviteFriends.
  ///
  /// In es, this message translates to:
  /// **'Invitar amigos'**
  String get inviteFriends;

  /// No description provided for @rodadaInviteChip.
  ///
  /// In es, this message translates to:
  /// **'Invitación'**
  String get rodadaInviteChip;

  /// No description provided for @rodadaInviteBanner.
  ///
  /// In es, this message translates to:
  /// **'Te invitaron a {title}'**
  String rodadaInviteBanner(String title);

  /// No description provided for @rsvpPending.
  ///
  /// In es, this message translates to:
  /// **'pendiente'**
  String get rsvpPending;

  /// No description provided for @rsvpAccept.
  ///
  /// In es, this message translates to:
  /// **'Aceptar'**
  String get rsvpAccept;

  /// No description provided for @rsvpDecline.
  ///
  /// In es, this message translates to:
  /// **'Rechazar'**
  String get rsvpDecline;

  /// No description provided for @inviteSent.
  ///
  /// In es, this message translates to:
  /// **'Invitación enviada'**
  String get inviteSent;

  /// No description provided for @inviteAlreadyMember.
  ///
  /// In es, this message translates to:
  /// **'Ya está en esta rodada'**
  String get inviteAlreadyMember;

  /// No description provided for @inviteSentNoToken.
  ///
  /// In es, this message translates to:
  /// **'Invitado en la app. Ese teléfono aún no registró notificaciones — que abra RiderLab con su cuenta.'**
  String get inviteSentNoToken;

  /// No description provided for @inviteSentPushFailed.
  ///
  /// In es, this message translates to:
  /// **'Invitado en la app, pero la notificación falló: {reason}'**
  String inviteSentPushFailed(String reason);

  /// No description provided for @invitePushAllOk.
  ///
  /// In es, this message translates to:
  /// **'{count} notificaciones enviadas'**
  String invitePushAllOk(int count);

  /// No description provided for @invitePushSummary.
  ///
  /// In es, this message translates to:
  /// **'Invitados en la app. Notificaciones: {ok} enviadas, {failed} fallidas ({reason})'**
  String invitePushSummary(int ok, int failed, String reason);

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
  /// **'Qué compartes'**
  String get yourSharing;

  /// No description provided for @sharingDefaultsHelp.
  ///
  /// In es, this message translates to:
  /// **'Apagado hasta que lo actives. Luego se envía tu ubicación cada 5 minutos durante toda la rodada (reintenta cada 1 minuto si falla).'**
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
  /// **'Compartir mi línea después de recorrer'**
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
  /// **'línea activa'**
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

  /// No description provided for @liveRiderLastSeen.
  ///
  /// In es, this message translates to:
  /// **'{name} · {when}'**
  String liveRiderLastSeen(String name, String when);

  /// No description provided for @liveRiderNoSignal.
  ///
  /// In es, this message translates to:
  /// **'{name} · Sin señal · {when}'**
  String liveRiderNoSignal(String name, String when);

  /// No description provided for @liveSeenJustNow.
  ///
  /// In es, this message translates to:
  /// **'ahora'**
  String get liveSeenJustNow;

  /// No description provided for @liveSeenMinutesAgo.
  ///
  /// In es, this message translates to:
  /// **'hace {minutes} min'**
  String liveSeenMinutesAgo(int minutes);

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
  /// **'Líneas de quienes activaron compartir. El GPS detallado se queda en cada teléfono.'**
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
  /// **'Sin puntos de la línea'**
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

  /// No description provided for @photosUploaded.
  ///
  /// In es, this message translates to:
  /// **'{count} fotos subidas'**
  String photosUploaded(int count);

  /// No description provided for @photoTitle.
  ///
  /// In es, this message translates to:
  /// **'Foto'**
  String get photoTitle;

  /// No description provided for @photoNeedsActiveRide.
  ///
  /// In es, this message translates to:
  /// **'Empieza un recorrido para ligar la foto a la ruta'**
  String get photoNeedsActiveRide;

  /// No description provided for @photoLinkedToRoute.
  ///
  /// In es, this message translates to:
  /// **'Foto ligada a la ruta'**
  String get photoLinkedToRoute;

  /// No description provided for @photoCaptureTooltip.
  ///
  /// In es, this message translates to:
  /// **'Foto de la rodada'**
  String get photoCaptureTooltip;

  /// No description provided for @photoTake.
  ///
  /// In es, this message translates to:
  /// **'Cámara'**
  String get photoTake;

  /// No description provided for @photoImportFromRoll.
  ///
  /// In es, this message translates to:
  /// **'Del carrete'**
  String get photoImportFromRoll;

  /// No description provided for @photoImportTitle.
  ///
  /// In es, this message translates to:
  /// **'Fotos de esta rodada'**
  String get photoImportTitle;

  /// No description provided for @photoImportHelp.
  ///
  /// In es, this message translates to:
  /// **'Encontramos estas fotos en el carrete durante tu ruta. Nada se sube hasta que confirmes.'**
  String get photoImportHelp;

  /// No description provided for @photoImportSkip.
  ///
  /// In es, this message translates to:
  /// **'Omitir'**
  String get photoImportSkip;

  /// No description provided for @photoImportConfirm.
  ///
  /// In es, this message translates to:
  /// **'Ligar {count} fotos'**
  String photoImportConfirm(int count);

  /// No description provided for @reelTitle.
  ///
  /// In es, this message translates to:
  /// **'Reel de la rodada'**
  String get reelTitle;

  /// No description provided for @reelDone.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get reelDone;

  /// No description provided for @reelBuilding.
  ///
  /// In es, this message translates to:
  /// **'Armando tu reel…'**
  String get reelBuilding;

  /// No description provided for @reelRetry.
  ///
  /// In es, this message translates to:
  /// **'Regenerar'**
  String get reelRetry;

  /// No description provided for @reelShare.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get reelShare;

  /// No description provided for @reelHookSub.
  ///
  /// In es, this message translates to:
  /// **'Recostada'**
  String get reelHookSub;

  /// No description provided for @reelCurvesLabel.
  ///
  /// In es, this message translates to:
  /// **'Curvas'**
  String get reelCurvesLabel;

  /// No description provided for @reelRidersLabel.
  ///
  /// In es, this message translates to:
  /// **'Riders'**
  String get reelRidersLabel;

  /// No description provided for @reelEndQuestion.
  ///
  /// In es, this message translates to:
  /// **'¿Tú cuánto te recuestas?'**
  String get reelEndQuestion;

  /// No description provided for @reelCta.
  ///
  /// In es, this message translates to:
  /// **'Graba tu línea en RiderLab'**
  String get reelCta;

  /// No description provided for @reelGenerate.
  ///
  /// In es, this message translates to:
  /// **'Generar reel'**
  String get reelGenerate;

  /// No description provided for @reelOverviewCta.
  ///
  /// In es, this message translates to:
  /// **'Comparte el reel de la rodada'**
  String get reelOverviewCta;

  /// No description provided for @reelLengthShort.
  ///
  /// In es, this message translates to:
  /// **'Corto'**
  String get reelLengthShort;

  /// No description provided for @reelLengthStandard.
  ///
  /// In es, this message translates to:
  /// **'Reels'**
  String get reelLengthStandard;

  /// No description provided for @reelLengthLong.
  ///
  /// In es, this message translates to:
  /// **'Completo'**
  String get reelLengthLong;

  /// No description provided for @reelLengthHint.
  ///
  /// In es, this message translates to:
  /// **'Elige cuánto dura el video'**
  String get reelLengthHint;

  /// No description provided for @reelLengthSeconds.
  ///
  /// In es, this message translates to:
  /// **'{seconds} s'**
  String reelLengthSeconds(int seconds);

  /// No description provided for @reelLengthCap.
  ///
  /// In es, this message translates to:
  /// **'Hasta {pauses} paradas · {photos} fotos'**
  String reelLengthCap(int pauses, int photos);

  /// No description provided for @reelStopLabel.
  ///
  /// In es, this message translates to:
  /// **'Parada {n}'**
  String reelStopLabel(int n);

  /// No description provided for @reelOnRoute.
  ///
  /// In es, this message translates to:
  /// **'En ruta'**
  String get reelOnRoute;

  /// No description provided for @reelNoStops.
  ///
  /// In es, this message translates to:
  /// **'No hubo paradas largas en esta ruta'**
  String get reelNoStops;

  /// No description provided for @reelPhotoCount.
  ///
  /// In es, this message translates to:
  /// **'{count} fotos'**
  String reelPhotoCount(int count);

  /// No description provided for @reelAddToStop.
  ///
  /// In es, this message translates to:
  /// **'Agregar foto'**
  String get reelAddToStop;

  /// No description provided for @skillCoach.
  ///
  /// In es, this message translates to:
  /// **'Tips de manejo'**
  String get skillCoach;

  /// No description provided for @skillCurvasRated.
  ///
  /// In es, this message translates to:
  /// **'{count} curvas calificadas · sirve para comparar con amigos'**
  String skillCurvasRated(int count);

  /// No description provided for @improveNextRide.
  ///
  /// In es, this message translates to:
  /// **'Mejorar el próximo recorrido'**
  String get improveNextRide;

  /// No description provided for @openCornerLab.
  ///
  /// In es, this message translates to:
  /// **'Abrir lab de curvas'**
  String get openCornerLab;

  /// No description provided for @skillTipNoCurvas.
  ///
  /// In es, this message translates to:
  /// **'No se detectaron curvas claras — recorre un tramo sinuoso para tener una base.'**
  String get skillTipNoCurvas;

  /// No description provided for @skillTipEntryHot.
  ///
  /// In es, this message translates to:
  /// **'Entraste rápido ({entry}→{apex} km/h). Frena antes de inclinar.'**
  String skillTipEntryHot(String entry, String apex);

  /// No description provided for @skillTipModerateSpeedDrop.
  ///
  /// In es, this message translates to:
  /// **'Bajaste bien de velocidad al centro — frena un poco más al inclinar.'**
  String get skillTipModerateSpeedDrop;

  /// No description provided for @skillTipLittleSpeedScrub.
  ///
  /// In es, this message translates to:
  /// **'Casi no bajaste de velocidad — checa que no lleves de más a media curva.'**
  String get skillTipLittleSpeedScrub;

  /// No description provided for @skillTipWeakExitDrive.
  ///
  /// In es, this message translates to:
  /// **'Salida floja — abre el gas más pronto cuando la moto se empiece a parar.'**
  String get skillTipWeakExitDrive;

  /// No description provided for @skillTipPeakLeanNotAtApex.
  ///
  /// In es, this message translates to:
  /// **'La inclinación máxima no fue en el punto más cerrado — inclina antes para llegar listo al centro.'**
  String get skillTipPeakLeanNotAtApex;

  /// No description provided for @skillTipLowLeanBigHeading.
  ///
  /// In es, this message translates to:
  /// **'Mucho giro con poca inclinación — checa que el teléfono esté bien sujeto, o inclínate más.'**
  String get skillTipLowLeanBigHeading;

  /// No description provided for @skillTipSolidCorner.
  ///
  /// In es, this message translates to:
  /// **'Buena curva — mantén este ritmo de entrada y centro.'**
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

  /// No description provided for @imuAzurePending.
  ///
  /// In es, this message translates to:
  /// **'IMU pendiente de subir'**
  String get imuAzurePending;

  /// No description provided for @imuAzureUploading.
  ///
  /// In es, this message translates to:
  /// **'Subiendo IMU…'**
  String get imuAzureUploading;

  /// No description provided for @imuAzureUploaded.
  ///
  /// In es, this message translates to:
  /// **'IMU en Azure'**
  String get imuAzureUploaded;

  /// No description provided for @imuAzureFailed.
  ///
  /// In es, this message translates to:
  /// **'Falló la subida de IMU'**
  String get imuAzureFailed;

  /// No description provided for @imuAzureRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar subida IMU'**
  String get imuAzureRetry;

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
  /// **'Toca para ver errores y cómo mejorarlos'**
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
  /// **'Primero las curvas con peor puntaje. Las barras son entrada → centro → salida. Toca Repetir para ver inclinación, freno y velocidad — y comparar la misma curva con un amigo.'**
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
  /// **'Se usa en el Lab de inclinación y en tus recorridos'**
  String get bikeSelectHelp;

  /// No description provided for @bikePickerTitle.
  ///
  /// In es, this message translates to:
  /// **'Garaje'**
  String get bikePickerTitle;

  /// No description provided for @bikePickerHelp.
  ///
  /// In es, this message translates to:
  /// **'Marca, luego año, luego modelo.'**
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

  /// No description provided for @bikeFamilyOffroad.
  ///
  /// In es, this message translates to:
  /// **'Off-road'**
  String get bikeFamilyOffroad;

  /// No description provided for @bikeFamilyOther.
  ///
  /// In es, this message translates to:
  /// **'Otra'**
  String get bikeFamilyOther;

  /// No description provided for @bikeSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar modelo o año'**
  String get bikeSearchHint;

  /// No description provided for @bikeStepMake.
  ///
  /// In es, this message translates to:
  /// **'Marca'**
  String get bikeStepMake;

  /// No description provided for @bikeStepYear.
  ///
  /// In es, this message translates to:
  /// **'Año'**
  String get bikeStepYear;

  /// No description provided for @bikeStepModel.
  ///
  /// In es, this message translates to:
  /// **'Modelo'**
  String get bikeStepModel;

  /// No description provided for @bikeSearchMake.
  ///
  /// In es, this message translates to:
  /// **'Buscar marca'**
  String get bikeSearchMake;

  /// No description provided for @bikeSearchYear.
  ///
  /// In es, this message translates to:
  /// **'Buscar año'**
  String get bikeSearchYear;

  /// No description provided for @bikeSearchModel.
  ///
  /// In es, this message translates to:
  /// **'Buscar modelo'**
  String get bikeSearchModel;

  /// No description provided for @bikePopularMakes.
  ///
  /// In es, this message translates to:
  /// **'Populares'**
  String get bikePopularMakes;

  /// No description provided for @bikeAllMakes.
  ///
  /// In es, this message translates to:
  /// **'Todas las marcas'**
  String get bikeAllMakes;

  /// No description provided for @bikeCustomModel.
  ///
  /// In es, this message translates to:
  /// **'Otro modelo…'**
  String get bikeCustomModel;

  /// No description provided for @bikeCustomModelHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe el nombre del modelo'**
  String get bikeCustomModelHint;

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

  /// No description provided for @labsSectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Pruebas / nuevas funciones'**
  String get labsSectionTitle;

  /// No description provided for @labsSectionHelp.
  ///
  /// In es, this message translates to:
  /// **'Herramientas experimentales. No forman parte del flujo diario.'**
  String get labsSectionHelp;

  /// No description provided for @pushDiagnosticsTitle.
  ///
  /// In es, this message translates to:
  /// **'Último envío de notificación'**
  String get pushDiagnosticsTitle;

  /// No description provided for @pushDiagnosticsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay un envío de notificación registrado.'**
  String get pushDiagnosticsEmpty;

  /// No description provided for @pushDiagnosticsCopied.
  ///
  /// In es, this message translates to:
  /// **'Registro de notificaciones copiado'**
  String get pushDiagnosticsCopied;

  /// No description provided for @leanLabIntro.
  ///
  /// In es, this message translates to:
  /// **'Bugambilias en ambos sentidos, con subidas. Guarda el 0° con la moto derecha, rueda y marca las curvas para mejorar la inclinación.'**
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
  /// **'Hacia la plaza, teléfono en su lugar de siempre. Captura inclinación en subida y bajada.'**
  String get leanLabProtoOutboundHelp;

  /// No description provided for @leanLabProtoReturn.
  ///
  /// In es, this message translates to:
  /// **'Base de regreso'**
  String get leanLabProtoReturn;

  /// No description provided for @leanLabProtoReturnHelp.
  ///
  /// In es, this message translates to:
  /// **'El otro sentido, mismo lugar del teléfono. Mismas curvas, lados al revés.'**
  String get leanLabProtoReturnHelp;

  /// No description provided for @leanLabProtoPocket.
  ///
  /// In es, this message translates to:
  /// **'Teléfono en el bolsillo'**
  String get leanLabProtoPocket;

  /// No description provided for @leanLabProtoPocketHelp.
  ///
  /// In es, this message translates to:
  /// **'El mismo circuito con el teléfono en el bolsillo, para ver cómo cambia la inclinación.'**
  String get leanLabProtoPocketHelp;

  /// No description provided for @leanLabProtoFree.
  ///
  /// In es, this message translates to:
  /// **'Vuelta libre Lean Lab'**
  String get leanLabProtoFree;

  /// No description provided for @leanLabProtoFreeHelp.
  ///
  /// In es, this message translates to:
  /// **'Cualquier sentido en este circuito. Guarda el 0° y luego marca las curvas.'**
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
  /// **'Preparar Lab de inclinación'**
  String get leanLabPrepTitle;

  /// No description provided for @leanLabPrepHelp.
  ///
  /// In es, this message translates to:
  /// **'Teléfono ya en el soporte o la maleta de tanque. Guarda el 0° con la moto derecha y arranca la vuelta.'**
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
  /// **'Guardar 0° (moto derecha)'**
  String get leanLabCalibTitle;

  /// No description provided for @leanLabCalibHelp.
  ///
  /// In es, this message translates to:
  /// **'Moto derecha, teléfono ya en su lugar. Sin tocarlo 4 segundos — así se guarda el 0°. La inclinación debe quedar cerca de 0°.'**
  String get leanLabCalibHelp;

  /// No description provided for @leanLabCalibHold.
  ///
  /// In es, this message translates to:
  /// **'Sostener vertical 4 s'**
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
  /// **'Toca, mételo del todo en el bolsillo, quédate quieto. Un vibrar y un beep confirman que el 0° quedó guardado y el recorrido arrancó — no lo guardes en la mano.'**
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
  /// **'No se quedó quieto. Colócalo de nuevo e inténtalo otra vez.'**
  String get leanLabCalibPocketFail;

  /// No description provided for @leanLabFreezeRedo.
  ///
  /// In es, this message translates to:
  /// **'El teléfono ya va {n}° de derecho. Vuelve a guardar el 0° con la moto bien parada.'**
  String leanLabFreezeRedo(String n);

  /// No description provided for @leanLabRawNeutral.
  ///
  /// In es, this message translates to:
  /// **'Ángulo del teléfono'**
  String get leanLabRawNeutral;

  /// No description provided for @leanLabFrozenNeutral.
  ///
  /// In es, this message translates to:
  /// **'0° guardado'**
  String get leanLabFrozenNeutral;

  /// No description provided for @leanLabStartRide.
  ///
  /// In es, this message translates to:
  /// **'Iniciar recorrido Lean Lab'**
  String get leanLabStartRide;

  /// No description provided for @leanLabReviewTitle.
  ///
  /// In es, this message translates to:
  /// **'Marcar inclinación'**
  String get leanLabReviewTitle;

  /// No description provided for @leanLabReviewHelp.
  ///
  /// In es, this message translates to:
  /// **'En cada curva: ¿la inclinación de la app se sintió alta, bien o baja? Se muestra la pendiente para corregir subida y bajada.'**
  String get leanLabReviewHelp;

  /// No description provided for @leanLabReviewHelpMax.
  ///
  /// In es, this message translates to:
  /// **'La inclinación máxima de la curva se queda arriba. Reproduce para ver inclinación y mapa; salta al pico cuando quieras.'**
  String get leanLabReviewHelpMax;

  /// No description provided for @leanLabMaxLean.
  ///
  /// In es, this message translates to:
  /// **'Inclinación máxima'**
  String get leanLabMaxLean;

  /// No description provided for @leanLabJumpToMax.
  ///
  /// In es, this message translates to:
  /// **'Ir a la inclinación máxima'**
  String get leanLabJumpToMax;

  /// No description provided for @leanLabLiveLean.
  ///
  /// In es, this message translates to:
  /// **'Inclinación en vivo'**
  String get leanLabLiveLean;

  /// No description provided for @leanLabAtPeak.
  ///
  /// In es, this message translates to:
  /// **'en el pico'**
  String get leanLabAtPeak;

  /// No description provided for @leanLabMaxLeanGps.
  ///
  /// In es, this message translates to:
  /// **'GPS donde ocurrió la inclinación máxima'**
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
  /// **'Este recorrido casi no tiene GPS en el teléfono. Abre Ajustes → Sincronizar recorridos con la nube (misma cuenta Google) y vuelve a intentar.'**
  String get leanLabNoTrackPoints;

  /// No description provided for @leanLabNoLeanData.
  ///
  /// In es, this message translates to:
  /// **'El GPS está, pero faltan muestras de inclinación — no se pueden etiquetar curvas. Sincroniza de nuevo o graba la vuelta con el teléfono bien fijado.'**
  String get leanLabNoLeanData;

  /// No description provided for @leanLabAppLean.
  ///
  /// In es, this message translates to:
  /// **'Inclinación de la app'**
  String get leanLabAppLean;

  /// No description provided for @leanLabGrade.
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get leanLabGrade;

  /// No description provided for @leanLabBiasQ.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo se sintió la inclinación de la app en el centro de la curva?'**
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
  /// **'Guardar marcas de curvas'**
  String get leanLabSaveLabels;

  /// No description provided for @leanLabSettingsTile.
  ///
  /// In es, this message translates to:
  /// **'Lab de inclinación (pruebas)'**
  String get leanLabSettingsTile;

  /// No description provided for @leanLabSettingsHelp.
  ///
  /// In es, this message translates to:
  /// **'Sesiones en Bugambilias · guardar 0° · pendientes · marcar curvas'**
  String get leanLabSettingsHelp;

  /// No description provided for @leanImuLabTitle.
  ///
  /// In es, this message translates to:
  /// **'Lab de sensores de inclinación'**
  String get leanImuLabTitle;

  /// No description provided for @leanImuLabIntro.
  ///
  /// In es, this message translates to:
  /// **'La misma inclinación que en el recorrido. Guarda el 0° con el teléfono en su lugar real, luego inclina. El letrero muestra cómo va el teléfono.'**
  String get leanImuLabIntro;

  /// No description provided for @leanImuLabSettingsTile.
  ///
  /// In es, this message translates to:
  /// **'Sensores de inclinación'**
  String get leanImuLabSettingsTile;

  /// No description provided for @leanImuLabSettingsHelp.
  ///
  /// In es, this message translates to:
  /// **'Mira los sensores y cómo se mide la inclinación'**
  String get leanImuLabSettingsHelp;

  /// No description provided for @leanImuLabFreeze.
  ///
  /// In es, this message translates to:
  /// **'Guardar 0° ahora'**
  String get leanImuLabFreeze;

  /// No description provided for @leanImuLabReset.
  ///
  /// In es, this message translates to:
  /// **'Reiniciar'**
  String get leanImuLabReset;

  /// No description provided for @leanImuLabFrozenHint.
  ///
  /// In es, this message translates to:
  /// **'El 0° está guardado. La inclinación debe ser cerca de 0°. Inclina a cualquier lado — el número es el ángulo.'**
  String get leanImuLabFrozenHint;

  /// No description provided for @leanImuLabAnglesTitle.
  ///
  /// In es, this message translates to:
  /// **'Ángulos'**
  String get leanImuLabAnglesTitle;

  /// No description provided for @leanImuLabAnglesHelp.
  ///
  /// In es, this message translates to:
  /// **'La inclinación (roja) sigue el canal fusionado ganador (mismo movimiento que morado/azul), limitada por el inclinómetro vector (verde). El verde puede moverse con cualquier tip desde 0°; el rojo sigue la lean de moto para esa pose — sin saltos de onda cuadrada.'**
  String get leanImuLabAnglesHelp;

  /// No description provided for @leanImuLabHistoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Últimos ~8 s'**
  String get leanImuLabHistoryTitle;

  /// No description provided for @leanImuLabStartRecord.
  ///
  /// In es, this message translates to:
  /// **'Grabar gráfica'**
  String get leanImuLabStartRecord;

  /// No description provided for @leanImuLabStopRecord.
  ///
  /// In es, this message translates to:
  /// **'Parar'**
  String get leanImuLabStopRecord;

  /// No description provided for @leanImuLabExportCsv.
  ///
  /// In es, this message translates to:
  /// **'Exportar CSV'**
  String get leanImuLabExportCsv;

  /// No description provided for @leanImuLabRecordingHint.
  ///
  /// In es, this message translates to:
  /// **'Grabando… {count} muestras (envíame el CSV tras Exportar)'**
  String leanImuLabRecordingHint(int count);

  /// No description provided for @leanImuLabExportDone.
  ///
  /// In es, this message translates to:
  /// **'Menú de compartir abierto para {path} — elige Drive, WhatsApp o Archivos'**
  String leanImuLabExportDone(String path);

  /// No description provided for @leanImuLabVectorsTitle.
  ///
  /// In es, this message translates to:
  /// **'Capacidades crudas'**
  String get leanImuLabVectorsTitle;

  /// No description provided for @leanImuLabNextTitle.
  ///
  /// In es, this message translates to:
  /// **'Cómo leer esto'**
  String get leanImuLabNextTitle;

  /// No description provided for @leanImuLabNextHelp.
  ///
  /// In es, this message translates to:
  /// **'Prueba en la pared: a unos 3° de un inclinómetro de verdad, en cualquier posición. Teléfono derecho: la inclinación sigue el roll. Teléfono plano: sigue el pitch. Si se mueve en el bolsillo, el letrero cambia en unos segundos.'**
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
  /// **'Inclinación máxima por curva'**
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
  /// **'Corrige ida/regreso, lugar del teléfono o posición si te equivocaste — los números de inclinación no cambian; las marcas se quedan hasta que las vuelvas a guardar.'**
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
  /// **'Mira cómo se rodó este tramo — inclinación, freno y velocidad van con el marcador en el mapa.'**
  String get skillReplayHelp;

  /// No description provided for @skillReplayCompareHelp.
  ///
  /// In es, this message translates to:
  /// **'Ambas líneas se recortan al mismo tramo. Los marcadores avanzan por distancia en la curva para comparar la línea, no el reloj.'**
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
  /// **'No hay puntos de la línea para este recorrido.'**
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
  /// **'Unos toques después de cada recorrido ayudan a enseñar inclinación, curvas y frenos. Puedes omitir.'**
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
  /// **'En la moto (tanque / manubrio)'**
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
  /// **'Buscando mejor señal GPS…'**
  String get gpsPreparing;

  /// No description provided for @gpsLookingSatellites.
  ///
  /// In es, this message translates to:
  /// **'Buscando satélites…'**
  String get gpsLookingSatellites;

  /// No description provided for @gpsWarming.
  ///
  /// In es, this message translates to:
  /// **'Esperando mejor señal GPS…'**
  String get gpsWarming;

  /// No description provided for @gpsWarmingAcc.
  ///
  /// In es, this message translates to:
  /// **'Esperando GPS (±{meters} m)…'**
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
  /// **'En el marcador · desfase de 0° {degrees}°'**
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
