# UAM Schedule

app de iPhone para llevar el **horario de clases** de la UAM (Universidad Americana, Managua) en el bolsillo: qué te toca hoy, cuál es la próxima clase, en qué aula, y avisos antes de que empiece.

es la hermana de [UAM Class](https://github.com/kisnner26/uam-class): UAM Class es una app de macOS para el aula virtual (Moodle); **UAM Schedule se centra en el horario**, en el iPhone, con widgets, Dynamic Island y Siri.

swiftui, iOS 17+.

## qué hace

**horario**
- vista de **hoy** y de **semana**, con materias editables (nombre, código, aula, color y sesiones)
- **escáner de horario**: lee tu horario desde una imagen con reconocimiento de texto, para no escribirlo a mano
- **importar desde calendario** y **respaldo / restauración** del horario
- onboarding para arrancar con tu horario en un par de minutos

**en tu pantalla, sin abrir la app**
- **widgets** pequeño, mediano y grande con lo que sigue
- **Live Activity y Dynamic Island** para la clase en curso
- **avisos** antes de cada clase, con nivel *time sensitive* para que atraviesen los modos de concentración
- **atajos de Siri**: próxima clase, clase actual, horario de hoy y tus materias

**día a día en la universidad**
- **control de asistencia** por materia
- **rutas dentro del campus** UAM, con el catálogo de edificios y puntos de interés
- **seguimiento de ánimo**
- **Jaguarcín**, la mascota que te acompaña y celebra contigo

**aula virtual (Moodle)**
- tareas pendientes, detalle de cursos, entrega de tareas y mensajería, integrados en la vista de hoy

## compilar

requiere Xcode y [XcodeGen](https://github.com/yonaskolb/XcodeGen). el proyecto usa Swift 6.

```bash
brew install xcodegen
xcodegen generate
open UAMSchedule.xcodeproj
```

1. en `project.yml` pon tu `DEVELOPMENT_TEAM` (o elige tu equipo en Xcode → Signing & Capabilities).
2. si tu equipo pide otro bundle id, cambia `com.kisnner.uamschedule` en `project.yml` y en `Auth0Config.swift`. el **App Group** (`group.com.kisnner.uamschedule`) debe coincidir en la app y en el widget.
3. configura el inicio de sesión (abajo).
4. elige un iPhone o simulador y corre.

> con una cuenta de desarrollador gratuita la app expira a los 7 días: reconecta el iPhone y vuelve a correr desde Xcode.

### inicio de sesión con Auth0

el login con Google usa [Auth0](https://auth0.com). el repo **no incluye credenciales**: crea las tuyas.

1. crea un tenant gratuito y una aplicación **Native**.
2. activa la conexión social **Google** (con el scope de solo lectura de Google Calendar si vas a usar la importación).
3. agrega la URL de callback: `com.kisnner.uamschedule://<TU_DOMINIO>/ios/com.kisnner.uamschedule/callback`.
4. rellena `domain` y `clientId` en [`UAMSchedule/Auth0Config.swift`](UAMSchedule/Auth0Config.swift).

## estructura

```
UAMSchedule/          app principal: vistas, managers (avisos, asistencia, Siri, backups), Moodle
UAMScheduleWidget/    widgets, Live Activity y Dynamic Island
Shared/               modelos, extensiones, sistema de diseño y catálogo del campus (app + widget)
project.yml           definición del proyecto (XcodeGen)
CHANGELOG_v26.md      notas de la versión 26
```

## notas

- el widget se refresca cada ~15 minutos por límites de WidgetKit.
- iOS no permite activar un modo de concentración desde una app; UAM Schedule usa avisos *time sensitive* y un enlace directo a Ajustes.

## licencia

pendiente de definir.
