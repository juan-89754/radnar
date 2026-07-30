from django.contrib import messages
from django.db import transaction
from django.http import HttpResponse
from django.shortcuts import get_object_or_404, redirect, render

from apps.clientes.models import Cliente
from apps.documentos.services import generar_pdf_comprobante_recepcion
from apps.ordenes.forms import (
    ChecklistInspeccionForm,
    ClienteForm,
    EquipoForm,
    OrdenForm,
)
from apps.ordenes.models import ChecklistRecepcion, FotoEvidencia, Orden


def ordenes_list(request):
    ordenes = Orden.objects.select_related("cliente", "equipo").all()
    return render(request, "ordenes/ordenes_list.html", {"ordenes": ordenes})


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

        # Si el teléfono ya existe, reusar el cliente existente
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

                # Crear checklist con datos en JSON
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
                    orden=orden, datos_inspeccion=datos_inspeccion
                )

                # Subir fotos de evidencia (máximo 10)
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
            "fotos"
        ),
        codigo_orden=codigo_orden,
    )
    pin_descifrado = orden.equipo.get_pin()
    return render(
        request,
        "ordenes/orden_detalle.html",
        {
            "orden": orden,
            "pin_descifrado": pin_descifrado,
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
