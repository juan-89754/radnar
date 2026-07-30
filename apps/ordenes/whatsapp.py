from urllib.parse import quote as url_quote

from django.conf import settings

from apps.ordenes.kanban import PLANTILLAS_WHATSAPP


def construir_variables_whatsapp(orden) -> dict:
    """
    Construye el diccionario de variables de reemplazo disponibles para las
    plantillas de WhatsApp a partir de la orden dada.
    Saldo pendiente se calcula desde Finanzas (Fase 4), por ahora 0.
    """
    saldo_pendiente = "0"
    try:
        from apps.finanzas.models import RegistroPago

        total_cobrado = sum(p.monto for p in RegistroPago.objects.filter(orden=orden))
        ult_cot = orden.cotizaciones.filter(estado="aprobada").last()
        total_cotizado = ult_cot.total_opcion_a if ult_cot else 0
        saldo_pendiente = str(max(0, total_cotizado - total_cobrado))
    except Exception:
        pass

    return {
        "nombre_cliente": orden.cliente.nombre_completo,
        "marca_modelo": f"{orden.equipo.marca} {orden.equipo.modelo}",
        "codigo_orden": orden.codigo_orden,
        "saldo_pendiente": saldo_pendiente,
        "telefono_taller": settings.BUSINESS_INFO.get("PHONE", ""),
    }


def generar_url_whatsapp(orden, clave_plantilla: str) -> str:
    """
    Genera el enlace dinámico wa.me/ para el número del cliente de la orden
    con el texto de la plantilla predefinida ya rellenado con las variables.
    """
    plantilla = PLANTILLAS_WHATSAPP.get(clave_plantilla)
    if not plantilla:
        return ""

    variables = construir_variables_whatsapp(orden)
    mensaje = plantilla["cuerpo"].format(**variables)
    # Extraer solo los dígitos del teléfono (E.164 quita el +)
    telefono = orden.cliente.telefono.replace("+", "").replace(" ", "")
    return f"https://wa.me/{telefono}?text={url_quote(mensaje)}"
