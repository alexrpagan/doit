import random
from doit.util import bucketize
from doit.dataaccess import DoitDB
from operator import itemgetter
from django.shortcuts import render_to_response, render
from django.http import HttpResponse
from django.utils import simplejson
from django.template import RequestContext
import settings


def source_index(req, dbname):
    db = DoitDB(dbname)
    return render(req, 'doit/source_index.html', {
                       'source_list': db.sources(), 'dbname': dbname, })


def source_processor(req, dbname, sid, method_index):
    db = DoitDB(dbname)
    method_name = db.process_source(sid, method_index)
    r = {'method': method_name, 'source': sid,
             'redirect': '/doit/' + dbname + '/' + sid + '/'}
    return HttpResponse(simplejson.dumps(r), mimetype='application/json')


def mapper(req, sid, dbname):
    db = DoitDB(dbname)
    meta = dict()
    meta['data'] = db.source_meta(sid)
    meta['category'] = 'Source %s' % sid
    field_mappings = db.field_mappings_by_source2(sid)
    egs = db.examplevalues(sid)
    for fid in field_mappings:
        egs.setdefault(int(fid), None)
        field_mappings[fid]['example'] = egs[int(fid)]
    attr_list = sorted(field_mappings.values(), key=lambda f: f['match']['score'])
    return render(req, 'doit/mapper.html', {
                       'attr_list': attr_list, 'source_id': sid, 'meta': meta, })


def mapper_by_field_name(req, dbname, field_name, comp_op):
    db = DoitDB(dbname)
    meta = {'category': 'Fields named "%s"' % field_name}
    field_mappings = db.field_mappings_by_name(field_name,
                                               exact_match=(comp_op != 'like'))
#    egs = db.examplevalues(sid)
#    for fid in field_mappings:
#        egs.setdefault(int(fid), None)
#        field_mappings[fid]['example'] = egs[int(fid)]
    return render(req, 'doit/mapper.html', {
        'attr_list': field_mappings.values(), 'field_name': field_name,
        'meta': meta, })


def auth_user(answerer_id, fields):
    """
    TODO:
    Use the user's expertsrc session key, answerer_id, and current id selection
    to make sure that they're answering the questions they should be.

    If not, redirect them to wherever they are supposed to be.
    """
    return True


def mapper_by_field_set(req, dbname):
    db = DoitDB(dbname)
    answerer_id = req.GET.get('answerer_id', False)
    fields = req.GET.get('fields', False)
    domain_id = req.GET.get('domain_id', False)
    assert all((fields, answerer_id, domain_id, auth_user(answerer_id, fields),))
    # hack to make sure that ids are really ints
    # this should raise an integer parse error if the ids are
    # tampered with.
    field_ids = map(int, fields.split(','))
    field_mappings = db.field_mappings_by_id_list(field_ids=field_ids, answerer_id=answerer_id)
    attr_list = sorted(field_mappings.values(), key=lambda f: f['match']['score'], reverse=True)
    source_name = ''
    if len(attr_list) > 0:
        # we assume that all mappings are from same source
        source_name = attr_list[0]['source_name']
    c = {'source_name': source_name,
         'attr_list': attr_list,
         'expertsrc': True,
         'expertsrc_url': settings.EXPERTSRC_URL,
         'answerer_id': answerer_id,
         'domain_id': domain_id}
    return render(req, 'doit/expertsrc-mapper.html', c, context_instance=RequestContext(req))


def source_meta(req, dbname, sid):
    db = DoitDB(dbname)
    meta = dict()
    meta['data'] = db.source_meta(sid)
    meta['category'] = 'Source %s' % sid
    return render(req, 'doit/source_meta.html', {'meta': meta})


def viewTable_template(req):
    return render(req, 'doit/viewTable_template.html')


def source_data(req, dbname, sid):
    db = DoitDB(dbname)
    data = {'fields': db.source_fields(sid),
            'entities': db.source_entities(sid, 10)}
    return HttpResponse(simplejson.dumps(data),
                        mimetype='application/json')


def source_table(req, dbname, sid):
    db = DoitDB(dbname)
    fields = db.source_fields(sid)
    entities = db.source_entities(sid, 10)
    for entity in entities:
        vals = []
        for field in fields:
            try:
                vals.append(entity['fields'][field['id']])
            except KeyError:
                vals.append('')
            if vals[-1] is None:
                vals[-1] = ''
        entity['fields'] = vals
    return render(req, 'doit/viewTable_template.html', {
                'fields': fields, 'entities': entities})


def source_entities(req, dbname, sid):
    db = DoitDB(dbname)
    data = {'entities': db.source_entities(sid, 10)}
    return HttpResponse(simplejson.dumps(data),
                        mimetype='application/json')


def field_candidates(req, fid, dbname):
    db = DoitDB(dbname)
    return render(req, 'doit/candidate_list.html', {
        'fid': fid, 'candidates': db.field_candidates(fid)})


