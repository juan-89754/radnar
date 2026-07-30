from django.core.exceptions import ValidationError

# Matriz de transiciones permitidas (no se puede saltar estados)
TRANSICIONES_PERMITIDAS = {
    "ingresado": ["en_diagnostico"],
    "en_diagnostico": ["cotizado", "ingresado"],
    "cotizado": ["aprobado", "en_diagnostico"],
    "aprobado": ["en_reparacion", "cotizado"],
    "en_reparacion": ["en_pruebas"],
    "en_pruebas": ["listo_entrega", "en_reparacion"],
    "listo_entrega": ["entregado_cobrado"],
    "entregado_cobrado": [],  # Estado terminal
}

ESTADOS_LEGIBLES = {
    "ingresado": "1. Ingresado",
    "en_diagnostico": "2. En diagnóstico",
    "cotizado": "3. Cotizado",
    "aprobado": "4. Aprobado",
    "en_reparacion": "5. En reparación",
    "en_pruebas": "6. En pruebas",
    "listo_entrega": "7. Listo para entrega",
    "entregado_cobrado": "8. Entregado y cobrado",
}

# Plantillas de mensajes WhatsApp predefinidas
PLANTILLAS_WHATSAPP = {
    "recepcion_confirmada": {
        "nombre": "Recepción Confirmada",
        "cuerpo": (
            "Hola {nombre_cliente} 👋, te confirmamos que hemos recibido tu equipo *{marca_modelo}* "
            "con el código de orden *{codigo_orden}* en RADNAR Servicio Técnico.\n\n"
            "Nos pondremos en contacto contigo en cuanto tengamos el diagnóstico listo.\n\n"
            "Gracias por confiar en nosotros 🔧"
        ),
    },
    "diagnostico_listo": {
        "nombre": "Diagnóstico Listo / Cotización",
        "cuerpo": (
            "Hola {nombre_cliente}, ya tenemos el diagnóstico de tu *{marca_modelo}* "
            "(Orden: {codigo_orden}) ✅.\n\n"
            "Por favor revisa la cotización adjunta o escríbenos aquí para que te la enviemos.\n\n"
            "Tu aprobación nos permite iniciar la reparación de inmediato. 🛠️"
        ),
    },
    "reparacion_lista": {
        "nombre": "Equipo Listo para Entrega",
        "cuerpo": (
            "¡Excelentes noticias {nombre_cliente}! 🎉\n\n"
            "Tu equipo *{marca_modelo}* (Orden: {codigo_orden}) está listo para ser recogido.\n\n"
            "💰 Valor total a cancelar: *${saldo_pendiente}*\n\n"
            "Horario de atención: Lunes a Sábado 8am–6pm. ¡Te esperamos! 😊"
        ),
    },
    "recordatorio_recogida": {
        "nombre": "Recordatorio de Recogida",
        "cuerpo": (
            "Hola {nombre_cliente} 👋, queremos recordarte que tu equipo *{marca_modelo}* "
            "(Orden: {codigo_orden}) sigue listo para ser recogido en RADNAR.\n\n"
            "💰 Saldo pendiente: *${saldo_pendiente}*\n\n"
            "Escríbenos o comunícate al {telefono_taller} para coordinar. 📲"
        ),
    },
    "entrega_completada": {
        "nombre": "Entrega Completada",
        "cuerpo": (
            "Hola {nombre_cliente} ✅\n\n"
            "Gracias por reclamar tu equipo *{marca_modelo}*. Tu pago ha sido recibido y la orden "
            "*{codigo_orden}* ha sido cerrada exitosamente.\n\n"
            "Cualquier inconveniente con la garantía de la reparación, no dudes en contactarnos. 🙏\n\n"
            "— RADNAR Servicio Técnico"
        ),
    },
}


def validar_transicion(estado_actual: str, estado_nuevo: str):
    """
    Valida que la transición de estado sea permitida según la matriz.
    Lanza ValidationError si la transición no está autorizada.
    """
    permitidos = TRANSICIONES_PERMITIDAS.get(estado_actual, [])
    if estado_nuevo not in permitidos:
        permitidos_str = (
            ", ".join(ESTADOS_LEGIBLES.get(e, e) for e in permitidos)
            or "ninguno (estado terminal)"
        )
        raise ValidationError(
            f"Transición no permitida: «{ESTADOS_LEGIBLES.get(estado_actual, estado_actual)}» "
            f"→ «{ESTADOS_LEGIBLES.get(estado_nuevo, estado_nuevo)}». "
            f"Desde este estado solo se puede avanzar a: {permitidos_str}."
        )
