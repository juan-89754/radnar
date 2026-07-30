from django.core.management.base import BaseCommand
from django.utils import timezone

from apps.cotizaciones.models import EnlaceProveedor
from apps.cotizaciones.services.scraper import extraer_metadatos_proveedor


class Command(BaseCommand):
    help = "Verifica los precios de las URLs de repuestos activas y marca alertas visuales si hubo cambios."

    def handle(self, *args, **options):
        self.stdout.write(
            self.style.NOTICE(
                "Iniciando verificación diaria de precios de repuestos RADNAR..."
            )
        )

        # Filtrar enlaces pertenecientes a cotizaciones activas (borrador o enviada)
        enlaces_activos = EnlaceProveedor.objects.filter(
            linea_cotizacion__cotizacion__estado__in=["borrador", "enviada"],
            url__isnull=False,
        ).exclude(url="")

        self.stdout.write(
            f"Procesando {enlaces_activos.count()} enlace(s) activo(s)..."
        )
        cambios_detectados = 0

        for enlace in enlaces_activos:
            self.stdout.write(
                f"Scrapeando URL ({enlace.get_proveedor_display()}): {enlace.url[:60]}..."
            )
            resultado = extraer_metadatos_proveedor(enlace.url)
            precio_nuevo = resultado.get("precio")

            enlace.timestamp_verificacion = timezone.now()

            if precio_nuevo and precio_nuevo > 0:
                if (
                    enlace.ultimo_precio_verificado
                    and enlace.ultimo_precio_verificado != precio_nuevo
                ):
                    enlace.alerta_cambio_precio = True
                    cambios_detectados += 1
                    self.stdout.write(
                        self.style.WARNING(
                            f"  [ALERTA] Precio cambió de ${enlace.ultimo_precio_verificado} a ${precio_nuevo}"
                        )
                    )
                enlace.precio_extraido = precio_nuevo
                enlace.ultimo_precio_verificado = precio_nuevo
                if resultado.get("titulo"):
                    enlace.titulo_extraido = resultado["titulo"]
                if resultado.get("imagen_url"):
                    enlace.imagen_url_extraida = resultado["imagen_url"]

            enlace.save()

        self.stdout.write(
            self.style.SUCCESS(
                f"Verificación finalizada exitosamente. Total procesados: {enlaces_activos.count()}, Cambios detectados: {cambios_detectados}."
            )
        )
