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
  String get tagline => 'Mejora en cada curva.';

  @override
  String get autoPauseToggle => 'Pausar al parar';

  @override
  String get autoPauseToggleHint =>
      'La grabación se pausa cuando paras y sigue cuando vuelves a rodar.';

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
      'Pone el nombre según dónde empezaste y terminaste (ej. Tesistán - Zapopan).';

  @override
  String namingRidesProgress(int done, int total) {
    return 'Nombrando $done de $total…';
  }

  @override
  String namedRidesDone(int count) {
    return 'Se nombraron $count recorridos.';
  }

  @override
  String get rideUntitledHint => 'Inicio - fin aún sin nombre';

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
  String get couldNotResolvePlaces => 'No se encontraron esos lugares';

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
      'Inicia un recorrido y RiderLab dibuja la línea que tomaste en la calle.';

  @override
  String get unfinishedRide => 'Recorrido sin terminar';

  @override
  String unfinishedRideBody(String when) {
    return 'Empezó $when. Termínalo para guardar la línea, o bórralo.';
  }

  @override
  String get discard => 'Descartar';

  @override
  String get keepLine => 'Guardar línea';

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
  String get rideLab => 'Lab del recorrido';

  @override
  String get rideLabSegment => 'Lab del recorrido · este tramo';

  @override
  String get rideNotFound => 'Recorrido no encontrado';

  @override
  String get collapseHint =>
      'Toca un título para ocultarlo. El marcador se queda abajo.';

  @override
  String get segmentZoomHint =>
      'Solo este tramo — números y gráficas son de esta parte del recorrido.';

  @override
  String get sectionSegment => 'Este tramo';

  @override
  String get sectionSegmentSub => 'Elige una parte del recorrido';

  @override
  String get sectionOverview => 'Resumen';

  @override
  String get sectionOverviewSub => 'Puntaje y números del recorrido';

  @override
  String get sectionOverviewSubZoom => 'Puntaje y números de este tramo';

  @override
  String get sectionLean => 'Inclinación';

  @override
  String get sectionLeanSub => 'Azul izquierda · amarillo derecha';

  @override
  String get sectionMap => 'Mapa + línea';

  @override
  String get sectionMapSub => 'Color = velocidad · puntos = frenos';

  @override
  String get sectionRoad => 'Curvas';

  @override
  String get sectionRoadSub => 'Por el giro y la inclinación';

  @override
  String get sectionLoop => 'Vueltas';

  @override
  String get sectionLoopSub => 'Encuentra vueltas o marca inicio y fin';

  @override
  String get sectionBrakes => 'Frenado';

  @override
  String get sectionBrakesSub =>
      'Las más fuertes primero · acerca el mapa para ver un tramo';

  @override
  String get sectionBrakesSubZoom => 'Frenadas de este tramo, en orden';

  @override
  String get sectionCharts => 'Gráficas';

  @override
  String get sectionChartsSub => 'Velocidad · inclinación · GPS';

  @override
  String get sectionNotes => 'Calidad GPS';

  @override
  String get sectionNotesSub => 'Tasa de muestreo y precisión de esta línea';

  @override
  String get segment => 'TRAMO';

  @override
  String get segmentZoom => 'ESTE TRAMO';

  @override
  String get segmentHint =>
      'Arrastra los controles para elegir un tramo y luego acércalo.';

  @override
  String get segmentHintZoomed =>
      'El mapa y los números muestran solo este tramo. Arrastra para cambiarlo.';

  @override
  String get zoomToSegment => 'Acercar a este tramo';

  @override
  String get fullRide => 'Recorrido completo';

  @override
  String get playhead => 'MARCADOR';

  @override
  String get distance => 'Distancia';

  @override
  String get time => 'Tiempo';

  @override
  String get speed => 'Velocidad';

  @override
  String get bikeLean => 'Inclinación';

  @override
  String get calibrating => 'Guardando 0°…';

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
      'Qué tan preciso está el GPS, en metros (más bajo es mejor)';

  @override
  String get chartSpeedSub =>
      'Los colores son la velocidad. Toca para moverte en el recorrido.';

  @override
  String get chartSpeedSubZoom =>
      'Solo la velocidad de este tramo. Toca para moverte.';

  @override
  String get leanHelp =>
      '0° es la moto derecha. Para que salga bien, fija el teléfono en el tanque o el manubrio, pantalla hacia ti. Un bolsillo suelto tira el número.';

  @override
  String get leanPhoneDisclaimer =>
      'Cómo llevas el teléfono importa: derecho, pantalla hacia ti, bien sujeto. Un bolsillo suelto hace ver mal la inclinación.';

  @override
  String get mapHint =>
      'Toca la línea para mover la moto. El color es la velocidad. Los puntos son frenos.';

  @override
  String get mapHintZoom =>
      'Toca la línea para mover la moto. Brillante = este tramo · tenue = el resto.';

  @override
  String get startingRide => 'Iniciando recorrido';

  @override
  String get gpsReady => 'GPS listo';

  @override
  String gpsWarmHelp(String meters) {
    return 'Quédate afuera con cielo abierto. La grabación empieza cuando el GPS esté suficientemente bien (cerca de ±$meters m).';
  }

  @override
  String get horizontalAccuracy => 'PRECISIÓN GPS';

  @override
  String lowerBetter(String meters) {
    return 'Menor es mejor · listo a ±$meters m';
  }

  @override
  String get couldNotStart => 'No se pudo iniciar el recorrido';

  @override
  String get tryAgain => 'Reintentar';

  @override
  String get back => 'Volver';

  @override
  String get activeMountHelp =>
      'El 0° ya está guardado. Puedes bloquear la pantalla — deja la notificación de grabación encendida.';

  @override
  String curvaTitle(int number) {
    return 'Curva #$number';
  }

  @override
  String get curveLine => 'Línea de la curva';

  @override
  String get entry => 'Entrada';

  @override
  String get apex => 'Punto más cerrado';

  @override
  String get exit => 'Salida';

  @override
  String get brakeToApex => 'Freno al punto más cerrado';

  @override
  String get accelFromApex => 'Acelera después del punto más cerrado';

  @override
  String get leanAtApex => 'Inclinación en el punto más cerrado';

  @override
  String get maxLean => 'Incl. máx';

  @override
  String get leftShort => 'Izq';

  @override
  String get rightShort => 'Der';

  @override
  String get curvaMapLegend =>
      'E = entrada · A = punto más cerrado · S = salida. El color es la velocidad.';

  @override
  String get curvaCoach =>
      'Revisa rápido: si entraste muy rápido (mucho freno antes de A), si el centro de la curva iba estable y si saliste acelerando limpio.';

  @override
  String roadStretchesHelp(int curvas) {
    return 'Curvas según el giro y la inclinación. $curvas curvas. Toca una para ver entrada, centro y salida — desliza para la siguiente.';
  }

  @override
  String get roadStretchesEmpty =>
      'Aún no hay suficiente giro en el GPS para detectar curvas.';

  @override
  String get openDetail => 'abrir detalle';

  @override
  String get brakesHelp =>
      'Se calcula por qué tan rápido baja la velocidad — no es un sensor de freno. Las más fuertes primero. Toca una marca para ir ahí. Acerca el mapa para ver más en un tramo.';

  @override
  String get brakesHelpZoom =>
      'Frenadas de este tramo, en orden de tiempo. Toca una marca para ir ahí.';

  @override
  String get brakesEmpty =>
      'No hay frenadas claras por GPS. Las paradas fuertes suelen verse amarillo, naranja o rojo.';

  @override
  String get brakesEmptyZoom => 'No hay frenadas claras en este tramo.';

  @override
  String brakesMoreOverview(int count) {
    return '$count más en este recorrido. Acerca el mapa para ver el resto de un tramo.';
  }

  @override
  String brakesMoreInStretch(int count) {
    return '$count más en este tramo.';
  }

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
      'Mueve y acerca el mapa. Dibuja un recuadro o usa lo que se ve, y luego carga los números de ese tramo.';

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
  String get loadAreaMetrics => 'Cargar números de esta área';

  @override
  String areaReady(int points) {
    return 'Área lista · $points puntos GPS. Carga los números para ver este tramo en el lab.';
  }

  @override
  String get zoomIn => 'Acercar';

  @override
  String get zoomOut => 'Alejar';

  @override
  String get fitRide => 'Ajustar recorrido';

  @override
  String get myLocation => 'Mi ubicación';

  @override
  String get myLocationUnavailable => 'No se pudo obtener tu ubicación.';

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
  String get mapLayerPlayhead => 'Marcador';

  @override
  String get mapLayerLegend => 'Leyenda';

  @override
  String get mapLayerGpsGaps => 'Huecos GPS';

  @override
  String get friends => 'Amigos';

  @override
  String get friendsSubtitle =>
      'Grupo cerrado — quien tenga la app aparece aquí.';

  @override
  String get friendsEmpty =>
      'Aún no hay otros riders. Cuando un amigo instale RiderLab, aparece aquí.';

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
  String get compareTitle => 'Comparar recorridos';

  @override
  String get comparePickPeer => 'Recorridos de amigos en la misma zona';

  @override
  String get compareEmpty =>
      'Ningún recorrido de amigos cubre esta zona todavía.';

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
      'Elige una primera vuelta y una segunda para comparar tiempos y líneas en el mismo circuito.';

  @override
  String get compareLocalEmpty =>
      'Necesitas al menos 2 vueltas terminadas en esta ruta. Usa el modo vueltas o marca recorridos con la misma ruta.';

  @override
  String get compareBaseline => 'Base';

  @override
  String get compareChallenger => 'Segunda vuelta';

  @override
  String compareLocal(int count) {
    return 'Comparar vueltas ($count)';
  }

  @override
  String compareDeltaFaster(String delta) {
    return 'La segunda vuelta es más rápida por $delta';
  }

  @override
  String compareDeltaSlower(String delta) {
    return 'La segunda vuelta es más lenta por $delta';
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
  String get friendRides => 'Recorridos compartidos';

  @override
  String get friendRidesEmpty =>
      'Este rider aún no tiene recorridos compartidos.';

  @override
  String get syncingRide => 'Compartiendo el recorrido con amigos…';

  @override
  String get cloudUnavailable =>
      'No hay conexión con la nube — revisa internet e inténtalo de nuevo.';

  @override
  String get cloudAnonymousOff =>
      'Amigos necesita el inicio de sesión activado en la nube de RiderLab. Pregunta a quien configuró la app, luego abre Amigos otra vez y desliza para actualizar.';

  @override
  String get routesTitle => 'Rutas';

  @override
  String get routesHelp =>
      'Nombra un circuito, compártelo y marca recorridos para que los amigos comparen en el mismo camino.';

  @override
  String get routesHowTitle => '¿Cómo se usan las rutas?';

  @override
  String get routesHowBody =>
      '1) Crea una ruta con + (ej. «Glorieta norte»).\n2) Abre la ruta → pestaña Vueltas: encuentra vueltas cerradas en recorridos marcados, o marca tú el inicio (A) y el fin (B).\n3) Inicia un recorrido de vueltas desde una vuelta guardada — cada vuelta se guarda en esta ruta.\n4) O en el lab del recorrido → Compartir, marca cualquier recorrido con esta ruta.\n5) Activa «compartida» si quieres que los amigos comparen el mismo circuito.';

  @override
  String get routesTapHint => 'Toca para ver vueltas';

  @override
  String get routesLoopReady => 'Vuelta lista';

  @override
  String get setYourAlias => 'Pon tu alias';

  @override
  String get sectionNotesProOnly => 'Solo Pro — notas de manejo';

  @override
  String get proCurvaBannerTitle => 'Detalle de curva · Pro';

  @override
  String get proCurvaBannerBody =>
      'Vista previa de 0,5 s. Con Pro ves entrada, centro, salida y el mapa sin bloqueo.';

  @override
  String get proNotesBannerTitle => 'Notas de manejo · Pro';

  @override
  String get proNotesBannerBody =>
      'Las notas de coaching de este ride están en RiderLab Pro.';

  @override
  String get proFeatureCurva => 'Detalle completo de curvas (sin banner)';

  @override
  String get proFeatureNotes => 'Notas de manejo';

  @override
  String get myRoutes => 'Tus rutas';

  @override
  String get routesEmpty =>
      'Aún no hay rutas — crea una para marcar y compartir recorridos.';

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
      'Los amigos ven este circuito y pueden comparar recorridos marcados.';

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
  String get shareThisRide => 'Compartir este recorrido';

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
  String get armAutoRide => 'Empezar al rodar';

  @override
  String get disarmAutoRide => 'Cancelar arranque auto';

  @override
  String get waitingForMotion => 'Esperando movimiento…';

  @override
  String get armedBannerBody =>
      'RiderLab empieza a grabar sola cuando te empiezas a mover.';

  @override
  String get armedSessionTitle => 'Ruta armada';

  @override
  String get armedSessionOpen => 'Ver sesión';

  @override
  String get armedSessionMinimize => 'Minimizar';

  @override
  String get armedSessionWatchRecording => 'Ver grabación';

  @override
  String get armedSessionEndArm => 'Terminar armado';

  @override
  String get armedSessionStretchesEmpty =>
      'Aún no hay tramos. Cuando empieces a rodar, aparecerán aquí.';

  @override
  String armedSessionStretchN(int n) {
    return 'Tramo $n';
  }

  @override
  String get armedSessionWaitingHelp =>
      'GPS listo. La grabación arranca sola al moverte.';

  @override
  String get armedSessionLiveHelp =>
      'Grabando. Puedes salir de esta pantalla; el recorrido sigue.';

  @override
  String get loopMode => 'Modo vueltas';

  @override
  String get pausedLabel => 'PAUSADO';

  @override
  String get suggestEndTitle => '¿Sigues rodando?';

  @override
  String get suggestEndBody =>
      'Sin movimiento hace rato. Termina el recorrido o sigue rodando.';

  @override
  String get keepRiding => 'Seguir rodando';

  @override
  String get markLoopInit => 'Marcar inicio de vuelta';

  @override
  String get loopInitSet => 'Inicio marcado';

  @override
  String get markLoopEnd => 'Marcar fin de vuelta';

  @override
  String get markLoopInitHere => 'Marcar A en mi GPS';

  @override
  String get markLoopEndHere => 'Marcar B en mi GPS';

  @override
  String get loopOpenMarkMap => 'Mapa: marcar A y B';

  @override
  String get loopMarkMapHint =>
      'Abre el mapa completo, muévelo y toca el punto A (inicio) y el B (fin).';

  @override
  String get loopTapPointA => 'Toca el mapa para marcar el punto A (inicio)';

  @override
  String get loopTapPointB => 'Toca el mapa para marcar el punto B (fin)';

  @override
  String get loopPointsReady => 'A y B listos — confirma para contar vueltas';

  @override
  String get loopMarkMapHelp =>
      'Mueve y acerca el mapa. Primer toque = A, segundo = B. El círculo es donde se cuenta la vuelta.';

  @override
  String get loopRemapA => 'Rehacer A';

  @override
  String get loopConfirmAb => 'Confirmar A y B';

  @override
  String get loopArmed => 'Listo para contar vueltas';

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
      'Elige cualquier tramo, detalle completo de curvas y el historial completo de frenadas.';

  @override
  String get proFeatureSegment => 'Acercar cualquier parte del recorrido';

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
      'Desbloqueo temporal hasta conectar la tienda. Apágalo para ver la versión gratis.';

  @override
  String proTrialDaysLeft(int days) {
    return 'Prueba Pro · $days días restantes';
  }

  @override
  String proPartnerDaysLeft(int days) {
    return 'Pro de socio · $days días restantes';
  }

  @override
  String get proExpiredKeepLab =>
      'Se acabó tu Pro — conserva el zoom de segmento y el detalle de curvas.';

  @override
  String get partnerProCode => 'Código Pro de socio';

  @override
  String get partnerProCodeHint => 'PRO-7K4M2Q';

  @override
  String get partnerProCodeHelp =>
      'Un código personal de un socio RiderLab. No es el código de una rodada.';

  @override
  String get redeemPartnerCode => 'Canjear';

  @override
  String get partnerCodeInvalid => 'Ese código no es válido.';

  @override
  String get partnerCodeUsed => 'Ese código ya se usó.';

  @override
  String get partnerCodeAlreadyRedeemed =>
      'Esta cuenta ya canjeó un código de socio.';

  @override
  String get partnerCodeAlreadyPaying =>
      'Ya tienes Pro. Dale este código a otra persona.';

  @override
  String get partnerCodeRedeemed => 'Pro de socio activo.';

  @override
  String get restorePurchases => 'Restaurar compras';

  @override
  String get havePartnerCode => '¿Tienes un código de socio?';

  @override
  String get createPartnerCode => 'Crear código de socio';

  @override
  String get createPartnerCodeHelp =>
      'Pro de 90 días, un solo uso, para un rider socio.';

  @override
  String get partnerLabelHint => 'Nombre del socio (opcional)';

  @override
  String partnerCodeCopied(String code) {
    return 'Copiado $code';
  }

  @override
  String get startTrialHelp =>
      'El Pro completo empieza cuando terminas tu primer ride.';

  @override
  String brakesProTeaser(int shown, int total) {
    return 'Mostrando $shown de $total. Desbloquea Pro para el historial completo de frenadas.';
  }

  @override
  String get segmentProLocked =>
      'Elegir un tramo del recorrido es una función Pro.';

  @override
  String get adPlaceholder => 'Anuncio';

  @override
  String get removeAdsWithPro => 'Pasa a Pro para el Ride Lab completo';

  @override
  String get routeTabLaps => 'Vueltas';

  @override
  String get routeTabLoop => 'Vueltas';

  @override
  String get routeLoopModuleHelp =>
      'Las vueltas pertenecen a esta ruta. Encuentra vueltas cerradas en recorridos marcados, o marca tú el inicio (A) y el fin (B) en el mapa.';

  @override
  String get routeLoopDefine => 'Marcar A / B';

  @override
  String get routeLoopDetect => 'Detectar';

  @override
  String get routeLoopSavedTitle => 'Vueltas guardadas';

  @override
  String get routeLoopEmpty =>
      'Aún no hay vueltas — encuéntralas en recorridos o marca A y B en el mapa.';

  @override
  String get routeLoopDetectedTitle => 'Vueltas posibles';

  @override
  String get routeLoopDetectedEmpty =>
      'No hay vueltas cerradas en los recorridos marcados. Rueda el circuito e inténtalo de nuevo.';

  @override
  String get routeLoopDetectedHint =>
      'Camino cerrado según el GPS — guárdalo para que cuente las vueltas solo.';

  @override
  String get routeLoopSave => 'Guardar';

  @override
  String get routeLoopSaved => 'Vuelta guardada en esta ruta';

  @override
  String get routeLoopManualName => 'Vuelta a mano';

  @override
  String get routeLoopPrimary => 'PRINCIPAL';

  @override
  String get routeLoopSetPrimary => 'Usar como principal';

  @override
  String get routeLoopStartRide => 'Iniciar recorrido de vueltas';

  @override
  String get routeLoopSourceManual => 'A mano';

  @override
  String get routeLoopSourceDetected => 'Detectado';

  @override
  String get deleteRoute => 'Eliminar ruta';

  @override
  String get deleteRouteBody =>
      'Se borra esta ruta, sus vueltas y se desmarcan los recorridos. Si está compartida, desaparece para todos.';

  @override
  String get routeDeleted => 'Ruta eliminada';

  @override
  String get deleteLoop => 'Eliminar vuelta';

  @override
  String get deleteLoopBody =>
      'Se elimina esta vuelta. Si era la principal, también se quitan los puntos A/B de la ruta (los amigos lo ven al sincronizar).';

  @override
  String get loopDeleted => 'Vuelta eliminada';

  @override
  String get deleteAllLoops => 'Quitar todas las vueltas';

  @override
  String get deleteAllLoopsBody =>
      'Se borran todas las vueltas de esta ruta y los puntos A/B. Los amigos verán la ruta sin vueltas al sincronizar.';

  @override
  String get loopsCleared => 'Vueltas eliminadas';

  @override
  String get deleteConfirm => 'Eliminar';

  @override
  String get deleteRide => 'Eliminar recorrido';

  @override
  String get deleteRideBody =>
      'Se borra el recorrido y su línea GPS de este teléfono (y de la nube si estaba sincronizado).';

  @override
  String get rideDeleted => 'Recorrido eliminado';

  @override
  String get accountSection => 'Cuenta';

  @override
  String get accountGuest => 'Invitado';

  @override
  String get accountGuestBody =>
      'Crea una cuenta para usar RiderLab. Grabar, amigos y la nube requieren un rider con sesión.';

  @override
  String get accountSignedIn => 'Sesión iniciada';

  @override
  String get accountSignedInBody =>
      'Tu cuenta está vinculada. Cerrar sesión vuelve a la pantalla de inicio de sesión.';

  @override
  String get authGateTitle => 'Entra para rodar';

  @override
  String get authGateBody =>
      'RiderLab necesita una cuenta. Usa Google o correo y contraseña — el modo invitado está apagado. Así también entra la revisión de las tiendas.';

  @override
  String signInWith(String provider) {
    return 'Entrar con $provider';
  }

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get accountSignedInSnack => 'Sesión iniciada — perfil sincronizado';

  @override
  String get accountSignedOutSnack => 'Sesión cerrada';

  @override
  String get authEmailLabel => 'Correo';

  @override
  String get authPasswordLabel => 'Contraseña';

  @override
  String get authOrEmail => 'o correo y contraseña';

  @override
  String get authSignInEmail => 'Entrar con correo';

  @override
  String get authCreateAccount => 'Crear cuenta';

  @override
  String get authInvalidEmail => 'Escribe un correo válido.';

  @override
  String get authShortPassword =>
      'La contraseña debe tener al menos 6 caracteres.';

  @override
  String get authInvalidCredentials => 'Correo o contraseña incorrectos.';

  @override
  String get authConfirmEmailThenSignIn =>
      'Confirma el correo que te enviamos y luego entra.';

  @override
  String get authEmailAlreadyRegistered =>
      'Esa cuenta ya existe. Entra con correo y contraseña.';

  @override
  String get authForgotPassword => '¿Olvidé mi contraseña?';

  @override
  String get authResetEmailSent =>
      'Revisa tu correo. Abre el enlace en el teléfono o la computadora.';

  @override
  String get authSetPasswordTitle => 'Nueva contraseña';

  @override
  String get authSetPasswordBody =>
      'Elige una nueva contraseña para esta cuenta de RiderLab.';

  @override
  String get authNewPasswordLabel => 'Nueva contraseña';

  @override
  String get authConfirmPasswordLabel => 'Confirmar contraseña';

  @override
  String get authPasswordMismatch => 'Las contraseñas no coinciden.';

  @override
  String get authSavePassword => 'Guardar contraseña';

  @override
  String get authPasswordUpdated =>
      'Contraseña actualizada. Ya puedes iniciar sesión.';

  @override
  String get impersonateTitle => 'Ver como rider';

  @override
  String get impersonateTile => 'Ver como otro rider';

  @override
  String get impersonateHelp =>
      'La sesión en la nube pasa a ser ese rider (rodadas, amigos, recorridos en la nube). El Garage de este teléfono sigue siendo tuyo. No grabes ni sincronices. Salir restaura tu cuenta.';

  @override
  String get impersonateSearchHint => 'Nombre, correo o id';

  @override
  String get impersonateEmpty => 'Nadie coincide.';

  @override
  String get impersonateStart => 'Ver como esa persona';

  @override
  String get impersonateExit => 'Salir';

  @override
  String impersonateBanner(String name) {
    return 'Viendo como $name';
  }

  @override
  String get impersonateConfirmTitle => '¿Cambiar la sesión en la nube?';

  @override
  String impersonateConfirmBody(String name) {
    return 'Este teléfono actuará como $name en la nube hasta que salgas. El Garage local y el GPS siguen siendo tuyos y quedan bloqueados.';
  }

  @override
  String get impersonateFailed => 'No se pudo cambiar de cuenta.';

  @override
  String get impersonateUnknown => 'otro rider';

  @override
  String get impersonateNoRide => 'No se graba mientras ves como otro rider.';

  @override
  String get impersonateNoSync =>
      'La sincronización está apagada mientras ves como otro rider.';

  @override
  String get rideLoopHelp =>
      'Encuentra vueltas cerradas en el GPS de este recorrido, o marca inicio (A) y fin (B) en el mapa. Al guardar se crea o usa una ruta para contar vueltas después.';

  @override
  String get rideLoopEmpty =>
      'Aún no hay vueltas guardadas en la ruta de este recorrido.';

  @override
  String get rideLoopDetectedEmpty =>
      'No hay vuelta cerrada en este recorrido. Prueba Marcar A / B en el mapa.';

  @override
  String get rideLoopNeedPoints =>
      'No hay suficientes puntos GPS para marcar una vuelta.';

  @override
  String get rideLoopSaveFirst =>
      'Guarda una vuelta primero — eso crea la ruta.';

  @override
  String get rideLoopOpenRoute => 'Abrir ruta (vueltas)';

  @override
  String get syncCloudRides => 'Sincronizar recorridos con la nube';

  @override
  String get syncCloudRidesHelp =>
      'Sube los recorridos terminados y descarga a este teléfono los del garaje y las sesiones de Lab de inclinación de esta cuenta.';

  @override
  String syncCloudRidesDone(int ok, int fail) {
    return 'Subida: $ok ok, $fail fallaron';
  }

  @override
  String syncCloudRidesPulled(int rides, int lean) {
    return 'Descargados $rides recorridos, $lean Lab de inclinación';
  }

  @override
  String get playStoreUpdatesOnly =>
      'En esta versión las actualizaciones llegan por Google Play.';

  @override
  String get labSection => 'Lab (pruebas)';

  @override
  String get labAdventureCameraHelp =>
      'GoPro opcional junto con el recorrido. Apagada por defecto — el GPS no cambia.';

  @override
  String get labAdventureCameraEnable => 'Cámara de aventura';

  @override
  String get labAdventureCameraEnableHelp =>
      'Activa las herramientas de cámara en este teléfono';

  @override
  String get labAdventureCameraSyncRide => 'Grabar con el recorrido';

  @override
  String get labAdventureCameraSyncRideHelp =>
      'Inicia y para con todo el recorrido. Si hay puntos de inicio en el mapa, la cámara espera hasta llegar a uno.';

  @override
  String get labAdventureCameraSyncPause => 'Seguir la pausa auto';

  @override
  String get labAdventureCameraSyncPauseHelp =>
      'Para la cámara mientras la pausa auto del GPS está activa (opcional)';

  @override
  String get labAdventureCameraBackend => 'Tipo de cámara';

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
      'Prueba el disparo a mano — no hace falta un recorrido. Conecta primero (o usa Simular).';

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
  String get labAdventureCameraZonesEnable => 'Inicio/parada en el mapa';

  @override
  String get labAdventureCameraZonesEnableHelp =>
      'Inicia y para al entrar en zonas del mapa. La cámara se queda apagada hasta el punto de inicio.';

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
  String get rideDeckTitle => 'Iniciar recorrido';

  @override
  String get rideDeckHelp =>
      'Toca una vez, pon el teléfono en el bolsillo o en el tanque, quédate quieto. Cuando sientas vibrar y un beep, el 0° quedó guardado y el recorrido arranca — no vuelves a tocar.';

  @override
  String get startRideNow => 'Iniciar recorrido ahora';

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
      '1. Enciende cada GoPro y abre la tapa lateral (Bluetooth activo).\n2. En el teléfono, permite Bluetooth (y dispositivos cercanos) si lo pide.\n3. Toca Añadir GoPro — espera el escaneo y elige cada cámara.\n4. Déjalas activas en la lista (apaga el interruptor para omitir una).\n5. Toca Conectar para enlazar todo el grupo.\n6. Inicia un recorrido (o usa zonas del mapa / auto-grabar agresivo) — el disparo arranca/para en todas las cámaras activas.\n7. En la pantalla del recorrido, CAM 2/2 significa que ambas están grabando.\n\nConsejos: acerca el teléfono a las cámaras en el primer enlace. Si una solo enciende y no graba, Conecta de nuevo y luego inicia el recorrido. Si una falla, las demás siguen.';

  @override
  String get labAdventureCameraScenariosTitle => 'Setups de prueba';

  @override
  String get labAdventureCameraScenarioZonesTitle =>
      'Solo entre puntos inicio/parada del mapa';

  @override
  String get labAdventureCameraScenarioZonesBody =>
      'ON: Cámara de aventura · Zonas inicio/fin en el mapa (coloca Inicio + Parada) · cámaras en el grupo.\nOFF: Grabar con el recorrido · Auto-grabar conducción agresiva · Seguir pausa auto.\n\nNota: estas son zonas de cámara del Lab — no los puntos A/B de vueltas de la ruta.';

  @override
  String get labAdventureCameraScenarioZonesApply => 'Aplicar setup solo zonas';

  @override
  String get labAdventureCameraScenarioAggressiveTitle =>
      'Solo al empezar conducción divertida / agresiva';

  @override
  String get labAdventureCameraScenarioAggressiveBody =>
      'ON: Cámara de aventura · Auto-grabar conducción agresiva · cámaras en el grupo.\nOFF: Grabar con el recorrido · Zonas inicio/fin en el mapa · Seguir pausa auto.';

  @override
  String get labAdventureCameraScenarioAggressiveApply =>
      'Aplicar setup solo agresivo';

  @override
  String get armAutoNoRouteHint =>
      'Listo — al rodar se inicia un recorrido en el garaje.';

  @override
  String get freezeThenArmHelp =>
      'Toca una vez, coloca el teléfono, quédate quieto. Un vibrar y un beep confirman que el 0° quedó guardado. Luego bloquea la pantalla — al arrancar se inicia el recorrido. No vuelves a tocar.';

  @override
  String get armAutoRouteArmed => 'Listo — al arrancar se inicia el recorrido';

  @override
  String armAutoRouteArmedNamed(String name) {
    return 'Listo para «$name» — el recorrido se guarda en esa ruta';
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
  String get familyCircleTitle => 'Círculo familiar';

  @override
  String get familyCircleHomeTile =>
      'Quién puede saber que estás bien al rodar';

  @override
  String get familyCircleHelp =>
      'Agrega contactos aquí. El link se genera al Grabar o en una Rodada (En vivo). Puedes reenviarlo a más personas sin romper los anteriores.';

  @override
  String get familyHowToShareTitle => 'Cómo mandar el link';

  @override
  String get familyHowToShareSteps =>
      '1) En Grabar o en una Rodada (pestaña En vivo).\n2) Toca el icono de compartir.\n3) Elige contactos — el mismo link sirve para todos.\n\n«Compartir en vivo» del pack es aparte: solo riders con la app.';

  @override
  String get familyShareNeedsRide =>
      'Primero inicia una grabación o abre una Rodada. Luego aparece el botón para compartir el link.';

  @override
  String get familyShareFromCircle => 'Compartir link ahora';

  @override
  String get familyRodadaTipTitle => '¿Link para familia?';

  @override
  String get familyRodadaTipBody =>
      'Pack = mapa de la rodada en la app. Familia sin app = compartir desde En vivo (mismo link se puede reenviar).';

  @override
  String get familyRodadaTipCta => 'Ver círculo familiar';

  @override
  String get familyAppBarShareTooltip => 'Avisar a familia';

  @override
  String get familyAddContact => 'Agregar contacto';

  @override
  String get familyContactLabel => 'Nombre';

  @override
  String get familyContactLabelHint => 'Mamá / Ana / …';

  @override
  String get familyOptionalFriend => 'Opcional: vincular un amigo de RiderLab';

  @override
  String get familyNoFriendsYet =>
      'Aún no hay amigos — puedes poner un nombre y compartir el link.';

  @override
  String get familySaveContact => 'Guardar';

  @override
  String get familyMyCircle => 'Mi círculo';

  @override
  String get familyCircleEmpty =>
      'Sin contactos. Agrega a alguien antes de la próxima salida.';

  @override
  String get familyLinkOnlyContact => 'Recibe el link (sin cuenta en la app)';

  @override
  String get familyAppContact => 'También puede ver en la app';

  @override
  String get familyWatchingNow => 'Rodando ahora';

  @override
  String get familyNoActiveWatches =>
      'Nadie de tu círculo está compartiendo una salida ahora.';

  @override
  String get familyTapToWatch => 'Toca para abrir el mapa';

  @override
  String get familyRiderFallback => 'Rider';

  @override
  String get familyNotifyToggle => 'Avisar a familia';

  @override
  String get familyNotifyHelp =>
      'Genera un link y abre el menú de compartir para mandárselo a tu familiar (no necesitan la app).';

  @override
  String get familyNotifyHelpRodada =>
      'Avisa a familia/amigos fuera del pack. Puedes reenviar el mismo link a más personas.';

  @override
  String get familyNotifyStart => 'Compartir';

  @override
  String get familyWatchActive => 'Familia puede verte';

  @override
  String get familyWatchStop => 'Parar';

  @override
  String get familyOk => 'Todo bien';

  @override
  String get familyStopped => 'Me detuve';

  @override
  String get familySos => 'Necesito ayuda';

  @override
  String get familyShareLink => 'Reenviar link';

  @override
  String get familyShareAgain => 'Enviar a otro';

  @override
  String get familyShareAgainHint =>
      'Puedes mandar el mismo link a más personas; los anteriores siguen funcionando.';

  @override
  String get familyRotateLink => 'Nuevo link';

  @override
  String get familyRotateLinkTitle => '¿Invalidar links anteriores?';

  @override
  String get familyRotateLinkBody =>
      'Se crea un link nuevo. Quien tenga el anterior dejará de ver tu ubicación. Úsalo si el link se filtró.';

  @override
  String get familyRotateLinkConfirm => 'Invalidar y compartir';

  @override
  String get familyShareNeedsSignIn =>
      'Inicia sesión para compartir con familia.';

  @override
  String get familyShareSubject => 'RiderLab — estoy rodando';

  @override
  String familyShareMessage(String url) {
    return 'Estoy en una salida. Abre este link para ver mi última ubicación (no es 911):\n$url';
  }

  @override
  String familyLastSeen(String when) {
    return 'Última señal $when';
  }

  @override
  String familyNoSignalSince(String when) {
    return 'Sin señal · última a las $when';
  }

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
      'Crea una rodada para Tapalpa, Moyahua o donde sea. Invita riders y comparte GPS en vivo, líneas y fotos solo si cada uno lo activa.';

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
  String get rodadaItinerary => 'Itinerario';

  @override
  String get rodadaPinStart => 'Inicio';

  @override
  String get rodadaPinFinish => 'Fin';

  @override
  String get rodadaPinStop => 'Parada';

  @override
  String get rodadaPinUnset => 'Sin marcar';

  @override
  String rodadaStopN(int n) {
    return 'Parada $n';
  }

  @override
  String get rodadaItineraryHelp =>
      'Busca o toca el mapa para marcar inicio, fin o paradas. GPS en vivo y fotos quedan apagados hasta que cada rider lo active.';

  @override
  String get routePrefTolls => 'Casetas';

  @override
  String get routePrefHighway => 'Autopista';

  @override
  String get routePrefStreet => 'Calle';

  @override
  String get routePrefOffroad => 'Terracería';

  @override
  String get routeSearchHint => 'Busca un lugar, pueblo o dirección…';

  @override
  String routeSummaryKmEta(String distance, String eta) {
    return '$distance · $eta';
  }

  @override
  String get routeFailedFallback =>
      'No se pudo seguir las carreteras — se muestra línea recta.';

  @override
  String get offRouteBanner => 'Fuera de ruta';

  @override
  String get routeRouting => 'Trazando ruta…';

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
  String get rodadaInviteShare => 'Compartir invitación';

  @override
  String get rodadaInviteShareHint =>
      'Comparte un resumen por WhatsApp u otra app.';

  @override
  String rodadaInviteShareSubject(String title) {
    return 'Rodada: $title';
  }

  @override
  String rodadaInviteShareWhen(String when) {
    return 'Cuándo: $when';
  }

  @override
  String rodadaInviteShareWhere(String place) {
    return 'Dónde: $place';
  }

  @override
  String rodadaInviteShareRoute(String summary) {
    return 'Ruta: $summary';
  }

  @override
  String rodadaInviteShareHost(String name) {
    return 'Anfitrión: $name';
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
    return 'Paradas: $names';
  }

  @override
  String rodadaInviteShareNotes(String notes) {
    return 'Notas: $notes';
  }

  @override
  String rodadaInviteShareMeetup(String url) {
    return 'Punto de encuentro: $url';
  }

  @override
  String rodadaInviteShareFinish(String url) {
    return 'Meta: $url';
  }

  @override
  String rodadaInviteShareCode(String code) {
    return 'Entra en RiderLab con el código $code';
  }

  @override
  String get rodadaInviteShareHow => 'Rodadas → Unirse con código';

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
  String get inviteFriend => 'Invitar amigos';

  @override
  String get leaveRodada => 'Salir de la rodada';

  @override
  String get leaveRodadaConfirmTitle => '¿Salir de esta rodada?';

  @override
  String get leaveRodadaConfirmBody =>
      'Dejarás de verla en tu lista. El anfitrión no se borra.';

  @override
  String get leaveRodadaDone => 'Saliste de la rodada';

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
  String get inviteFriends => 'Invitar amigos';

  @override
  String get rodadaInviteChip => 'Invitación';

  @override
  String rodadaInviteBanner(String title) {
    return 'Te invitaron a $title';
  }

  @override
  String get rsvpPending => 'pendiente';

  @override
  String get rsvpAccept => 'Aceptar';

  @override
  String get rsvpDecline => 'Rechazar';

  @override
  String get inviteSent => 'Invitación enviada';

  @override
  String get inviteAlreadyMember => 'Ya está en esta rodada';

  @override
  String get inviteSentNoToken =>
      'Invitado en la app. Ese teléfono aún no registró notificaciones — que abra RiderLab con su cuenta.';

  @override
  String inviteSentPushFailed(String reason) {
    return 'Invitado en la app, pero la notificación falló: $reason';
  }

  @override
  String invitePushAllOk(int count) {
    return '$count notificaciones enviadas';
  }

  @override
  String invitePushSummary(int ok, int failed, String reason) {
    return 'Invitados en la app. Notificaciones: $ok enviadas, $failed fallidas ($reason)';
  }

  @override
  String rodadaCodeBanner(String code) {
    return 'código $code';
  }

  @override
  String get meetup => 'Encuentro';

  @override
  String get yourSharing => 'Qué compartes';

  @override
  String get sharingDefaultsHelp =>
      'Apagado hasta que lo actives. Luego se envía tu ubicación cada 5 minutos durante toda la rodada (reintenta cada 1 minuto si falla).';

  @override
  String get notRodadaMember => 'No eres miembro.';

  @override
  String get shareLocationOnRoute => 'Compartir ubicación en ruta';

  @override
  String get shareLocationEvery5Min =>
      'Cada 5 min mientras la rodada está abierta/en vivo';

  @override
  String get shareTrackAfterRides => 'Compartir mi línea después de recorrer';

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
  String get memberTrackOn => 'línea activa';

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
  String liveRiderLastSeen(String name, String when) {
    return '$name · $when';
  }

  @override
  String liveRiderNoSignal(String name, String when) {
    return '$name · Sin señal · $when';
  }

  @override
  String get liveSeenJustNow => 'ahora';

  @override
  String liveSeenMinutesAgo(int minutes) {
    return 'hace $minutes min';
  }

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
      'Líneas de quienes activaron compartir. El GPS detallado se queda en cada teléfono.';

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
  String get noTrackPoints => 'Sin puntos de la línea';

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
  String photosUploaded(int count) {
    return '$count fotos subidas';
  }

  @override
  String get photoTitle => 'Foto';

  @override
  String get photoNeedsActiveRide =>
      'Empieza un recorrido para ligar la foto a la ruta';

  @override
  String get photoLinkedToRoute => 'Foto ligada a la ruta';

  @override
  String get photoCaptureTooltip => 'Foto de la rodada';

  @override
  String get photoTake => 'Cámara';

  @override
  String get photoImportFromRoll => 'Del carrete';

  @override
  String get photoImportTitle => 'Fotos de esta rodada';

  @override
  String get photoImportHelp =>
      'Encontramos estas fotos en el carrete durante tu ruta. Nada se sube hasta que confirmes.';

  @override
  String get photoImportSkip => 'Omitir';

  @override
  String photoImportConfirm(int count) {
    return 'Ligar $count fotos';
  }

  @override
  String get reelTitle => 'Reel de la rodada';

  @override
  String get reelDone => 'Listo';

  @override
  String get reelBuilding => 'Armando tu reel…';

  @override
  String get reelRetry => 'Regenerar';

  @override
  String get reelShare => 'Compartir';

  @override
  String get reelHookSub => 'Recostada';

  @override
  String get reelCurvesLabel => 'Curvas';

  @override
  String get reelRidersLabel => 'Riders';

  @override
  String get reelEndQuestion => '¿Tú cuánto te recuestas?';

  @override
  String get reelCta => 'Graba tu línea en RiderLab';

  @override
  String get reelGenerate => 'Generar reel';

  @override
  String get reelOverviewCta => 'Comparte el reel de la rodada';

  @override
  String get reelLengthShort => 'Corto';

  @override
  String get reelLengthStandard => 'Reels';

  @override
  String get reelLengthLong => 'Completo';

  @override
  String get reelLengthHint => 'Elige cuánto dura el video';

  @override
  String reelLengthSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String reelLengthCap(int pauses, int photos) {
    return 'Hasta $pauses paradas · $photos fotos';
  }

  @override
  String reelStopLabel(int n) {
    return 'Parada $n';
  }

  @override
  String get reelOnRoute => 'En ruta';

  @override
  String get reelNoStops => 'No hubo paradas largas en esta ruta';

  @override
  String reelPhotoCount(int count) {
    return '$count fotos';
  }

  @override
  String get reelAddToStop => 'Agregar foto';

  @override
  String get skillCoach => 'Tips de manejo';

  @override
  String skillCurvasRated(int count) {
    return '$count curvas calificadas · sirve para comparar con amigos';
  }

  @override
  String get improveNextRide => 'Mejorar el próximo recorrido';

  @override
  String get openCornerLab => 'Abrir lab de curvas';

  @override
  String get skillTipNoCurvas =>
      'No se detectaron curvas claras — recorre un tramo sinuoso para tener una base.';

  @override
  String skillTipEntryHot(String entry, String apex) {
    return 'Entraste rápido ($entry→$apex km/h). Frena antes de inclinar.';
  }

  @override
  String get skillTipModerateSpeedDrop =>
      'Bajaste bien de velocidad al centro — frena un poco más al inclinar.';

  @override
  String get skillTipLittleSpeedScrub =>
      'Casi no bajaste de velocidad — checa que no lleves de más a media curva.';

  @override
  String get skillTipWeakExitDrive =>
      'Salida floja — abre el gas más pronto cuando la moto se empiece a parar.';

  @override
  String get skillTipPeakLeanNotAtApex =>
      'La inclinación máxima no fue en el punto más cerrado — inclina antes para llegar listo al centro.';

  @override
  String get skillTipLowLeanBigHeading =>
      'Mucho giro con poca inclinación — checa que el teléfono esté bien sujeto, o inclínate más.';

  @override
  String get skillTipSolidCorner =>
      'Buena curva — mantén este ritmo de entrada y centro.';

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
  String get imuAzurePending => 'IMU pendiente de subir';

  @override
  String get imuAzureUploading => 'Subiendo IMU…';

  @override
  String get imuAzureUploaded => 'IMU en Azure';

  @override
  String get imuAzureFailed => 'Falló la subida de IMU';

  @override
  String get imuAzureRetry => 'Reintentar subida IMU';

  @override
  String get pressure => 'Presión';

  @override
  String get pressureChartSub => 'Barómetro a lo largo del recorrido (hPa)';

  @override
  String get skillLabTitle => 'Lab de técnica';

  @override
  String get skillLabTapHint => 'Toca para ver errores y cómo mejorarlos';

  @override
  String get skillLabTapHintEmpty => 'Toca para tips tras un tramo sinuoso';

  @override
  String get skillLabFocusTitle => 'Dónde mejorar';

  @override
  String get skillLabFocusHelp =>
      'Primero las curvas con peor puntaje. Las barras son entrada → centro → salida. Toca Repetir para ver inclinación, freno y velocidad — y comparar la misma curva con un amigo.';

  @override
  String get bikeSection => 'Mi moto';

  @override
  String get bikeSelect => 'Elige tu moto';

  @override
  String get bikeSelectHelp =>
      'Se usa en el Lab de inclinación y en tus recorridos';

  @override
  String get bikePickerTitle => 'Garaje';

  @override
  String get bikePickerHelp => 'Marca, luego año, luego modelo.';

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
  String get bikeFamilyOffroad => 'Off-road';

  @override
  String get bikeFamilyOther => 'Otra';

  @override
  String get bikeSearchHint => 'Buscar modelo o año';

  @override
  String get bikeStepMake => 'Marca';

  @override
  String get bikeStepYear => 'Año';

  @override
  String get bikeStepModel => 'Modelo';

  @override
  String get bikeSearchMake => 'Buscar marca';

  @override
  String get bikeSearchYear => 'Buscar año';

  @override
  String get bikeSearchModel => 'Buscar modelo';

  @override
  String get bikePopularMakes => 'Populares';

  @override
  String get bikeAllMakes => 'Todas las marcas';

  @override
  String get bikeCustomModel => 'Otro modelo…';

  @override
  String get bikeCustomModelHint => 'Escribe el nombre del modelo';

  @override
  String get leanLabHomeCta => 'Lab de inclinación — Bugambilias';

  @override
  String get leanLabTitle => 'Lab de inclinación';

  @override
  String get labsSectionTitle => 'Pruebas / nuevas funciones';

  @override
  String get labsSectionHelp =>
      'Herramientas experimentales. No forman parte del flujo diario.';

  @override
  String get pushDiagnosticsTitle => 'Último envío de notificación';

  @override
  String get pushDiagnosticsEmpty =>
      'Aún no hay un envío de notificación registrado.';

  @override
  String get pushDiagnosticsCopied => 'Registro de notificaciones copiado';

  @override
  String get leanLabIntro =>
      'Bugambilias en ambos sentidos, con subidas. Guarda el 0° con la moto derecha, rueda y marca las curvas para mejorar la inclinación.';

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
      'Hacia la plaza, teléfono en su lugar de siempre. Captura inclinación en subida y bajada.';

  @override
  String get leanLabProtoReturn => 'Base de regreso';

  @override
  String get leanLabProtoReturnHelp =>
      'El otro sentido, mismo lugar del teléfono. Mismas curvas, lados al revés.';

  @override
  String get leanLabProtoPocket => 'Teléfono en el bolsillo';

  @override
  String get leanLabProtoPocketHelp =>
      'El mismo circuito con el teléfono en el bolsillo, para ver cómo cambia la inclinación.';

  @override
  String get leanLabProtoFree => 'Vuelta libre Lean Lab';

  @override
  String get leanLabProtoFreeHelp =>
      'Cualquier sentido en este circuito. Guarda el 0° y luego marca las curvas.';

  @override
  String get leanLabStartProtocol => 'Preparar y rodar';

  @override
  String get leanLabNeedsLabels => 'Faltan etiquetas de curva';

  @override
  String leanLabElevationSummary(String climb, String descent) {
    return '↑$climb m · ↓$descent m';
  }

  @override
  String get leanLabPrepTitle => 'Preparar Lab de inclinación';

  @override
  String get leanLabPrepHelp =>
      'Teléfono ya en el soporte o la maleta de tanque. Guarda el 0° con la moto derecha y arranca la vuelta.';

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
  String get leanLabCalibTitle => 'Guardar 0° (moto derecha)';

  @override
  String get leanLabCalibHelp =>
      'Moto derecha, teléfono ya en su lugar. Sin tocarlo 4 segundos — así se guarda el 0°. La inclinación debe quedar cerca de 0°.';

  @override
  String get leanLabCalibHold => 'Sostener vertical 4 s';

  @override
  String get leanLabCalibHolding => 'Quédate quieto…';

  @override
  String get leanLabCalibPocket => 'Guardar en el bolsillo';

  @override
  String get leanLabCalibPocketHelp =>
      'Toca, mételo del todo en el bolsillo, quédate quieto. Un vibrar y un beep confirman que el 0° quedó guardado y el recorrido arrancó — no lo guardes en la mano.';

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
      'No se quedó quieto. Colócalo de nuevo e inténtalo otra vez.';

  @override
  String leanLabFreezeRedo(String n) {
    return 'El teléfono ya va $n° de derecho. Vuelve a guardar el 0° con la moto bien parada.';
  }

  @override
  String get leanLabRawNeutral => 'Ángulo del teléfono';

  @override
  String get leanLabFrozenNeutral => '0° guardado';

  @override
  String get leanLabStartRide => 'Iniciar recorrido Lean Lab';

  @override
  String get leanLabReviewTitle => 'Marcar inclinación';

  @override
  String get leanLabReviewHelp =>
      'En cada curva: ¿la inclinación de la app se sintió alta, bien o baja? Se muestra la pendiente para corregir subida y bajada.';

  @override
  String get leanLabReviewHelpMax =>
      'La inclinación máxima de la curva se queda arriba. Reproduce para ver inclinación y mapa; salta al pico cuando quieras.';

  @override
  String get leanLabMaxLean => 'Inclinación máxima';

  @override
  String get leanLabJumpToMax => 'Ir a la inclinación máxima';

  @override
  String get leanLabLiveLean => 'Inclinación en vivo';

  @override
  String get leanLabAtPeak => 'en el pico';

  @override
  String get leanLabMaxLeanGps => 'GPS donde ocurrió la inclinación máxima';

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
      'Este recorrido casi no tiene GPS en el teléfono. Abre Ajustes → Sincronizar recorridos con la nube (misma cuenta Google) y vuelve a intentar.';

  @override
  String get leanLabNoLeanData =>
      'El GPS está, pero faltan muestras de inclinación — no se pueden etiquetar curvas. Sincroniza de nuevo o graba la vuelta con el teléfono bien fijado.';

  @override
  String get leanLabAppLean => 'Inclinación de la app';

  @override
  String get leanLabGrade => 'Pendiente';

  @override
  String get leanLabBiasQ =>
      '¿Cómo se sintió la inclinación de la app en el centro de la curva?';

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
  String get leanLabSaveLabels => 'Guardar marcas de curvas';

  @override
  String get leanLabSettingsTile => 'Lab de inclinación (pruebas)';

  @override
  String get leanLabSettingsHelp =>
      'Sesiones en Bugambilias · guardar 0° · pendientes · marcar curvas';

  @override
  String get leanImuLabTitle => 'Lab de sensores de inclinación';

  @override
  String get leanImuLabIntro =>
      'La misma inclinación que en el recorrido. Guarda el 0° con el teléfono en su lugar real, luego inclina. El letrero muestra cómo va el teléfono.';

  @override
  String get leanImuLabSettingsTile => 'Sensores de inclinación';

  @override
  String get leanImuLabSettingsHelp =>
      'Mira los sensores y cómo se mide la inclinación';

  @override
  String get leanImuLabFreeze => 'Guardar 0° ahora';

  @override
  String get leanImuLabReset => 'Reiniciar';

  @override
  String get leanImuLabFrozenHint =>
      'El 0° está guardado. La inclinación debe ser cerca de 0°. Inclina a cualquier lado — el número es el ángulo.';

  @override
  String get leanImuLabAnglesTitle => 'Ángulos';

  @override
  String get leanImuLabAnglesHelp =>
      'La inclinación (roja) sigue el canal fusionado ganador (mismo movimiento que morado/azul), limitada por el inclinómetro vector (verde). El verde puede moverse con cualquier tip desde 0°; el rojo sigue la lean de moto para esa pose — sin saltos de onda cuadrada.';

  @override
  String get leanImuLabHistoryTitle => 'Últimos ~8 s';

  @override
  String get leanImuLabStartRecord => 'Grabar gráfica';

  @override
  String get leanImuLabStopRecord => 'Parar';

  @override
  String get leanImuLabExportCsv => 'Exportar CSV';

  @override
  String leanImuLabRecordingHint(int count) {
    return 'Grabando… $count muestras (envíame el CSV tras Exportar)';
  }

  @override
  String leanImuLabExportDone(String path) {
    return 'Menú de compartir abierto para $path — elige Drive, WhatsApp o Archivos';
  }

  @override
  String get leanImuLabVectorsTitle => 'Capacidades crudas';

  @override
  String get leanImuLabNextTitle => 'Cómo leer esto';

  @override
  String get leanImuLabNextHelp =>
      'Prueba en la pared: a unos 3° de un inclinómetro de verdad, en cualquier posición. Teléfono derecho: la inclinación sigue el roll. Teléfono plano: sigue el pitch. Si se mueve en el bolsillo, el letrero cambia en unos segundos.';

  @override
  String get leanLabPastSessions => 'Sesiones anteriores';

  @override
  String get leanLabSessionDetailTitle => 'Sesión Lean Lab';

  @override
  String get leanLabSessionMissing => 'No se encontró esta sesión de Lean Lab.';

  @override
  String get leanLabMeasuresTitle => 'Medidas';

  @override
  String get leanLabCornerMeasures => 'Inclinación máxima por curva';

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
      'Corrige ida/regreso, lugar del teléfono o posición si te equivocaste — los números de inclinación no cambian; las marcas se quedan hasta que las vuelvas a guardar.';

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
      'Mira cómo se rodó este tramo — inclinación, freno y velocidad van con el marcador en el mapa.';

  @override
  String get skillReplayCompareHelp =>
      'Ambas líneas se recortan al mismo tramo. Los marcadores avanzan por distancia en la curva para comparar la línea, no el reloj.';

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
      'No hay puntos de la línea para este recorrido.';

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
      'Unos toques después de cada recorrido ayudan a enseñar inclinación, curvas y frenos. Puedes omitir.';

  @override
  String get engineLabelSkip => 'Omitir';

  @override
  String get engineLabelSave => 'Guardar respuestas';

  @override
  String get engineLabelMountQ => '¿Dónde iba el teléfono en este recorrido?';

  @override
  String get engineLabelMountCenter => 'En la moto (tanque / manubrio)';

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
  String get gpsPreparing => 'Buscando mejor señal GPS…';

  @override
  String get gpsLookingSatellites => 'Buscando satélites…';

  @override
  String get gpsWarming => 'Esperando mejor señal GPS…';

  @override
  String gpsWarmingAcc(String meters) {
    return 'Esperando GPS (±$meters m)…';
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
    return 'En el marcador · desfase de 0° $degrees°';
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
