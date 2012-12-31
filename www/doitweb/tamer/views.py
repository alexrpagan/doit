import re
from tamer.db import TamerDB, f2c
from django.core.urlresolvers import reverse
from django.shortcuts import render
from django.http import HttpResponse, HttpResponseRedirect
from django.utils import simplejson
import settings


source_schema = settings.SOURCE_SCHEMA


##
# Full console views
##
def main_console(req, dbname):
    db = TamerDB(dbname)
    return render(req, 'tamer/console.html', {
        'navitems': nav_items(db), })


def import_console(req, dbname, import_object):
    db = TamerDB(dbname)
    return render(req, 'tamer/import-console.html', {
        'navitems': nav_items(db), 'tables': db.schema_tables(source_schema),
        'global_attributes': db.global_attribute_names(),
        'schemaname': source_schema, 'object': import_object})


def source_console(req, dbname, sid):
    db = TamerDB(dbname)

    tab = req.GET['tab'] if 'tab' in req.GET else 0

    source = {'id': sid, 'name': db.source_name(sid),
              'stats': db.source_stats(sid)}

    return render(req, 'tamer/source-console.html', {
        'navitems': nav_items(db), 'source': source, 'tab': tab,
        'actionsets': action_sets(db, tab, sid)})


def config_console(req, dbname, model_name):
    db = TamerDB(dbname)
    mname = 'Entity Resolution' if model_name == 'dedup' else 'Schema Mapping'
    return render(req, 'tamer/config-console.html', {
        'navitems': nav_items(db),
        'mod_name': mname,
        'params': db.config_params(model_name)})


def set_config(req, dbname, model_name):
    db = TamerDB(dbname)
    for n, v in req.GET.iteritems():
        db.set_config(n, v)
    return HttpResponse(simplejson.dumps({'status': 'OK'}),
                        mimetype='application/json')


def init_dedup_console(req, dbname):
    db = TamerDB(dbname)
    return render(req, 'tamer/init-dedup-console.html', {
        'navitems': nav_items(db),
        'attributes': db.global_attributes()})


def init_dedup_submit(req, dbname):
    db = TamerDB(dbname)
    important = []
    irrelevant = []
    for k in req.POST:
        if 'important-' in k:
            important.append(req.POST[k])
        if 'irrelevant-' in k:
            irrelevant.append(req.POST[k])
    db.init_dedup(important, irrelevant)
    return HttpResponse(simplejson.dumps({'status': 'OK'}),
                        mimetype='application/json')


def train_dedup(req, dbname):
    db = TamerDB(dbname)
    if not db.dedup_model_exists():
        return HttpResponseRedirect(reverse('tamer:init_dedup_console', args=(dbname,)))
    else:
        db.dedup_all()
        return HttpResponseRedirect(reverse('tamer:compare_entities', args=(dbname,)))


##
# Dedup feedback page
##
def compare_entities(req, dbname):
    db = TamerDB(dbname)
    save_entity_comparison_feedback(req, db)
    target_similarity = req.GET['sim'] if 'sim' in req.GET \
        else None
    eid1, eid2, sim = db.get_entities_to_compare(target_similarity, req.GET['sort'] if 'sort' in req.GET else None)
    e1 = {'id': eid1, 'data': db.entity_data(eid1)}
    e2 = {'id': eid2, 'data': db.entity_data(eid2)}
    guess = 'Yes' if sim > 0.6 else 'No'
    attr = pretty_order_entity_attributes(e1, e2)
    return render(req, 'doit/compare-entities.html', {
        'attributes': attr, 'similarity': sim, 'guess': guess,
        'e1id': eid1, 'e2id': eid2, })


def save_entity_comparison_feedback(req, db):
    if not 'answer' in req.POST:
        return
    db.save_entity_comparison(
        req.POST['e1'], req.POST['e2'], req.POST['answer'])


def pretty_order_entity_attributes(e1, e2):
    attr = {}
    for name, value in e1['data'].items():
        attr[name] = {'name': name, 'value1': value}
        attr[name]['value2'] = e2['data'][name] if name in e2['data'] else ''
    for name, value in e2['data'].items():
        if name not in attr:
            attr[name] = {'name': name, 'value2': value, 'value1': ''}

    def sort_order_key(a):
        score = 0
        if a['value1'] is not None and a['value1'] != '' and a['value1'] != 'None':
            score += 1
        if a['value2'] is not None and a['value2'] != '' and a['value2'] != 'None':
            score += 1
        return score * -1
    return sorted(attr.values(), key=sort_order_key)


