from django.core.exceptions import ValidationError
from django.test import TestCase

from apps.clientes.models import Cliente


class ClienteModelTest(TestCase):
    def test_crear_cliente_exitoso(self):
        cliente = Cliente.objects.create(
            nombre_completo="Juan Perez",
            telefono="+573001234567",
            email="juan@ejemplo.com",
        )
        self.assertEqual(cliente.telefono, "+573001234567")
        self.assertEqual(str(cliente), "Juan Perez (+573001234567)")

    def test_telefono_e164_invalido(self):
        cliente = Cliente(nombre_completo="Ana", telefono="abc123")
        with self.assertRaises(ValidationError):
            cliente.full_clean()

    def test_telefono_10_digitos_autocorregido(self):
        cliente = Cliente(nombre_completo="Ana", telefono="3001234567")
        cliente.clean()
        self.assertEqual(cliente.telefono, "+573001234567")

    def test_duplicado_telefono_error(self):
        Cliente.objects.create(nombre_completo="Carlos", telefono="+573009998877")
        cliente_duplicado = Cliente(
            nombre_completo="Carlos II", telefono="+573009998877"
        )
        with self.assertRaises(ValidationError):
            cliente_duplicado.full_clean()
