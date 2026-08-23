from django.contrib import messages
from django.http import HttpResponse
from django.shortcuts import get_object_or_404, redirect, render

from apps.cotizaciones.forms import CotizacionForm, LineaCotizacionForm
from apps.cotizaciones.models import Cotizacion, EnlaceProveedor, LineaCotizacion
from apps.cotizaciones.services.scraper import extraer_metadatos_proveedor
from apps.documentos.services import generar_pdf_cotizacion
from apps.ordenes.models import Orden


def cotizaciones_list(request):
    cotizaciones = Cotizacion.objects.select_related("orden", "orden__cliente").all()
    ordenes = Orden.objects.select_related("cliente", "equipo").all()
    return render(
        request,
        "cotizaciones/cotizaciones_list.html",
        {"cotizaciones": cotizaciones, "ordenes": ordenes},
    )


def cotizacion_crear(request, codigo_orden):
    orden = get_object_or_404(Orden, codigo_orden=codigo_orden)
    if request.method == "POST":
        form = CotizacionForm(request.POST)
        if form.is_valid():
            cotizacion = form.save(commit=False)
            cotizacion.orden = orden
            cotizacion.save()
            messages.success(
                request,
                f"¡Cotización #{cotizacion.id} creada exitosamente para la orden {orden.codigo_orden}!",
            )
            return redirect("cotizacion_detalle", cotizacion_id=cotizacion.id)
        else:
            messages.error(
                request, "Error al crear la cotización. Por favor revisa los datos ingresados."
            )
    else:
        form = CotizacionForm()

    return render(
        request, "cotizaciones/cotizacion_form.html", {"form": form, "orden": orden}
    )


def cotizacion_detalle(request, cotizacion_id):
    cotizacion = get_object_or_404(
        Cotizacion.objects.select_related("orden", "orden__cliente", "orden__equipo"),
        id=cotizacion_id,
    )
    lineas = cotizacion.lineas.select_related("enlace_proveedor").all()

    if request.method == "POST":
        linea_form = LineaCotizacionForm(request.POST)
        if linea_form.is_valid():
            linea = linea_form.save(commit=False)
            linea.cotizacion = cotizacion
            linea.save()

            # Procesar URL de proveedor si se proporcionó
            url_prov = linea_form.cleaned_data.get("url_proveedor")
            if url_prov:
                resultado = extraer_metadatos_proveedor(url_prov)
                prov_type = (
                    "mercadolibre"
                    if "mercadolibre" in url_prov.lower()
                    else ("amazon" if "amazon" in url_prov.lower() else "local")
                )
                EnlaceProveedor.objects.create(
                    linea_cotizacion=linea,
                    url=url_prov,
                    proveedor=prov_type,
                    titulo_extraido=resultado.get("titulo") or "",
                    precio_extraido=resultado.get("precio"),
                    imagen_url_extraida=resultado.get("imagen_url") or "",
                    ultimo_precio_verificado=resultado.get("precio"),
                )
                if (
                    resultado.get("precio")
                    and resultado["precio"] > 0
                    and linea.costo_proveedor == 0
                ):
                    linea.costo_proveedor = resultado["precio"]
                    linea.save()

            messages.success(
                request, f"¡Línea '{linea.descripcion}' agregada correctamente!"
            )
            return redirect("cotizacion_detalle", cotizacion_id=cotizacion.id)
        else:
            messages.error(
                request,
                "Error al agregar la línea. Asegúrate de ingresar una descripción y precio válido."
            )
    else:
        linea_form = LineaCotizacionForm()

    return render(
        request,
        "cotizaciones/cotizacion_detalle.html",
        {
            "cotizacion": cotizacion,
            "lineas": lineas,
            "linea_form": linea_form,
        },
    )


def linea_cotizacion_eliminar(request, linea_id):
    linea = get_object_or_404(LineaCotizacion, id=linea_id)
    cotizacion_id = linea.cotizacion_id
    linea.delete()
    messages.success(request, "Línea eliminada de la cotización.")
    return redirect("cotizacion_detalle", cotizacion_id=cotizacion_id)


def descargar_cotizacion_pdf(request, cotizacion_id):
    cotizacion = get_object_or_404(
        Cotizacion.objects.select_related("orden", "orden__cliente", "orden__equipo"),
        id=cotizacion_id,
    )
    pdf_bytes = generar_pdf_cotizacion(cotizacion)
    response = HttpResponse(pdf_bytes, content_type="application/pdf")
    response["Content-Disposition"] = (
        f'attachment; filename="Cotizacion_{cotizacion.orden.codigo_orden}_v{cotizacion.id}.pdf"'
    )
    return response
