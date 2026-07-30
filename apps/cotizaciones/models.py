from decimal import Decimal

from django.db import models

from apps.ordenes.models import Orden


class Cotizacion(models.Model):
    ESTADO_CHOICES = [
        ("borrador", "Borrador"),
        ("enviada", "Enviada al Cliente"),
        ("aprobada", "Aprobada por el Cliente"),
        ("rechazada", "Rechazada por el Cliente"),
    ]

    orden = models.ForeignKey(
        Orden, on_delete=models.CASCADE, related_name="cotizaciones"
    )
    titulo = models.CharField(
        max_length=150,
        default="Cotización de Diagnóstico y Reparación",
        verbose_name="Título de la Cotización",
    )
    estado = models.CharField(
        max_length=20,
        choices=ESTADO_CHOICES,
        default="borrador",
        verbose_name="Estado de Cotización",
    )
    notas_cliente = models.TextField(
        blank=True, verbose_name="Notas u Observaciones para el Cliente"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Cotización"
        verbose_name_plural = "Cotizaciones"
        ordering = ["-created_at"]

    @property
    def total_opcion_a(self) -> Decimal:
        """Calcula el total a cobrar al cliente para la Opción A (Principal)."""
        lineas = self.lineas.filter(opcion="opcion_a", aprobada_por_cliente=True)
        return sum((linea.subtotal_cliente for linea in lineas), Decimal("0.00"))

    @property
    def total_opcion_b(self) -> Decimal:
        """Calcula el total a cobrar al cliente para la Opción B (Alternativa)."""
        lineas = self.lineas.filter(opcion="opcion_b", aprobada_por_cliente=True)
        return sum((linea.subtotal_cliente for linea in lineas), Decimal("0.00"))

    def __str__(self):
        return f"Cotización #{self.id} — Orden {self.orden.codigo_orden} ({self.get_estado_display()})"


class LineaCotizacion(models.Model):
    TIPO_CHOICES = [
        ("mano_obra", "Mano de Obra / Servicio Técnico"),
        ("repuesto", "Repuesto / Componente"),
        ("equipo_completo", "Equipo Completo / Periférico"),
    ]

    OPCION_CHOICES = [
        ("opcion_a", "Opción A (Principal / Recomendada)"),
        ("opcion_b", "Opción B (Alternativa / Económica)"),
    ]

    cotizacion = models.ForeignKey(
        Cotizacion, on_delete=models.CASCADE, related_name="lineas"
    )
    tipo = models.CharField(
        max_length=30,
        choices=TIPO_CHOICES,
        default="repuesto",
        verbose_name="Tipo de Línea",
    )
    opcion = models.CharField(
        max_length=20,
        choices=OPCION_CHOICES,
        default="opcion_a",
        verbose_name="Opción de Cotización",
    )
    descripcion = models.CharField(
        max_length=255, verbose_name="Descripción del Repuesto o Servicio"
    )

    # Campo Privado para el Técnico (NUNCA expuesto al cliente)
    costo_proveedor = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=Decimal("0.00"),
        verbose_name="Costo Proveedor (Privado)",
    )
    margen_porcentaje = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=Decimal("30.00"),
        verbose_name="Margen de Ganancia (%)",
    )

    # Precio Cobrado al Cliente
    precio_cliente = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=Decimal("0.00"),
        verbose_name="Precio Unitario Cliente",
    )
    cantidad = models.PositiveIntegerField(default=1, verbose_name="Cantidad")
    aprobada_por_cliente = models.BooleanField(
        default=True, verbose_name="Aprobada en la Cotización"
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Línea de Cotización"
        verbose_name_plural = "Líneas de Cotización"

    @property
    def subtotal_cliente(self) -> Decimal:
        return self.precio_cliente * self.cantidad

    def save(self, *args, **kwargs):
        # Calcular automáticamente el precio al cliente si no fue especificado manualmente
        if self.costo_proveedor > Decimal("0.00") and (
            self.precio_cliente == Decimal("0.00") or self.precio_cliente is None
        ):
            margen_factor = Decimal("1.00") + (
                self.margen_porcentaje / Decimal("100.00")
            )
            self.precio_cliente = (self.costo_proveedor * margen_factor).quantize(
                Decimal("0.01")
            )
        super().save(*args, **kwargs)

    def __str__(self):
        return (
            f"{self.get_opcion_display()}: {self.descripcion} (${self.precio_cliente})"
        )


class EnlaceProveedor(models.Model):
    PROVEEDOR_CHOICES = [
        ("mercadolibre", "MercadoLibre Colombia"),
        ("amazon", "Amazon"),
        ("local", "Proveedor Local / Entrada Manual"),
    ]

    linea_cotizacion = models.OneToOneField(
        LineaCotizacion, on_delete=models.CASCADE, related_name="enlace_proveedor"
    )
    url = models.URLField(blank=True, max_length=500, verbose_name="Enlace de Producto")
    proveedor = models.CharField(
        max_length=30,
        choices=PROVEEDOR_CHOICES,
        default="local",
        verbose_name="Proveedor",
    )

    titulo_extraido = models.CharField(
        max_length=255, blank=True, verbose_name="Título Extraído del Proveedor"
    )
    precio_extraido = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        verbose_name="Último Precio Extraído",
    )
    imagen_url_extraida = models.URLField(
        max_length=500, blank=True, verbose_name="URL Imagen del Proveedor"
    )
    imagen_local = models.ImageField(
        upload_to="proveedores_locales/%Y/%m/",
        blank=True,
        verbose_name="Imagen Local (Proveedor Local)",
    )

    ultimo_precio_verificado = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        verbose_name="Último Precio Verificado",
    )
    timestamp_verificacion = models.DateTimeField(
        null=True, blank=True, verbose_name="Timestamp de Verificación"
    )
    alerta_cambio_precio = models.BooleanField(
        default=False, verbose_name="Alerta Visual: Precio Cambió"
    )

    def __str__(self):
        return f"Enlace {self.get_proveedor_display()} — {self.linea_cotizacion.descripcion}"
