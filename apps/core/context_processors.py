from django.conf import settings


def business_info(request):
    """
    Context processor to provide business information (RADNAR, Juan Benites, etc.)
    globally to all Django templates without re-fetching.
    """
    return {"business": settings.BUSINESS_INFO}
