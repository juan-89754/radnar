from django.shortcuts import render
from apps.clientes.models import Cliente


def clientes_list(request):
    clientes = Cliente.objects.prefetch_related("ordenes", "equipos").all()
    return render(request, "clientes/clientes_list.html", {"clientes": clientes})
