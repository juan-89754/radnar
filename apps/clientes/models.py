import re

from django.core.exceptions import ValidationError
from django.db import models


def validate_e164_phone(value):
    """
    Validates that a phone number adheres strictly to the E.164 international format.
    Example: +573206672858 or +14155552671
    """
    if not value:
        return
    # Strip spaces or hyphens for user convenience if provided
    clean_val = value.strip().replace(" ", "").replace("-", "")
    pattern = r"^\+[1-9]\d{6,14}$"
    if not re.match(pattern, clean_val):
        raise ValidationError(
            f"'{value}' no es un número de teléfono válido en formato E.164 (ej. +573206672858)."
        )


class Cliente(models.Model):
    nombre_completo = models.CharField(max_length=150, verbose_name="Nombre Completo")
    telefono = models.CharField(
        max_length=20,
        unique=True,
        validators=[validate_e164_phone],
        verbose_name="Teléfono (E.164)",
        help_text="Formato internacional E.164 (ej. +573206672858). Único por cliente.",
    )
    email = models.EmailField(blank=True, null=True, verbose_name="Correo Electrónico")
    direccion = models.CharField(max_length=255, blank=True, verbose_name="Dirección")
    notas = models.TextField(blank=True, verbose_name="Notas Internas")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Cliente"
        verbose_name_plural = "Clientes"
        ordering = ["-created_at"]

    def clean(self):
        super().clean()
        if self.telefono:
            # Normalizar teléfono quitando espacios e guiones antes de guardar
            self.telefono = self.telefono.strip().replace(" ", "").replace("-", "")

    def save(self, *args, **kwargs):
        self.full_clean()
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.nombre_completo} ({self.telefono})"
