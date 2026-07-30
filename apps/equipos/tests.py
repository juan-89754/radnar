from django.test import TestCase

from apps.clientes.models import Cliente
from apps.equipos.models import Equipo


class EquipoFernetEncryptionTest(TestCase):
    def setUp(self):
        self.cliente = Cliente.objects.create(
            nombre_completo="Prueba Cifrado", telefono="+573112223344"
        )

    def test_fernet_cifrado_y_descifrado_pin(self):
        equipo = Equipo(
            cliente=self.cliente, tipo="laptop", marca="Lenovo", modelo="ThinkPad T14"
        )
        pin_secreto = "MiPINSecreto1234!"
        equipo.set_pin(pin_secreto)
        equipo.save()

        # Asegurar que pin_cifrado no es texto plano
        self.assertNotEqual(equipo.pin_cifrado, pin_secreto)
        self.assertTrue(len(equipo.pin_cifrado) > 20)

        # Recuperar desde la base de datos y descifrar
        equipo_db = Equipo.objects.get(pk=equipo.pk)
        self.assertEqual(equipo_db.get_pin(), pin_secreto)
