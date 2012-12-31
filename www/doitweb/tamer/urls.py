from django.conf.urls.defaults import *

urlpatterns = patterns('tamer.views',
    url(r'^(?P<dbname>\w+)/$', 'main_console', name='main_console'),

    url(r'^(?P<dbname>\w+)/import-console-(?P<import_object>\w+)$', 'import_console', name='import_console'),

    url(r'^(?P<dbname>\w+)/widgets/attribute-selector$', 'widget_attr_labeller', name='widget_attr_labeller'),
    url(r'^(?P<dbname>\w+)/widgets/attribute-radio$', 'widget_attr_radio', name='widget_attr_radio'),

    url(r'^(?P<dbname>\w+)/import-table$', 'run_import', name='run_import'),
    url(r'^(?P<dbname>\w+)/import-auxiliary$', 'import_auxiliary', name='import_auxiliary'),

    url(r'^(?P<dbname>\w+)/source-(?P<sid>\d+)-map$', 'schema_map_source', name='schema_map_source'),
    url(r'^(?P<dbname>\w+)/source-(?P<sid>\d+)-map/run$', 'schema_map_source_run', name='schema_map_source_run'),
    url(r'^(?P<dbname>\w+)/source-(?P<sid>\d+)-map/schedule$', 'schema_map_source_schedule', name='schema_map_source_schedule'),
    url(r'^(?P<dbname>\w+)/source-(?P<sid>\d+)-dedup$', 'dedup_source', name='dedup_source'),
    url(r'^(?P<dbname>\w+)/source-(?P<sid>\d+)-dedup/clusters$', 'dedup_source_clusters', name='dedup_source_clusters'),
    url(r'^(?P<dbname>\w+)/source-(?P<sid>\d+)$', 'source_console', name='source_console'),
    url(r'^(?P<dbname>\w+)/source-(?P<sid>\d+)-(?P<tab>\w+)$', 'source_console', name='source_console'),

    url(r'^(?P<dbname>\w+)/configure-(?P<model_name>\w+)/set$', 'set_config', name='set_config'),
    url(r'^(?P<dbname>\w+)/configure-(?P<model_name>\w+)$', 'config_console', name='config_console'),

    url(r'^(?P<dbname>\w+)/initialize-dedup$', 'init_dedup_console', name='init_dedup_console'),
    url(r'^(?P<dbname>\w+)/initialize-dedup-submit$', 'init_dedup_submit', name='init_dedup_submit'),
    url(r'^(?P<dbname>\w+)/train-dedup$', 'train_dedup', name='train_dedup'),
    url(r'^(?P<dbname>\w+)/evaluate-dedup$', 'compare_entities', name='compare_entities'),

    url(r'^(?P<dbname>\w+)/.*', 'main_console', name='main_console'),
)
