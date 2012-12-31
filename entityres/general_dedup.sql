

/*
create or replace function tokenize_besk (text) returns setof text as
$$
begin
  return query
     select token from ts_parse('default', $1)
	 where tokid != 12 and length(token) < 2048;
end;
$$ language plpgsql;
*/

-- delete all qgrams with TF.IDF < returned
CREATE OR REPLACE FUNCTION cutoff(arr double precision ARRAY,threshold double precision) RETURNS double precision AS
$$
DECLARE
weight_sum double precision default 0;
BEGIN
FOR i in 1..array_length(arr,1) LOOP
	weight_sum := weight_sum + arr[i];
	IF (weight_sum >= threshold) THEN
			RETURN arr[i];
	END IF;
END LOOP;
RETURN arr[array_length(arr,1)];
END;
$$ language plpgsql IMMUTABLE STRICT;

DROP TABLE IF EXISTS data_from_new_source CASCADE;
CREATE TABLE data_from_new_source (category_id integer, entity_id integer, tag_id integer, value text);
--CREATE INDEX data_from_new_source__tag_id ON data_from_new_source(tag_id);
--CREATE INDEX data_from_new_source__entity_id_tag_id ON data_from_new_source(entity_id,tag_id);

DROP TABLE IF EXISTS data_from_new_source_qgrams CASCADE;
CREATE TABLE data_from_new_source_qgrams(category_id integer, entity_id integer, tag_id integer, qgram text, freq double precision);
CREATE INDEX data_from_new_source_qgrams__qgram_tag_id_category_id ON data_from_new_source_qgrams(qgram,tag_id, category_id);
--CREATE INDEX data_from_new_source_qgrams__tag_id_category_id_cluster_id_entity_id ON data_from_new_source_qgrams(tag_id, category_id, entity_id, cluster_id);

DROP TABLE IF EXISTS data_from_new_source_qgrams_tmp CASCADE;
CREATE TABLE data_from_new_source_qgrams_tmp(category_id integer, entity_id integer, tag_id integer, qgram text, freq double precision);


DROP TABLE IF EXISTS data_from_new_source_real CASCADE;
CREATE TABLE data_from_new_source_real (category_id integer, entity_id integer, tag_id integer, value double precision);
--CREATE INDEX data_from_new_source_real__category_id_tag_id ON data_from_new_source_real(category_id, tag_id);
--CREATE INDEX data_from_new_source_real__entity_id_tag_id ON data_from_new_source_real(entity_id,tag_id);
CREATE INDEX data_from_new_source_real__value_tag_id ON data_from_new_source_real(value, tag_id);
--CREATE INDEX data_from_new_source_real__cluster_id ON data_from_new_source_real(cluster_id);


DROP TABLE IF EXISTS inserted_data CASCADE;
CREATE TABLE inserted_data(category_id integer, entity_id integer, tag_id integer, value text);
--CREATE INDEX inserted_data__category_id_tag_id ON inserted_data(category_id, tag_id);
--CREATE INDEX inserted_data__entity_id_tag_id ON inserted_data(entity_id, tag_id);
--CREATE INDEX inserted_data__cluster_id ON inserted_data(cluster_id);

DROP TABLE IF EXISTS inserted_data_qgrams_candidates CASCADE;
CREATE TABLE inserted_data_qgrams_candidates (category_id integer, entity_id integer, tag_id integer, qgram text, freq double precision);
CREATE INDEX inserted_data_qgrams_candidates__qgram_tag_id_category_id ON inserted_data_qgrams_candidates(qgram, tag_id, category_id);

DROP TABLE IF EXISTS inserted_data_qgrams CASCADE;
CREATE TABLE inserted_data_qgrams (category_id integer, entity_id integer, tag_id integer, qgram text, freq double precision);
CREATE INDEX inserted_data_qgrams__qgram_tag_id_category_id ON inserted_data_qgrams(qgram, tag_id, category_id);

DROP TABLE IF EXISTS inserted_data_real CASCADE;
CREATE TABLE inserted_data_real(category_id integer, entity_id integer, tag_id integer, value double precision);
--CREATE INDEX inserted_data_real__category_id_tag_id ON inserted_data_real(category_id, tag_id);
--CREATE INDEX inserted_data_real__entity_id_tag_id ON inserted_data_real(entity_id, tag_id);
CREATE INDEX inserted_data_real__value_tag_id ON inserted_data_real(value, tag_id);
--CREATE INDEX inserted_data_real__cluster_id ON inserted_data_real(cluster_id);


DROP TABLE IF EXISTS similarity_self_join_qrams CASCADE;
CREATE TABLE similarity_self_join_qrams (entity1_id integer, entity2_id integer, tag_id integer, cos_sim double precision);


DROP TABLE IF EXISTS similarity_self_join_result_cat CASCADE;
CREATE TABLE similarity_self_join_result_cat(category_id int, entity1_id integer, entity2_id integer, prob_s_m double precision, prob_s_u double precision);

DROP TABLE IF EXISTS similarity_self_join_result CASCADE;
CREATE TABLE similarity_self_join_result(entity1_id integer, entity2_id integer, m_prob double precision);
CREATE INDEX similarity_self_join_result__entity1_id ON similarity_self_join_result(entity1_id);
CREATE INDEX similarity_self_join_result__entity2_id ON similarity_self_join_result(entity2_id);

DROP TABLE IF EXISTS candidate_pairs CASCADE;
CREATE TABLE candidate_pairs (category_id int, entity1_id integer, entity2_id integer);


DROP TABLE IF EXISTS candidate_attributes CASCADE;
CREATE TABLE candidate_attributes(category_id int, entity1_id integer, entity2_id integer, tag_id integer, similarity double precision);
--CREATE INDEX candidate_attributes__entity1_id ON candidate_attributes(entity1_id);
--CREATE INDEX candidate_attributes__entity2_id ON candidate_attributes(entity2_id);
CREATE INDEX candidate_attributes__entity1_id_entity2_id_tag_id ON candidate_attributes(entity1_id, entity2_id, tag_id);

DROP TABLE IF EXISTS  candidate_attributes_text_qgram CASCADE;
CREATE TABLE candidate_attributes_text_qgram(category_id int, entity1_id integer, entity2_id integer, tag_id integer, sim double precision);
--CREATE INDEX candidate_attributes_text_qgram__entity1_id_entity2_id_tag_id ON candidate_attributes_text_qgram(entity1_id, entity2_id, tag_id);


DROP TABLE IF EXISTS candidate_pairs_2way CASCADE;
CREATE TABLE candidate_pairs_2way (category_id int, entity1_id integer, entity2_id integer);

DROP TABLE IF EXISTS candidate_attributes_2way CASCADE;
CREATE TABLE candidate_attributes_2way(category_id int, entity1_id integer, entity2_id integer, tag_id integer, similarity double precision);
--CREATE INDEX candidate_attributes__entity1_id ON candidate_attributes(entity1_id);
--CREATE INDEX candidate_attributes__entity2_id ON candidate_attributes(entity2_id);
CREATE INDEX candidate_attributes_2way__entity1_id_entity2_id_tag_id ON candidate_attributes_2way(category_id, entity1_id, entity2_id, tag_id);

DROP TABLE IF EXISTS  candidate_attributes_text_qgram_2way CASCADE;
CREATE TABLE candidate_attributes_text_qgram_2way(category_id int, entity1_id integer,  entity2_id integer, tag_id integer, sim double precision);
--CREATE INDEX candidate_attributes_text_qgram__entity1_id_entity2_id_tag_id ON candidate_attributes_text_qgram(entity1_id, entity2_id, tag_id);


