from django.conf import settings
from django.template.loader import render_to_string
from weasyprint import HTML


def generar_pdf_comprobante_recepcion(orden) -> bytes:
    """
    Generates a PDF bytes object for the Reception Receipt of the given order using WeasyPrint.
    Follows Swiss Typographic Style guidelines.
    """
    context = {
        "orden": orden,
        "business": settings.BUSINESS_INFO,
    }
    html_string = render_to_string("documentos/comprobante_recepcion.html", context)
    return HTML(string=html_string).write_pdf()


def generar_pdf_cotizacion(cotizacion) -> bytes:
    """
    Generates a PDF bytes object for the Quote with Options A & B using WeasyPrint.
    Strictly excludes provider cost to protect technician privacy.
    """
    lineas_opcion_a = cotizacion.lineas.filter(opcion="opcion_a")
    lineas_opcion_b = cotizacion.lineas.filter(opcion="opcion_b")

    context = {
        "cotizacion": cotizacion,
        "lineas_opcion_a": lineas_opcion_a,
        "lineas_opcion_b": lineas_opcion_b,
        "business": settings.BUSINESS_INFO,
    }
    html_string = render_to_string("documentos/cotizacion_pdf.html", context)
    return HTML(string=html_string).write_pdf()


def generar_ticket_termico(orden) -> bytes:
    """
    Generates an 80mm thermal receipt PDF using WeasyPrint.
    """
    context = {
        "orden": orden,
        "business": settings.BUSINESS_INFO,
    }
    html_string = render_to_string("documentos/ticket_termico.html", context)
    return HTML(string=html_string).write_pdf()