# Handles new mapping POST
def mapper_results(req, dbname):
    db = DoitDB(dbname)
    mappings = simplejson.loads(req.POST['mappings'])
    rejects = simplejson.loads(req.POST['rejects'])
    answerer_id = int(req.POST['answerer_id'])
    s = db.create_mappings(mappings, answerer_id=answerer_id)
    t = db.create_mappings(rejects, anti=True, answerer_id=answerer_id)
    return HttpResponse(s)


def suggest_new_attribute_form(req, dbname):
    return render(req, 'doit/suggest_new_attribute_form.html', {
        'fid': req.GET['fid'], 'fname': req.GET['fname'], 'dbname': dbname})


def suggest_new_attribute(req, dbname):
    db = DoitDB(dbname)
    field_id = req.POST['fid']
    suggestion = req.POST['suggestion']
    username = req.POST['user']
    comment = req.POST['comment']
    success = db.new_attribute(field_id, suggestion, username, comment)
    return HttpResponse(simplejson.dumps({'success': success}),
                        mimetype='application/json')


# currently broken...
def lowscoremapper(req, dbname):
    db = DoitDB(dbname)
    matchscores = db.lowscorers(25)
    attr_list = []
    for name in matchscores:
        cand = sorted(matchscores[name],
                              key=itemgetter(2), reverse=True)
        attr_list.append({'name': name, 'candidates': cand})
    return render(req, 'doit/mapper.html', {'attr_list': attr_list})


def detail_summary(req, dbname, fid):
    db = DoitDB(dbname)
    attr_name = db.fieldname(fid)
    source_name = db.fieldsource(fid)
    meta = db.field_meta(fid)
    vals = db.fieldexamples(fid, 1000, distinct=False)
    histo = bucketize(vals)
    return render(req, 'doit/pop_summary.html', {
            'histo': histo, 'attr_name': attr_name, 'source': source_name, 'fid': fid,
            'metadata': meta, 'db': dbname, })


def detail_examples(req, dbname, fid):
    db = DoitDB(dbname)
    attr_name = db.fieldname(fid)
    egs = [{'name': attr_name, 'values': db.fieldexamples(fid, 10)}]
    matches = db.field_candidates(fid)[:5]
    for match in matches:
        egs.append({'name': match['name'],
                            'values': db.globalfieldexamples(match['id'], 10)})
    transpose = [[]]
    for eg in egs:
        transpose[0].append(eg['name'])
    for i in range(0, 10):
        transpose.append([])
        for eg in egs:
            try:
                transpose[i + 1].append(eg['values'][i])
            except IndexError:
                transpose[i + 1].append(' ')
    return render(req, 'doit/pop_egs.html', {
            'examples': transpose, 'attr_name': attr_name, 'fid': fid,
            'db': dbname})


def detail_shared(req, dbname, fid):
    db = DoitDB(dbname)
    attr_name = db.fieldname(fid)
    shared = []
    matches = db.field_candidates(fid)
    shared_value = False
    for match in matches[:4]:
        shared.append({'name': match['name'],
                           'values': db.sharedvalues(fid, match['id'])})
    table = [[]]
    for match in shared:
        table[0].append(match['name'])
    for i in range(0, 10):
        table.append([])
        for match in shared:
            try:
                table[i + 1].append(match['values'][i])
                if match['values'][i] is not None:
                        shared_value = True
            except IndexError:
                table[i + 1].append(' ')
    return render(req, 'doit/pop_shared.html', {
            'shared': table, 'attr_name': attr_name, 'fid': fid,
            'db': dbname, 'at_least_one': shared_value, })


def detail_distro(req,  dbname, fid):
    db = DoitDB(dbname)
    attr_name = db.fieldname(fid)
    vals = db.fieldexamples(fid, 1000, distinct=False)
    histos = [bucketize(vals)]
    histos[0]['name'] = attr_name
    matches = db.field_candidates(fid)[:4]
    for match in matches:
        histo = bucketize(db.globalfieldexamples(int(match['id']), n=1000, distinct=False))
        histo['name'] = match['name']
        histos.append(histo)
    return render(req, 'doit/pop_distro.html', {
            'histos': histos, 'attr_name': attr_name, 'fid': fid,
            'db': dbname, })


def detail_scoring(req, dbname, fid):
    db = DoitDB(dbname)
    attr_name = db.fieldname(fid)
    matches = db.indivscores(fid)
    return render(req, 'doit/pop_scores.html', {
            'matches': matches, 'attr_name': attr_name, 'fid': fid,
            'db': dbname, })


def compare_entities(req, dbname):
    db = DoitDB(dbname)
    save_entity_comparison_feedback(req, db)
    target_similarity = req.GET['sim'] if 'sim' in req.GET \
        else '0.' + str(random.randint(0, 9))
    eid1, eid2, sim = db.get_entities_to_compare(target_similarity)
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
