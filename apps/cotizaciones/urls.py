from django.urls import path

from apps.cotizaciones import views

urlpatterns = [
    path("", views.cotizaciones_list, name="cotizaciones_list"),
    path("crear/<str:codigo_orden>/", views.cotizacion_crear, name="cotizacion_crear"),
    path("<int:cotizacion_id>/", views.cotizacion_detalle, name="cotizacion_detalle"),
    path(
        "<int:cotizacion_id>/pdf/",
        views.descargar_cotizacion_pdf,
        name="descargar_cotizacion_pdf",
    ),
]