DROP TABLE IF EXISTS tag_frequency CASCADE;
CREATE TABLE tag_frequency(category_id int, tag_id integer, tuples_count integer);
--CREATE INDEX tag_frequency__tag_id_category_id ON tag_frequency(category_id, tag_id);

DROP TABLE IF EXISTS gen_qgrams_idf CASCADE;
CREATE TABLE gen_qgrams_idf(category_id int, tag_id integer, qgram text, doc_count integer);
CREATE INDEX gen_qgrams_idf__tag_id_qgram ON gen_qgrams_idf(category_id, tag_id, qgram);

DROP TABLE IF EXISTS similarity_2way_join_result_cat CASCADE;
CREATE TABLE similarity_2way_join_result_cat(category_id int, entity1_id integer, entity2_id integer, prob_s_m double precision, prob_s_u double precision);

DROP TABLE IF EXISTS similarity_2way_join_result CASCADE;
CREATE TABLE similarity_2way_join_result(entity1_id integer, entity2_id integer, m_prob double precision);
--CREATE INDEX similarity_2way_join_result__entity1_id ON similarity_self_join_result(entity1_id);
--CREATE INDEX similarity_2way_join_result__entity2_id ON similarity_self_join_result(entity2_id);




DROP TABLE IF EXISTS sim_pairs CASCADE;
CREATE TABLE sim_pairs(entity1_id int, entity2_id int, prob_m double precision);

DROP TABLE IF EXISTS edges CASCADE;
CREATE TABLE edges(entity1_id int, entity2_id int);
CREATE INDEX edges__entity1_id ON edges(entity1_id);
CREATE INDEX edges__entity2_id ON edges(entity2_id);

DROP SEQUENCE IF EXISTS cluster_id_seq CASCADE;
CREATE SEQUENCE cluster_id_seq;

DROP TABLE IF EXISTS entity_clustering CASCADE;
CREATE TABLE entity_clustering(entity_id int, cluster_id int);
CREATE INDEX ON entity_clustering(cluster_id);

/*
DROP TABLE IF EXISTS entity_cluster_mapping CASCADE;
CREATE TABLE entity_cluster_mapping(entity_id int, cluster_id int default nextval('cluster_id_seq'), clustering_id int);
CREATE INDEX entity_cluster_mapping__cluster_id ON entity_cluster_mapping(cluster_id);
CREATE INDEX entity_cluster_mapping__entity_id ON entity_cluster_mapping(entity_id);
*/

--DROP TABLE IF EXISTS cluster_clustering_mapping CASCADE;
--CREATE TABLE cluster_clustering_mapping(cluster_id int, clustering_id int);

DROP VIEW IF EXISTS cluster_size CASCADE;
CREATE VIEW cluster_size AS
SELECT cluster_id, count(*) as size
FROM entity_clustering
GROUP BY cluster_id;

DROP VIEW IF EXISTS relevant_qgrams_idf CASCADE;
CREATE VIEW relevant_qgrams_idf AS
select distinct q.category_id, q.tag_id, q.qgram, log(t.tuples_count::double precision / q.doc_count) as idf
FROM gen_qgrams_idf q , (select distinct category_id, tag_id, qgram from data_from_new_source_qgrams) d,  tag_frequency t
WHERE d.tag_id=q.tag_id AND d.qgram=q.qgram AND d.category_id = q.category_id AND t.tag_id=q.tag_id AND t.category_id = q.category_id;


DROP TABLE IF EXISTS dedup_running_time;
CREATE TABLE dedup_running_time(i int, source_id int, runningtime_sec real);

CREATE VIEW not_freq_qgrams
AS SELECT q.category_id, q.tag_id, qgram
FROM gen_qgrams_idf q, tag_frequency t
WHERE q.tag_id = t.tag_id AND q.category_id=t.category_id AND  q.doc_count::double precision/t.tuples_count < 0.1;

CREATE VIEW freq_qgrams
AS SELECT q.category_id, q.tag_id, qgram
FROM gen_qgrams_idf q, tag_frequency t
WHERE q.tag_id = t.tag_id AND q.category_id=t.category_id AND  q.doc_count::double precision/t.tuples_count >= 0.1;

DROP TABLE IF EXISTS new_entities CASCADE;
CREATE TABLE new_entities (entity_id int);

DROP TABLE IF EXISTS new_edges CASCADE;
CREATE TABLE new_edges (entity1_id int, entity2_id int);

DROP TABLE IF EXISTS removed_entities CASCADE;
CREATE TABLE removed_entities (entity_id int);

DROP TABLE IF EXISTS removed_edges CASCADE;
CREATE TABLE removed_edges (entity1_id int, entity2_id int);

DROP TABLE IF EXISTS clusters_to_merge_tmp CASCADE;
CREATE TABLE clusters_to_merge_tmp(cid1 int, cid2 int);

DROP TABLE IF EXISTS clusters_to_merge CASCADE;
CREATE TABLE clusters_to_merge(cid1 int, cid2 int);

CREATE OR REPLACE FUNCTION _final_random(anyarray)
 RETURNS anyelement AS
$BODY$
 SELECT $1[array_lower($1,1) + floor((1 + array_upper($1, 1) - array_lower($1, 1))*random())];
$BODY$
LANGUAGE 'sql' IMMUTABLE;

CREATE AGGREGATE random(anyelement) (
  SFUNC=array_append, --Function to call for each row. Just builds the array
  STYPE=anyarray,
  FINALFUNC=_final_random, --Function to call after everything has been added to array
  INITCOND='{}' --Initialize an empty array when starting
);


----------------- function definitions--------------------------

-- add a new source. The paramter is the source_id
CREATE OR REPLACE FUNCTION add_all_sources() RETURNS void AS
$$
DECLARE
 sid int;
 sources_count int;
 StartTime timestamptz;
EndTime timestamptz;
Delta real;
i int;
BEGIN

sources_count:= (select count(*) from local_sources);
i := 1;

truncate inserted_data;
truncate inserted_data_real;
truncate inserted_data_qgrams;
truncate dedup_running_time;
truncate entity_clustering;
truncate sim_pairs;

perform bootstrap_qgrams_idf();
RAISE INFO 'bootstraping qgrams idf done';


for sid in select id from local_sources LOOP
	RAISE INFO 'Strating source % (% of %) done. Duration in secs=%', sid, i , sources_count, Delta;

	StartTime := clock_timestamp();
	perform get_candidates(sid);
	perform sim_join(sid);
	perform incr_clusterings();
	EndTime := clock_timestamp();
	Delta := ( extract(epoch from EndTime) - extract(epoch from StartTime));
	RAISE INFO 'Source % (% of %) done. Duration in secs=%', sid, i , sources_count, Delta;
	INSERT INTO dedup_running_time values(i, sid, delta);
	i := i+1;

END LOOP;

END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_source(sid int) RETURNS void AS
$$
DECLARE

BEGIN
	if (not exists (select * from entity_clustering)) THEN
		truncate inserted_data;
		truncate inserted_data_qgrams;
		truncate inserted_data_qgrams_candidates;
		truncate edges;
		truncate sim_pairs;
		perform bootstrap_qgrams_idf();
		RAISE INFO 'cleared previous dedup data';

	END IF;
	perform get_candidates(sid);
	perform sim_join(sid);
	perform incr_clusterings();
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION bootstrap_qgrams_idf() RETURNS void AS
$$
DECLARE
cat_id int;
i int;
cat_count int;
BEGIN
TRUNCATE data_from_new_source;
TRUNCATE data_from_new_source_qgrams;
TRUNCATE tag_frequency;
TRUNCATE gen_qgrams_idf;

