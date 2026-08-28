# Sistema de audio

## 1. Componentes

`AudioService` administra un único `AudioPlayer` estático durante toda la aplicación. `AudioNotificationService` publica eventos en un stream broadcast y `AudioOverlayWrapper` los convierte en información visual superpuesta.

```text
UI o endpoint → AudioService → audioplayers → asset
                     │
                     └→ AudioNotificationService → overlay
```

## 2. Reproducción

`AudioService.play()` recibe:

- `assetPath`: ruta relativa para `AssetSource`, por ejemplo `audio/question_coffe.wav`.
- `force`: ignora el cooldown.
- `volume`: valor solicitado; una llamada marcada como remota lo reemplaza por `1.0`.
- `displayText`: texto opcional del overlay.
- `showOverlay`: default `true`.

El servicio configura volumen, inicia el asset y espera `onPlayerComplete.first`. Retorna `true` si termina correctamente y `false` si el cooldown lo omite o hay una excepción.

## 3. Cooldown y llamadas remotas

El cooldown global predeterminado es de cinco segundos y se calcula desde el inicio de la última reproducción aceptada. `force: true` lo evita.

Antes de reproducir desde un endpoint, `AppServer` llama `setRemoteCall(true)`. La siguiente reproducción fuerza volumen al 100 % y restablece la bandera. Como la bandera es global, llamadas concurrentes deben tratarse con cuidado.

## 4. Overlay

Al comenzar se emite `AudioEventType.playing`; al terminar, fallar o detenerse se emite `stopped`. Si no se proporciona texto, se deriva del nombre quitando `audio/`, `.wav` y reemplazando guiones bajos por espacios.

`AudioOverlayWidget` administra su propio timer de ocultamiento. El overlay no controla el audio: únicamente representa los eventos publicados.

## 5. Métodos predefinidos

| Método | Asset |
| --- | --- |
| `playQuestion()` | `audio/question_coffe.wav` |
| `playThanks()` | `audio/thanks_shopping.wav` |
| `playBuy()` | `audio/purchase_buy.wav` |
| `playThereIsAnOrder()` | `audio/there_is_an_order.wav` |
| `playAttentionExcuseMe()` | `audio/attention_excuse_me.wav` |
| `playCollectTray()` | `audio/collect_tray.wav` |
| `playHereIsCoffee()` | `audio/here_is_coffee.wav` |

Los textos predeterminados proceden de `AudioMessages`.

## 6. Integración con flujos

- `/greet` y `/play-question` muestran el primer producto y reproducen pregunta.
- `/greet/audio?asset=audio/...` muestra el primer producto y reproduce el
  asset indicado.
- Un pago confirmado en `QrPaymentPage` reproduce agradecimiento.
- El panel QR embebido también reproduce audio en su flujo posterior al éxito.
- Los demás audios pueden dispararse mediante endpoints especializados o `/audio/play`.

## 7. Plataforma y ciclo de vida

Existe una función `_boostLinuxVolume`, pero las instrucciones `pactl` están comentadas; actualmente solo espera 300 ms en Linux. `stop()` detiene reproducción y overlay. `dispose()` libera el player, aunque no se invoca desde `main.dart` en el código vigente.

Los assets registrados por Flutter son todo `assets/audio/`. Para agregar un archivo basta ubicarlo allí; si se cambia la estructura, debe actualizarse `pubspec.yaml`.

## 8. API

Los cuerpos, parámetros y respuestas de `/audio/play`, `/play-audio`, `/audio/stop` y endpoints predefinidos están en [API.md](API.md).

## Referencias

- [Diagrama del sistema de audio](diagrams/13-audio-flow.md)
- [Diagrama de servidor local y bus de comandos](diagrams/06-server-commands.md)
- [Arquitectura general](ARCHITECTURE.md)
