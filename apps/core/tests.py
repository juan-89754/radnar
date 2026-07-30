from django.core.exceptions import ValidationError
from django.test import RequestFactory, TestCase

from apps.clientes.models import Cliente
from apps.core.context_processors import business_info
from apps.equipos.models import Equipo
from apps.ordenes.kanban import validar_transicion
from apps.ordenes.models import (
    BitacoraTecnica,
    HistorialEstadoOrden,
    Orden,
)
from apps.ordenes.whatsapp import generar_url_whatsapp


class BusinessInfoContextProcessorTest(TestCase):
    def setUp(self):
        self.factory = RequestFactory()

    def test_business_info_context_processor(self):
        request = self.factory.get("/")
        context = business_info(request)
        self.assertIn("business", context)
        self.assertEqual(context["business"]["NAME"], "RADNAR")
        self.assertEqual(context["business"]["OWNER"], "Juan Benites")
        self.assertEqual(context["business"]["PHONE"], "3206672858")
        self.assertEqual(context["business"]["EMAIL"], "benitezsanabriajuan@gmail.com")


class KanbanTransitionMatrixTest(TestCase):
    def setUp(self):
        self.cliente = Cliente.objects.create(
            nombre_completo="Kanban Test",
            telefono="+573000000001",
        )
        self.equipo = Equipo.objects.create(
            cliente=self.cliente,
            tipo="laptop",
            marca="Test",
            modelo="KanbanPro",
        )
        self.orden = Orden.objects.create(
            cliente=self.cliente,
            equipo=self.equipo,
            motivo_ingreso="Prueba kanban",
        )

    def test_transicion_valida_ingresado_a_diagnostico(self):
        """Transición inicial válida: ingresado → en_diagnostico."""
        try:
            validar_transicion("ingresado", "en_diagnostico")
        except ValidationError:
            self.fail(
                "validar_transicion() lanzó ValidationError en una transición válida."
            )

    def test_transicion_invalida_salta_estados(self):
        """No debe permitirse saltar estados: ingresado → en_reparacion."""
        with self.assertRaises(ValidationError):
            validar_transicion("ingresado", "en_reparacion")

    def test_transicion_invalida_estado_terminal(self):
        """El estado entregado_cobrado no permite ninguna transición."""
        with self.assertRaises(ValidationError):
            validar_transicion("entregado_cobrado", "listo_entrega")

    def test_retroceso_permitido_diagnostico_a_ingresado(self):
        """Retroceso autorizado de un paso: en_diagnostico → ingresado."""
        try:
            validar_transicion("en_diagnostico", "ingresado")
        except ValidationError:
            self.fail("Retroceso de un paso debería estar permitido.")

    def test_historial_estado_creado_en_cambio(self):
        """Verificar que el historial de estados se graba correctamente."""
        HistorialEstadoOrden.objects.create(
            orden=self.orden,
            estado_anterior="ingresado",
            estado_nuevo="en_diagnostico",
            notas_transicion="Iniciando diagnóstico de placa.",
        )
        self.assertEqual(self.orden.historial_estados.count(), 1)
        h = self.orden.historial_estados.first()
        self.assertEqual(h.estado_nuevo, "en_diagnostico")

    def test_bitacora_tecnica_privada(self):
        """Bitácora técnica debe marcarse como privada por defecto."""
        entrada = BitacoraTecnica.objects.create(
            orden=self.orden,
            contenido="Voltaje en placa 3.3v OK. CPU temp 65°C.",
        )
        self.assertTrue(entrada.es_privado)
        self.assertIn("Kanban Test", str(self.orden))


class WhatsAppURLGeneratorTest(TestCase):
    def setUp(self):
        self.cliente = Cliente.objects.create(
            nombre_completo="María WhatsApp",
            telefono="+573201234567",
        )
        self.equipo = Equipo.objects.create(
            cliente=self.cliente,
            tipo="laptop",
            marca="HP",
            modelo="Pavilion 15",
        )
        self.orden = Orden.objects.create(
            cliente=self.cliente,
            equipo=self.equipo,
            motivo_ingreso="Pantalla rota",
        )

    def test_genera_url_wa_me_valida(self):
        url = generar_url_whatsapp(self.orden, "recepcion_confirmada")
        self.assertTrue(url.startswith("https://wa.me/573201234567"))
        self.assertIn("RADNAR", url)
        self.assertIn(self.orden.codigo_orden, url)

    def test_plantilla_inexistente_retorna_vacio(self):
        url = generar_url_whatsapp(self.orden, "plantilla_no_existe")
        self.assertEqual(url, "")

    def test_nombre_cliente_en_url(self):
        url = generar_url_whatsapp(self.orden, "reparacion_lista")
        self.assertIn("Mar%C3%ADa", url)  # URL-encoded "María"
