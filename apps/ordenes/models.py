import hashlib
import json

from django.core.exceptions import ValidationError
from django.db import models
from django.utils import timezone

from apps.clientes.models import Cliente
from apps.core.models import Tecnico
from apps.equipos.models import Equipo


class Orden(models.Model):
    ESTADO_CHOICES = [
        ("ingresado", "1. Ingresado"),
        ("en_diagnostico", "2. En diagnóstico"),
        ("cotizado", "3. Cotizado / Esperando aprobación"),
        ("aprobado", "4. Aprobado / Repuestos pedidos"),
        ("en_reparacion", "5. En reparación"),
        ("en_pruebas", "6. En pruebas (stress test)"),
        ("listo_entrega", "7. Listo para entrega"),
        ("entregado_cobrado", "8. Entregado y cobrado"),
    ]

    ESTADOS_BLOQUEADOS = [
        "en_reparacion",
        "en_pruebas",
        "listo_entrega",
        "entregado_cobrado",
    ]

    codigo_orden = models.CharField(
        max_length=20,
        unique=True,
        editable=False,
        verbose_name="Código de Orden (ORD-AAAA-NNN)",
    )
    cliente = models.ForeignKey(
        Cliente, on_delete=models.PROTECT, related_name="ordenes"
    )
    equipo = models.ForeignKey(Equipo, on_delete=models.PROTECT, related_name="ordenes")
    tecnico = models.ForeignKey(
        Tecnico,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="ordenes",
    )

    estado = models.CharField(
        max_length=30,
        choices=ESTADO_CHOICES,
        default="ingresado",
        verbose_name="Estado de la Orden",
    )

    motivo_ingreso = models.TextField(
        verbose_name="Motivo de Ingreso / Fallas Reportadas"
    )
    accesorios_incluidos = models.TextField(
        blank=True, verbose_name="Accesorios Recibidos (Cargador, funda, etc.)"
    )

    fecha_ingreso = models.DateTimeField(
        default=timezone.now, verbose_name="Fecha y Hora de Ingreso"
    )
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Orden de Servicio"
        verbose_name_plural = "Órdenes de Servicio"
        ordering = ["-fecha_ingreso"]

    @property
    def is_locked(self) -> bool:
        """
        Devuelve True si la orden se encuentra en 'En reparación' o estado posterior,
        lo que bloquea la edición del checklist y del cliente.
        """
        return self.estado in self.ESTADOS_BLOQUEADOS

    def generate_codigo_orden(self):
        year = timezone.now().year
        prefix = f"ORD-{year}-"
        last_order = (
            Orden.objects.filter(codigo_orden__startswith=prefix).order_by("id").last()
        )
        if not last_order:
            next_num = 1
        else:
            try:
                last_num_str = last_order.codigo_orden.split("-")[-1]
                next_num = int(last_num_str) + 1
            except ValueError:
                next_num = 1
        return f"{prefix}{next_num:03d}"

    def clean(self):
        super().clean()
        if self.pk:
            old_instance = Orden.objects.get(pk=self.pk)
            # Regla de negocio 2.2: Bloquear cambio de cliente tras pasar a 'En reparación' o posterior
            if old_instance.is_locked and old_instance.cliente_id != self.cliente_id:
                raise ValidationError(
                    "No se permite cambiar el cliente asociado a la orden una vez que pasa a estado 'En reparación' o posterior."
                )

    def save(self, *args, **kwargs):
        if not self.codigo_orden:
            self.codigo_orden = self.generate_codigo_orden()
        self.full_clean()
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.codigo_orden} — {self.cliente.nombre_completo} ({self.get_estado_display()})"


