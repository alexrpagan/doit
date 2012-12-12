from django.conf import settings

# context processors...

def url_context(request):
    alt_root = ''
    if settings.ALT_ROOT:
        alt_root = ''.join(('/', settings.ALT_ROOT, ))
    return { 'url_context_on': True,
             'base_url': settings.BASE_URL,
             'alt_root': alt_root }
