// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'CornerIQ';

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
      'Inicia una ruta y CornerIQ dibujará la línea exacta que tomaste en la calle.';

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
    return 'CornerIQ $version está lista (tienes $current).';
  }

  @override
  String get update => 'Actualizar';

  @override
  String get later => 'Después';

  @override
  String get onLatest => 'Ya tienes la última CornerIQ.';

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
    return 'Según cambio de rumbo (el lean ayuda al lado). $rectas rectas · $curvas curvas. Toca una curva para ver entrada / ápice / salida.';
  }

  @override
  String get roadStretchesEmpty =>
      'Aún no hay suficiente cambio de rumbo GPS para separar rectas y curvas.';

  @override
  String get openDetail => 'abrir detalle';

  @override
  String get brakesHelp =>
      'Inferido por qué tan rápido cae la velocidad — no es sensor de freno. Toca un golpe para saltar el playhead.';

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
  String get friends => 'Amigos';

  @override
  String get friendsSubtitle =>
      'Beta cerrada — todo quien tenga la app aparece en tu lista.';

  @override
  String get friendsEmpty =>
      'Aún no hay otros riders. Cuando un amigo instale CornerIQ, aparecerá aquí.';

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
}
