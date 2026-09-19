# UAMSchedule v26 — Changelog

Versión publicada: 11 de mayo, 2026

---

## Para regenerar el proyecto en Xcode

Hay archivos nuevos. Antes de abrir el proyecto en Xcode, ejecuta:

```bash
cd uam-schedule
xcodegen generate
open UAMSchedule.xcodeproj
```

Esto agrega automaticamente los nuevos archivos a los targets correctos
(estan en directorios escaneados por `project.yml`: `Shared/`, `UAMSchedule/`,
`UAMScheduleWidget/`).

---

## 1. Fix critico — Dynamic Island

### Bugs encontrados (causa raiz)

1. **`Info.plist` de la app principal NO declaraba `NSSupportsLiveActivities`**.
   Solo el widget lo tenia. Sin esa key, `Activity.request(...)` falla
   silenciosamente y "Activar isla dinamica" parece no hacer nada.
2. El toggle `liveActivityActive` arrancaba siempre en `false`, sin importar
   si habia una activity viva del sistema. Tras cold-launch o dismissal externo
   el toggle quedaba desincronizado de la realidad.
3. `LiveActivityManager.currentActivity` no se rehidrataba en cold-launch:
   tras relanzar la app, el manager creia que no habia nada activo aunque
   ActivityKit aun tuviera una activity viva.
4. El manager no observaba `activityStateUpdates`, asi que si iOS terminaba
   la activity por stale o el usuario hacia dismissal manual, el estado interno
   se quedaba podrido.
5. `checkAndAutoStart` solo se invocaba al pasar a foreground. Mientras la app
   estaba activa, el smart mode no se re-evaluaba con el paso del tiempo.
6. La barra de progreso del Dynamic Island nunca se actualizaba — el manager
   solo arrancaba o terminaba activities, nunca pusheaba updates de progreso.

### Cambios aplicados

- **`UAMSchedule/Info.plist`**: agregadas `NSSupportsLiveActivities` y
  `NSSupportsLiveActivitiesFrequentUpdates`.
- **`Shared/LiveActivityManager.swift`**: reescrito completo. Ahora:
  - Es `ObservableObject` con `@Published var isActive` y `activeCourseID`.
  - `rehydrateFromSystem()` se ejecuta en init y reconecta a cualquier
    activity ya viva en el sistema.
  - Observa `activityStateUpdates` para enterarse de cambios externos
    (dismissal, stale).
  - Timer de 60 segundos que pushea `tickProgress` y re-evalua smart mode.
  - `tickProgress(store:)` actualiza progressPercent, courseName, room y color
    desde el ScheduleStore actual.
- **`UAMSchedule/SettingsView.swift`**:
  - Quitado el `@State liveActivityActive` y reemplazado por binding directo
    al manager (`liveActivity.isActive`).
  - El sublabel muestra ahora si la permission esta denegada en iOS Settings.
  - El smart mode dispara `checkAndAutoStart` inmediatamente al activarse.
- **`UAMSchedule/UAMScheduleApp.swift`**: agregado `.onChange(of: scenePhase)`
  que rehidrata + ejecuta `checkAndAutoStart` cada vez que la app pasa a active.

---

## 2. Sonidos y haptics — sistema centralizado nuevo

Antes el feedback estaba descentralizado: `AudioServicesPlaySystemSound(1519)`
ad-hoc en splash, onboarding, jaguarcin. No habia toggle global ni catalogo.

### Cambios aplicados

- **`Shared/Soft.swift`** (NUEVO): facade unico para sonidos y haptics.
  - 13 eventos de sonido categorizados (tabSwitch, toggle, success, error,
    classStart, classEnd, attendance, checklist, routeStart, etc.).
  - 9 tipos de haptic (light/medium/heavy/soft/rigid, success/warning/error,
    selection).
  - Respeta los toggles `soundsEnabled` y `hapticsEnabled` en UserDefaults.
  - APIs convenientes: `Soft.tap()`, `Soft.confirm()`, `Soft.reject()`.
- **`UAMSchedule/SettingsView.swift`**: nueva seccion "SONIDO Y HAPTICS" con:
  - Toggle de Sonidos.
  - Toggle de Vibracion (haptics).
  - Boton "Probar feedback" para probar la combinacion inmediatamente.
- Integraciones de `Soft.*` en:
  - Tab bar (`ContentView`): haptic selection + sound tabSwitch al cambiar.
  - Course detail (`CourseDetailView`): haptic selection al cambiar tab.
  - Attendance manager: haptic+sound contextual segun status (present, late,
    absent, justified).
  - Toggle reminders / checklist / favorite: haptic success al completar.
  - Live Activity toggles y end class: feedback completo.

---

## 3. Feature nuevo — Rutas dentro del campus UAM

Para que estudiantes nuevos puedan orientarse fisicamente en el campus.

### Archivos nuevos