--i := 1;
--SELECT INTO cat_count count(distinct category_id) from cat_features_tf;

FOR cat_id in (select distinct category_id from cat_features_tf) LOOP
INSERT INTO data_from_new_source (category_id, entity_id, tag_id, value)
       SELECT cat_id, d.entity_id, m.global_id, value
         FROM local_data d, attribute_mappings m
     where d.field_id = m.local_id AND d.entity_id in (select entity_id from entity_cat_mapping where category_id = cat_id order by random() limit 50000);


	 --RAISE INFO 'added category % of %',i, cat_count;
	 --i := i+1;
END LOOP;

RAISE INFO 'Inserted data sample. Timestamp : %', (select timeofday()) ;

INSERT INTO tag_frequency
SELECT category_id, tag_id, count(distinct entity_id) AS tuples_count
FROM data_from_new_source
GROUP BY category_id, tag_id;


INSERT INTO data_from_new_source_qgrams(category_id, entity_id, tag_id, qgram, freq)
SELECT category_id, entity_id, d.tag_id, tokenize_besk(value) as qgram, count(*) as freq
FROM data_from_new_source d, global_attributes f
WHERE d.tag_id = f.id AND f.type = 'TEXT'
GROUP BY category_id, entity_id, d.tag_id, qgram;

RAISE INFO 'Constructed all q-grams for the sample data. Timestamp : %', (select timeofday()) ;


INSERT INTO gen_qgrams_idf
SELECT category_id, tag_id, qgram , count(distinct entity_id) as doc_count
FROM data_from_new_source_qgrams
GROUP BY category_id,tag_id, qgram;

TRUNCATE data_from_new_source;

RAISE INFO 'Built q-grams IDFs. Timestamp : %', (select timeofday()) ;

END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_global_attr_types() RETURNS void AS
$$
DECLARE
attr RECORD;
BEGIN

DROP TABLE IF EXISTS value_sample;
CREATE TEMP TABLE value_sample(value text);

FOR attr in select * from global_attributes LOOP

TRUNCATE value_sample;

INSERT INTO value_sample
SELECT d.value
FROM local_data d, attribute_mappings m
WHERE d.value is not NULL AND m.local_id = d.field_id AND m.global_id = attr.id
LIMIT 100000;

IF (select count(value) from value_sample) > 0 and (select count(to_num(value)) from value_sample)::real / (select count(value) from value_sample) > 0.9 THEN
UPDATE global_attributes SET type = 'REAL'
WHERE id = attr.id;
END IF;

END LOOP;
DROP TABLE value_sample;

END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION extract_new_data(new_source_id integer,cat_id integer, sample_size integer) RETURNS void AS
$$
DECLARE
  c integer;
  entity_count int;
BEGIN

-- extract all entities an their attributes that belong to the passes source_id
	TRUNCATE data_from_new_source;

IF (cat_id = 0 AND new_source_id > 0 AND sample_size <= 0) THEN
	INSERT INTO data_from_new_source (category_id, entity_id, tag_id, value)
       SELECT e.category_id, e.entity_id, f.global_id, array_to_string(array_agg(value), ' , ')
         FROM local_entities t, local_data d, attribute_mappings f, entity_cat_mapping e
     where t.source_id=new_source_id AND t.id=d.entity_id AND d.field_id = f.local_id AND e.entity_id = d.entity_id
     GROUP BY e.category_id, e.entity_id, f.global_id;

ELSIF (new_source_id = 0 AND cat_id > 0 AND sample_size <= 0) THEN
	INSERT INTO data_from_new_source (category_id, entity_id, tag_id, value)
       SELECT cat_id, entity_id, global_id, string_agg(value,', ')
         FROM local_data d, attribute_mappings f
     where d.entity_id in (select entity_id from entity_cat_mapping where category_id = cat_id)
	 AND d.field_id = f.local_id
     GROUP BY entity_id, global_id;

ELSIF (new_source_id = 0 AND cat_id > 0 AND sample_size > 0) THEN
	INSERT INTO data_from_new_source (category_id, entity_id, tag_id, value)
       SELECT cat_id, entity_id, global_id, string_agg(value,', ')
         FROM local_data d, attribute_mappings f
     where d.entity_id in (select entity_id from entity_cat_mapping where category_id = cat_id order by random() limit sample_size)
	 AND d.field_id = f.local_id
     GROUP BY entity_id, global_id;

ELSIF (new_source_id > 0 AND cat_id > 0 AND sample_size <= 0) THEN

INSERT INTO data_from_new_source (category_id, entity_id, tag_id, value)
       SELECT cat_id, entity_id, global_id, string_agg(value,', ')
         FROM local_entities t, local_data d, attribute_mappings f
     where t.id in (select entity_id from entity_cat_mapping where category_id = cat_id)
	 AND t.source_id=new_source_id AND t.id=d.entity_id AND d.field_id = f.local_id
     GROUP BY entity_id, global_id;

ELSIF (new_source_id > 0 AND cat_id > 0 AND sample_size > 0) THEN

	 INSERT INTO data_from_new_source (category_id, entity_id, tag_id, value)
       SELECT cat_id, entity_id, global_id, string_agg(value,', ')
         FROM local_entities t, local_data d, attribute_mappings f
     where t.id in (select entity_id from entity_cat_mapping where category_id = cat_id order by random() limit sample_size)
	 AND t.source_id=new_source_id AND t.id=d.entity_id AND d.field_id = f.local_id
     GROUP BY entity_id, global_id;

ELSIF (new_source_id = 0 AND cat_id = 0 AND sample_size > 0) THEN
	INSERT INTO data_from_new_source (category_id, entity_id, tag_id, value)
       SELECT null, entity_id, global_id, string_agg(value,', ')
         FROM local_data d, attribute_mappings f
     where d.entity_id in (select entity_id from local_entity order by random() limit sample_size)
	 AND d.field_id = f.local_id
     GROUP BY entity_id, global_id;

END IF;

/*
INSERT INTO data_from_new_source (entity_id, cluster_id, tag_id, value)
       SELECT  entity_id, entity_id, m.global_id , array_to_string(array_agg(value), ' , ')
         FROM local_entities e, local_data d, attribute_mappings m
     where e.source_id=new_source_id AND d.entity_id=e.id AND m.local_id = d.field_id
     GROUP BY entity_id, entity_id, m.global_id;
*/

RAISE INFO 'data_from_new_source has the data now. Timestamp : %', (select timeofday()) ;

-- update frequency table and remove any value that occur in more than 5% of tuples

UPDATE tag_frequency t1
SET tuples_count = t1.tuples_count + t2.tuples_count
FROM (SELECT category_id, tag_id, count(distinct entity_id) AS tuples_count
	FROM data_from_new_source
	GROUP BY tag_id, category_id) t2
WHERE t1.tag_id = t2.tag_id and t1.category_id = t2.category_id;

INSERT INTO tag_frequency
SELECT category_id, tag_id, count(distinct entity_id) AS tuples_count
	FROM data_from_new_source
WHERE (category_id, tag_id) NOT IN (SELECT category_id,tag_id FROM tag_frequency)
GROUP BY category_id, tag_id;

RAISE INFO 'Updated tag frequncies. Timestamp : %', (select timeofday()) ;

-- populate q-grams
TRUNCATE data_from_new_source_qgrams;
INSERT INTO data_from_new_source_qgrams(category_id, entity_id, tag_id, qgram, freq)
SELECT category_id, entity_id, d.tag_id, tokenize_besk(value) as qgram, count(*) as freq
FROM data_from_new_source d, global_attributes f
WHERE d.tag_id = f.id AND f.type = 'TEXT'
GROUP BY category_id, entity_id, d.tag_id, qgram;

