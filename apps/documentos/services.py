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
    pdf_file = HTML(string=html_string).write_pdf()
    return pdf_file
