from django.urls import path
from apps.clientes import views

urlpatterns = [
    path("", views.clientes_list, name="clientes_list"),
]