RAISE INFO 'Constructed all q-grams for the new data. Timestamp : %', (select timeofday()) ;

DROP TABLE IF EXISTS new_source_qgrams;
CREATE TEMP TABLE new_source_qgrams AS
SELECT category_id, tag_id, qgram , count(distinct entity_id) as doc_count FROM data_from_new_source_qgrams group by category_id, tag_id, qgram;

UPDATE gen_qgrams_idf a
SET doc_count = a.doc_count + b.doc_count
FROM new_source_qgrams b
WHERE a.tag_id= b.tag_id AND a.qgram = b.qgram AND a.category_id = b.category_id;

INSERT INTO gen_qgrams_idf (category_id, tag_id, qgram, doc_count)
SELECT a.category_id, a.tag_id, a.qgram, doc_count
FROM new_source_qgrams a,
((SELECT category_id, tag_id, qgram FROM new_source_qgrams) except all (SELECT category_id, tag_id, qgram FROM gen_qgrams_idf)) b
where a.category_id = b.category_id AND a.tag_id = b.tag_id and a.qgram= b.qgram;


DROP TABLE new_source_qgrams;


RAISE INFO 'Updated q-grams IDFs. Timestamp : %', (select timeofday()) ;


--truncate frequent, non-distinctive q-grams that occur in more than 20% of the tuples
DELETE FROM data_from_new_source_qgrams
WHERE (category_id, tag_id, qgram) IN (
SELECT q.category_id, q.tag_id, qgram
FROM gen_qgrams_idf q, tag_frequency t
WHERE q.tag_id = t.tag_id AND q.category_id=t.category_id AND  q.doc_count::double precision/t.tuples_count > 0.2);

RAISE INFO 'Truncated frequent, non-distinctive q-grams that occur in more than 20 percent of the tuples.  Timestamp : %', (select timeofday()) ;

/*
entity_count:= (select count(distinct entity_id) from data_from_new_source);

DELETE FROM data_from_new_source_qgrams
WHERE (category_id, tag_id, qgram) IN
(SELECT d.category_id, tag_id, qgram
FROM data_from_new_source_qgrams d, est_dup_prob e
WHERE d.category_id = e.category_id
group by d.category_id, tag_id, qgram, e.dup_prob
HAVING count(*) > sqrt(e.dup_prob) * 100 * entity_count);
*/

-- update the freq of qgrams by multiplying by the idf
TRUNCATE data_from_new_source_qgrams_tmp;
INSERT INTO data_from_new_source_qgrams_tmp
select b.category_id, b.entity_id, b.tag_id, b.qgram , b.freq * a.idf as freq from relevant_qgrams_idf a , data_from_new_source_qgrams b where  a.category_id = b.category_id AND a.tag_id = b.tag_id and a.qgram=b.qgram;

TRUNCATE data_from_new_source_qgrams;
INSERT INTO data_from_new_source_qgrams select * from data_from_new_source_qgrams_tmp;

TRUNCATE data_from_new_source_qgrams_tmp;

RAISE INFO 'updated the freq of qgrams by multiplying by the idf.  Timestamp : %', (select timeofday()) ;


--update the norm
UPDATE data_from_new_source_qgrams d
SET freq = freq / norm
FROM
(SELECT category_id, entity_id, tag_id, |/sum(freq*freq) as norm
	FROM data_from_new_source_qgrams
	GROUP BY category_id, entity_id, tag_id
) agg
WHERE agg.category_id = d.category_id AND agg.entity_id = d.entity_id AND agg.tag_id = d.tag_id;

RAISE INFO 'updated the norms of values.  Timestamp : %', (select timeofday());

TRUNCATE data_from_new_source_real;
INSERT INTO data_from_new_source_real(category_id, entity_id, tag_id, value)
SELECT category_id, entity_id, d.tag_id, to_num(value)
FROM data_from_new_source d, global_attributes f
WHERE d.tag_id = f.id AND f.type='REAL' AND to_num(value) is not null;


END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION remove_source(new_source_id int) RETURNS void AS
$$
DECLARE
  entity_count int;
BEGIN

DELETE FROM inserted_data_qgrams_candidates i
USING entity_cat_mapping e
where e.entity_id = i.entity_id
and e.source_id = new_source_id;

DELETE FROM inserted_data_real i
USING entity_cat_mapping e
where e.entity_id = i.entity_id
and e.source_id = new_source_id;

DELETE FROM sim_pairs
USING entity_cat_mapping e
where entity1_id = entity_id
and source_id = new_source_id;

DELETE FROM sim_pairs
USING entity_cat_mapping e
where entity2_id = entity_id
and source_id = new_source_id;

DELETE FROM edges
USING entity_cat_mapping
where entity1_id = entity_id
and source_id = new_source_id;

DELETE FROM edges
USING entity_cat_mapping
where entity2_id = entity_id
and source_id = new_source_id;

DELETE FROM entity_clustering c
USING entity_cat_mapping e
where e.entity_id = c.entity_id
and e.source_id = new_source_id;


END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_candidates(new_source_id int) RETURNS void AS
$$
DECLARE
  entity_count int;
BEGIN

perform remove_source(new_source_id);

RAISE INFO 'Removed the source to be inserted. Timestamp : %', (select timeofday()) ;

SET enable_nestloop TO OFF;
SET enable_mergejoin TO OFF;

TRUNCATE data_from_new_source;
INSERT INTO data_from_new_source (category_id, entity_id, tag_id, value)
SELECT e.category_id, e.entity_id, f.global_id, string_agg(value, ' , ')
         FROM (local_data d INNER JOIN entity_cat_mapping e on e.entity_id = d.entity_id)
		  INNER JOIN attribute_mappings f ON d.field_id = f.local_id
     where e.source_id=new_source_id and (category_id, f.global_id) in (SELECT category_id, tag_id FROM field_thresholds)
     GROUP BY e.category_id, e.entity_id, f.global_id;

SET enable_nestloop TO ON;
SET enable_mergejoin TO ON;

RAISE INFO 'data_from_new_source has the data now. Timestamp : %', (select timeofday()) ;


UPDATE tag_frequency t1
SET tuples_count = t1.tuples_count + t2.tuples_count
FROM (SELECT category_id, tag_id, count(distinct entity_id) AS tuples_count
	FROM data_from_new_source
	GROUP BY tag_id, category_id) t2
WHERE t1.tag_id = t2.tag_id and t1.category_id = t2.category_id;

INSERT INTO tag_frequency
SELECT category_id, tag_id, count(distinct entity_id) AS tuples_count
	FROM data_from_new_source
WHERE (category_id, tag_id) NOT IN (SELECT category_id,tag_id FROM tag_frequency)
GROUP BY category_id, tag_id;

RAISE INFO 'Updated tag frequncies. Timestamp : %', (select timeofday()) ;

TRUNCATE data_from_new_source_qgrams;
INSERT INTO data_from_new_source_qgrams(category_id, entity_id, tag_id, qgram, freq)
SELECT category_id, entity_id, d.tag_id, tokenize_besk(value) as qgram, count(*) as freq
FROM data_from_new_source d
WHERE d.tag_id in (select f.id  from global_attributes f where f.type = 'TEXT')
AND (category_id, tag_id) in (select category_id, tag_id from field_thresholds)
GROUP BY category_id, entity_id, d.tag_id, qgram;

RAISE INFO 'Constructed all q-grams for the new data. Timestamp : %', (select timeofday()) ;


entity_count:= (select count(distinct entity_id) from data_from_new_source);