##
# Console components
##
def nav_items(db):
    navitems = []

    db.name = 'goby'

    # Add new data tab
    n = {'title': 'Import from PostgreSQL', 'id': 'import'}
    s = [{'content': 'Data Source', 'target': 'import-console-source'},
         {'content': 'Global Schema', 'target': 'import-console-schema'},
         {'content': 'Schema Template', 'target': 'import-console-template'},
         {'content': 'Attribute Dictionary', 'target': 'import-console-attdict'},
         {'content': 'Synonym Dictionary', 'target': 'import-console-syndict'}]
    n['subitems'] = s
    navitems.append(n)

    # Schema Map
    n = {'title': 'Map Schema', 'id': 'map-schema', 'subitems': [
        {'content': s['name'], 'target': 'source-' + str(s['id']) + '-map',
         'redirect': 'redirect'}
        for s in db.source_list(30)]}
    navitems.append(n)

    # Dedup
    n = {'title': 'De-duplicate', 'id': 'dedup', 'subitems': [
        {'content': s['name'], 'target': 'source-' + str(s['id']) + '-dedup',
         'redirect': 'redirect'}
        for s in db.source_list(30)]}
    navitems.append(n)

    # # Recent sources tab
    # n = {'title': 'Recently Added Data', 'id': 'recent-sources', 'subitems': [
    #     {'content': s['date'], 'target': 'recent-' + str(s['rank'])}
    #     for s in db.recent_sources(20)]}
    # navitems.append(n)

    # # All sources tab
    # n = {'title': 'All Data', 'id': 'all-data', 'subitems': [
    #     {'content': s['name'], 'target': 'source-' + str(s['id'])}
    #     for s in db.source_list(20)]}
    # navitems.append(n)

    # Configuration
    n = {'title': 'Configure', 'id': 'configure', 'subitems': [
        #{'content': 'Schema Mapper', 'target': 'configure-schema-mapper'},
        {'content': 'De-duplicator', 'target': 'configure-dedup'}]}
    navitems.append(n)

    # # Training
    # n = {'title': 'Training', 'id': 'training', 'subitems': [
    #     {'content': 'Schema Mapper', 'target': 'configure-schema-mapper'},
    #     {'content': 'De-duplicator', 'target': 'train-dedup'}]}
    # navitems.append(n)

    # Crowd
    n = {'title': 'Crowd Market', 'id': 'crowd', 'subitems': [
        {'content': 'Admin console', 'target': '%s/user' % settings.EXPERTSRC_URL},
        {'content': 'Imported batches', 'target': '%s/batches' % settings.EXPERTSRC_URL},
        ]}
    navitems.append(n)
    return navitems


def action_sets(db, tab, sid):
    sets = []

    # Loading actions
    a = {'header': 'Data', 'actions': [
         {'description': 'Add data', 'button': 'Add', 'disabled': 'disabled',
          'status': ''},
         {'description': 'Add meta data', 'button': 'Add', 'disabled': 'disabled',
          'status': ''}]}
    sets.append(a)

    # Schema actions
    a = {'header': 'Schema', 'actions': [
         {'description': 'Compute suggestions', 'button': 'Go', 'disabled': '',
          'status': '', 'target': 'source-' + sid + '-map'}]}
    sets.append(a)

    # De-duplication
    a = {'header': 'Entity de-duplication', 'actions': [
         {'description': 'Find duplicates within this source', 'button': 'Go', 'disabled': '',
          'status': '', 'target': 'source-' + sid + '-dedup'},
         {'description': 'Merge source with composite', 'button': 'Go', 'disabled': 'disabled',
          'status': ''}]}
    sets.append(a)
    return sets


##
# Ajax widgets
##
def widget_attr_labeller(req, dbname):
    db = TamerDB(dbname)

    tablename = req.GET['tablename'] if 'tablename' in req.GET else req.POST['tablename']
    labels = ['import as data', 'use as entity key', 'use as source key', 'do not import']

    attrs = [{'name': a, 'labels': labels}
             for a in db.table_attributes(tablename)]
    return render(req, 'tamer/widget-attribute-labeller.html', {
        'attrs': attrs})


def widget_attr_radio(req, dbname):
    db = TamerDB(dbname)
    tablename = req.GET['tablename'] if 'tablename' in req.GET else req.POST['tablename']
    n = req.GET['name'] if 'name' in req.GET else req.POST['name']
    return render(req, 'tamer/widget-attribute-radio.html', {
        'attrs': db.table_attributes(tablename), 'inputname': n})


