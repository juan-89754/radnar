from django.contrib import messages
from django.core.exceptions import ValidationError
from django.db import transaction
from django.http import HttpResponse, JsonResponse
from django.shortcuts import get_object_or_404, redirect, render

from apps.clientes.models import Cliente
from apps.documentos.services import (
    generar_pdf_comprobante_recepcion,
    generar_ticket_termico,
)
from apps.ordenes.forms import (
    ChecklistInspeccionForm,
    ClienteForm,
    EquipoForm,
    OrdenForm,
)
from apps.ordenes.kanban import (
    PLANTILLAS_WHATSAPP,
    TRANSICIONES_PERMITIDAS,
    validar_transicion,
)
from apps.ordenes.models import (
    BitacoraTecnica,
    ChecklistRecepcion,
    FotoEvidencia,
    HistorialEstadoOrden,
    Orden,
)
from apps.ordenes.whatsapp import generar_url_whatsapp


def ordenes_list(request):
    ordenes = Orden.objects.select_related("cliente", "equipo").all()
    return render(request, "ordenes/ordenes_list.html", {"ordenes": ordenes})


def kanban_board(request):
    """Vista del tablero Kanban con las 8 columnas de estado."""
    ESTADOS_ORDEN = [
        ("ingresado", "1. Ingresado"),
        ("en_diagnostico", "2. En diagnóstico"),
        ("cotizado", "3. Cotizado"),
        ("aprobado", "4. Aprobado"),
        ("en_reparacion", "5. En reparación"),
        ("en_pruebas", "6. En pruebas"),
        ("listo_entrega", "7. Listo para entrega"),
        ("entregado_cobrado", "8. Entregado y cobrado"),
    ]

    ordenes_por_estado = {}
    for key, _ in ESTADOS_ORDEN:
        ordenes_por_estado[key] = Orden.objects.filter(estado=key).select_related(
            "cliente", "equipo"
        )

    return render(
        request,
        "ordenes/kanban_board.html",
        {
            "estados": ESTADOS_ORDEN,
            "ordenes_por_estado": ordenes_por_estado,
            "transiciones": TRANSICIONES_PERMITIDAS,
        },
    )


def cambiar_estado_orden(request, codigo_orden):
    """Procesa el cambio de estado de una orden con validación de la matriz de transiciones."""
    if request.method != "POST":
        return JsonResponse({"error": "Método no permitido."}, status=405)

    orden = get_object_or_404(Orden, codigo_orden=codigo_orden)
    nuevo_estado = request.POST.get("nuevo_estado", "").strip()
    notas = request.POST.get("notas_transicion", "").strip()

    try:
        validar_transicion(orden.estado, nuevo_estado)
    except ValidationError as e:
        messages.error(request, str(e.message))
        return redirect("orden_detalle", codigo_orden=codigo_orden)

    with transaction.atomic():
        estado_anterior = orden.estado
        orden.estado = nuevo_estado
        orden.save()
        HistorialEstadoOrden.objects.create(
            orden=orden,
            estado_anterior=estado_anterior,
            estado_nuevo=nuevo_estado,
            notas_transicion=notas,
        )

    messages.success(
        request,
        f"Orden {orden.codigo_orden} avanzó de «{estado_anterior}» a «{nuevo_estado}» exitosamente.",
    )
    return redirect("orden_detalle", codigo_orden=codigo_orden)


def agregar_bitacora(request, codigo_orden):
    """Agrega una entrada privada a la bitácora técnica de la orden."""
    if request.method != "POST":
        return redirect("orden_detalle", codigo_orden=codigo_orden)

    orden = get_object_or_404(Orden, codigo_orden=codigo_orden)
    contenido = request.POST.get("contenido", "").strip()
    autor = request.POST.get("autor_texto", "Técnico").strip()

    if contenido:
        BitacoraTecnica.objects.create(
            orden=orden,
            contenido=contenido,
            autor_texto=autor,
            es_privado=True,
        )
        messages.success(request, "Entrada agregada a la bitácora técnica.")
    else:
        messages.warning(request, "El contenido de la bitácora no puede estar vacío.")

    return redirect("orden_detalle", codigo_orden=codigo_orden)


