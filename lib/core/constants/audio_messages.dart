/// Mensajes predefinidos para el overlay de audio.
/// Centraliza todos los textos que se muestran cuando se reproduce un audio.
class AudioMessages {
  AudioMessages._();

  // ─── Saludo / Pregunta ───
  static const String question = '¿Hola, quieres un café?';

  // ─── Agradecimiento ───
  static const String thanks = ' Gracias por tu compra, enseguida te lo traigo';

  // ─── Invitación a comprar ───
  static const String buy = 'Si compras un café, te lo traigo enseguida';

  // ─── Orden recibida ───
  static const String orderReceived = 'Tengo un pedido, los puedes revisar, son los que dicen "Robot Mesero"';

  // ─── Atención / Disculpa ───
  static const String attention = 'Atención, con permiso por favor';

  // ─── Cobrar bandeja ───
  static const String collectTray = ' ¿Hola, puedo recojer tu bandeja?';

  // ─── Café listo ───
  static const String coffeeReady = 'Aqui tienes tu café, que lo disfrutes';

  // ─── Pago exitoso ───
  static const String paymentSuccess = '¡Pago confirmado! Preparando tu pedido...';

  // ─── Pago fallido ───
  static const String paymentFailed = 'El pago fue rechazado o expiró.';

  // ─── Pago cancelado ───
  static const String paymentCancelled = 'El pago fue cancelado.';
}