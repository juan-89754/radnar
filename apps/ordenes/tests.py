from django.core.exceptions import ValidationError
from django.test import TestCase

from apps.clientes.models import Cliente
from apps.documentos.services import generar_pdf_comprobante_recepcion
from apps.equipos.models import Equipo
from apps.ordenes.models import ChecklistRecepcion, Orden


class OrdenChecklistBusinessRulesTest(TestCase):
    def setUp(self):
        self.cliente = Cliente.objects.create(
            nombre_completo="Cliente Test", telefono="+573201112233"
        )
        self.equipo = Equipo.objects.create(
            cliente=self.cliente, tipo="desktop", marca="Dell", modelo="OptiPlex 7080"
        )
        self.orden = Orden.objects.create(
            cliente=self.cliente,
            equipo=self.equipo,
            motivo_ingreso="Mantenimiento preventivo",
        )

    def test_codigo_orden_autogenerado(self):
        self.assertTrue(self.orden.codigo_orden.startswith("ORD-"))

    def test_checklist_hash_y_sellado(self):
        checklist = ChecklistRecepcion.objects.create(
            orden=self.orden, datos_inspeccion={"pantalla": "ok", "teclado": "ok"}
        )
        self.assertIsNotNone(checklist.hash_sha256)
        self.assertEqual(len(checklist.hash_sha256), 64)

    def test_bloqueo_edicion_tras_en_reparacion(self):
        ChecklistRecepcion.objects.create(
            orden=self.orden, datos_inspeccion={"pantalla": "ok"}
        )

        # Avanzar orden a 'en_reparacion'
        self.orden.estado = "en_reparacion"
        self.orden.save()

        # Intentar modificar el cliente asociado a la orden bloqueada
        cliente2 = Cliente.objects.create(
            nombre_completo="Otro", telefono="+573009990011"
        )
        self.orden.cliente = cliente2
        with self.assertRaises(ValidationError):
            self.orden.full_clean()

    def test_generacion_pdf_comprobante(self):
        ChecklistRecepcion.objects.create(
            orden=self.orden, datos_inspeccion={"pantalla": "ok", "enciende": "si"}
        )
        pdf_bytes = generar_pdf_comprobante_recepcion(self.orden)
        self.assertTrue(len(pdf_bytes) > 0)
        self.assertTrue(pdf_bytes.startswith(b"%PDF"))
