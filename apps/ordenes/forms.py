from django import forms

from apps.clientes.models import Cliente
from apps.equipos.models import Equipo
from apps.ordenes.models import Orden


class ClienteForm(forms.ModelForm):
    class Meta:
        model = Cliente
        fields = ["nombre_completo", "telefono", "email", "direccion", "notas"]
        widgets = {
            "nombre_completo": forms.TextInput(
                attrs={"class": "form-control", "placeholder": "Ej. Maria Lopez"}
            ),
            "telefono": forms.TextInput(
                attrs={"class": "form-control", "placeholder": "+573206672858"}
            ),
            "email": forms.EmailInput(
                attrs={"class": "form-control", "placeholder": "correo@ejemplo.com"}
            ),
            "direccion": forms.TextInput(
                attrs={"class": "form-control", "placeholder": "Calle 10 # 20-30"}
            ),
            "notas": forms.Textarea(attrs={"class": "form-control", "rows": 2}),
        }


class EquipoForm(forms.ModelForm):
    pin_plano = forms.CharField(
        required=False,
        widget=forms.PasswordInput(
            attrs={
                "class": "form-control",
                "placeholder": "PIN / Contraseña del equipo",
            }
        ),
        label="PIN / Contraseña del Equipo (Cifrada con Fernet)",
    )

    class Meta:
        model = Equipo
        fields = [
            "tipo",
            "marca",
            "modelo",
            "numero_serie",
            "procesador",
            "ram",
            "almacenamiento",
        ]
        widgets = {
            "tipo": forms.Select(attrs={"class": "form-control"}),
            "marca": forms.TextInput(
                attrs={
                    "class": "form-control",
                    "placeholder": "Ej. Lenovo, Asus, Apple",
                }
            ),
            "modelo": forms.TextInput(
                attrs={"class": "form-control", "placeholder": "Ej. ThinkPad T14"}
            ),
            "numero_serie": forms.TextInput(
                attrs={"class": "form-control", "placeholder": "S/N Opcional"}
            ),
            "procesador": forms.TextInput(
                attrs={"class": "form-control", "placeholder": "Ej. Intel i7 12va gen"}
            ),
            "ram": forms.TextInput(
                attrs={"class": "form-control", "placeholder": "Ej. 16 GB DDR4"}
            ),
            "almacenamiento": forms.TextInput(
                attrs={"class": "form-control", "placeholder": "Ej. 512 GB SSD NVMe"}
            ),
        }


class OrdenForm(forms.ModelForm):
    class Meta:
        model = Orden
        fields = ["motivo_ingreso", "accesorios_incluidos"]
        widgets = {
            "motivo_ingreso": forms.Textarea(
                attrs={
                    "class": "form-control",
                    "rows": 3,
                    "placeholder": "Describe detalladamente la falla o solicitud del cliente",
                }
            ),
            "accesorios_incluidos": forms.Textarea(
                attrs={
                    "class": "form-control",
                    "rows": 2,
                    "placeholder": "Cargador original, funda, mouse, etc.",
                }
            ),
        }


class ChecklistInspeccionForm(forms.Form):
    pantalla_estado = forms.ChoiceField(
        choices=[
            ("ok", "Buen Estado / Sin Rayones"),
            ("rayada", "Con Rayones Leves"),
            ("fisurada", "Fisurada / Rompimiento"),
            ("no_da_video", "No da Video"),
        ],
        widget=forms.Select(attrs={"class": "form-control"}),
        label="Estado de Pantalla",
    )
    teclado_estado = forms.ChoiceField(
        choices=[
            ("ok", "Todas las Teclas Funcionan"),
            ("teclas_faltantes", "Teclas Faltantes"),
            ("teclas_pegadas", "Teclas Pegadas / No responden"),
        ],
        widget=forms.Select(attrs={"class": "form-control"}),
        label="Estado de Teclado",
    )
    chasis_estetico = forms.ChoiceField(
        choices=[
            ("excelente", "Excelente"),
            ("rayones_leves", "Rayones / Desgaste Normal"),
            ("golpes", "Golpes / Bisagras dañadas"),
        ],
        widget=forms.Select(attrs={"class": "form-control"}),
        label="Estado del Chasis / Bisagras",
    )
    enciende = forms.ChoiceField(
        choices=[
            ("si", "Sí Enciende"),
            ("no", "No Enciende"),
            ("intermitente", "Enciende Intermitentemente"),
        ],
        widget=forms.Select(attrs={"class": "form-control"}),
        label="Prueba de Encendido Inicial",
    )
    observaciones_adicionales = forms.CharField(
        required=False,
        widget=forms.Textarea(attrs={"class": "form-control", "rows": 2}),
        label="Observaciones Físicas Adicionales",
    )
