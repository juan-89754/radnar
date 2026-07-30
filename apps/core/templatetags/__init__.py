from django import template

register = template.Library()


@register.filter
def get_item(dictionary, key):
    """Template filter to access dict values by variable key."""
    return dictionary.get(key, [])
