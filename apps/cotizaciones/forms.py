from django import forms

from apps.cotizaciones.models import Cotizacion, LineaCotizacion


class CotizacionForm(forms.ModelForm):
    class Meta:
        model = Cotizacion
        fields = ["titulo", "notas_cliente", "estado"]
        widgets = {
            "titulo": forms.TextInput(
                attrs={
                    "class": "form-control",
                    "placeholder": "Ej. Cotización Mantenimiento y Cambio de Pantalla",
                }
            ),
            "notas_cliente": forms.Textarea(
                attrs={
                    "class": "form-control",
                    "rows": 2,
                    "placeholder": "Notas explicativas o condiciones de garantía para el cliente",
                }
            ),
            "estado": forms.Select(attrs={"class": "form-control"}),
        }


class LineaCotizacionForm(forms.ModelForm):
    url_proveedor = forms.URLField(
        required=False,
        widget=forms.URLInput(
            attrs={
                "class": "form-control",
                "placeholder": "URL de MercadoLibre o Amazon (opcional)",
            }
        ),
        label="Enlace del Repuesto (MercadoLibre / Amazon)",
    )

    class Meta:
        model = LineaCotizacion
        fields = [
            "tipo",
            "opcion",
            "descripcion",
            "costo_proveedor",
            "margen_porcentaje",
            "precio_cliente",
            "cantidad",
        ]
        widgets = {
            "tipo": forms.Select(attrs={"class": "form-control"}),
            "opcion": forms.Select(attrs={"class": "form-control"}),
            "descripcion": forms.TextInput(
                attrs={
                    "class": "form-control",
                    "placeholder": 'Ej. Pantalla FHD 15.6" IPS 30 Pines',
                }
            ),
            "costo_proveedor": forms.NumberInput(
                attrs={"class": "form-control", "step": "0.01"}
            ),
            "margen_porcentaje": forms.NumberInput(
                attrs={"class": "form-control", "step": "0.01"}
            ),
            "precio_cliente": forms.NumberInput(
                attrs={
                    "class": "form-control",
                    "step": "0.01",
                    "placeholder": "Calculado automáticamente",
                }
            ),
            "cantidad": forms.NumberInput(attrs={"class": "form-control", "min": "1"}),
        }
