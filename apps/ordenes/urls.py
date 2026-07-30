from django.urls import path

from apps.ordenes import views

urlpatterns = [
    path("", views.ordenes_list, name="ordenes_list"),
    path("nueva-recepcion/", views.recepcion_nueva, name="recepcion_nueva"),
    path("<str:codigo_orden>/", views.orden_detalle, name="orden_detalle"),
    path(
        "<str:codigo_orden>/pdf/",
        views.descargar_comprobante_pdf,
        name="descargar_comprobante_pdf",
    ),
]