def recepcion_nueva(request):
    """
    Creación completa en un solo flujo (Fase 1):
    1. Buscar o crear cliente por teléfono E.164.
    2. Crear equipo cifrando PIN/contraseña con Fernet.
    3. Crear orden con código automático ORD-AAAA-NNN.
    4. Crear checklist de inspección sellado con hash SHA-256 e timestamp.
    5. Subir hasta 10 fotos con anotaciones.
    """
    if request.method == "POST":
        cliente_form = ClienteForm(request.POST)
        equipo_form = EquipoForm(request.POST)
        orden_form = OrdenForm(request.POST)
        checklist_form = ChecklistInspeccionForm(request.POST)
        fotos = request.FILES.getlist("fotos")

        telefono_ingresado = (
            request.POST.get("telefono", "").strip().replace(" ", "").replace("-", "")
        )
        cliente_existente = Cliente.objects.filter(telefono=telefono_ingresado).first()
        cliente_valid = True if cliente_existente else cliente_form.is_valid()

        if (
            cliente_valid
            and equipo_form.is_valid()
            and orden_form.is_valid()
            and checklist_form.is_valid()
        ):
            with transaction.atomic():
                if cliente_existente:
                    cliente = cliente_existente
                else:
                    cliente = cliente_form.save()

                equipo = equipo_form.save(commit=False)
                equipo.cliente = cliente
                pin_plano = equipo_form.cleaned_data.get("pin_plano")
                if pin_plano:
                    equipo.set_pin(pin_plano)
                equipo.save()

                orden = orden_form.save(commit=False)
                orden.cliente = cliente
                orden.equipo = equipo
                orden.save()

                datos_inspeccion = {
                    "pantalla": checklist_form.cleaned_data["pantalla_estado"],
                    "teclado": checklist_form.cleaned_data["teclado_estado"],
                    "chasis": checklist_form.cleaned_data["chasis_estetico"],
                    "enciende": checklist_form.cleaned_data["enciende"],
                    "observaciones": checklist_form.cleaned_data[
                        "observaciones_adicionales"
                    ],
                }
                checklist = ChecklistRecepcion.objects.create(
                    orden=orden,
                    datos_inspeccion=datos_inspeccion,
                )

                for i, foto in enumerate(fotos[:10]):
                    anotacion = request.POST.get(
                        f"anotacion_{i}", f"Foto evidencia #{i+1}"
                    )
                    FotoEvidencia.objects.create(
                        orden=orden,
                        checklist=checklist,
                        imagen=foto,
                        anotacion=anotacion,
                    )

                # Registrar primer estado en historial
                HistorialEstadoOrden.objects.create(
                    orden=orden,
                    estado_anterior="",
                    estado_nuevo="ingresado",
                    notas_transicion="Orden creada en recepción.",
                )

                messages.success(
                    request, f"Orden {orden.codigo_orden} creada exitosamente."
                )
                return redirect("orden_detalle", codigo_orden=orden.codigo_orden)
    else:
        cliente_form = ClienteForm()
        equipo_form = EquipoForm()
        orden_form = OrdenForm()
        checklist_form = ChecklistInspeccionForm()

    return render(
        request,
        "ordenes/recepcion_nueva.html",
        {
            "cliente_form": cliente_form,
            "equipo_form": equipo_form,
            "orden_form": orden_form,
            "checklist_form": checklist_form,
        },
    )


def orden_detalle(request, codigo_orden):
    orden = get_object_or_404(
        Orden.objects.select_related("cliente", "equipo", "checklist").prefetch_related(
            "fotos", "historial_estados", "bitacora"
        ),
        codigo_orden=codigo_orden,
    )
    pin_descifrado = orden.equipo.get_pin()
    transiciones_disponibles = TRANSICIONES_PERMITIDAS.get(orden.estado, [])

    # Generar todas las URLs de WhatsApp disponibles
    urls_whatsapp = {}
    for clave, plantilla in PLANTILLAS_WHATSAPP.items():
        urls_whatsapp[clave] = {
            "nombre": plantilla["nombre"],
            "url": generar_url_whatsapp(orden, clave),
        }

    return render(
        request,
        "ordenes/orden_detalle.html",
        {
            "orden": orden,
            "pin_descifrado": pin_descifrado,
            "transiciones_disponibles": transiciones_disponibles,
            "urls_whatsapp": urls_whatsapp,
        },
    )


def descargar_comprobante_pdf(request, codigo_orden):
    orden = get_object_or_404(
        Orden.objects.select_related("cliente", "equipo", "checklist"),
        codigo_orden=codigo_orden,
    )
    pdf_bytes = generar_pdf_comprobante_recepcion(orden)
    response = HttpResponse(pdf_bytes, content_type="application/pdf")
    response["Content-Disposition"] = (
        f'attachment; filename="Comprobante_Recepcion_{orden.codigo_orden}.pdf"'
    )
    return response


def descargar_ticket_termico(request, codigo_orden):
    orden = get_object_or_404(
        Orden.objects.select_related("cliente", "equipo"),
        codigo_orden=codigo_orden,
    )
    pdf_bytes = generar_ticket_termico(orden)
    response = HttpResponse(pdf_bytes, content_type="application/pdf")
    response["Content-Disposition"] = (
        f'attachment; filename="Ticket_{orden.codigo_orden}.pdf"'
    )
    return response
