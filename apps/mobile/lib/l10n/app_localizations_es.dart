// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'RiderLab';

  @override
  String get tagline =>
      'Graba la línea que rodaste. Revísala. Mejora cada curva.';

  @override
  String get startRide => 'Iniciar ruta';

  @override
  String get endRide => 'Terminar ruta';

  @override
  String get recording => 'Grabando';

  @override
  String get starting => 'Iniciando…';

  @override
  String get live => 'EN VIVO';

  @override
  String get checkUpdates => 'Buscar actualizaciones';

  @override
  String get language => 'Idioma';

  @override
  String get spanish => 'Español';

  @override
  String get english => 'English';

  @override
  String get garage => 'Garaje';

  @override
  String get yourRides => 'Tus rutas';

  @override
  String get emptyRidesTitle => 'Aún no hay rutas';

  @override
  String get emptyRidesBody =>
      'Inicia una ruta y RiderLab dibujará la línea exacta que tomaste en la calle.';

  @override
  String get unfinishedRide => 'Ruta sin terminar';

  @override
  String unfinishedRideBody(String when) {
    return 'Empezó $when. Finalízala para guardar la línea, o descártala.';
  }

  @override
  String get discard => 'Descartar';

  @override
  String get keepLine => 'Conservar línea';

  @override
  String get updateAvailable => 'Actualización disponible';

  @override
  String updateReady(String version, String current) {
    return 'RiderLab $version está lista (tienes $current).';
  }

  @override
  String get update => 'Actualizar';

  @override
  String get later => 'Después';

  @override
  String get onLatest => 'Ya tienes la última RiderLab.';

  @override
  String get downloadingUpdate => 'Descargando actualización';

  @override
  String get updateFailed => 'Falló la actualización';

  @override
  String get connecting => 'Conectando…';

  @override
  String get close => 'Cerrar';

  @override
  String get checkingUpdates => 'Buscando actualizaciones…';

  @override
  String updatePrompt(String current) {
    return 'Hay una versión nueva (tienes $current). ¿Descargar e instalar ahora?';
  }

  @override
  String get notNow => 'Ahora no';

  @override
  String updateCheckFailed(String error) {
    return 'Error al buscar actualización: $error';
  }

  @override
  String get rideLab => 'Ride Lab';

  @override
  String get rideLabSegment => 'Ride Lab · segmento';

  @override
  String get rideNotFound => 'Ruta no encontrada';

  @override
  String get collapseHint =>
      'Toca los encabezados para plegar. El playhead queda abajo.';

  @override
  String get segmentZoomHint =>
      'Zoom de segmento — métricas y gráficas solo de este tramo.';

  @override
  String get sectionSegment => 'Zoom de segmento';

  @override
  String get sectionSegmentSub => 'Elige un tramo de carretera';

  @override
  String get sectionOverview => 'Resumen';

  @override
  String get sectionOverviewSub => 'Puntuación + métricas';

  @override
  String get sectionOverviewSubZoom => 'Puntuación + métricas de este segmento';

  @override
  String get sectionLean => 'Inclinación';

  @override
  String get sectionLeanSub => 'Cian izquierda · ámbar derecha';

  @override
  String get sectionMap => 'Mapa + línea';

  @override
  String get sectionMapSub => 'Colores de velocidad · frenos';

  @override
  String get sectionRoad => 'Rectas y curvas';

  @override
  String get sectionRoadSub => 'Por cambio de rumbo';

  @override
  String get sectionBrakes => 'Frenado';

  @override
  String get sectionBrakesSub => 'Inferido por caída de velocidad';

  @override
  String get sectionCharts => 'Gráficas';

  @override
  String get sectionChartsSub => 'Velocidad · lean · GPS';

  @override
  String get sectionNotes => 'Precisión + notas';

  @override
  String get sectionNotesSub => 'Calidad GPS y notas';

  @override
  String get segment => 'SEGMENTO';

  @override
  String get segmentZoom => 'ZOOM DE SEGMENTO';

  @override
  String get segmentHint =>
      'Arrastra los controles, luego haz zoom para métricas del tramo.';

  @override
  String get segmentHintZoomed =>
      'Mapa y métricas muestran solo este tramo. Ajusta con los controles.';

  @override
  String get zoomToSegment => 'Zoom al segmento';

  @override
  String get fullRide => 'Ruta completa';

  @override
  String get playhead => 'PLAYHEAD';

  @override
  String get distance => 'Distancia';

  @override
  String get time => 'Tiempo';

  @override
  String get speed => 'Velocidad';

  @override
  String get bikeLean => 'Inclinación';

  @override
  String get calibrating => 'Calibrando…';

  @override
  String get points => 'Puntos';

  @override
  String get maxLR => 'Máx I / D';

  @override
  String get maxSpeed => 'Vel. máx';

  @override
  String get duration => 'Duración';

  @override
  String get speedProfile => 'Perfil de velocidad';

  @override
  String get leanProfile => 'Inclinación izq / der';

  @override
  String get gpsPrecision => 'Precisión GPS';

  @override
  String get gpsPrecisionSub =>
      'Precisión horizontal en metros (menor es mejor)';

  @override
  String get chartSpeedSub => 'Colores de alto contraste. Toca para scrub.';

  @override
  String get chartSpeedSubZoom =>
      'Solo velocidad del segmento. Toca para scrub.';

  @override
  String get leanHelp =>
      '0° es vertical inferida (sirve con el teléfono en el bolsillo).';

  @override
  String get mapHint =>
      'Azul→magenta según velocidad. Puntos = frenos inferidos.';

  @override
  String get mapHintZoom =>
      'Brillante = tramo elegido · tenue = resto. Puntos = frenos.';

  @override
  String get startingRide => 'Iniciando ruta';

  @override
  String get gpsReady => 'GPS listo';

  @override
  String gpsWarmHelp(String meters) {
    return 'Quédate al aire libre con cielo abierto. La grabación empieza cuando el GPS esté lo bastante estable (objetivo ±$meters m).';
  }

  @override
  String get horizontalAccuracy => 'PRECISIÓN HORIZONTAL';

  @override
  String lowerBetter(String meters) {
    return 'Menor es mejor · listo a ±$meters m';
  }

  @override
  String get couldNotStart => 'No se pudo iniciar la ruta';

  @override
  String get tryAgain => 'Reintentar';

  @override
  String get back => 'Volver';

  @override
  String get activeMountHelp =>
      'Monta firme (vertical, pantalla hacia ti). Deja la notificación de grabación activa — la pantalla puede bloquearse.';

  @override
  String curvaTitle(int number) {
    return 'Curva #$number';
  }

  @override
  String get curveLine => 'Línea de la curva';

  @override
  String get entry => 'Entrada';

  @override
  String get apex => 'Ápice';

  @override
  String get exit => 'Salida';

  @override
  String get brakeToApex => 'Freno a ápice';

  @override
  String get accelFromApex => 'Acelera desde ápice';

  @override
  String get leanAtApex => 'Lean en ápice';

  @override
  String get maxLean => 'Lean máx';

  @override
  String get leftShort => 'Izq';

  @override
  String get rightShort => 'Der';

  @override
  String get curvaMapLegend =>
      'E = entrada · A = ápice · S = salida. Línea por velocidad.';

  @override
  String get curvaCoach =>
      'Lectura rápida: mira si entras demasiado rápido (mucho freno a A), si el ápice es estable, y si sales acelerando limpio.';

  @override
  String roadStretchesHelp(int rectas, int curvas) {
    return 'Según rumbo + inclinación. $rectas rectas · $curvas curvas. Toca una curva para entrada / ápice / salida — desliza entre curvas.';
  }

  @override
  String get roadStretchesEmpty =>
      'Aún no hay suficiente cambio de rumbo GPS para separar rectas y curvas.';

  @override
  String get openDetail => 'abrir detalle';

  @override
  String get brakesHelp =>
      'Inferido por qué tan rápido cae la velocidad — no es sensor de freno. Toca un golpe para saltar el playhead. El botón de mapa hace zoom a ese freno.';

  @override
  String get brakesEmpty =>
      'No hay frenadas claras por GPS. Las paradas fuertes suelen verse como golpes amarillo/naranja/rojo.';

  @override
  String get brakeLight => 'Suave';

  @override
  String get brakeMedium => 'Medio';

  @override
  String get brakeHard => 'Fuerte';

  @override
  String brakeAtTime(String time) {
    return 'En $time';
  }

  @override
  String get brakeZoomMap => 'Zoom del mapa al freno';

  @override
  String get noGpsPoints => 'Sin puntos GPS';

  @override
  String get kmh => 'km/h';

  @override
  String get recta => 'Recta';

  @override
  String get curva => 'Curva';

  @override
  String get curvaIzquierda => 'Curva izquierda';

  @override
  String get curvaDerecha => 'Curva derecha';

  @override
  String get fullscreenMap => 'Mapa completo';

  @override
  String get fullscreenMapHelp =>
      'Desplaza y haz zoom libremente. Marca un área o usa el mapa visible, luego carga métricas de ese tramo.';

  @override
  String get selectArea => 'Marcar área';

  @override
  String get selectAreaHint => 'Arrastra un recuadro sobre el tramo';

  @override
  String get selectAreaBody =>
      'Arrastra en el mapa para marcar un área. El pellizco sigue haciendo zoom.';

  @override
  String get useVisibleArea => 'Usar mapa visible';

  @override
  String get clearArea => 'Limpiar';

  @override
  String get loadAreaMetrics => 'Cargar métricas del área';

  @override
  String areaReady(int points) {
    return 'Área lista · $points puntos GPS. Carga métricas para enfocar el Ride Lab en este tramo.';
  }

  @override
  String get zoomIn => 'Acercar';

  @override
  String get zoomOut => 'Alejar';

  @override
  String get fitRide => 'Ajustar ruta';

  @override
  String get openFullscreenMap => 'Abrir mapa completo';

  @override
  String get mapLayerSpeed => 'Velocidad';

  @override
  String get mapLayerRoadKind => 'Curvas';

  @override
  String get mapLayerBrakes => 'Frenos';

  @override
  String get mapLayerStartEnd => 'Inicio/fin';

  @override
  String get mapLayerPlayhead => 'Playhead';

  @override
  String get mapLayerLegend => 'Leyenda';

  @override
  String get friends => 'Amigos';

  @override
  String get friendsSubtitle =>
      'Beta cerrada — todo quien tenga la app aparece en tu lista.';

  @override
  String get friendsEmpty =>
      'Aún no hay otros riders. Cuando un amigo instale RiderLab, aparecerá aquí.';

  @override
  String get yourName => 'Tu nombre visible';

  @override
  String get saveName => 'Guardar nombre';

  @override
  String get nameHint => 'Apodo para amigos';

  @override
  String get nameSaved => 'Nombre guardado';

  @override
  String get compare => 'Comparar';

  @override
  String get compareTitle => 'Comparar rutas';

  @override
  String get comparePickPeer => 'Rutas de amigos en la misma zona';

  @override
  String get compareEmpty => 'Ninguna ruta de amigos cubre esta zona todavía.';

  @override
  String get compareYou => 'Tú';

  @override
  String get compareLocalTitle => 'Comparar vueltas';

  @override
  String compareRouteTitle(String name) {
    return 'Comparar · $name';
  }

  @override
  String get compareLocalHelp =>
      'Elige una vuelta base y otra para comparar métricas y líneas en el mismo circuito.';

  @override
  String get compareLocalEmpty =>
      'Necesitas al menos 2 vueltas completadas en esta ruta. Usa modo Loop o etiqueta rides con la misma ruta.';

  @override
  String get compareBaseline => 'Base';

  @override
  String get compareChallenger => 'Retador';

  @override
  String compareLocal(int count) {
    return 'Comparar vueltas ($count)';
  }

  @override
  String compareDeltaFaster(String delta) {
    return 'Retador más rápido por $delta';
  }

  @override
  String compareDeltaSlower(String delta) {
    return 'Retador más lento por $delta';
  }

  @override
  String get compareDeltaTie => 'Mismo tiempo';

  @override
  String get compareLaps => 'Comparar vueltas';

  @override
  String get compareNeedTwoLaps =>
      'Marca al menos 2 vueltas en esta ruta para comparar.';

  @override
  String get lineScore => 'Puntuación de línea';

  @override
  String get avgSpeed => 'Vel. media';

  @override
  String get friendRides => 'Rutas compartidas';

  @override
  String get friendRidesEmpty => 'Este rider aún no tiene rutas compartidas.';

  @override
  String get syncingRide => 'Compartiendo ruta con amigos…';

  @override
  String get cloudUnavailable =>
      'Nube no disponible — revisa conexión y auth anónima.';

  @override
  String get cloudAnonymousOff =>
      'Amigos necesita Anonymous activado en la nube de RiderLab (proyecto Supabase CornerIQ):\nDashboard → Authentication → Providers → Anonymous → Enable.\nLuego vuelve a abrir Amigos y desliza para refrescar.';

  @override
  String get routesTitle => 'Rutas';

  @override
  String get routesHelp =>
      'Nombra un circuito, compártelo y etiqueta rides para que amigos comparen en la misma ruta.';

  @override
  String get myRoutes => 'Tus rutas';

  @override
  String get routesEmpty =>
      'Aún no hay rutas — crea una para etiquetar y compartir rides.';

  @override
  String get friendRoutes => 'Rutas compartidas de amigos';

  @override
  String get friendRoutesEmpty =>
      'Ningún amigo ha compartido una ruta todavía.';

  @override
  String get createRoute => 'Nueva ruta';

  @override
  String get routeNameHint => 'Nombre (ej. Glorieta norte)';

  @override
  String get routeDescHint => 'Notas opcionales';

  @override
  String get shareRoute => 'Compartir ruta';

  @override
  String get shareRouteHelp =>
      'Los amigos ven este circuito y pueden comparar rides etiquetados.';

  @override
  String get routeCreated => 'Ruta creada';

  @override
  String get sharedRoute => 'Compartida';

  @override
  String get privateRoute => 'Privada';

  @override
  String get shareRideTitle => 'Compartir y ruta';

  @override
  String get shareRideHelp =>
      'Comparte este ride con amigos y opcionalmente asígnalo a un circuito.';

  @override
  String get shareThisRide => 'Compartir este ride';

  @override
  String get assignRoute => 'Asignar a ruta';

  @override
  String get noRouteAssigned => 'Sin ruta';

  @override
  String get areaNoPoints =>
      'No hay tramo GPS en esa área — acerca el zoom o dibuja un recuadro más grande.';

  @override
  String get curvaSwipeHint =>
      'Desliza izquierda / derecha para cambiar de curva.';

  @override
  String get curvaOpenMap => 'Mapa completo';

  @override
  String get curvaZoomLab => 'Zoom Ride Lab';

  @override
  String get armAutoRide => 'Armar auto-ride';

  @override
  String get disarmAutoRide => 'Desarmar auto-ride';

  @override
  String get waitingForMotion => 'Esperando movimiento…';

  @override
  String get armedBannerBody =>
      'RiderLab iniciará la grabación sola en cuanto detecte que empiezas a rodar.';

  @override
  String get loopMode => 'Modo Loop';

  @override
  String get pausedLabel => 'PAUSADO';

  @override
  String get suggestEndTitle => '¿Sigues rodando?';

  @override
  String get suggestEndBody =>
      'Sin movimiento hace rato. Termina la ruta o sigue rodando.';

  @override
  String get keepRiding => 'Seguir rodando';

  @override
  String get markLoopInit => 'Marcar inicio de loop';

  @override
  String get loopInitSet => 'Inicio marcado';

  @override
  String get markLoopEnd => 'Marcar fin de loop';

  @override
  String get loopArmed => 'Auto-vuelta activada';

  @override
  String lapCountLabel(int count) {
    return 'Vuelta $count';
  }

  @override
  String get endSession => 'Terminar sesión';
}
