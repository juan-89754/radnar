from django.contrib.auth.models import User
from django.db import models


class Tecnico(models.Model):
    user = models.OneToOneField(
        User, on_delete=models.CASCADE, related_name="tecnico_profile"
    )
    nombre_completo = models.CharField(max_length=150, verbose_name="Nombre Completo")
    telefono = models.CharField(max_length=20, blank=True, verbose_name="Teléfono")
    activo = models.BooleanField(default=True, verbose_name="Técnico Activo")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Técnico"
        verbose_name_plural = "Técnicos"

    def __str__(self):
        return f"{self.nombre_completo} ({self.user.username})"
