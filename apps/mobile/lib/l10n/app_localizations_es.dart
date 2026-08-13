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
  String get tagline => 'Domina cada curva.';

  @override
  String get autoPauseToggle => 'Pausa auto';

  @override
  String get autoPauseToggleHint =>
      'Pausa y reanuda la grabación al detenerte o moverte';

  @override
  String get startRide => 'Iniciar recorrido';

  @override
  String get endRide => 'Terminar recorrido';

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
  String get yourRides => 'Tus recorridos';

  @override
  String get nameRidesFromMap => 'Nombrar desde el mapa';

  @override
  String get nameRidesFromMapHelp =>
      'Calcula origen y destino con GPS (ej. Tesistán - Zapopan).';

  @override
  String namingRidesProgress(int done, int total) {
    return 'Nombrando $done de $total…';
  }

  @override
  String namedRidesDone(int count) {
    return 'Se nombraron $count recorridos.';
  }

  @override
  String get rideUntitledHint => 'Origen - destino pendiente';

  @override
  String get rideNameTitle => 'Nombre del recorrido';

  @override
  String get rideNameHint => 'Tesistán - Zapopan';

  @override
  String get rideNameHelp =>
      'Escribe un nombre o usa el mapa (inicio y fin del GPS).';

  @override
  String get nameFromMap => 'Desde el mapa';

  @override
  String get lookingUpPlaces => 'Buscando lugares…';

  @override
  String get couldNotResolvePlaces => 'No se pudieron obtener los nombres';

  @override
  String get rideTitleCleared => 'Nombre borrado';

  @override
  String rideNamed(String title) {
    return 'Nombrado: $title';
  }

  @override
  String get renameRide => 'Renombrar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get emptyRidesTitle => 'Aún no hay recorridos';

  @override
  String get emptyRidesBody =>
      'Inicia un recorrido y RiderLab dibujará la línea exacta que tomaste en la calle.';

  @override
  String get unfinishedRide => 'Recorrido sin terminar';

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
  String get whatsNew => 'Novedades';

  @override
  String get newVersionBadge => 'NUEVA';

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
  String get rideLab => 'Lab del ride';

  @override
  String get rideLabSegment => 'Ride Lab · segmento';

  @override
  String get rideNotFound => 'Ruta no encontrada';

  @override
  String get collapseHint =>
      'Toca los encabezados para plegar. El cursor queda abajo.';

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
  String get sectionRoad => 'Curvas';

  @override
  String get sectionRoadSub => 'Por rumbo e inclinación';

  @override
  String get sectionLoop => 'Vueltas';

  @override
  String get sectionLoopSub => 'Detecta o marca A/B en este ride';

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
  String get playhead => 'CURSOR';

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
      '0° es vertical inferida. Para inclinación precisa, monta el teléfono firme en vertical (pantalla hacia ti) en el tanque o manillar — evita bolsillo suelto o apaisado.';

  @override
  String get leanPhoneDisclaimer =>
      'La posición del celular importa: vertical, pantalla hacia ti, montaje fijo. Un bolsillo suelto sesga la inclinación.';

  @override
  String get mapHint =>
      'Toca la línea para mover la moto. Azul→magenta por velocidad. Puntos = frenos.';

  @override
  String get mapHintZoom =>
      'Toca la línea para mover la moto. Brillante = elegido · tenue = resto.';

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
      'El 0° se congeló antes de salir. La pantalla puede bloquearse — deja la notificación de grabación activa.';

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
  String get maxLean => 'Incl. máx';

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
  String roadStretchesHelp(int curvas) {
    return 'Según rumbo + inclinación. $curvas curvas. Toca una curva para entrada / ápice / salida — desliza entre curvas.';
  }

  @override
  String get roadStretchesEmpty =>
      'Aún no hay suficiente cambio de rumbo GPS para detectar curvas.';

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
  String get myLocation => 'Mi ubicación';

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
  String get mapLayerPlayhead => 'Cursor';

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
  String get routesHowTitle => '¿Cómo se usan las Rutas?';

  @override
  String get routesHowBody =>
      '1) Crea una ruta con + (ej. «Glorieta norte»).\n2) Abre la ruta → pestaña Loop: detecta vueltas cerradas en rides etiquetados, o marca A/B tú mismo.\n3) Inicia un ride en loop desde un loop guardado — cada vuelta se etiqueta a esta ruta.\n4) O en Ride Lab → Comparte, etiqueta cualquier ride con esta ruta.\n5) Activa «compartida» si quieres que amigos comparen el mismo circuito.';

  @override
  String get routesTapHint => 'Toca para vueltas + módulo Loop';

  @override
  String get routesLoopReady => 'Loop listo';

  @override
  String get setYourAlias => 'Pon tu alias';

  @override
  String get sectionNotesProOnly => 'Solo Pro — precisión GPS y notas';

  @override
  String get proCurvaBannerTitle => 'Detalle de curva · Pro';

  @override
  String get proCurvaBannerBody =>
      'Vista previa de 0,5 s. Con Pro ves entrada, ápice, salida y mapa sin bloqueo.';

  @override
  String get proNotesBannerTitle => 'Precisión + notas · Pro';

  @override
  String get proNotesBannerBody =>
      'Calidad GPS y tips del coach están en CornerIQ Pro.';

  @override
  String get proFeatureCurva => 'Detalle completo de curvas (sin banner)';

  @override
  String get proFeatureNotes => 'Precisión GPS + notas de coach';

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
  String get shareRideTitle => 'Compartir';

  @override
  String get shareRideHelp =>
      'Comparte este recorrido con amigos y opcionalmente asígnalo a un circuito.';

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
  String get curvaZoomLab => 'Zoom Lab';

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
  String get markLoopInitHere => 'Marcar A en mi GPS';

  @override
  String get markLoopEndHere => 'Marcar B en mi GPS';

  @override
  String get loopOpenMarkMap => 'Mapa: marcar A y B';

  @override
  String get loopMarkMapHint =>
      'Abre el mapa a pantalla completa, desplázate y toca el punto A (inicio) y el B (fin) de la ruta.';

  @override
  String get loopTapPointA => 'Toca el mapa para marcar el punto A (inicio)';

  @override
  String get loopTapPointB => 'Toca el mapa para marcar el punto B (fin)';

  @override
  String get loopPointsReady =>
      'A y B listos — confirma para armar auto-vuelta';

  @override
  String get loopMarkMapHelp =>
      'Pan y zoom libres. Primer toque = A, segundo = B. El círculo es la zona de detección de vueltas.';

  @override
  String get loopRemapA => 'Rehacer A';

  @override
  String get loopConfirmAb => 'Confirmar A y B';

  @override
  String get loopArmed => 'Auto-vuelta activada';

  @override
  String lapCountLabel(int count) {
    return 'Vuelta $count';
  }

  @override
  String get endSession => 'Terminar sesión';

  @override
  String get byRawThrottle => 'by RawThrottle';

  @override
  String get pro => 'PRO';

  @override
  String get free => 'Gratis';

  @override
  String get settings => 'Ajustes';

  @override
  String get proUnlock => 'RiderLab Pro';

  @override
  String get proUnlockBody =>
      'Segmenta cualquier tramo, detalle completo de curvas, precisión + notas, frenadas completas y sin anuncios.';

  @override
  String get proFeatureSegment =>
      'Zoom de segmento — elige cualquier tramo del ride';

  @override
  String get proFeatureBrakes =>
      'Detalle completo de frenadas (no solo una vista previa)';

  @override
  String get proFeatureNoAds => 'Sin banners publicitarios';

  @override
  String get upgradeToPro => 'Pasar a Pro';

  @override
  String get proUnlocked => 'Pro activo';

  @override
  String get proToggleDev => 'Pro desbloqueado';

  @override
  String get proToggleHelp =>
      'Desbloqueo temporal hasta conectar la tienda. Apágalo para ver la versión Gratis.';

  @override
  String brakesProTeaser(int shown, int total) {
    return 'Mostrando $shown de $total. Desbloquea Pro para el historial completo de frenadas.';
  }

  @override
  String get segmentProLocked => 'Elegir un tramo del ride es una función Pro.';

  @override
  String get adPlaceholder => 'Anuncio';

  @override
  String get removeAdsWithPro => 'Pasa a Pro para quitar anuncios';

  @override
  String get routeTabLaps => 'Vueltas';

  @override
  String get routeTabLoop => 'Loop';

  @override
  String get routeLoopModuleHelp =>
      'Los loops pertenecen a esta ruta. Detecta vueltas cerradas en rides etiquetados, o marca tú el inicio (A) y el fin (B) en el mapa.';

  @override
  String get routeLoopDefine => 'Marcar A / B';

  @override
  String get routeLoopDetect => 'Detectar';

  @override
  String get routeLoopSavedTitle => 'Loops guardados';

  @override
  String get routeLoopEmpty =>
      'Aún no hay loops — detecta desde rides o marca A y B en el mapa.';

  @override
  String get routeLoopDetectedTitle => 'Candidatos detectados';

  @override
  String get routeLoopDetectedEmpty =>
      'No hay vueltas cerradas en los rides etiquetados. Rueda el circuito e intenta de nuevo.';

  @override
  String get routeLoopDetectedHint =>
      'Trayecto cerrado inferido por GPS — guárdalo para auto-vuelta.';

  @override
  String get routeLoopSave => 'Guardar';

  @override
  String get routeLoopSaved => 'Loop guardado en esta ruta';

  @override
  String get routeLoopManualName => 'Loop manual';

  @override
  String get routeLoopPrimary => 'PRINCIPAL';

  @override
  String get routeLoopSetPrimary => 'Usar como principal';

  @override
  String get routeLoopStartRide => 'Iniciar ride en loop';

  @override
  String get routeLoopSourceManual => 'A mano';

  @override
  String get routeLoopSourceDetected => 'Detectado';

  @override
  String get deleteRoute => 'Eliminar ruta';

  @override
  String get deleteRouteBody =>
      'Se borrará esta ruta, sus loops y se desvincularán los rides. Si está compartida, desaparece para todos.';

  @override
  String get routeDeleted => 'Ruta eliminada';

  @override
  String get deleteLoop => 'Eliminar loop';

  @override
  String get deleteLoopBody =>
      'Se elimina este loop. Si era el principal, se quitan también los puntos A/B de la ruta (incl. amigos al sincronizar).';

  @override
  String get loopDeleted => 'Loop eliminado';

  @override
  String get deleteAllLoops => 'Quitar todos los loops';

  @override
  String get deleteAllLoopsBody =>
      'Se borran todos los loops de esta ruta y los puntos A/B. Los amigos verán la ruta sin loop al sincronizar.';

  @override
  String get loopsCleared => 'Loops eliminados';

  @override
  String get deleteConfirm => 'Eliminar';

  @override
  String get deleteRide => 'Eliminar ride';

  @override
  String get deleteRideBody =>
      'Se borrará permanentemente el ride y su línea GPS de este teléfono (y de la nube si estaba sincronizado).';

  @override
  String get rideDeleted => 'Ride eliminado';

  @override
  String get accountSection => 'Cuenta';

  @override
  String get accountGuest => 'Rider invitado';

  @override
  String get accountGuestBody =>
      'Estás en sesión de invitado. Inicia sesión para conservar tu perfil entre dispositivos — tus rides actuales se vinculan cuando es posible.';

  @override
  String get accountSignedIn => 'Sesión iniciada';

  @override
  String get accountSignedInBody =>
      'Tu cuenta de Google está vinculada. Cerrar sesión vuelve a modo invitado en este teléfono.';

  @override
  String signInWith(String provider) {
    return 'Entrar con $provider';
  }

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get accountSignedInSnack => 'Sesión iniciada — perfil sincronizado';

  @override
  String get accountSignedOutSnack => 'Sesión cerrada — modo invitado';

  @override
  String get rideLoopHelp =>
      'Encuentra vueltas cerradas en el GPS de este ride, o marca inicio (A) y fin (B) en el mapa. Al guardar se crea/usa una ruta para auto-vuelta después.';

  @override
  String get rideLoopEmpty =>
      'Aún no hay loops guardados en la ruta de este ride.';

  @override
  String get rideLoopDetectedEmpty =>
      'No hay vuelta cerrada en este ride. Prueba Marcar A / B en el mapa.';

  @override
  String get rideLoopNeedPoints =>
      'No hay suficientes puntos GPS para marcar un loop.';

  @override
  String get rideLoopSaveFirst => 'Guarda un loop primero — eso crea la ruta.';

  @override
  String get rideLoopOpenRoute => 'Abrir ruta (vueltas + loops)';

  @override
  String get syncCloudRides => 'Sincronizar rides con la nube';

  @override
  String get syncCloudRidesHelp =>
      'Sube los rides terminados y descarga a este teléfono los rides del Garage y las sesiones de Lean Lab de esta cuenta.';

  @override
  String syncCloudRidesDone(int ok, int fail) {
    return 'Subida: $ok ok, $fail fallaron';
  }

  @override
  String syncCloudRidesPulled(int rides, int lean) {
    return 'Descargados $rides rides, $lean Lean Lab';
  }

  @override
  String get playStoreUpdatesOnly =>
      'En esta versión las actualizaciones llegan por Google Play.';

  @override
  String get labSection => 'Lab (experimental)';

  @override
  String get labAdventureCameraHelp =>
      'Obturador GoPro opcional sincronizado con rides. Apagado por defecto — no cambia el GPS.';

  @override
  String get labAdventureCameraEnable => 'Cámara adventure';

  @override
  String get labAdventureCameraEnableHelp =>
      'Activa el módulo de cámara lab en este teléfono';

  @override
  String get labAdventureCameraSyncRide => 'Grabar con el ride';

  @override
  String get labAdventureCameraSyncRideHelp =>
      'Inicia/detiene con toda la ruta. Si hay zonas de inicio en el mapa, ellas mandan — la cámara espera el punto de inicio.';

  @override
  String get labAdventureCameraSyncPause => 'Seguir pausa auto';

  @override
  String get labAdventureCameraSyncPauseHelp =>
      'Pausa la cámara mientras la pausa auto de GPS está activa (opcional)';

  @override
  String get labAdventureCameraBackend => 'Backend';

  @override
  String get labAdventureCameraBackendGoPro => 'GoPro';

  @override
  String get labAdventureCameraBackendSim => 'Simular';

  @override
  String get labAdventureCameraConnect => 'Conectar';

  @override
  String get labAdventureCameraDisconnect => 'Desconectar';

  @override
  String get labAdventureCameraTestHelp =>
      'Prueba manual del obturador — sin ride. Conecta primero (o usa Simular).';

  @override
  String get labAdventureCameraTestStart => 'Probar inicio';

  @override
  String get labAdventureCameraTestStop => 'Probar parada';

  @override
  String get labAdventureCameraTestStartSnack => 'Inicio de cámara disparado';

  @override
  String get labAdventureCameraTestStopSnack => 'Parada de cámara disparada';

  @override
  String get labAdventureCameraPhaseOff => 'Lab apagado';

  @override
  String get labAdventureCameraPhaseIdle => 'Inactivo';

  @override
  String get labAdventureCameraPhaseScanning => 'Buscando…';

  @override
  String get labAdventureCameraPhaseConnecting => 'Conectando…';

  @override
  String get labAdventureCameraPhaseReady => 'Listo';

  @override
  String get labAdventureCameraPhaseRecording => 'Grabando';

  @override
  String get labAdventureCameraPhaseError => 'Error';

  @override
  String get labAdventureCameraZonesEnable => 'Zonas inicio/fin en el mapa';

  @override
  String get labAdventureCameraZonesEnableHelp =>
      'Inicia/detiene al entrar en geocercas. Los puntos de inicio controlan la grabación (cámara apagada hasta llegar).';

  @override
  String get labAdventureCameraZonesEdit => 'Editar zonas de cámara';

  @override
  String get labAdventureCameraZonesEmpty =>
      'Sin zonas — toca el mapa para añadir inicio/parada';

  @override
  String labAdventureCameraZonesCount(int count) {
    return '$count zonas en el mapa';
  }

  @override
  String get labAdventureCameraZonesTitle => 'Zonas de cámara';

  @override
  String get labAdventureCameraZonesHelp =>
      'Toca para colocar Inicio, luego toca de nuevo para la Parada de ese par. Mantén pulsado un marcador para borrar el par. Una Parada solo actúa después de su Inicio ligado.';

  @override
  String get labAdventureCameraZonesPlaceStart => 'Siguiente toque: Inicio ▶';

  @override
  String get labAdventureCameraZonesPlaceStop =>
      'Siguiente toque: Parada ■ de este par';

  @override
  String get labAdventureCameraZonesPairs => 'Pares';

  @override
  String get rideDeckTitle => 'Panel del ride';

  @override
  String get rideDeckHelp =>
      'Si va en el bolsillo: toca Guardar en el bolsillo y mételo antes de que acabe la cuenta. Quédate quieto hasta el haptic — no vuelves a tocar. Tanque/manillar: Sostener vertical 4s.';

  @override
  String get startRideNow => 'Iniciar ride ahora';

  @override
  String get labAdventureCameraZoneStart => 'Inicio';

  @override
  String get labAdventureCameraZoneStop => 'Parada';

  @override
  String get labAdventureCameraZonesClear => 'Borrar todas';

  @override
  String get labAdventureCameraZonesSave => 'Guardar zonas';

  @override
  String get labAdventureCameraAggressive => 'Auto-grabar conducción agresiva';

  @override
  String get labAdventureCameraAggressiveHelp =>
      'Arranca solo a ≥85 km/h con cambios de inclinación constantes; pausa al calmar la inclinación o bajar de velocidad';

  @override
  String get labAdventureCameraGroup => 'Grupo de cámaras';

  @override
  String get labAdventureCameraGroupHelp =>
      'Añade varias GoPro — el obturador se envía a todas las cámaras activas a la vez.';

  @override
  String get labAdventureCameraGroupEmpty => 'Aún no hay cámaras en el grupo.';

  @override
  String get labAdventureCameraGroupAdd => 'Añadir GoPro';

  @override
  String get labAdventureCameraGroupRemove => 'Quitar';

  @override
  String get labAdventureCameraGroupScanning => 'Buscando GoPros…';

  @override
  String get labAdventureCameraGroupNoneFound =>
      'No hay GoPros nuevas — enciéndelas y abre la tapa lateral.';

  @override
  String get labAdventureCameraGroupPick => 'Añadir al grupo';

  @override
  String get labAdventureCameraGroupSetupHelp => 'Ayuda: varias cámaras';

  @override
  String get labAdventureCameraGroupSetupBody =>
      '1. Enciende cada GoPro y abre la tapa lateral (Bluetooth activo).\n2. En el teléfono, permite Bluetooth (y dispositivos cercanos) si lo pide.\n3. Toca Añadir GoPro — espera el escaneo y elige cada cámara.\n4. Déjalas activas en la lista (apaga el interruptor para omitir una).\n5. Toca Conectar para enlazar todo el grupo.\n6. Inicia un ride (o usa zonas del mapa / auto-grabar agresivo) — el obturador arranca/para en todas las cámaras activas.\n7. En la pantalla del ride, CAM 2/2 significa que ambas están grabando.\n\nConsejos: acerca el teléfono a las cámaras en el primer enlace. Si una solo enciende y no graba, Conecta de nuevo y luego inicia el ride. Si una falla, las demás siguen.';

  @override
  String get labAdventureCameraScenariosTitle => 'Setups de prueba';

  @override
  String get labAdventureCameraScenarioZonesTitle =>
      'Solo entre puntos inicio/parada del mapa';

  @override
  String get labAdventureCameraScenarioZonesBody =>
      'ON: Cámara adventure · Zonas inicio/fin en el mapa (coloca Inicio + Parada) · cámaras en el grupo.\nOFF: Grabar con el ride · Auto-grabar conducción agresiva · Seguir pausa auto.\n\nNota: estas son zonas de cámara del Lab — no los puntos A/B de vueltas de la ruta.';

  @override
  String get labAdventureCameraScenarioZonesApply => 'Aplicar setup solo zonas';

  @override
  String get labAdventureCameraScenarioAggressiveTitle =>
      'Solo al empezar conducción divertida / agresiva';

  @override
  String get labAdventureCameraScenarioAggressiveBody =>
      'ON: Cámara adventure · Auto-grabar conducción agresiva · cámaras en el grupo.\nOFF: Grabar con el ride · Zonas inicio/fin en el mapa · Seguir pausa auto.';

  @override
  String get labAdventureCameraScenarioAggressiveApply =>
      'Aplicar setup solo agresivo';

  @override
  String get armAutoNoRouteHint =>
      'Armado — al moverte se inicia un recorrido en el Garaje.';

  @override
  String get freezeThenArmHelp =>
      'Toca ahora y mételo al bolsillo. Quédate quieto hasta el haptic. Luego bloquea la pantalla — al arrancar se inicia el ride. No vuelves a tocar.';

  @override
  String get armAutoRouteArmed => 'Armado — al arrancar se inicia el recorrido';

  @override
  String armAutoRouteArmedNamed(String name) {
    return 'Armado para «$name» — al arrancar el ride queda en esa ruta';
  }

  @override
  String couldNotLoadRides(String error) {
    return 'No se pudieron cargar recorridos: $error';
  }

  @override
  String get rodadasTitle => 'Rodadas';

  @override
  String get rodadasHomeSubtitle =>
      'Crea una rodada · invita · comparte GPS en vivo';

  @override
  String get friendsHelp =>
      'Busca riders, envía solicitudes de amistad e invita amigos aceptados a una rodada.';

  @override
  String get findRiders => 'Buscar riders';

  @override
  String get searchByNameHint => 'Buscar por nombre…';

  @override
  String get noRidersFound => 'No se encontraron riders';

  @override
  String friendRequestSent(String name) {
    return 'Solicitud enviada a $name';
  }

  @override
  String get addFriend => 'Añadir';

  @override
  String get friendRequests => 'Solicitudes';

  @override
  String get wantsToBeFriends => 'quiere ser tu amigo';

  @override
  String get accept => 'Aceptar';

  @override
  String get decline => 'Rechazar';

  @override
  String get pendingSent => 'Pendientes enviadas';

  @override
  String get waitingAcceptance => 'Esperando aceptación';

  @override
  String get yourFriends => 'Tus amigos';

  @override
  String get noFriendsYet =>
      'Aún no tienes amigos — busca arriba y envía una solicitud.';

  @override
  String get viewRides => 'Ver recorridos';

  @override
  String get inviteToRodada => 'Invitar a rodada';

  @override
  String get createRodadaFirst => 'Crea una rodada primero';

  @override
  String get inviteTo => 'Invitar a…';

  @override
  String friendInvited(String name) {
    return '$name invitado';
  }

  @override
  String scoreLabel(int score) {
    return 'Puntaje $score';
  }

  @override
  String get joinWithCodeTooltip => 'Unirse con código';

  @override
  String get createRodadaTooltip => 'Crear rodada';

  @override
  String get signInForRodadas => 'Inicia sesión para usar Rodadas';

  @override
  String couldNotLoadRodadas(String error) {
    return 'No se pudieron cargar rodadas.\n$error';
  }

  @override
  String get groupRidesTitle => 'Rodadas en grupo';

  @override
  String get groupRidesBody =>
      'Crea una rodada para Tapalpa, Moyahua o donde sea. Invita riders y comparte GPS en vivo, tracks y fotos solo si cada uno lo activa.';

  @override
  String get createRodada => 'Crear rodada';

  @override
  String get joinWithInviteCode => 'Unirse con código de invitación';

  @override
  String get joinRodadaTitle => 'Unirse a rodada';

  @override
  String get inviteCodeLabel => 'Código de invitación';

  @override
  String get inviteCodeHint => 'ej. TAP42A';

  @override
  String get joinButton => 'Unirse';

  @override
  String joinFailed(String error) {
    return 'No se pudo unir: $error';
  }

  @override
  String get timeTbd => 'Hora por definir';

  @override
  String rodadaRidersCount(int count) {
    return '$count riders';
  }

  @override
  String get newRodada => 'Nueva rodada';

  @override
  String get rodadaCreateButton => 'Crear';

  @override
  String get rodadaTitleLabel => 'Título';

  @override
  String get rodadaTitleHint => 'Tapalpa sábado';

  @override
  String get rodadaDestinationLabel => 'Destino';

  @override
  String get rodadaDestinationHint => 'Tapalpa / Moyahua / …';

  @override
  String get rodadaNotesLabel => 'Notas';

  @override
  String get rodadaNotesHint => 'Punto de encuentro en Shell, casco blanco…';

  @override
  String get rodadaStartsAt => 'Empieza';

  @override
  String get rodadaPickDateTime => 'Elegir fecha y hora';

  @override
  String get meetupPin => 'Pin de encuentro';

  @override
  String get useMyGps => 'Usar mi GPS';

  @override
  String get clearPin => 'Borrar';

  @override
  String get meetupMapHelp =>
      'Toca el mapa para fijar el punto de encuentro. GPS en vivo y fotos quedan apagados hasta que cada rider lo active.';

  @override
  String get titleRequired => 'El título es obligatorio';

  @override
  String locationFailed(String error) {
    return 'Falló la ubicación: $error';
  }

  @override
  String get rodadaFallback => 'Rodada';

  @override
  String get copyInviteCode => 'Copiar código de invitación';

  @override
  String inviteCodeCopied(String code) {
    return 'Código $code copiado';
  }

  @override
  String get markAsLive => 'Marcar EN VIVO';

  @override
  String get markAsOpen => 'Marcar abierta';

  @override
  String get endRodada => 'Terminar rodada';

  @override
  String get inviteFriend => 'Invitar amigo';

  @override
  String get rodadaTabOverview => 'Resumen';

  @override
  String get rodadaTabLive => 'En vivo';

  @override
  String get rodadaTabRides => 'Recorridos';

  @override
  String get rodadaTabPhotos => 'Fotos';

  @override
  String get rodadaTabRadio => 'Radio';

  @override
  String get rodadaNotFound => 'Rodada no encontrada';

  @override
  String rodadaStatusChanged(String status) {
    return 'Estado → $status';
  }

  @override
  String get noFriendsToInvite => 'Aún no hay amigos para invitar.';

  @override
  String get inviteSent => 'Invitación enviada';

  @override
  String rodadaCodeBanner(String code) {
    return 'código $code';
  }

  @override
  String get meetup => 'Encuentro';

  @override
  String get yourSharing => 'Tu compartición';

  @override
  String get sharingDefaultsHelp =>
      'Apagado por defecto. Si lo activas, envía ubicación cada 5 minutos durante la rodada (reintenta cada 1 minuto si falla).';

  @override
  String get notRodadaMember => 'No eres miembro.';

  @override
  String get shareLocationOnRoute => 'Compartir ubicación en ruta';

  @override
  String get shareLocationEvery5Min =>
      'Cada 5 min mientras la rodada está abierta/en vivo';

  @override
  String get shareTrackAfterRides => 'Compartir mi track después de recorridos';

  @override
  String get rodadaRiders => 'Riders';

  @override
  String get noMembersYet => 'Aún no hay miembros';

  @override
  String get rsvpGoing => 'voy';

  @override
  String get rsvpMaybe => 'tal vez';

  @override
  String get rsvpDeclined => 'no voy';

  @override
  String get memberLiveOn => 'vivo activo';

  @override
  String get memberTrackOn => 'track activo';

  @override
  String get sharingLocationBanner =>
      'Compartiendo ubicación cada 5 min (reintento 1 min si falla)';

  @override
  String get liveMapViewOnly =>
      'Mapa en vivo solo lectura. Activa compartir en Resumen.';

  @override
  String get shareLive => 'Compartir en vivo';

  @override
  String get noLiveRidersYet =>
      'Aún no hay riders en vivo. Los que opten aparecen aquí (~5 s).';

  @override
  String get addStop => 'Añadir parada';

  @override
  String get stopFab => 'Parada';

  @override
  String get stopTitleLabel => 'Título';

  @override
  String get dropAtMyGps => 'Soltar en mi GPS';

  @override
  String get gasBreakDefault => 'Gas / descanso';

  @override
  String get stopDefault => 'Parada';

  @override
  String get sharedTracksHelp =>
      'Tracks compartidos de miembros que lo activaron. El GPS denso queda en cada teléfono.';

  @override
  String get linkMyRide => 'Vincular mi recorrido';

  @override
  String get noSharedRidesYet => 'Aún no hay recorridos compartidos';

  @override
  String get noCompletedRidesToLink =>
      'No hay recorridos terminados para vincular';

  @override
  String get syncRideFirst =>
      'Sincroniza el recorrido primero e inténtalo de nuevo';

  @override
  String get rideLinkedToRodada => 'Recorrido vinculado a esta rodada';

  @override
  String get noTrackPoints => 'Sin puntos de track';

  @override
  String get radioAllGood => 'Todo bien';

  @override
  String get radioStoppingFiveMin => 'Parando 5 min';

  @override
  String get radioNeedHelp => 'Necesito ayuda';

  @override
  String get noMessagesYet => 'Aún no hay mensajes';

  @override
  String get shortRadioMessageHint => 'Mensaje corto de radio…';

  @override
  String get safetyTag => 'SEGURIDAD';

  @override
  String get riderFallback => 'Rider';

  @override
  String get photosAlbumHelp =>
      'El álbum carga solo miniaturas. La imagen completa se abre al tocar y se libera al cerrar.';

  @override
  String get photoAdd => 'Añadir';

  @override
  String get noPhotosYet => 'Aún no hay fotos';

  @override
  String get photoUploaded => 'Foto subida';

  @override
  String get photoTitle => 'Foto';

  @override
  String get skillCoach => 'Coach de habilidad';

  @override
  String skillCurvasRated(int count) {
    return '$count curvas calificadas · huellas para comparar';
  }

  @override
  String get improveNextRide => 'Mejorar el próximo recorrido';

  @override
  String get openCornerLab => 'Abrir corner lab';

  @override
  String get skillTipNoCurvas =>
      'No se detectaron curvas sólidas — recorre una sección sinuosa para tener una base.';

  @override
  String skillTipEntryHot(String entry, String apex) {
    return 'Entrada caliente ($entry→$apex km/h). Frena antes del tip-in.';
  }

  @override
  String get skillTipModerateSpeedDrop =>
      'Caída moderada de velocidad al apex — trail brake un poco más.';

  @override
  String get skillTipLittleSpeedScrub =>
      'Poca reducción de velocidad — confirma que no llevas demasiada en mitad de curva.';

  @override
  String get skillTipWeakExitDrive =>
      'Salida débil — abre gas antes cuando la inclinación empiece a bajar.';

  @override
  String get skillTipPeakLeanNotAtApex =>
      'Inclinación máxima no en el apex — inclina antes para estar listo en el apex.';

  @override
  String get skillTipLowLeanBigHeading =>
      'Gran cambio de rumbo con poca inclinación — revisa el sensor o inclínate más.';

  @override
  String get skillTipSolidCorner =>
      'Curva sólida — mantén este ritmo de entrada/apex.';

  @override
  String skillHighlightBest(String label, int score) {
    return 'Mejor: $label · $score/100';
  }

  @override
  String skillHighlightMedian(int score) {
    return 'Puntaje mediano de curvas $score/100';
  }

  @override
  String skillTipDrillRepeat(String label) {
    return 'Práctica: repite una $label similar y frena 10–15 m antes.';
  }

  @override
  String get performanceLabel => 'RENDIMIENTO';

  @override
  String get statRides => 'Recorridos';

  @override
  String get statDistance => 'Distancia';

  @override
  String get statTopSpeed => 'Vel. máx.';

  @override
  String get statPeakLean => 'Inclinación';

  @override
  String get rideDiscarded => 'Descartado';

  @override
  String get gpsQualitySparseTip =>
      'GPS escaso — deja la notificación de grabación y evita límites de batería.';

  @override
  String gpsQualityFairTip(String meters) {
    return 'GPS ~$meters m — la línea sirve, pero un poco suave.';
  }

  @override
  String gpsQualityWeakTip(String meters) {
    return 'GPS débil (~$meters m) — fija mejor el teléfono y rueda al aire libre.';
  }

  @override
  String gpsRateHz(String hz) {
    return '$hz Hz';
  }

  @override
  String get pressure => 'Presión';

  @override
  String get pressureChartSub => 'Barómetro a lo largo del recorrido (hPa)';

  @override
  String get skillLabTitle => 'Lab de técnica';

  @override
  String get skillLabTapHint => 'Toca para ver errores y cómo mejorar';

  @override
  String get skillLabTapHintEmpty => 'Toca para tips tras un tramo sinuoso';

  @override
  String get skillLabFocusTitle => 'Dónde mejorar';

  @override
  String get skillLabFocusHelp =>
      'Primero las curvas con peor puntaje. Las barras son entrada → ápice → salida. Toca Repetir para ver inclinación, freno y velocidad — y comparar la misma sección de curva con un amigo.';

  @override
  String get bikeSection => 'Mi moto';

  @override
  String get bikeSelect => 'Elige tu moto';

  @override
  String get bikeSelectHelp =>
      'Catálogo Triumph — se usa en Lean Lab y contexto de recorridos';

  @override
  String get bikePickerTitle => 'Garage';

  @override
  String get bikePickerHelp =>
      'Elige la Triumph que ruedas. Etiqueta Lean Lab y datos de entrenamiento.';

  @override
  String get bikeClear => 'Quitar';

  @override
  String get bikeFamilyNaked => 'Naked';

  @override
  String get bikeFamilyAdventure => 'Adventure';

  @override
  String get bikeFamilyClassic => 'Clásica';

  @override
  String get bikeFamilySport => 'Sport';

  @override
  String get bikeFamilyCruiser => 'Cruiser';

  @override
  String get bikeFamilyOther => 'Otra';

  @override
  String get leanLabHomeCta => 'Lab de inclinación — Bugambilias';

  @override
  String get leanLabTitle => 'Lab de inclinación';

  @override
  String get leanLabIntro =>
      'Protocolo para pilots en Bugambilias — ambos sentidos, con elevación. Calibra vertical, rueda y etiqueta curvas para pulir el lean.';

  @override
  String get leanLabCircuitName => 'Circuito Bugambilias';

  @override
  String get leanLabCircuitHelp =>
      'Plaza Panorámica Bugambilias · ambos sentidos · abrir en Maps';

  @override
  String leanLabProgress(int labeled, int total) {
    return '$labeled de $total sesiones etiquetadas';
  }

  @override
  String get leanLabProtocols => 'Protocolos';

  @override
  String get leanLabProtoOutbound => 'Base de ida';

  @override
  String get leanLabProtoOutboundHelp =>
      'Hacia la plaza, mount al centro. Captura lean en subida/bajada.';

  @override
  String get leanLabProtoReturn => 'Base de regreso';

  @override
  String get leanLabProtoReturnHelp =>
      'Sentido contrario, mount al centro. Mismas curvas, lados invertidos.';

  @override
  String get leanLabProtoPocket => 'Mount A/B — bolsillo';

  @override
  String get leanLabProtoPocketHelp =>
      'Mismo circuito con teléfono en bolsillo para aprender el sesgo del mount.';

  @override
  String get leanLabProtoFree => 'Vuelta libre Lean Lab';

  @override
  String get leanLabProtoFreeHelp =>
      'Cualquier sentido en este circuito con calib + etiquetas de curva.';

  @override
  String get leanLabStartProtocol => 'Preparar y rodar';

  @override
  String get leanLabNeedsLabels => 'Faltan etiquetas de curva';

  @override
  String leanLabElevationSummary(String climb, String descent) {
    return '↑$climb m · ↓$descent m';
  }

  @override
  String get leanLabPrepTitle => 'Prep Lean Lab';

  @override
  String get leanLabPrepHelp =>
      'Elige mount y pose. Congela g0 con el teléfono ya en ese mount — los sensores eligen roll o pitch. Luego arranca la vuelta.';

  @override
  String get leanLabPoseQ => '¿Cómo va el teléfono?';

  @override
  String get leanLabPoseScreenOut => 'Vertical · pantalla afuera';

  @override
  String get leanLabPoseScreenIn => 'Vertical · pantalla adentro';

  @override
  String get leanLabPoseLandscape => 'Horizontal';

  @override
  String get leanLabDirectionQ => '¿Dirección en Bugambilias?';

  @override
  String get leanLabDirectionOutbound => 'Ida (a la plaza)';

  @override
  String get leanLabDirectionReturn => 'Regreso';

  @override
  String get leanLabCalibTitle => 'Calibración vertical';

  @override
  String get leanLabCalibHelp =>
      'Moto vertical, teléfono ya montado. Sin tocarlo, 4 segundos — congela gravedad (g0). El vector lean debe quedar cerca de 0°.';

  @override
  String get leanLabCalibHold => 'Sostener vertical 4s';

  @override
  String get leanLabCalibHolding => 'Quédate quieto…';

  @override
  String get leanLabCalibPocket => 'Guardar en el bolsillo';

  @override
  String get leanLabCalibPocketHelp =>
      'Siéntate vertical en la moto. Toca, mételo del todo antes de que acabe la cuenta. Quédate quieto hasta el haptic — no congeles en la mano.';

  @override
  String leanLabCalibPocketCountdown(int n) {
    return 'Mételo ahora · ${n}s';
  }

  @override
  String get leanLabCalibPocketSettle => 'Quédate quieto…';

  @override
  String get leanLabCalibPocketCapture => 'Capturando 0°…';

  @override
  String get leanLabCalibPocketFail =>
      'No se quedó quieto. Sácalo y reintenta.';

  @override
  String leanLabFreezeRedo(String n) {
    return 'El teléfono ya va $n° de vertical. Repite el freeze con la moto de verdad derecha.';
  }

  @override
  String get leanLabRawNeutral => 'Ángulo crudo del teléfono';

  @override
  String get leanLabFrozenNeutral => 'Neutro congelado';

  @override
  String get leanLabStartRide => 'Iniciar recorrido Lean Lab';

  @override
  String get leanLabReviewTitle => 'Etiquetar inclinación';

  @override
  String get leanLabReviewHelp =>
      'En cada curva: ¿el lean de la app se sintió alto, bien o bajo? Se muestra la pendiente para corregir sesgo de subida/bajada.';

  @override
  String get leanLabReviewHelpMax =>
      'El lean máximo de la curva queda fijo arriba. Reproduce la curva para ver lean y mapa; salta al pico cuando quieras.';

  @override
  String get leanLabMaxLean => 'Lean máximo';

  @override
  String get leanLabJumpToMax => 'Ir al lean máximo';

  @override
  String get leanLabLiveLean => 'Lean en vivo';

  @override
  String get leanLabAtPeak => 'en el pico';

  @override
  String get leanLabMaxLeanGps => 'GPS donde ocurrió el lean máximo';

  @override
  String leanLabMaxLeanGpsA(String lat, String lng) {
    return 'A · $lat, $lng';
  }

  @override
  String leanLabMaxLeanGpsB(String lat, String lng) {
    return 'B · $lat, $lng';
  }

  @override
  String get leanLabSideLeft => 'izquierda';

  @override
  String get leanLabSideRight => 'derecha';

  @override
  String get leanLabNoCorners =>
      'No hay curvas detectadas para etiquetar en este recorrido.';

  @override
  String get leanLabNoTrackPoints =>
      'Este recorrido casi no tiene GPS en el teléfono. Abre Ajustes → Sincronizar rides con la nube (misma cuenta Google) y vuelve a intentar.';

  @override
  String get leanLabNoLeanData =>
      'El GPS está, pero faltan muestras de inclinación — no se pueden etiquetar curvas. Sincroniza de nuevo o graba la vuelta con el teléfono bien fijado.';

  @override
  String get leanLabAppLean => 'Lean app';

  @override
  String get leanLabGrade => 'Pendiente';

  @override
  String get leanLabBiasQ => '¿Cómo se sintió el lean de la app en el ápice?';

  @override
  String get leanLabBiasAppHigh => 'App muy alto';

  @override
  String get leanLabBiasOk => 'Se sintió bien';

  @override
  String get leanLabBiasAppLow => 'App muy bajo';

  @override
  String get leanLabBiasUnsure => 'No estoy seguro';

  @override
  String get leanLabTrendClimbing => 'subiendo';

  @override
  String get leanLabTrendDescending => 'bajando';

  @override
  String get leanLabTrendFlat => 'plano';

  @override
  String get leanLabSaveLabels => 'Guardar etiquetas';

  @override
  String get leanLabSettingsTile => 'Lab de inclinación (pilots)';

  @override
  String get leanLabSettingsHelp =>
      'Protocolo Bugambilias · calib · elevación · verdad de curvas';

  @override
  String get leanImuLabTitle => 'Lab IMU de inclinación';

  @override
  String get leanImuLabIntro =>
      'El mismo motor que producción. Congela vertical en el mount real, luego inclina — bike lean es la magnitud vectorial con el signo del canal ganador. El banner muestra pose (Vertical / Landscape / Flat) y el ganador.';

  @override
  String get leanImuLabSettingsTile => 'Sensores IMU de lean';

  @override
  String get leanImuLabSettingsHelp =>
      'Estudia accel / gyro / mag / baro y el motor de lean según el mount';

  @override
  String get leanImuLabFreeze => 'Congelar vertical';

  @override
  String get leanImuLabReset => 'Reset';

  @override
  String get leanImuLabFrozenHint =>
      'g0 está congelado. Bike lean debe ser ~0°. Inclina en cualquier dirección — el vector es el ángulo, el ganador da izquierda/derecha.';

  @override
  String get leanImuLabAnglesTitle => 'Candidatos de ángulo';

  @override
  String get leanImuLabAnglesHelp =>
      'Bike lean = producción. Vector = ángulo 3D desde el freeze. Roll sigue el lean si el teléfono está vertical; pitch si está plano. Fused = gyro + accel. Old App lean es la fórmula de eje más cercano que retiramos.';

  @override
  String get leanImuLabHistoryTitle => 'Últimos ~8 s';

  @override
  String get leanImuLabVectorsTitle => 'Capacidades crudas';

  @override
  String get leanImuLabNextTitle => 'Cómo leer esto para producción';

  @override
  String get leanImuLabNextHelp =>
      'Pared: vector a ~3° de un clinómetro, cualquier pose. Vertical: bike lean sigue fused roll. Plano: sigue pitch/vector. Si se mueve en el bolsillo: el banner cambia de pose en unos segundos. Mag (heading) es extra, no es lean de la moto.';

  @override
  String get leanLabPastSessions => 'Sesiones anteriores';

  @override
  String get leanLabSessionDetailTitle => 'Sesión Lean Lab';

  @override
  String get leanLabSessionMissing => 'No se encontró esta sesión de Lean Lab.';

  @override
  String get leanLabMeasuresTitle => 'Medidas';

  @override
  String get leanLabCornerMeasures => 'Lean máximo por curva';

  @override
  String get leanLabCoverage => 'Cobertura del circuito';

  @override
  String get leanLabCornersCount => 'Curvas etiquetadas';

  @override
  String leanLabLabeledCount(int count) {
    return '$count curvas etiquetadas';
  }

  @override
  String get leanLabEditConfigTitle => 'Corregir configuración';

  @override
  String get leanLabEditConfigHelp =>
      'Corrige ida/vuelta, mount o pose si te equivocaste — los números de lean no cambian; las etiquetas se quedan hasta que las vuelvas a guardar.';

  @override
  String get leanLabSaveConfig => 'Guardar configuración';

  @override
  String get leanLabConfigSaved => 'Configuración guardada';

  @override
  String get leanLabRelabelCorners => 'Revisar / actualizar etiquetas';

  @override
  String get leanLabOpenRide => 'Abrir mapa del recorrido';

  @override
  String get skillReplayTitle => 'Repetición de curva';

  @override
  String get skillReplayHelp =>
      'Mira cómo se rodó este tramo — inclinación, freno y velocidad van con el cursor en el mapa.';

  @override
  String get skillReplayCompareHelp =>
      'Ambas líneas se recortan al mismo tramo de carretera. Los cursores avanzan por distancia en la curva para comparar la línea, no el reloj.';

  @override
  String get skillReplayCompareWith => 'Comparar con un amigo';

  @override
  String get skillReplayNoPeerMatch =>
      'Este amigo no pasó por la misma sección de la curva.';

  @override
  String get skillReplayAlignedSection =>
      'Misma sección de curva para ambos (coinciden en el corredor).';

  @override
  String get skillReplaySameSection =>
      'misma sección · sincronizado por distancia';

  @override
  String get skillReplay => 'Repetir';

  @override
  String get compareSharedSectionHelp =>
      'Continua = tú · punteada = otro. Las líneas se separan un poco y se recortan al tramo compartido para ver ambas.';

  @override
  String get compareTrackUnavailable =>
      'No hay puntos de track para este recorrido.';

  @override
  String get compareOneTrackOnly =>
      'Solo una de las dos rutas tiene puntos suficientes para dibujar.';

  @override
  String get play => 'Reproducir';

  @override
  String get pause => 'Pausa';

  @override
  String get restart => 'Reiniciar';

  @override
  String get loopReplay => 'Bucle';

  @override
  String get brake => 'Freno';

  @override
  String get engineLabelTitle => 'Ayuda a entrenar RiderLab';

  @override
  String get engineLabelIntro =>
      'Solo beta — unos toques tras cada recorrido enseñan inclinación, curvas y frenos. Puedes omitir.';

  @override
  String get engineLabelSkip => 'Omitir';

  @override
  String get engineLabelSave => 'Guardar respuestas';

  @override
  String get engineLabelMountQ => '¿Dónde iba el teléfono en este recorrido?';

  @override
  String get engineLabelMountCenter => 'Base (tanque / manillar)';

  @override
  String get engineLabelMountLeftPocket => 'Bolsillo izquierdo';

  @override
  String get engineLabelMountRightPocket => 'Bolsillo derecho';

  @override
  String get engineLabelMountOther => 'Otro / suelto';

  @override
  String get engineLabelLeanQ => '¿La inclinación se sintió bien?';

  @override
  String get engineLabelLeanGood => 'Se sintió bien';

  @override
  String get engineLabelLeanLeftHigh => 'Izquierda se veía alta';

  @override
  String get engineLabelLeanRightHigh => 'Derecha se veía alta';

  @override
  String get engineLabelLeanBothOff => 'Ambos lados mal';

  @override
  String get engineLabelLeanUnsure => 'No sé';

  @override
  String get engineLabelBrakeQ => '¿Los frenos detectados se vieron bien?';

  @override
  String get engineLabelBrakeGood => 'Se sintió bien';

  @override
  String get engineLabelBrakeTooMany => 'Demasiados / falsos';

  @override
  String get engineLabelBrakeTooFew => 'Faltaron frenos reales';

  @override
  String get engineLabelBrakeUnsure => 'No sé';

  @override
  String get engineLabelContextQ => '¿Qué tipo de recorrido fue?';

  @override
  String get engineLabelContextStreet => 'Ciudad';

  @override
  String get engineLabelContextMountain => 'Montaña';

  @override
  String get engineLabelContextTrack => 'Pista';

  @override
  String get engineLabelContextCommute => 'Traslado';

  @override
  String get engineLabelContextOther => 'Otro';

  @override
  String get gpsCheckingPermission => 'Comprobando permiso de ubicación…';

  @override
  String get gpsPreparing => 'Preparando GPS de alta precisión…';

  @override
  String get gpsLookingSatellites => 'Buscando satélites…';

  @override
  String get gpsWarming => 'Calentando GPS…';

  @override
  String gpsWarmingAcc(String meters) {
    return 'Calentando GPS (±$meters m)…';
  }

  @override
  String gpsReadyAcc(String meters) {
    return 'GPS listo (±$meters m)';
  }

  @override
  String gpsStartWithAcc(String meters) {
    return 'Arrancando con ±$meters m — mantén el cielo abierto';
  }

  @override
  String get gpsStartKeepSky =>
      'Arrancando — mantén el cielo abierto para mejor señal';

  @override
  String get gpsRollingNextLap => 'Rodando hacia la siguiente vuelta…';

  @override
  String get locationServicesOff => 'Activa la ubicación para grabar tu línea.';

  @override
  String get locationPermissionDenied =>
      'Se necesita permiso de ubicación para dibujar tu línea.';

  @override
  String get locationPermissionDeniedForever =>
      'Activa la ubicación en Ajustes e inténtalo de nuevo.';

  @override
  String leanAtPlayhead(String degrees) {
    return 'En el cursor · offset neutral $degrees°';
  }

  @override
  String scrubPointMeta(int index, int total, String speed) {
    return 'Punto $index/$total  ·  $speed  ·  incl. ';
  }

  @override
  String scrubGpsMeta(String meters) {
    return '  ·  GPS $meters m';
  }

  @override
  String get shareVisibilityHelp =>
      'Elige quién puede ver este recorrido. Los amigos deben aceptar tu solicitud primero.';

  @override
  String get speedLegendScale => 'azul→lima→amarillo→rojo→magenta';

  @override
  String brakePeakDecel(String value) {
    return 'pico $value m/s²';
  }

  @override
  String curvaMetaTurnLean(String turn, String lean) {
    return 'giro $turn° · incl. $lean°';
  }
}
