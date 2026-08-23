from django.urls import path
from apps.equipos import views

urlpatterns = [
    path("", views.equipos_list, name="equipos_list"),
]