- **`Shared/UAMCampus.swift`**: catalogo de edificios y POIs del campus UAM
  Managua (Costado Noroeste Camino de Oriente, centro aprox. 12.108511,
  -86.25712). Incluye:
  - Edificios A–H (Edificio H y C aparecen explicitamente en OpenStreetMap).
  - Biblioteca Central, Auditorio Central, Cafeteria.
  - Canchas deportivas, parqueo, entrada principal.
  - Funcion `inferBuilding(fromRoom:)` que infiere el edificio desde el codigo
    de aula (ej. "B-104" → Edificio B). Acepta formatos "B-104", "B104",
    "EDIF B 104", "EDIFICIO B 104".
- **`UAMSchedule/UAMRouteView.swift`**: vista MapKit con:
  - Mapa centrado en el campus con todos los edificios marcados.
  - Picker de origen (default: Entrada Principal).
  - Picker de destino (default: edificio inferido del aula de la materia).
  - Linea de "ruta" (geodesic dashed) entre origen y destino con el color
    de la materia.
  - Markers diferenciados: walker en origen, flag en destino.
  - Boton primario: "Caminar con Apple Maps" — abre Apple Maps con
    `MKLaunchOptionsDirectionsModeWalking` y los dos puntos como waypoints,
    para direcciones reales con voz.
  - Boton secundario: "Ver mapa oficial UAM" — abre tu shortlink
    https://maps.apple/p/N7.yIdSBqEz_Sc en Apple Maps.
  - `BuildingPickerView` para seleccionar edificios agrupados por categoria.

### Integraciones

- **`CourseDetailView`**: nueva tarjeta "Como llegar al aula" arriba del
  selector de tabs + icono `map.fill` en la toolbar.
- **`TodayView`**:
  - `ActiveClassCard` tiene boton "Trazar ruta" junto a "Finalizar".
  - `NextClassBanner` es tappable completo — abre la ruta directamente.

---

## 4. Widgets — mejoras

- **Nuevo Lock Screen widget** (`UAMScheduleLockScreenWidget`) con 3 familias:
  - `accessoryRectangular`: muestra estado, nombre de materia, aula y hora.
  - `accessoryInline`: linea unica con codigo + aula + hora.
  - `accessoryCircular`: codigo abreviado + minutos restantes, con anillo
    de progreso cuando esta en clase.
- **Timeline mas denso**: en lugar de 1 entrada cada 15 minutos, ahora genera:
  - 1 entrada por minuto durante los proximos 30 minutos.
  - 1 entrada cada 5 minutos durante la siguiente hora.
  - Esto hace que la cuenta regresiva ("3 min", "2 min", "1 min") se vea
    actualizada en el widget Small/Medium.

---

## 5. Archivos modificados — checklist

```
NUEVOS:
  Shared/Soft.swift
  Shared/UAMCampus.swift
  UAMSchedule/UAMRouteView.swift

REESCRITOS:
  Shared/LiveActivityManager.swift

MODIFICADOS:
  Shared/Models.swift                   (Soft feedback + ScheduleStore.shared)
  UAMSchedule/Info.plist                (NSSupportsLiveActivities + Frequent)
  UAMSchedule/UAMScheduleApp.swift      (scenePhase rehydrate)
  UAMSchedule/ContentView.swift         (tab haptic+sound)
  UAMSchedule/SettingsView.swift        (toggle binding real + Sonido section)
  UAMSchedule/TodayView.swift           (Trazar ruta en active + next class)
  UAMSchedule/CourseDetailView.swift    (Como llegar al aula + toolbar)
  UAMSchedule/AttendanceManager.swift   (Soft feedback al marcar)
  UAMScheduleWidget/UAMScheduleWidget.swift  (Lock Screen widget + timeline)
```

---

## 6. Como probar despues del build

### Dynamic Island
1. Agrega una materia con horario que coincida con la hora actual.
2. Ajustes → Dynamic Island → toca "Activar isla dinamica".
3. La isla deberia aparecer arriba con el progreso de la clase.
4. Cierra la app, abre de nuevo: el toggle debe seguir en ON y la isla viva.
5. Toca "Activar automaticamente": antes de cada clase (15 min) se activa sola.
   Despues de la clase se cierra sola.

### Sonidos
1. Ajustes → Sonido y Haptics → "Probar feedback".
2. Cambia tabs: debes sentir + oir feedback.
3. Apaga "Sonidos" y prueba de nuevo: solo haptic.
4. Apaga ambos: nada.

### Rutas
1. Cualquier materia → toca la tarjeta "Como llegar al aula".
2. Verifica que el destino sea el edificio correcto (inferido del aula).
3. Cambia el origen tocando el picker.
4. "Caminar con Apple Maps" abre direcciones a pie reales.
5. "Ver mapa oficial UAM" abre tu shortlink.

### Widgets
1. Lock Screen: agrega el widget circular/rectangular en bloqueo.
2. Verifica que "minutos restantes" cuente bien al pasar el tiempo.
3. Home screen: el widget Small debe mostrar cuenta regresiva exacta.