##
# Ajax Jobs on the DB
##
def run_import(req, dbname):
    db = TamerDB(dbname)

    rclean = re.compile(r'[a-zA-Z][a-zA-Z0-9_-]*')

    def sanitize_db_constant(s):
        return rclean.match(str(s)).group() if s is not None else None

    # Clean table and attribute names
    schemaname = source_schema
    try:
        tablename = sanitize_db_constant(req.POST['tablename'])
        dataattr = [sanitize_db_constant(a)
                    for a in re.split(',', req.POST['dataattr'])]
    except:
        return HttpResponse(simplejson.dumps({'status': 'fail'}),
                            mimetype='application/json')

    try:
        eidattr = sanitize_db_constant(req.POST['eidattr'])
    except:
        eidattr = None

    try:
        sidattr = sanitize_db_constant(req.POST['sidattr'])
    except:
        sidattr = None
    #return HttpResponse(simplejson.dumps({'e': eidattr, 's': sidattr, 't': tablename, 'd': dataattr, 'n': schemaname}), mimetype='application/json')
    db.import_from_pg_table(schemaname, tablename, eidattr, sidattr, dataattr)
    return HttpResponse(simplejson.dumps({'status': 'success'}), mimetype='application/json')


def import_auxiliary(req, dbname):
    db = TamerDB(dbname)
    schema = source_schema
    #try:
    table = req.POST['tablename']
    obj = req.POST['object']
    #except:
    #    return HttpResponse(simplejson.dumps({'status': 'fail'}),
    #                        mimetype='application/json')

    att = req.POST['attribute'] if 'attribute' in req.POST else None
    column = req.POST['columnname'] if 'columnname' in req.POST else None
    columna = req.POST['columna'] if 'columna' in req.POST else None
    columnb = req.POST['columnb'] if 'columnb' in req.POST else None
    template = req.POST['templatename'] if 'templatename' in req.POST else None

    if obj == 'attdict':
        db.import_attribute_dictionary(att, schema, table, column)
    elif obj == 'syndict':
        db.import_synonym_dictionary(att, schema, table, columna, columnb)
    elif obj == 'schema':
        db.import_global_schema(schema, table, column)
    elif obj == 'template':
        db.import_attribute_template(template, schema, table, column)

    return HttpResponse(simplejson.dumps({'status': 'success'}),
                        mimetype='application/json')


def schema_map_source(req, dbname, sid):
    db = TamerDB(dbname)
    redirect_url = '%s/import/schema-map/questions' % settings.EXPERTSRC_URL
    thresh_incr_num = map(lambda x: (x + 1) / 10.0, reversed(range(20)))
    greens = map(lambda x: f2c(x / 1.0), thresh_incr_num)
    reds = map(lambda x: f2c(1.0 - x / 2.0), thresh_incr_num)
    thresh_incr = []
    for x in range(len(thresh_incr_num)):
        point = {}
        point['val'] = thresh_incr_num[x]
        point['green'] = greens[x]
        point['red'] = reds[x]
        thresh_incr.append(point)
    c = {'redirect_url': redirect_url,
        'source_id': db.sourcename(sid),
        'dbname': dbname,
        'sid': sid,
        'navitems': nav_items(db),
        'source_name': 'test_source',
        'threshhold_increments': thresh_incr, }
    return render(req, 'tamer/schema-map-console.html', c)


def schema_map_source_run(req, dbname, sid):
    db = TamerDB(dbname)
    db.rebuild_schema_mapping_models()
    db.schema_map_source(sid)
    field_mappings = db.get_field_mappings_by_source(sid)
    attr_list = sorted(field_mappings.values(), key=lambda f: f['match']['score'], reverse=True)
    return render(req, 'tamer/match-rows.html', {'attr_list': attr_list})


def schema_map_source_schedule(req, dbname, sid):
    db = TamerDB(dbname)
    thresh = req.POST['thresh']
    db.answer_with_thresh(sid, float(thresh))
    db.register_schema_map(sid)
    return HttpResponse(simplejson.dumps({'status': 'success'}),
                        mimetype='application/json')


def dedup_source(req, dbname, sid):
    db = TamerDB(dbname)
    # db.dedup_source(sid)
    c = {
        'source_id': db.sourcename(sid),
        'dbname': dbname,
        'source_id': sid,
        'navitems': nav_items(db), }
    return render(req, 'tamer/dedup-console.html', c)


def dedup_source_clusters(req, dbname, sid):
    db = TamerDB(dbname)
    data = db.get_cluster_data(sid)
    return HttpResponse(simplejson.dumps(data),
                        mimetype='application/json')

