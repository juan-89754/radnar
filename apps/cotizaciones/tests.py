from decimal import Decimal
from unittest.mock import MagicMock, patch

from bs4 import BeautifulSoup
from django.core.management import call_command
from django.test import TestCase

from apps.clientes.models import Cliente
from apps.cotizaciones.models import Cotizacion, EnlaceProveedor, LineaCotizacion
from apps.cotizaciones.services.scraper import (
    extraer_metadatos_json_ld,
    extraer_metadatos_open_graph,
    extraer_precio_limpio,
)
from apps.documentos.services import generar_pdf_cotizacion
from apps.equipos.models import Equipo
from apps.ordenes.models import Orden


class CotizacionModelAndSecurityTest(TestCase):
    def setUp(self):
        self.cliente = Cliente.objects.create(
            nombre_completo="Maria Cotizaciones", telefono="+573159998877"
        )
        self.equipo = Equipo.objects.create(
            cliente=self.cliente, tipo="laptop", marca="Asus", modelo="ZenBook"
        )
        self.orden = Orden.objects.create(
            cliente=self.cliente, equipo=self.equipo, motivo_ingreso="Pantalla rota"
        )
        self.cotizacion = Cotizacion.objects.create(
            orden=self.orden, titulo="Cotización Reparación Pantalla"
        )

    def test_calculo_margen_y_subtotales_opciones_a_b(self):
        linea_a = LineaCotizacion.objects.create(
            cotizacion=self.cotizacion,
            opcion="opcion_a",
            descripcion="Pantalla FHD Original",
            costo_proveedor=Decimal("200000.00"),
            margen_porcentaje=Decimal("30.00"),
            cantidad=1,
        )
        # 200,000 * 1.30 = 260,000.00
        self.assertEqual(linea_a.precio_cliente, Decimal("260000.00"))
        self.assertEqual(self.cotizacion.total_opcion_a, Decimal("260000.00"))

        linea_b = LineaCotizacion.objects.create(
            cotizacion=self.cotizacion,
            opcion="opcion_b",
            descripcion="Pantalla Genérica Económica",
            costo_proveedor=Decimal("120000.00"),
            margen_porcentaje=Decimal("25.00"),
            cantidad=1,
        )
        # 120,000 * 1.25 = 150,000.00
        self.assertEqual(linea_b.precio_cliente, Decimal("150000.00"))
        self.assertEqual(self.cotizacion.total_opcion_b, Decimal("150000.00"))

    def test_pdf_seguridad_costo_proveedor_nunca_expuesto(self):
        LineaCotizacion.objects.create(
            cotizacion=self.cotizacion,
            opcion="opcion_a",
            descripcion="Repuesto Secreto",
            costo_proveedor=Decimal("777555.00"),  # Costo privado técnico
            precio_cliente=Decimal("999000.00"),
            cantidad=1,
        )
        pdf_bytes = generar_pdf_cotizacion(self.cotizacion)
        self.assertTrue(len(pdf_bytes) > 0)

        # Validar en decodificación de texto que el costo privado 777555 no aparece en la salida del cliente
        pdf_text = pdf_bytes.decode("latin-1", errors="ignore")
        self.assertNotIn("777555", pdf_text)


class ScraperCascadaTest(TestCase):
    def test_extraer_precio_limpio(self):
        self.assertEqual(extraer_precio_limpio("$ 1.250.000,00"), Decimal("1250000.00"))
        self.assertEqual(extraer_precio_limpio("USD 45.99"), Decimal("45.99"))

    def test_open_graph_parser(self):
        html = '<html><head><meta property="og:title" content="Pantalla Asus"><meta property="og:price:amount" content="150000.00"></head></html>'
        soup = BeautifulSoup(html, "html.parser")
        res = extraer_metadatos_open_graph(soup)
        self.assertEqual(res["titulo"], "Pantalla Asus")
        self.assertEqual(res["precio"], Decimal("150000.00"))

    def test_json_ld_parser(self):
        html = """<html><head><script type="application/ld+json">
        {"@type": "Product", "name": "Batería HP", "offers": {"price": "85000.00"}}
        </script></head></html>"""
        soup = BeautifulSoup(html, "html.parser")
        res = extraer_metadatos_json_ld(soup)
        self.assertEqual(res["titulo"], "Batería HP")
        self.assertEqual(res["precio"], Decimal("85000.00"))

    @patch("apps.cotizaciones.services.scraper.requests.get")
    def test_verificar_precios_command(self, mock_get):
        # Mock de respuesta HTTP con OpenGraph
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.text = '<html><head><meta property="og:title" content="Disco SSD"><meta property="og:price:amount" content="195000.00"></head></html>'
        mock_get.return_value = mock_response

        cliente = Cliente.objects.create(
            nombre_completo="Test", telefono="+573100001122"
        )
        equipo = Equipo.objects.create(
            cliente=cliente, tipo="desktop", marca="HP", modelo="Pavilion"
        )
        orden = Orden.objects.create(
            cliente=cliente, equipo=equipo, motivo_ingreso="SSD"
        )
        cotizacion = Cotizacion.objects.create(orden=orden, estado="borrador")
        linea = LineaCotizacion.objects.create(
            cotizacion=cotizacion,
            descripcion="SSD 1TB",
            costo_proveedor=Decimal(180000),
        )

        enlace = EnlaceProveedor.objects.create(
            linea_cotizacion=linea,
            url="https://articulo.mercadolibre.com.co/MCO-12345",
            proveedor="mercadolibre",
            ultimo_precio_verificado=Decimal("180000.00"),
        )

        call_command("verificar_precios")

        enlace.refresh_from_db()
        self.assertEqual(enlace.ultimo_precio_verificado, Decimal("195000.00"))
        self.assertTrue(enlace.alerta_cambio_precio)