DELETE FROM data_from_new_source_qgrams
WHERE (category_id, tag_id, qgram) IN
(SELECT d.category_id, tag_id, qgram
FROM data_from_new_source_qgrams d, est_dup_prob e
WHERE d.category_id = e.category_id
group by d.category_id, tag_id, qgram, e.dup_prob
HAVING count(*) > sqrt(e.dup_prob) * entity_count);


DROP TABLE IF EXISTS new_source_qgrams;
CREATE TEMP TABLE new_source_qgrams AS
SELECT category_id, tag_id, qgram , count(distinct entity_id) as doc_count
FROM data_from_new_source_qgrams group by category_id, tag_id, qgram;

UPDATE gen_qgrams_idf a
SET doc_count = a.doc_count + b.doc_count
FROM new_source_qgrams b
WHERE a.tag_id= b.tag_id AND a.qgram = b.qgram AND a.category_id = b.category_id;

INSERT INTO gen_qgrams_idf (category_id, tag_id, qgram, doc_count)
SELECT a.category_id, a.tag_id, a.qgram, doc_count
FROM new_source_qgrams a,
((SELECT category_id, tag_id, qgram FROM new_source_qgrams) except all (SELECT category_id, tag_id, qgram FROM gen_qgrams_idf)) b
where a.category_id = b.category_id AND a.tag_id = b.tag_id and a.qgram= b.qgram;

DROP TABLE new_source_qgrams;

TRUNCATE data_from_new_source_qgrams_tmp;
INSERT INTO data_from_new_source_qgrams_tmp
select b.category_id, b.entity_id, b.tag_id, b.qgram , b.freq * a.idf as freq from relevant_qgrams_idf a , data_from_new_source_qgrams b where  a.category_id = b.category_id AND a.tag_id = b.tag_id and a.qgram=b.qgram;

TRUNCATE data_from_new_source_qgrams;
INSERT INTO data_from_new_source_qgrams select * from data_from_new_source_qgrams_tmp;

TRUNCATE data_from_new_source_qgrams_tmp;

UPDATE data_from_new_source_qgrams d
SET freq = freq / norm
FROM
(SELECT category_id, entity_id, tag_id, |/sum(freq*freq) as norm
	FROM data_from_new_source_qgrams
	GROUP BY category_id, entity_id, tag_id
) agg
WHERE agg.category_id = d.category_id AND agg.entity_id = d.entity_id AND agg.tag_id = d.tag_id;

RAISE INFO 'updated the norms of values.  Timestamp : %', (select timeofday());


--  use threshold to remove popular qgrams

DELETE FROM data_from_new_source_qgrams d
USING (
SELECT f.category_id, entity_id, f.tag_id, cutoff(array_agg(freq order by freq),f.threshold) as cutoff
FROM data_from_new_source_qgrams d, field_thresholds f
WHERE d.category_id = f.category_id and d.tag_id = f.tag_id
GROUP BY f.category_id, entity_id, f.tag_id, f.threshold) a
WHERE d.category_id = a.category_id and d.entity_id = a.entity_id and d.tag_id = a.tag_id and d.freq < a.cutoff;



TRUNCATE data_from_new_source_real;
INSERT INTO data_from_new_source_real(category_id, entity_id, tag_id, value)
SELECT category_id, entity_id, d.tag_id, to_num(value)
FROM data_from_new_source d
WHERE d.tag_id in (select f.id from global_attributes f where f.type='REAL')
AND (category_id,tag_id) in (SELECT category_id,tag_id FROM features)
 AND to_num(value) is not null;


-- self join and cluster data_from_new_source

RAISE INFO 'Starting self-join. Timestamp : %', (select timeofday());

SET enable_nestloop TO OFF;
SET enable_mergejoin TO OFF;

/*
TRUNCATE candidate_pairs;
INSERT INTO candidate_pairs
	SELECT distinct a.category_id, a.entity_id, b.entity_id
	FROM data_from_new_source_qgrams a, data_from_new_source_qgrams b, field_thresholds f
	WHERE a.category_id = b.category_id AND  b.category_id =f.category_id AND a.tag_id = b.tag_id AND a.entity_id < b.entity_id AND a.qgram=b.qgram AND a.tag_id = f.tag_id
	GROUP BY a.category_id, a.entity_id, b.entity_id, a.tag_id, f.threshold
	HAVING  sum(a.freq*b.freq) >= f.threshold;

TRUNCATE candidate_pairs_2way;
INSERT INTO candidate_pairs_2way
	SELECT distinct a.category_id, a.entity_id, b.entity_id
	FROM data_from_new_source_qgrams a, inserted_data_qgrams_candidates b, field_thresholds f
	WHERE a.category_id = b.category_id AND  b.category_id =f.category_id AND a.tag_id = b.tag_id AND a.qgram=b.qgram AND a.tag_id = f.tag_id
	GROUP BY a.category_id, a.entity_id, b.entity_id, a.tag_id, f.threshold
	HAVING  sum(a.freq*b.freq) >= f.threshold;
*/

TRUNCATE candidate_pairs;
INSERT INTO candidate_pairs
	SELECT distinct a.category_id, a.entity_id, b.entity_id
	FROM data_from_new_source_qgrams a, data_from_new_source_qgrams b
	WHERE a.category_id = b.category_id AND a.tag_id = b.tag_id AND a.entity_id < b.entity_id AND a.qgram=b.qgram;


TRUNCATE candidate_pairs_2way;
INSERT INTO candidate_pairs_2way
	SELECT distinct a.category_id, a.entity_id, b.entity_id
	FROM data_from_new_source_qgrams a, inserted_data_qgrams_candidates b
	WHERE a.category_id = b.category_id AND a.tag_id = b.tag_id AND a.qgram=b.qgram;


SET enable_nestloop TO ON;
SET enable_mergejoin TO ON;

RAISE INFO 'Q-gram join done. Timestamp : %', (select timeofday()) ;

-- remember, f.threshold is a negative value
INSERT INTO candidate_pairs
SELECT distinct a.category_id, a.entity_id, b.entity_id
FROM data_from_new_source_real a, data_from_new_source_real b, field_thresholds f
WHERE a.category_id = b.category_id AND  b.category_id = f.category_id AND a.entity_id < b.entity_id AND f.threshold is not null AND a.tag_id=b.tag_id AND a.tag_id=f.tag_id AND a.value BETWEEN b.value + f.threshold AND b.value - f.threshold  AND b.value BETWEEN a.value + f.threshold AND a.value - f.threshold;


INSERT INTO candidate_pairs_2way
SELECT distinct a.category_id, a.entity_id, b.entity_id
FROM data_from_new_source_real a, inserted_data_real b,  field_thresholds f
WHERE a.category_id = b.category_id AND  b.category_id = f.category_id AND f.threshold is not null AND a.tag_id=b.tag_id AND a.tag_id=f.tag_id AND a.value BETWEEN b.value + f.threshold AND b.value - f.threshold  AND b.value BETWEEN a.value + f.threshold AND a.value - f.threshold;


RAISE INFO 'Real-based candidate pairs obtained. Timestamp : %', (select timeofday()) ;

SET enable_nestloop TO OFF;
SET enable_mergejoin TO OFF;


INSERT INTO inserted_data_qgrams_candidates (category_id, entity_id, tag_id, qgram, freq)
SELECT category_id, entity_id, tag_id, qgram, freq
FROM data_from_new_source_qgrams;

SET enable_nestloop TO ON;
SET enable_mergejoin TO ON;

END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sim_join(new_source_id int) RETURNS void AS
$$
DECLARE
  sim_threshold double precision;
  entity_count int;
BEGIN

sim_threshold:=  (select to_num(value) from configuration_properties where name='truncate_threshold');

