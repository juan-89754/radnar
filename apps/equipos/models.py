from django.db import models

from apps.clientes.models import Cliente
from apps.core.utils import decrypt_sensitive_data, encrypt_sensitive_data


class Equipo(models.Model):
    TIPO_CHOICES = [
        ("laptop", "Laptop / Portátil"),
        ("desktop", "PC de Escritorio"),
        ("all_in_one", "All-in-One"),
        ("console", "Consola de Videojuegos"),
        ("servidor", "Servidor / Workstation"),
        ("otro", "Otro"),
    ]

    cliente = models.ForeignKey(
        Cliente, on_delete=models.CASCADE, related_name="equipos"
    )
    tipo = models.CharField(
        max_length=30,
        choices=TIPO_CHOICES,
        default="laptop",
        verbose_name="Tipo de Equipo",
    )
    marca = models.CharField(max_length=80, verbose_name="Marca")
    modelo = models.CharField(max_length=100, verbose_name="Modelo Exacto")
    numero_serie = models.CharField(
        max_length=100, blank=True, verbose_name="Número de Serie / S/N"
    )

    # Campo cifrado Fernet para PIN / Contraseña de acceso
    pin_cifrado = models.TextField(
        blank=True, verbose_name="PIN / Contraseña Cifrada (Fernet)"
    )

    # Detalle de componentes
    procesador = models.CharField(max_length=100, blank=True, verbose_name="Procesador")
    ram = models.CharField(max_length=50, blank=True, verbose_name="Memoria RAM")
    almacenamiento = models.CharField(
        max_length=100, blank=True, verbose_name="Almacenamiento (SSD/HDD)"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Equipo"
        verbose_name_plural = "Equipos"

    def set_pin(self, pin_plano: str):
        """Encrypts and stores the plain PIN/password."""
        if pin_plano:
            self.pin_cifrado = encrypt_sensitive_data(pin_plano)
        else:
            self.pin_cifrado = ""

    def get_pin(self) -> str:
        """Decrypts and returns the plain PIN/password."""
        if self.pin_cifrado:
            return decrypt_sensitive_data(self.pin_cifrado)
        return ""

    def __str__(self):
        return f"{self.get_tipo_display()} {self.marca} {self.modelo} — {self.cliente.nombre_completo}"
