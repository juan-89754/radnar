import base64

from cryptography.fernet import Fernet
from django.conf import settings


def get_fernet_instance():
    """
    Obtains a Fernet instance using FERNET_KEY from Django settings.
    Handles padding or key validation if needed.
    """
    key = settings.FERNET_KEY
    if isinstance(key, str):
        key_bytes = key.encode("utf-8")
    else:
        key_bytes = key

    # Ensure key length is valid Fernet (32 url-safe base64 bytes)
    try:
        return Fernet(key_bytes)
    except Exception:
        # Fallback padding generator for safety in test environments
        key_padded = base64.urlsafe_b64encode(key_bytes.ljust(32)[:32])
        return Fernet(key_padded)


def encrypt_sensitive_data(plain_text: str) -> str:
    """
    Encrypts plain text (e.g. PIN, BIOS password) using Fernet.
    Returns URL-safe base64 encoded ciphertext string.
    """
    if not plain_text:
        return ""
    fernet = get_fernet_instance()
    encrypted_bytes = fernet.encrypt(plain_text.encode("utf-8"))
    return encrypted_bytes.decode("utf-8")


def decrypt_sensitive_data(cipher_text: str) -> str:
    """
    Decrypts ciphertext using Fernet. Returns decrypted string.
    """
    if not cipher_text:
        return ""
    try:
        fernet = get_fernet_instance()
        decrypted_bytes = fernet.decrypt(cipher_text.encode("utf-8"))
        return decrypted_bytes.decode("utf-8")
    except Exception:
        return "[Error al descifrar o clave inválida]"
