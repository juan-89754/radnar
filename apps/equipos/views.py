from django.shortcuts import render
from apps.equipos.models import Equipo


def equipos_list(request):
    equipos = Equipo.objects.select_related("cliente").all()
    return render(request, "equipos/equipos_list.html", {"equipos": equipos})
