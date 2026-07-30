from django.urls import path

from apps.ordenes import views

urlpatterns = [
    path("", views.ordenes_list, name="ordenes_list"),
    path("kanban/", views.kanban_board, name="kanban_board"),
    path("nueva-recepcion/", views.recepcion_nueva, name="recepcion_nueva"),
    path("<str:codigo_orden>/", views.orden_detalle, name="orden_detalle"),
    path(
        "<str:codigo_orden>/estado/",
        views.cambiar_estado_orden,
        name="cambiar_estado_orden",
    ),
    path(
        "<str:codigo_orden>/bitacora/", views.agregar_bitacora, name="agregar_bitacora"
    ),
    path(
        "<str:codigo_orden>/pdf/",
        views.descargar_comprobante_pdf,
        name="descargar_comprobante_pdf",
    ),
    path(
        "<str:codigo_orden>/ticket/",
        views.descargar_ticket_termico,
        name="descargar_ticket_termico",
    ),
]
