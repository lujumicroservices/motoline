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
  String get sectionLoop => 'Loop';

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
  String get routeLoopSourceManual => 'Manual';

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
  String get syncCloudRides => 'Subir rides a la nube';

  @override
  String get syncCloudRidesHelp =>
      'Guarda métricas (velocidad, lean, line score, GPS) de todos los rides terminados en tu cuenta.';

  @override
  String syncCloudRidesDone(int ok, int fail) {
    return 'Nube: $ok ok, $fail fallaron';
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
      'Elige Inicio o Parada y toca el mapa. Mantén pulsado un marcador para borrarlo. Apaga “Grabar con el ride” para grabar solo en las zonas.';

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
      'Inicia la cámara con inclinación fuerte o aceleración brusca';

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
  String get armAutoNoRouteHint =>
      'Armado sin ruta — el ride irá al Garage, no a Vueltas. Ábrelo desde una ruta o crea una primero.';

  @override
  String get armAutoRouteArmed =>
      'Armado — al arrancar se guarda en tu última ruta';

  @override
  String armAutoRouteArmedNamed(String name) {
    return 'Armado para «$name» — al arrancar el ride queda en esa ruta';
  }
}
