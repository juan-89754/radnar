import json
import re
import time
from decimal import Decimal
from urllib.parse import urlparse

import requests
from bs4 import BeautifulSoup

# Dominio rate limiter: rastrea el timestamp de la última solicitud por dominio
LAST_REQUEST_TIMES = {}
MIN_DELAY_SECONDS = 5.0

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
    "Accept-Language": "es-CO,es;q=0.9,en-US;q=0.8,en;q=0.7",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
}


def rate_limit_domain(url: str):
    """
    Garantiza que transcurran al menos 5 segundos entre solicitudes consecutivas al mismo dominio.
    """
    domain = urlparse(url).netloc
    last_time = LAST_REQUEST_TIMES.get(domain, 0)
    elapsed = time.time() - last_time
    if elapsed < MIN_DELAY_SECONDS:
        time.sleep(MIN_DELAY_SECONDS - elapsed)
    LAST_REQUEST_TIMES[domain] = time.time()


def extraer_precio_limpio(texto_precio: str) -> Decimal:
    """
    Limpia cadenas de precios como "$ 1.250.000,00" o "USD 45.99" a un Decimal.
    """
    if not texto_precio:
        return Decimal("0.00")
    # Eliminar cualquier caracter que no sea dígito, coma o punto
    clean_str = re.sub(r"[^\d.,]", "", str(texto_precio))
    if not clean_str:
        return Decimal("0.00")

    # Manejar formatos de miles con punto y decimales con coma (Formato CO/EU)
    if "." in clean_str and "," in clean_str:
        clean_str = clean_str.replace(".", "").replace(",", ".")
    elif "," in clean_str:
        clean_str = clean_str.replace(",", ".")

    try:
        return Decimal(clean_str)
    except Exception:
        return Decimal("0.00")


def extraer_metadatos_open_graph(soup: BeautifulSoup) -> dict:
    """Nivel 1: Open Graph (og:title, og:image, og:price:amount)"""
    meta_title = soup.find("meta", property="og:title") or soup.find(
        "meta", attrs={"name": "og:title"}
    )
    meta_image = soup.find("meta", property="og:image") or soup.find(
        "meta", attrs={"name": "og:image"}
    )
    meta_price = (
        soup.find("meta", property="og:price:amount")
        or soup.find("meta", property="product:price:amount")
        or soup.find("meta", attrs={"name": "twitter:data1"})
    )

    title = (
        meta_title["content"].strip()
        if meta_title and meta_title.get("content")
        else None
    )
    image = (
        meta_image["content"].strip()
        if meta_image and meta_image.get("content")
        else None
    )
    price_val = (
        extraer_precio_limpio(meta_price["content"])
        if meta_price and meta_price.get("content")
        else None
    )

    if title or price_val:
        return {
            "titulo": title,
            "imagen_url": image,
            "precio": price_val,
            "metodo": "OpenGraph",
        }
    return {}


def extraer_metadatos_json_ld(soup: BeautifulSoup) -> dict:
    """Nivel 2: JSON-LD (schema.org/Product)"""
    scripts = soup.find_all("script", type="application/ld+json")
    for script in scripts:
        if not script.string:
            continue
        try:
            data = json.loads(script.string)
            if isinstance(data, list):
                data = data[0] if len(data) > 0 else {}

            if data.get("@type") in ("Product", "ItemPage", "IndividualProduct"):
                title = data.get("name")
                image = data.get("image")
                if isinstance(image, list) and len(image) > 0:
                    image = image[0]

                offers = data.get("offers", {})
                if isinstance(offers, list) and len(offers) > 0:
                    offers = offers[0]

                price_raw = offers.get("price") or offers.get("lowPrice")
                price_val = extraer_precio_limpio(price_raw) if price_raw else None

                if title or price_val:
                    return {
                        "titulo": title,
                        "imagen_url": image if isinstance(image, str) else None,
                        "precio": price_val,
                        "metodo": "JSON-LD",
                    }
        except Exception:
            continue
    return {}


def extraer_metadatos_microdata(soup: BeautifulSoup) -> dict:
    """Nivel 3: Microdata HTML específico de tienda"""
    # Intentar selectors típicos de MercadoLibre / Amazon
    title_elem = soup.find("h1") or soup.find(
        class_=re.compile(r"title|product-name", re.IGNORECASE)
    )
    price_elem = soup.find(
        class_=re.compile(r"price-tag-fraction|a-price-whole|price", re.IGNORECASE)
    )
    image_elem = soup.find(
        "img", class_=re.compile(r"image|photo|thumbnail", re.IGNORECASE)
    )

    title = title_elem.get_text(strip=True) if title_elem else None
    price_val = (
        extraer_precio_limpio(price_elem.get_text(strip=True)) if price_elem else None
    )
    image_url = image_elem.get("src") if image_elem else None

    if title or price_val:
        return {
            "titulo": title,
            "imagen_url": image_url,
            "precio": price_val,
            "metodo": "Microdata",
        }
    return {}


def extraer_metadatos_proveedor(url: str) -> dict:
    """
    Flujo de extracción en cascada:
    Open Graph → JSON-LD → Microdata → Fallback manual (Nivel 4)
    """
    if not url:
        return {
            "titulo": None,
            "imagen_url": None,
            "precio": Decimal("0.00"),
            "metodo": "Manual",
        }

    rate_limit_domain(url)

    try:
        response = requests.get(url, headers=HEADERS, timeout=10)
        if response.status_code != 200:
            return {
                "titulo": None,
                "imagen_url": None,
                "precio": Decimal("0.00"),
                "metodo": "FallbackManual",
            }

        soup = BeautifulSoup(response.text, "html.parser")

        # Nivel 1: Open Graph
        og_result = extraer_metadatos_open_graph(soup)
        if og_result.get("precio") and og_result["precio"] > 0:
            return og_result

        # Nivel 2: JSON-LD
        jsonld_result = extraer_metadatos_json_ld(soup)
        if jsonld_result.get("precio") and jsonld_result["precio"] > 0:
            return jsonld_result

        # Nivel 3: Microdata
        microdata_result = extraer_metadatos_microdata(soup)
        if microdata_result.get("precio") and microdata_result["precio"] > 0:
            return microdata_result

        # Si recuperó al menos título o imagen pero sin precio exacto
        combined_title = (
            og_result.get("titulo")
            or jsonld_result.get("titulo")
            or microdata_result.get("titulo")
        )
        combined_image = (
            og_result.get("imagen_url")
            or jsonld_result.get("imagen_url")
            or microdata_result.get("imagen_url")
        )

        return {
            "titulo": combined_title,
            "imagen_url": combined_image,
            "precio": Decimal("0.00"),
            "metodo": "CascadaIncompleta",
        }

    except Exception:
        # Nivel 4: Entrada manual ante cualquier fallo de red o scraping
        return {
            "titulo": None,
            "imagen_url": None,
            "precio": Decimal("0.00"),
            "metodo": "FallbackManual",
        }