-- now , reconstrucnt data_from_new_source_qgrams to retrieve pruned qgrams
SET enable_nestloop TO OFF;
SET enable_mergejoin TO OFF;


TRUNCATE data_from_new_source;
INSERT INTO data_from_new_source (category_id, entity_id, tag_id, value)
SELECT e.category_id, e.entity_id, f.global_id, string_agg(value, ' , ')
         FROM (local_data d INNER JOIN entity_cat_mapping e on e.entity_id = d.entity_id)
		  INNER JOIN attribute_mappings f ON d.field_id = f.local_id
     where e.source_id=new_source_id and (category_id, f.global_id) in (SELECT category_id, tag_id FROM features)
	 and e.entity_id in ((select entity1_id from candidate_pairs) UNION (select entity2_id from candidate_pairs))
     GROUP BY e.category_id, e.entity_id, f.global_id;


SET enable_nestloop TO OFF;
SET enable_mergejoin TO OFF;

RAISE INFO 'Re-extracted data.  Timestamp : %', (select timeofday()) ;

UPDATE tag_frequency t1
SET tuples_count = t1.tuples_count + t2.tuples_count
FROM (SELECT category_id, tag_id, count(distinct entity_id) AS tuples_count
	FROM data_from_new_source
	GROUP BY tag_id, category_id) t2
WHERE t1.tag_id = t2.tag_id and t1.category_id = t2.category_id;

INSERT INTO tag_frequency
SELECT category_id, tag_id, count(distinct entity_id) AS tuples_count
	FROM data_from_new_source
WHERE (category_id, tag_id) NOT IN (SELECT category_id,tag_id FROM tag_frequency)
GROUP BY category_id, tag_id;


TRUNCATE data_from_new_source_qgrams;
INSERT INTO data_from_new_source_qgrams(category_id, entity_id, tag_id, qgram, freq)
SELECT category_id, entity_id, d.tag_id, tokenize_besk(value) as qgram, count(*) as freq
FROM data_from_new_source d
WHERE d.tag_id in (select f.id  from global_attributes f where f.type = 'TEXT')
GROUP BY category_id, entity_id, d.tag_id, qgram;

DROP TABLE IF EXISTS new_source_qgrams;
CREATE TEMP TABLE new_source_qgrams AS
SELECT category_id, tag_id, qgram , count(distinct entity_id) as doc_count
FROM data_from_new_source_qgrams group by category_id, tag_id, qgram;

INSERT INTO gen_qgrams_idf (category_id, tag_id, qgram, doc_count)
SELECT a.category_id, a.tag_id, a.qgram, doc_count
FROM new_source_qgrams a,
((SELECT category_id, tag_id, qgram FROM new_source_qgrams) except all (SELECT category_id, tag_id, qgram FROM gen_qgrams_idf)) b
where a.category_id = b.category_id AND a.tag_id = b.tag_id and a.qgram= b.qgram;

DROP TABLE new_source_qgrams;


TRUNCATE data_from_new_source_qgrams_tmp;
INSERT INTO data_from_new_source_qgrams_tmp
select b.category_id, b.entity_id, b.tag_id, b.qgram , b.freq * a.idf as freq
from relevant_qgrams_idf a , data_from_new_source_qgrams b
where  a.category_id = b.category_id AND a.tag_id = b.tag_id and a.qgram=b.qgram;

TRUNCATE data_from_new_source_qgrams;
INSERT INTO data_from_new_source_qgrams select * from data_from_new_source_qgrams_tmp;

TRUNCATE data_from_new_source_qgrams_tmp;


--update the norm
UPDATE data_from_new_source_qgrams d
SET freq = freq / norm
FROM
(SELECT category_id, entity_id, tag_id, |/sum(freq*freq) as norm
	FROM data_from_new_source_qgrams
	GROUP BY category_id, entity_id, tag_id
) agg
WHERE agg.category_id = d.category_id AND agg.entity_id = d.entity_id AND agg.tag_id = d.tag_id;

RAISE INFO 'Reconstruction of Qgrams done %', (select timeofday()) ;



-- reconstruction done

SET enable_nestloop TO OFF;
SET enable_mergejoin TO OFF;

TRUNCATE candidate_attributes;
INSERT INTO candidate_attributes
   SELECT dup.category_id, dup.entity1_id, dup.entity2_id, q1.tag_id, SUM(q1.freq * q2.freq) AS sim
   FROM (select distinct category_id, entity1_id, entity2_id from candidate_pairs) dup, data_from_new_source_qgrams q1, data_from_new_source_qgrams q2
   WHERE dup.category_id = q1.category_id AND q1.category_id = q2.category_id AND dup.entity1_id = q1.entity_id AND dup.entity2_id = q2.entity_id
        AND q1.tag_id = q2.tag_id AND q1.qgram = q2.qgram
   GROUP BY dup.entity1_id, dup.entity2_id, q1.tag_id, dup.category_id;

SET enable_nestloop TO ON;
SET enable_mergejoin TO ON;

RAISE INFO 'Adding qgram frequencies done. Timestamp : %', (select timeofday()) ;


INSERT INTO candidate_attributes
SELECT dup.category_id, entity1_id, entity2_id, d1.tag_id , - abs(d1.value - d2.value)
FROM (select distinct category_id, entity1_id, entity2_id from candidate_pairs) dup, data_from_new_source_real d1, data_from_new_source_real d2
WHERE dup.category_id = d1.category_id AND d1.category_id = d2.category_id AND dup.entity1_id=d1.entity_id AND dup.entity2_id=d2.entity_id AND d1.tag_id = d2.tag_id;

RAISE INFO 'Computing real similarities done. Timestamp : %', (select timeofday()) ;

-- TODO: how to avoid adding zero similarity?
INSERT INTO candidate_attributes
(SELECT dup.category_id, dup.entity1_id, dup.entity2_id, d1.tag_id, 0
FROM (select distinct category_id, entity1_id, entity2_id from candidate_pairs) dup, data_from_new_source d1, data_from_new_source d2
	WHERE dup.category_id = d1.category_id AND d1.category_id = d2.category_id  AND dup.entity1_id = d1.entity_id AND dup.entity2_id = d2.entity_id AND d1.tag_id = d2.tag_id)
		EXCEPT ALL (Select category_id, entity1_id,entity2_id, tag_id, 0 from candidate_attributes);

RAISE INFO 'Adding zero qgrams done. Timestamp : %', (select timeofday()) ;


TRUNCATE similarity_self_join_result_cat;
Insert into similarity_self_join_result_cat
SELECT c.category_id, entity1_id, entity2_id,
       COALESCE(p.null_prod_m,1) * e.dup_prob  * product(COALESCE(f.f_given_m,1)) / product(COALESCE(n.f_given_m,1)),
       COALESCE(p.null_prod_u,1) * (1- e.dup_prob) * product(COALESCE(f.f_given_u,1)) / product(COALESCE(n.f_given_u,1))
FROM (((candidate_attributes c INNER JOIN est_dup_prob e ON c.category_id = e.category_id)
	LEFT OUTER JOIN features f ON (c.category_id = f.category_id and c.tag_id = f.tag_id and c.similarity >= f.t1 and c.similarity < f.t2))
	 LEFT OUTER JOIN feature_nulls n ON (c.category_id = n.category_id AND c.tag_id = n.tag_id)) LEFT OUTER JOIN null_prod p ON c.category_id = p.category_id
GROUP BY entity1_id, entity2_id, c.category_id, p.null_prod_m, p.null_prod_u, e.dup_prob;

RAISE INFO 'Computing prob of dup done. Timestamp : %', (select timeofday()) ;

