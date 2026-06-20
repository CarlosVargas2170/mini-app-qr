Coloca aquí los archivos de audio necesarios para el bot del diner.

Archivos requeridos:
- question.mp3   -> Audio de saludo: '¿Deseas un café?'
- thanks.mp3     -> Audio de agradecimiento: 'Gracias por tu compra'

Notas:
- Si tus archivos usan otro formato (wav, ogg, etc.), renómbralos a .mp3
  o cambia la extensión en lib/core/services/audio_service.dart.
- La app reproduce 'question.mp3' al pulsar el botón 'SALUDAR CLIENTE'.
- La app reproduce 'thanks.mp3' automáticamente cuando el pago QR se confirma.
- Evita archivos muy pesados para no aumentar el tamaño de la app.