class ChecklistRecepcion(models.Model):
    orden = models.OneToOneField(
        Orden, on_delete=models.CASCADE, related_name="checklist"
    )
    datos_inspeccion = models.JSONField(
        default=dict,
        verbose_name="Datos de Inspección Física",
        help_text="Estructura JSON con checklist (pantalla, teclado, bisagras, cargador, encendido, rayones, etc.)",
    )
    hash_sha256 = models.CharField(
        max_length=64, editable=False, verbose_name="Hash SHA-256 de Inmutabilidad"
    )
    timestamp_sellado = models.DateTimeField(
        auto_now_add=True, verbose_name="Timestamp de Sellado"
    )

    class Meta:
        verbose_name = "Checklist de Recepción"
        verbose_name_plural = "Checklists de Recepción"

    def calculate_hash(self) -> str:
        """
        Calcula un hash SHA-256 determinista a partir de los datos de inspección y el código de orden.
        """
        json_dump = json.dumps(
            self.datos_inspeccion, sort_keys=True, ensure_ascii=False
        )
        ts_str = self.timestamp_sellado.isoformat() if self.timestamp_sellado else ""
        raw_payload = f"{self.orden.codigo_orden}:{ts_str}:{json_dump}"
        return hashlib.sha256(raw_payload.encode("utf-8")).hexdigest()

    def clean(self):
        super().clean()
        if self.pk:
            old_instance = ChecklistRecepcion.objects.get(pk=self.pk)
            # Regla de negocio 2.2: Bloquear edición del checklist si la orden está en 'En reparación' o posterior
            if self.orden.is_locked:
                raise ValidationError(
                    "El checklist de recepción está bloqueado y no puede editarse una vez que la orden pasa a 'En reparación' o posterior."
                )
            # Inmutabilidad del checklist guardado
            if old_instance.datos_inspeccion != self.datos_inspeccion:
                raise ValidationError(
                    "El checklist de recepción es inmutable tras su creación y no puede modificarse."
                )

    def save(self, *args, **kwargs):
        if not self.pk:
            # First save to set timestamp_sellado
            if not self.timestamp_sellado:
                self.timestamp_sellado = timezone.now()
            self.hash_sha256 = self.calculate_hash()
        else:
            self.clean()
        super().save(*args, **kwargs)

    def __str__(self):
        return f"Checklist {self.orden.codigo_orden} (Hash: {self.hash_sha256[:8]}...)"


class FotoEvidencia(models.Model):
    orden = models.ForeignKey(Orden, on_delete=models.CASCADE, related_name="fotos")
    checklist = models.ForeignKey(
        ChecklistRecepcion,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="fotos",
    )
    imagen = models.ImageField(
        upload_to="evidencias/%Y/%m/", verbose_name="Fotografía de Evidencia"
    )
    anotacion = models.CharField(
        max_length=255, blank=True, verbose_name="Anotación / Observación"
    )
    hash_sha256 = models.CharField(
        max_length=64, editable=False, verbose_name="Hash SHA-256 de la Imagen"
    )
    timestamp_sellado = models.DateTimeField(
        auto_now_add=True, verbose_name="Timestamp de Carga"
    )

    class Meta:
        verbose_name = "Fotografía de Evidencia"
        verbose_name_plural = "Fotografías de Evidencia"
        ordering = ["timestamp_sellado"]

    def calculate_image_hash(self) -> str:
        """Calcula el hash SHA-256 del contenido binario de la imagen."""
        if not self.imagen:
            return ""
        hasher = hashlib.sha256()
        self.imagen.open()
        for chunk in self.imagen.chunks():
            hasher.update(chunk)
        return hasher.hexdigest()

    def clean(self):
        super().clean()
        if not self.pk:
            count = FotoEvidencia.objects.filter(orden=self.orden).count()
            if count >= 10:
                raise ValidationError(
                    "No se permiten más de 10 fotos por orden de recepción."
                )

    def save(self, *args, **kwargs):
        self.clean()
        if not self.hash_sha256 and self.imagen:
            self.hash_sha256 = self.calculate_image_hash()
        super().save(*args, **kwargs)

    def __str__(self):
        return f"Foto {self.orden.codigo_orden} - {self.anotacion or 'Sin anotación'}"