TRUNCATE similarity_self_join_result;
INSERT INTO similarity_self_join_result
SELECT entity1_id, entity2_id, avg(prob_s_m / (prob_s_m + prob_s_u))
FROM similarity_self_join_result_cat
WHERE prob_s_m >0 OR prob_s_u >0
GROUP BY entity1_id, entity2_id;

INSERT INTO sim_pairs
SELECT entity1_id, entity2_id, m_prob
FROM similarity_self_join_result;

INSERT INTO edges
SELECT entity1_id, entity2_id
FROM similarity_self_join_result
WHERE m_prob >= sim_threshold;


TRUNCATE new_edges;
INSERT INTO new_edges
SELECT entity1_id, entity2_id
FROM similarity_self_join_result
WHERE m_prob >= sim_threshold;

RAISE INFO 'Self-join done. Timestamp : %', (select timeofday()) ;

RAISE INFO 'Starting similarity-join..';



-- now , reconstrucnt data_from_new_source_qgrams to retrieve pruned qgrams

TRUNCATE inserted_data;
INSERT INTO inserted_data (category_id, entity_id, tag_id, value)
SELECT e.category_id, d.entity_id, f.global_id, string_agg(value, ' , ')
         FROM (local_data d INNER JOIN candidate_pairs_2way e on e.entity2_id = d.entity_id)
		  INNER JOIN attribute_mappings f ON d.field_id = f.local_id
     where (category_id, f.global_id) in (SELECT category_id, tag_id FROM features)
     GROUP BY e.category_id, d.entity_id, f.global_id;

RAISE INFO 'Re-extracted data.  Timestamp : %', (select timeofday()) ;

TRUNCATE inserted_data_qgrams;
INSERT INTO inserted_data_qgrams(category_id, entity_id, tag_id, qgram, freq)
SELECT category_id, entity_id, d.tag_id, tokenize_besk(value) as qgram, count(*) as freq
FROM inserted_data d
WHERE d.tag_id in (select f.id  from global_attributes f where f.type = 'TEXT')
GROUP BY category_id, entity_id, d.tag_id, qgram;

TRUNCATE data_from_new_source_qgrams_tmp;
INSERT INTO data_from_new_source_qgrams_tmp
select b.category_id, b.entity_id, b.tag_id, b.qgram , b.freq * a.idf as freq
from relevant_qgrams_idf a, inserted_data_qgrams b
where  a.category_id = b.category_id AND a.tag_id = b.tag_id and a.qgram=b.qgram;

TRUNCATE inserted_data_qgrams;
INSERT INTO inserted_data_qgrams select * from data_from_new_source_qgrams_tmp;

TRUNCATE data_from_new_source_qgrams_tmp;

--update the norm
UPDATE inserted_data_qgrams d
SET freq = freq / norm
FROM
(SELECT category_id, entity_id, tag_id, |/sum(freq*freq) as norm
	FROM inserted_data_qgrams
	GROUP BY category_id, entity_id, tag_id
) agg
WHERE agg.category_id = d.category_id AND agg.entity_id = d.entity_id AND agg.tag_id = d.tag_id;

RAISE INFO 'Reconstruction of Qgrams done %', (select timeofday()) ;


TRUNCATE candidate_attributes_2way;

SET enable_nestloop TO OFF;
SET enable_mergejoin TO OFF;

INSERT INTO candidate_attributes_2way
   SELECT dup.category_id, dup.entity1_id, dup.entity2_id, q1.tag_id, SUM(q1.freq * q2.freq) AS sim
   FROM (select distinct category_id, entity1_id, entity2_id from candidate_pairs_2way) dup, data_from_new_source_qgrams q1, inserted_data_qgrams q2
   WHERE dup.category_id = q1.category_id AND q1.category_id = q2.category_id AND dup.entity1_id = q1.entity_id AND dup.entity2_id = q2.entity_id
        AND q1.tag_id = q2.tag_id AND q1.qgram = q2.qgram
   GROUP BY dup.entity1_id, dup.entity2_id, q1.tag_id, dup.category_id;

SET enable_nestloop TO ON;
SET enable_mergejoin TO ON;

RAISE INFO 'Adding qgram frequencies done. Timestamp : %', (select timeofday()) ;

INSERT INTO candidate_attributes_2way
SELECT dup.category_id, dup.entity1_id, dup.entity2_id, d1.tag_id , - abs(d1.value - d2.value)
FROM (select distinct category_id, entity1_id, entity2_id from candidate_pairs_2way) dup, data_from_new_source_real d1, inserted_data_real d2
WHERE dup.category_id = d1.category_id AND d1.category_id = d2.category_id AND dup.entity1_id=d1.entity_id AND dup.entity2_id=d2.entity_id AND d1.tag_id = d2.tag_id;


RAISE INFO 'Computing real similarities done. Timestamp : %', (select timeofday()) ;

INSERT INTO candidate_attributes_2way
(SELECT dup.category_id, dup.entity1_id, dup.entity2_id, d1.tag_id, 0
FROM (select distinct category_id, entity1_id, entity2_id from candidate_pairs_2way) dup, data_from_new_source d1, inserted_data d2
WHERE dup.category_id = d1.category_id AND d1.category_id = d2.category_id AND dup.entity1_id = d1.entity_id AND dup.entity2_id = d2.entity_id AND d1.tag_id = d2.tag_id)
EXCEPT ALL (select category_id, entity1_id, entity2_id, tag_id, 0 from candidate_attributes_2way);

RAISE INFO 'Adding zero qgrams done. Timestamp : %', (select timeofday()) ;


TRUNCATE similarity_2way_join_result_cat;
Insert into similarity_2way_join_result_cat
SELECT c.category_id, entity1_id, entity2_id,
       COALESCE(p.null_prod_m,1) * e.dup_prob  * product(COALESCE(f.f_given_m,1)) / product(COALESCE(n.f_given_m,1)),
       COALESCE(p.null_prod_u,1) * (1- e.dup_prob) * product(COALESCE(f.f_given_u,1)) / product(COALESCE(n.f_given_u,1))
FROM (((candidate_attributes_2way c INNER JOIN est_dup_prob e ON c.category_id = e.category_id)
	LEFT OUTER JOIN features f ON (c.category_id = f.category_id and c.tag_id = f.tag_id and c.similarity >= f.t1 and c.similarity < f.t2))
	 LEFT OUTER JOIN feature_nulls n ON (f.category_id = n.category_id AND n.tag_id = f.tag_id)) LEFT OUTER JOIN null_prod p ON f.category_id = p.category_id
GROUP BY entity1_id, entity2_id, c.category_id, p.null_prod_m, p.null_prod_u, e.dup_prob;

RAISE INFO 'similarity_2way_join done. Timestamp : %', (select timeofday()) ;

TRUNCATE similarity_2way_join_result;
INSERT INTO similarity_2way_join_result
SELECT entity1_id, entity2_id, avg(prob_s_m / (prob_s_m + prob_s_u))
FROM similarity_2way_join_result_cat
WHERE prob_s_m >0 OR prob_s_u >0
GROUP BY entity1_id, entity2_id;

RAISE INFO 'Two-way-join done. Timestamp : %', (select timeofday()) ;

INSERT INTO sim_pairs
SELECT entity1_id, entity2_id, m_prob
FROM similarity_2way_join_result;

INSERT INTO edges
SELECT entity1_id, entity2_id
FROM similarity_2way_join_result
WHERE m_prob >= sim_threshold;

INSERT INTO new_edges
SELECT entity1_id, entity2_id
FROM similarity_2way_join_result
WHERE m_prob >= sim_threshold;

-- update inserted_data table

