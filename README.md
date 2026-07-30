# RADNAR — Sistema de Gestión Técnica

Sistema de Gestión Operativa, Cotización Dinámica, Diagnóstico e Inventario para Servicio Técnico de Cómputo.

## Información del Negocio y Marca
- **Sistema / Taller**: RADNAR
- **Técnico / Propietario**: Juan Benites
- **Teléfono / WhatsApp**: 3206672858
- **Correo**: benitezsanabriajuan@gmail.com
- **Zona Horaria**: America/Bogota
- **Formato Fecha/Hora**: DD/MM/AAAA, 12h

---

## Requisitos Previos
- Python 3.12 o 3.13 instalado.
- Git instalado.

---

## Guía de Instalación y Configuración Local

### 1. Clonar el repositorio y acceder a la carpeta
```bash
git clone <url-del-repositorio>
cd radnar
```

### 2. Crear y activar el entorno virtual
En Windows (PowerShell / Command Prompt):
```powershell
py -m venv venv
.\venv\Scripts\activate
```

### 3. Instalar dependencias
```powershell
pip install --upgrade pip setuptools wheel
pip install -r requirements.txt
```

### 4. Configurar variables de entorno (`.env`)
Copiar el archivo de plantilla `.env.example` a `.env`:
```powershell
copy .env.example .env
```

Asegurarse de configurar las variables obligatorias en el archivo `.env`:
- `SECRET_KEY`: Clave secreta aleatoria de Django.
- `FERNET_KEY`: Clave de cifrado Fernet de 32 bytes en base64 url-safe (generada una sola vez y mantenida fuera del repositorio).
- `DATABASE_URL`: `sqlite:///db.sqlite3` (o `postgres://usuario:clave@localhost:5432/radnar_db` si se habilita PostgreSQL).
- `TIME_ZONE`: `America/Bogota`

### 5. Ejecutar migraciones e iniciar el servidor de desarrollo
```powershell
python manage.py migrate
python manage.py runserver
```
Acceder al sistema en el navegador en `http://127.0.0.1:8000/`.

---

## Configuración de Tareas Programadas en Windows Task Scheduler

Para ejecutar comandos de gestión de Django automáticamente en Windows sin Redis/Celery (ej. verificación periódica de precios o copias de seguridad):

### Registro de Tarea de Verificación de Precios (Fase 2)
1. Abrir **Programador de Tareas** (`taskschd.msc`) en Windows.
2. Hacer clic en **Crear Tarea básica...**
3. Nombre: `RADNAR - Verificación Diaria de Precios`
4. Desencadenador: **Diariamente** a las 07:00 AM.
5. Acción: **Iniciar un programa**.
6. Programa o script: `E:\Desktop\radnar\venv\Scripts\python.exe` (ruta absoluta a `python.exe` del venv).
7. Agregar argumentos: `manage.py verificar_precios`
8. Iniciar en: `E:\Desktop\radnar` (ruta absoluta del proyecto).

### Registro de Tarea de Respaldo de Base de Datos (Fase 5)
1. Repetir los pasos anteriores con el Nombre: `RADNAR - Backup Diario de Base de Datos`.
2. Programa o script: `E:\Desktop\radnar\venv\Scripts\python.exe`
3. Agregar argumentos: `manage.py dbbackup`
4. Iniciar en: `E:\Desktop\radnar`

---

## Comandos de Calidad y Pruebas
```powershell
# Ejecutar suite de pruebas
python manage.py test

# Formateo y Linting
black .
ruff check .
mypy .
```
