from django.test import TestCase, RequestFactory
from django.conf import settings
from apps.core.context_processors import business_info

class BusinessInfoContextProcessorTest(TestCase):
    def setUp(self):
        self.factory = RequestFactory()

    def test_business_info_context_processor(self):
        request = self.factory.get('/')
        context = business_info(request)
        self.assertIn('business', context)
        self.assertEqual(context['business']['NAME'], 'RADNAR')
        self.assertEqual(context['business']['OWNER'], 'Juan Benites')
        self.assertEqual(context['business']['PHONE'], '3206672858')
        self.assertEqual(context['business']['EMAIL'], 'benitezsanabriajuan@gmail.com')