INSERT INTO inserted_data_real (category_id, entity_id, tag_id, value)
SELECT category_id, entity_id, tag_id, value
FROM data_from_new_source_real;
END;
$$ LANGUAGE plpgsql;
---------------------------------------------------------------------------------------------------------------------------
-- Input:  removed_entities, new_edges, removed edges

CREATE OR REPLACE FUNCTION incr_clusterings() RETURNS void AS
$$
DECLARE
cluster_pair RECORD;
cl_id int;
i int;
new_cluster_id int;
sid int;
cluster_aggresivness real;
BEGIN

cluster_aggresivness:=  (select to_num(value) from configuration_properties where name='cluster_aggresivness');

-- find tuples to completely delete
TRUNCATE removed_entities;
INSERT INTO removed_entities
((SELECT entity1_id from removed_edges) union (select entity2_id from removed_edges));

-- assume for now that all edges are not missed by the clustering

-- TODO:check later
DELETE FROM entity_clustering
WHERE entity_id in (select entity_id from removed_entities);


-- Undo (Split) clusters involving new edges

-- Extend the new entities to the old one removed from clustering
TRUNCATE new_entities;
INSERT INTO new_entities
((select entity1_id from new_edges) union (select entity2_id from new_edges));

--Extend the new edges
TRUNCATE new_edges;
INSERT INTO new_edges
SELECT entity1_id , entity2_id
FROM edges
WHERE (entity1_id in (select entity_id from new_entities) or entity2_id in (select entity_id from new_entities));


DELETE FROM entity_clustering
WHERE entity_id in (select entity_id from new_entities);


INSERT INTO entity_clustering
SELECT entity_id, entity_id
from new_entities;



i := 1;

LOOP

RAISE INFO 'round #%', i;

TRUNCATE clusters_to_merge_tmp;


INSERT into clusters_to_merge_tmp
SELECT c1id, c2id FROM
(SELECT least(c1.cluster_id,c2.cluster_id) as c1id, greatest(c1.cluster_id,c2.cluster_id) c2id, count(*) as edge_count
FROM entity_clustering c1, entity_clustering c2, new_edges s
WHERE c1.cluster_id <> c2.cluster_id
	AND c1.entity_id = s.entity1_id AND c2.entity_id = s.entity2_id
GROUP BY c1id , c2id) p, cluster_size c1s, cluster_size c2s
WHERE p.c1id = c1s.cluster_id AND p.c2id=c2s.cluster_id AND edge_count >= c1s.size * c2s.size / cluster_aggresivness;


IF (not exists(select * from clusters_to_merge_tmp)) THEN
	EXIT;
END IF;

TRUNCATE clusters_to_merge;
INSERT INTO clusters_to_merge
SELECT random(cid1), cid2
FROM(
	Select cid1, random(cid2) as cid2
	FROM clusters_to_merge_tmp
	GROUP BY cid1) a
GROUP BY cid2;


UPDATE entity_clustering c
SET cluster_id = m.cid2
FROM  clusters_to_merge m
WHERE c.cluster_id = m.cid1;

i := i + 1;

END LOOP;


END;
$$ LANGUAGE plpgsql;


/*

CREATE OR REPLACE FUNCTION incr_clusterings(k int) RETURNS void AS
$$
DECLARE
cluster_pair RECORD;
stable bool default false;
cl_id int;
i int;
new_cluster_id int;
BEGIN

FOR cl_id in 1..k LOOP

--TRUNCATE entity_cluster_mapping;
INSERT INTO entity_cluster_mapping(entity_id, cluster_id, clustering_id)
Select entity_id, nextval('cluster_id_seq'), cl_id FROM
(((SELECT entity1_id as entity_id from edges) UNION (SELECT entity2_id as entity_id from edges)) EXCEPT (select entity_id from entity_cluster_mapping where clustering_id = cl_id)) a;

END LOOP;

i := 1;
WHILE (not stable) LOOP
stable := true;

RAISE INFO 'round #%', i;

i := i + 1;

FOR cluster_pair in
(SELECT c1id, c2id FROM
(SELECT least(c1.cluster_id,c2.cluster_id) as c1id, greatest(c1.cluster_id,c2.cluster_id) c2id, count(*) as edge_count
FROM entity_cluster_mapping c1, entity_cluster_mapping c2, edges s
WHERE c1.cluster_id <> c2.cluster_id
	AND c1.entity_id = s.entity1_id AND c2.entity_id = s.entity2_id AND	c1.clustering_id = c2.clustering_id
GROUP BY c1id , c2id) p, cluster_size c1s, cluster_size c2s
WHERE p.c1id = c1s.cluster_id AND p.c2id=c2s.cluster_id AND edge_count >= c1s.size * c2s.size / 2.0 order by random())  LOOP

stable := false;

IF ((select count(*) from entity_cluster_mapping where cluster_id = cluster_pair.c1id)>0
	AND (select count(*) from entity_cluster_mapping where cluster_id = cluster_pair.c2id)>0) THEN

	new_cluster_id:= nextval('cluster_id_seq');
	UPDATE entity_cluster_mapping SET cluster_id = new_cluster_id
	WHERE cluster_id in (cluster_pair.c1id, cluster_pair.c2id);

END IF;
END LOOP;

END LOOP;

END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_min_disagg_clustering_id() RETURNS int AS
$$
DECLARE
cl_id int;
current_disagg_1 int;
current_disagg_2 int;
min_disagg int;
min_dissag_cl_id int;
BEGIN
min_disagg := 1e9;
current_disagg_1 := 0;
current_disagg_2 := 0;

FOR cl_id in (select distinct clustering_id from entity_cluster_mapping) LOOP

select into current_disagg_1 count(*) FROM
((select a.entity_id, b.entity_id
FROM entity_cluster_mapping a, entity_cluster_mapping b
WHERE a.cluster_id = b.cluster_id and a.entity_id < b.entity_id and a.clustering_id = cl_id and b.clustering_id =cl_id)
EXCEPT
(SELECT least(entity1_id, entity2_id), greatest(entity1_id, entity2_id) FROM edges)) a;

current_disagg_2 :=
(SELECT count(*)
FROM entity_cluster_mapping a, entity_cluster_mapping b, edges e
WHERE a.cluster_id <> b.cluster_id AND e.entity1_id = a.entity_id and e.entity2_id = b.entity_id and a.clustering_id = cl_id and b.clustering_id =cl_id);

RAISE INFO 'disagreements for clustering % is (intra) % + (inter) %', cl_id, current_disagg_1, current_disagg_2;

IF (current_disagg_1 + current_disagg_2 < min_disagg) THEN
min_disagg := current_disagg_1 + current_disagg_2;
min_dissag_cl_id := cl_id;

END IF;

END LOOP;

RETURN min_dissag_cl_id;
END;
$$ LANGUAGE plpgsql;

*/


CREATE OR REPLACE FUNCTION clean_up() RETURNS void AS
$$
BEGIN

TRUNCATE data_from_new_source;
TRUNCATE data_from_new_source_qgrams;
TRUNCATE data_from_new_source_real;
TRUNCATE inserted_data;
TRUNCATE inserted_data_qgrams;
TRUNCATE inserted_data_real;
TRUNCATE tag_values_frequency;
TRUNCATE tag_frequency;
TRUNCATE gen_qgrams_idf;
TRUNCATE est_dup_prob;
TRUNCATE field_thresholds;
TRUNCATE features;
TRUNCATE duplicate_pairs;
TRUNCATE duplicate_attributes;
TRUNCATE random_pairs;
TRUNCATE random_attributes;
TRUNCATE questions;
TRUNCATE entity_clustering;
TRUNCATE sim_pairs;
TRUNCATE edges;
END;
$$ LANGUAGE plpgsql;


