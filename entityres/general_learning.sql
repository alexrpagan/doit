DROP TABLE IF EXISTS field_thresholds CASCADE;
CREATE TABLE field_thresholds(category_id int, tag_id int, threshold double precision);
CREATE INDEX field_thresholds__cat_id_tag_id ON field_thresholds(category_id, tag_id);

DROP TABLE IF EXISTS features CASCADE;
CREATE TABLE features(category_id int, tag_id integer, t1 double precision, t2 double precision, f_given_m double precision, f_given_u double precision);

DROP TABLE IF EXISTS est_dup_prob CASCADE;
CREATE TABLE est_dup_prob(category_id int, dup_prob double precision);
CREATE OR REPLACE FUNCTION multiply_aggregate(double precision,double precision) RETURNS double precision AS
' select $1 * $2; ' language sql IMMUTABLE STRICT;

CREATE AGGREGATE product (basetype=double precision, sfunc=multiply_aggregate, stype=double precision,
initcond=1 ) ;

CREATE OR REPLACE FUNCTION to_num(v_input text)
RETURNS double precision AS $$
DECLARE v_int_value double precision DEFAULT NULL;
BEGIN
    BEGIN
        v_int_value := v_input::double precision;
    EXCEPTION WHEN OTHERS THEN
        RETURN NULL;
    END;
RETURN v_int_value;
END;
$$ LANGUAGE plpgsql;

create or replace function tokenize_besk (text) returns setof text as
$$
begin
  return query
  select trim(token) from (
  select trim(both '{}' from ts_lexize('english_stem', token)::text) as token
    from (
    	 select * from ts_parse('default', $1)
	  where tokid != 12 and length(token) < 200
	 ) t
	 ) b
	 WHERE trim(token)<>'';
end;
$$ language plpgsql;



DROP TABLE IF EXISTS duplicate_pairs CASCADE;
CREATE TABLE duplicate_pairs (category_id integer, entity1_id integer, entity2_id integer);
DROP TABLE IF EXISTS duplicate_attributes CASCADE;
CREATE TABLE duplicate_attributes (category_id integer, entity1_id integer, entity2_id integer, tag_id integer, similarity double precision);

DROP TABLE IF EXISTS random_pairs CASCADE;
CREATE TABLE random_pairs (category_id integer, entity1_id integer, entity2_id integer);
DROP TABLE IF EXISTS random_attributes CASCADE;
CREATE TABLE random_attributes (category_id integer, entity1_id integer, entity2_id integer, tag_id integer, similarity double precision);


DROP VIEW IF EXISTS feature_nulls;
CREATE VIEW feature_nulls AS
     SELECT * FROM features
      WHERE t1 IS NULL;


DROP VIEW IF EXISTS null_prod;
CREATE VIEW null_prod AS
SELECT category_id, product(f_given_m) as null_prod_m, product(f_given_u) as null_prod_u
FROM features
WHERE t1 IS NULL
GROUP BY category_id;

DROP SEQUENCE IF EXISTS pair_id CASCADE;
CREATE SEQUENCE pair_id;

DROP TABLE IF EXISTS rand_entity1;
CREATE TABLE rand_entity1(id int default nextval('pair_id'), entity_id int);
DROP TABLE IF EXISTS rand_entity2;
CREATE TABLE rand_entity2(id int default nextval('pair_id'), entity_id int);


DROP TABLE IF EXISTS learning_attrs CASCADE;
CREATE TABLE learning_attrs(tag_id int);

DROP TABLE IF EXISTS questions CASCADE;
CREATE TABLE questions(category_id int, entity1_id int, entity2_id int, sim double precision, human_label text); 	-- human_label = 'Yes', 'No', 'Maybe' (case sensitive)



CREATE OR REPLACE FUNCTION populate_questions() RETURNS void AS
$$
DECLARE
global_attr_id int;
questions_per_attr int;
bin int;
bin_count int;
min_sim double precision;
max_sim double precision;
range_start double precision;
range_end double precision;
cat_id int;
questions_sample_size int;
expected_dup_prob double precision;
sim_threshold double precision;
sid int;
question_sample_sources int;
BEGIN


questions_per_attr := ceil((select value::integer from configuration_properties where name= 'question_budget') / (select count(*) from learning_attrs))::integer / (select count(distinct category_id) from cat_features_tf);
expected_dup_prob := (select value::double precision from configuration_properties where name= 'expected_dup_prob');
bin_count := (select value::int from configuration_properties where name= 'bins_count');
questions_sample_size:= (select value::int from configuration_properties where name= 'questions_sample_size');
question_sample_sources:= (select value::int from configuration_properties where name= 'question_sample_sources');
TRUNCATE questions;
TRUNCATE random_pairs;
TRUNCATE random_attributes;
TRUNCATE field_thresholds;
TRUNCATE features;
TRUNCATE sim_pairs;
TRUNCATE est_dup_prob;

For cat_id in (select distinct category_id from cat_features_tf) LOOP

perform extract_new_data(0, cat_id, questions_sample_size / 2);

RAISE INFO 'extracted sample tuples for category %', cat_id;

perform setval('pair_id', 1);
TRUNCATE rand_entity1;
INSERT INTO rand_entity1 (entity_id)
select entity_id from data_from_new_source order by random() limit questions_sample_size;

perform setval('pair_id', 1);
TRUNCATE rand_entity2;
INSERT INTO rand_entity2 (entity_id)
select entity_id from data_from_new_source order by random() limit questions_sample_size;

INSERT INTO random_pairs
SELECT distinct cat_id, least(a.entity_id, b.entity_id), greatest(a.entity_id, b.entity_id)
FROM rand_entity1 a, rand_entity2 b
WHERE a.id = b.id
AND a.entity_id <> b.entity_id;


INSERT INTO random_attributes
     SELECT cat_id, dup.entity1_id, dup.entity2_id, q1.tag_id, SUM(q1.freq * q2.freq) AS sim
       FROM random_pairs dup, data_from_new_source_qgrams q1, data_from_new_source_qgrams q2
        WHERE dup.entity1_id = q1.entity_id AND dup.entity2_id = q2.entity_id
        AND q1.tag_id = q2.tag_id AND q1.qgram = q2.qgram AND dup.category_id = cat_id
		AND q1.tag_id in (select tag_id from learning_attrs)
   GROUP BY dup.entity1_id, dup.entity2_id, q1.tag_id;


INSERT INTO random_attributes
SELECT cat_id, entity1_id, entity2_id, d1.tag_id , - abs(d1.value - d2.value)
FROM random_pairs dup, data_from_new_source_real d1, data_from_new_source_real d2
WHERE dup.entity1_id=d1.entity_id AND dup.entity2_id=d2.entity_id
AND d1.tag_id = d2.tag_id AND dup.category_id = cat_id
AND d1.tag_id in (select tag_id from learning_attrs);


INSERT INTO random_attributes
(SELECT cat_id, dup.entity1_id, dup.entity2_id, d1.tag_id, 0
FROM random_pairs dup, data_from_new_source d1, data_from_new_source d2
WHERE dup.entity1_id = d1.entity_id AND dup.entity2_id = d2.entity_id
AND d1.tag_id = d2.tag_id AND dup.category_id = cat_id
AND d1.tag_id in (select tag_id from learning_attrs))
EXCEPT ALL (select category_id, entity1_id, entity2_id, tag_id, 0 FROM random_attributes WHERE category_id = cat_id);


RAISE INFO 'Computing random_attributes is done';

INSERT INTO est_dup_prob values(cat_id, expected_dup_prob);

FOR global_attr_id in Select tag_id from learning_attrs LOOP

sim_threshold:= (select similarity from random_attributes where category_id = cat_id and tag_id = global_attr_id order by similarity desc limit 1 offset floor(questions_sample_size * expected_dup_prob)::int);
sim_threshold := sim_threshold - 1e-4;

INSERT INTO field_thresholds values(cat_id, global_attr_id, sim_threshold);

IF (select type from global_attributes where id = global_attr_id) = 'TEXT' THEN
	max_sim := 1 + 1e-9;
ELSE
	max_sim := 1e-9;
END IF;

min_sim := (select min(similarity) from random_attributes where tag_id = global_attr_id AND category_id = cat_id);

IF (min_sim is not null and sim_threshold is not null) THEN
	INSERT INTO features(category_id, tag_id, t1, t2, f_given_m, f_given_u) values(cat_id, global_attr_id, sim_threshold, max_sim, 0.9, 0.1);
	INSERT INTO features(category_id, tag_id, t1, t2, f_given_m, f_given_u) values(cat_id, global_attr_id, min_sim, sim_threshold, 0.1, 0.9);
END IF;
END LOOP; --next attribute

End LOOP; --next cat

RAISE INFO 'Starting adding sources....';

-- select random sources
For sid in (select id from local_sources order by random() limit question_sample_sources) LOOP
-- now retrieve all pairs above that threshold and put in questions

perform get_candidates(sid);
perform sim_join(sid);

END LOOP;

INSERT INTO questions (category_id, entity1_id, entity2_id, sim)
SELECT e1.category_id, entity1_id, entity2_id, s.prob_m
FROM sim_pairs s, entity_cat_mapping e1, entity_cat_mapping e2
where entity1_id = e1.entity_id and entity2_id = e2.entity_id and e1.category_id = e2.category_id;

END;
$$ LANGUAGE plpgsql;

----------------------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION learn_manual_weights() RETURNS void AS
$$
DECLARE
est_dup double precision;
abs_perf_threshold double precision;
rel_perf_threshold double precision;
i int;

tag_record RECORD;
sim_record RECORD;
sim_itr integer;
sim_step integer;
prob_s_n double precision;
prob_f double precision;
acc_prob_m double precision;
acc_prob_u double precision;
global_attr_itr int;
prob_f_given_u double precision;
prob_f_given_m double precision;
prob_m_given_f double precision;
cat_id int;
max_est_dup double precision;
m_corr double precision;
u_corr double precision;
prob_dist_threshold double precision;
pdf_diff double precision;
bins_count int;
global_attr_id int;
max_sim double precision;
min_sim double precision;
range_start double precision;
range_end double precision;
BEGIN

--est_dup := (select to_num(value) from configuration_properties where name='est_dup');
abs_perf_threshold := (select to_num(value) from configuration_properties where name='abs_perf_threshold');
rel_perf_threshold := (select to_num(value) from configuration_properties where name='rel_perf_threshold');
prob_dist_threshold := (select to_num(value) from configuration_properties where name='prob_dist_threshold');
bins_count:= (select to_num(value)::int from configuration_properties where name='bins_count');

FOR cat_id in (Select distinct category_id from cat_features_tf) LOOP

DELETE FROM field_thresholds where category_id = cat_id;
DELETE FROM features where category_id = cat_id;
DELETE FROM est_dup_prob where category_id = cat_id;
--now for each tag_id, and for each threshold value T, get Pr(S>T|M) and Pr(S>T)

--TODO: get better estimation for est_dup without overestimation

-- populate (Candidate) dupliate_attributes

TRUNCATE duplicate_attributes;

INSERT INTO duplicate_attributes
     SELECT cat_id, q.entity1_id, q.entity2_id, q1.tag_id, SUM(q1.freq * q2.freq) AS sim
       FROM questions q, inserted_data_qgrams_candidates q1, inserted_data_qgrams_candidates q2
         WHERE q.entity1_id = q1.entity_id AND q.entity2_id = q2.entity_id
		 and q.category_id = q1.category_id and q.category_id = q2.category_id
		 and q.category_id = cat_id  AND q1.tag_id = q2.tag_id  AND q1.qgram = q2.qgram AND (q.human_label = 'Yes' OR q.human_label = 'No')
    GROUP BY q.entity1_id, q.entity2_id, q1.tag_id;


INSERT INTO duplicate_attributes
SELECT cat_id, entity1_id, entity2_id, q1.tag_id , - abs(q1.value - q2.value)
FROM questions q, inserted_data_real q1, inserted_data_real q2
WHERE q.entity1_id=q1.entity_id AND q.entity2_id=q2.entity_id AND q1.tag_id = q2.tag_id and q.category_id = q1.category_id and q.category_id = q2.category_id and q.category_id = cat_id
AND (q.human_label = 'Yes' OR q.human_label = 'No');

--TODO : improve performance by replacin inserted_data_qgrams_candidates with something similar to inserted_data
INSERT INTO duplicate_attributes
(SELECT distinct cat_id, q.entity1_id, q.entity2_id, q1.tag_id, 0
FROM questions q, inserted_data_qgrams_candidates q1, inserted_data_qgrams_candidates q2
WHERE q.entity1_id = q1.entity_id AND q.entity2_id = q2.entity_id AND q1.tag_id = q2.tag_id
AND (q.human_label = 'Yes' OR q.human_label = 'No')
and q.category_id = q1.category_id and q.category_id = q2.category_id and q.category_id = cat_id)
 	EXCEPT ALL (select category_id, entity1_id, entity2_id, tag_id, 0 FROM duplicate_attributes);


FOR global_attr_id in Select distinct tag_id from learning_attrs LOOP

		IF (not exists (select * from random_attributes where tag_id = global_attr_id and category_id = cat_id)) then
			continue;
		END IF;

		prob_f_given_m:= (SELECT count(*) from
			((Select q.entity1_id, q.entity2_id FROM questions q WHERE human_label='Yes' and category_id = cat_id)
			EXCEPT
			(Select entity1_id, entity2_id FROM duplicate_attributes WHERE category_id = cat_id and tag_id = global_attr_id)) a)
			/ (Select count(*) FROM questions q WHERE human_label='Yes' and q.category_id = cat_id)::double precision;



		prob_f_given_u:= (SELECT count(*) from
			((Select q.entity1_id, q.entity2_id FROM questions q WHERE human_label='No' and category_id = cat_id)
			EXCEPT
			(Select entity1_id, entity2_id FROM duplicate_attributes WHERE category_id = cat_id and tag_id = global_attr_id)) a)
			/ (Select count(*) FROM questions q WHERE human_label='No' and q.category_id = cat_id)::double precision;

		INSERT INTO features values (cat_id, global_attr_id, null, null, prob_f_given_m, prob_f_given_u);

		IF (select type from global_attributes where id = global_attr_id) = 'TEXT' THEN
			max_sim := 1 + 1e-9;
		ELSE
			max_sim := 1e-9;
		END IF;

		min_sim := (select min(similarity) from random_attributes where tag_id = global_attr_id AND category_id = cat_id);



		For bin in 0..bins_count-1 LOOP

			range_start := min_sim + bin / bins_count::double precision * (max_sim - min_sim);
			range_end := min_sim + (bin+1) / bins_count::double precision * (max_sim - min_sim);

			prob_f_given_m:= (SELECT count(*) FROM questions q, duplicate_attributes p  WHERE human_label='Yes' and q.category_id = cat_id and p.category_id = cat_id
				and q.entity1_id=p.entity1_id and q.entity2_id=p.entity2_id and p.tag_id = global_attr_id and similarity >= range_start and similarity < range_end);

			prob_f_given_m:= prob_f_given_m / (Select count(*) FROM questions WHERE human_label='Yes' and category_id = cat_id);

			prob_f_given_u:= (SELECT count(distinct (q.entity1_id, q.entity2_id)) FROM questions q, duplicate_attributes p  WHERE human_label='No' and q.category_id = cat_id and p.category_id = cat_id
				and q.entity1_id=p.entity1_id and q.entity2_id=p.entity2_id and p.tag_id = global_attr_id and similarity >= range_start and similarity < range_end);

			prob_f_given_u:= prob_f_given_u / (Select count(*) FROM questions WHERE human_label='No' and category_id = cat_id);

			INSERT INTO features values (cat_id, global_attr_id, range_start, range_end, prob_f_given_m, prob_f_given_u);
	END LOOP;


	SELECT INTO m_corr corr(f_given_m, t1+t2)
	FROM features
	WHERE tag_id  = global_attr_id and category_id = cat_id and t1 is not null;

	SELECT INTO u_corr corr(f_given_u, t1+t2)
	FROM features
	WHERE tag_id  = global_attr_id and category_id = cat_id and t1 is not null;

	RAISE INFO 'For % : M-corr = %, U-corr = %', global_attr_id, m_corr, u_corr;
		-- compute pdf difference
	SELECT INTO pdf_diff SUM(diff)
	FROM (SELECT abs(f_given_m - f_given_u) as diff
	FROM features
	WHERE tag_id = global_attr_id and category_id = cat_id) a;

	RAISE INFO 'PDF diff for % is %', global_attr_id, pdf_diff;
	IF (pdf_diff < prob_dist_threshold or m_corr is null or m_corr <= 0 or u_corr is null or u_corr >= 0) THEN
		DELETE FROM features
		WHERE tag_id = global_attr_id and category_id = cat_id;
	END IF;

END LOOP;
update features set f_given_m=1e-9 where f_given_m=0 and category_id = cat_id;
update features set f_given_u=1e-9 where f_given_u=0 and category_id = cat_id;

/*
UPDATE features f
SET f_given_m = f_given_m / a.norm
FROM (select tag_id, sum(f_given_m) as norm from features where category_id = cat_id group by tag_id) a
WHERE  f.tag_id = a.tag_id and f.category_id =cat_id;

UPDATE features f
SET f_given_u = f_given_u / a.norm
FROM (select tag_id, sum(f_given_u) as norm from features where category_id = cat_id group by tag_id) a
WHERE  f.tag_id = a.tag_id and f.category_id =cat_id;
*/

RAISE INFO 'now, setting the threshold';

FOR global_attr_itr IN SELECT distinct tag_id from learning_attrs LOOP

	acc_prob_m := (select f_given_m FROM features where t1 is null and tag_id = global_attr_itr and category_id = cat_id);
	If (acc_prob_m is null) THEN
		acc_prob_m := 0;
	END IF;

	acc_prob_u := (select f_given_u FROM features where t1 is null and tag_id = global_attr_itr and category_id = cat_id);

	If (acc_prob_u is null) THEN
		acc_prob_u := 0;
	END IF;

	FOR tag_record IN (SELECT * FROM features where tag_id = global_attr_itr and t1 is not null and category_id = cat_id order by t1) LOOP
		FOR i in 1..200 LOOP
			acc_prob_m := acc_prob_m + tag_record.f_given_m / 200.0;
			acc_prob_u := acc_prob_u + tag_record.f_given_u / 200.0;
--			IF (global_attr_itr = 26) THEN
--				Raise Info 'For tag_id = %, at T = %, 1-acc_prob_m = %, and (1-acc_prob_m) / (1-acc_prob_u) = %', global_attr_itr, ( tag_record.t1 + (tag_record.t2 - tag_record.t1) * i / 200.0),  (1-acc_prob_m), (1-acc_prob_m) / (1-acc_prob_u);
--			END IF;
			IF (1-acc_prob_m > abs_perf_threshold and (1-acc_prob_m) / (1-acc_prob_u) > rel_perf_threshold) THEN
				RAISE INFO 'Found threshold at iteration % in [%,%], acc_prob_m = %, acc_prob_u = %', i, tag_record.t1, tag_record.t2,acc_prob_m, acc_prob_u;
				INSERT INTO field_thresholds values (cat_id, global_attr_itr, tag_record.t1 + (tag_record.t2 - tag_record.t1) * i / 200.0);
				EXIT;
			END IF;
		END LOOP;
		IF (select count(*) from field_thresholds where tag_id = global_attr_itr and category_id = cat_id) > 0  THEN
			EXIT;
		END IF;

	END LOOP;

END LOOP;

max_est_dup := 0;

FOR global_attr_itr in SELECT distinct tag_id from learning_attrs LOOP

est_dup:=0;
FOR tag_record IN select distinct tag_id, t1, t2 from features where tag_id = global_attr_itr and category_id = cat_id order by t1 LOOP

IF (tag_record.t1 is null) THEN

SELECT INTO prob_f (SELECT count(*) FROM random_attributes r where r.tag_id = tag_record.tag_id and category_id = cat_id)/
 (select count(*) from random_pairs where category_id = cat_id)::double precision;

 prob_f := 1 - prob_f;

prob_m_given_f:=
(select count(*) from (select cat_id, entity1_id, entity2_id, global_attr_itr from questions
where category_id = cat_id and human_label = 'Yes'
EXCEPT select category_id, entity1_id, entity2_id, tag_id from duplicate_attributes) a)/
(select count(*) from (select  cat_id, entity1_id, entity2_id, global_attr_itr from questions
 where category_id = cat_id
 except select category_id, entity1_id, entity2_id, tag_id from duplicate_attributes) a)::double precision;

ELSE

SELECT INTO prob_f (SELECT count(*) FROM random_attributes r where r.tag_id = tag_record.tag_id and category_id = cat_id and r.similarity >= tag_record.t1 and r.similarity < tag_record.t2)/ (select count(*) from random_pairs where category_id = cat_id)::double precision;

if (exists (select * from duplicate_attributes d
where d.category_id = cat_id and d.tag_id = tag_record.tag_id
and d.similarity >= tag_record.t1 and d.similarity < tag_record.t2)) THEN

prob_m_given_f:=
(select count(*) from questions q, duplicate_attributes d
where q.entity1_id = d.entity1_id and q.entity2_id = d.entity2_id
and q.category_id = cat_id and d.category_id = cat_id and d.tag_id = tag_record.tag_id
and human_label = 'Yes' and d.similarity >= tag_record.t1 and d.similarity < tag_record.t2)/
(select count(*) from duplicate_attributes d
where d.category_id = cat_id and d.tag_id = tag_record.tag_id
and d.similarity >= tag_record.t1 and d.similarity < tag_record.t2)::double precision;

ELSE

prob_m_given_f:=0;

END IF;

END IF;
--Raise info 'Adding % * % to est_prob', prob_f , prob_m_given_f;
est_dup:= est_dup + prob_f * prob_m_given_f;

END LOOP;

max_est_dup := greatest(max_est_dup, est_dup);

END LOOP;

INSERT INTO est_dup_prob values (cat_id, max_est_dup);

END LOOP; --next cat


END;
$$ LANGUAGE plpgsql;


----------------------------------------------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION learn_weights() RETURNS void AS
$$
DECLARE

-- training_mode: 1 = from goby_entity_result, 2 = from entity_clustering
prob_dist_threshold double precision;
est_dup double precision;
bins_count integer;
rel_perf_threshold double precision;
abs_perf_threshold double precision;

min_sim_m double precision;
min_sim_u double precision;
max_sim_m double precision;
max_sim_u double precision;
cur_sim double precision;

prob_s_n_given_m double precision;
prob_s_n_given_u double precision;
prob_s_n double precision;

prob_f_given_m double precision;
prob_f double precision;
prob_f_given_u double precision;

sim_thr_max_likelihood double precision;
next_sim double precision;
tag_record RECORD;
pdf_diff double precision;
m_corr double precision;
u_corr double precision;
acc_prob_f_given_m double precision;
threshold_set bool;
sim_record RECORD;
sim_itr integer;
sim_step integer;
cat_id int;
BEGIN

prob_dist_threshold:= (select to_num(value) from configuration_properties where name='prob_dist_threshold');
bins_count:= (select to_num(value)::int from configuration_properties where name='bins_count');
rel_perf_threshold := (select to_num(value) from configuration_properties where name='rel_perf_threshold');
abs_perf_threshold := (select to_num(value) from configuration_properties where name='abs_perf_threshold');

TRUNCATE field_thresholds;
TRUNCATE features;
TRUNCATE est_dup_prob;

For cat_id in (select distinct category_id from cat_features_tf) LOOP

perform extract_new_data(0, cat_id, 100000);

TRUNCATE duplicate_pairs;
--add duplciates from goby clustering

INSERT INTO duplicate_pairs
select cat_id, la.id, lb.id
from goby_entity_result a, goby_entity_result b, local_entities la, local_entities lb
where a.global_entity_id = b.global_entity_id
AND a.local_entity_id = la.local_id AND b.local_entity_id = lb.local_id
AND la.id < lb.id
AND la.id in ((Select entity_id from data_from_new_source) INTERSECT (select entity_id from entity_cat_mapping where category_id = cat_id))
AND lb.id in ((Select entity_id from data_from_new_source) INTERSECT (select entity_id from entity_cat_mapping where category_id = cat_id));


TRUNCATE duplicate_attributes;

INSERT INTO duplicate_attributes
     SELECT cat_id, dup.entity1_id, dup.entity2_id, q1.tag_id, SUM(q1.freq * q2.freq) AS sim
       FROM duplicate_pairs dup, data_from_new_source_qgrams q1, data_from_new_source_qgrams q2
         WHERE dup.entity1_id = q1.entity_id AND dup.entity2_id = q2.entity_id
        AND q1.tag_id = q2.tag_id  AND q1.qgram = q2.qgram
    GROUP BY dup.entity1_id, dup.entity2_id, q1.tag_id;


INSERT INTO duplicate_attributes
SELECT cat_id, entity1_id, entity2_id, d1.tag_id , - abs(d1.value - d2.value)
FROM duplicate_pairs dup, data_from_new_source_real d1, data_from_new_source_real d2
WHERE dup.entity1_id=d1.entity_id AND dup.entity2_id=d2.entity_id AND d1.tag_id = d2.tag_id;

INSERT INTO duplicate_attributes
(SELECT cat_id, dup.entity1_id, dup.entity2_id, d1.tag_id, 0
FROM duplicate_pairs dup, data_from_new_source d1, data_from_new_source d2
WHERE dup.entity1_id = d1.entity_id AND dup.entity2_id = d2.entity_id AND d1.tag_id = d2.tag_id)
 	EXCEPT ALL (select category_id, entity1_id, entity2_id, tag_id, 0 FROM duplicate_attributes);


TRUNCATE random_pairs;


perform setval('pair_id', 1);
TRUNCATE rand_entity1;
INSERT INTO rand_entity1 (entity_id)
select entity_id from data_from_new_source order by random() limit 50000;

perform setval('pair_id', 1);
TRUNCATE rand_entity2;
INSERT INTO rand_entity2 (entity_id)
select entity_id from data_from_new_source order by random() limit 50000;


INSERT INTO random_pairs
SELECT distinct cat_id, least(a.entity_id, b.entity_id), greatest(a.entity_id, b.entity_id)
FROM rand_entity1 a, rand_entity2 b
WHERE a.id = b.id
AND a.entity_id <> b.entity_id;


TRUNCATE random_attributes;
INSERT INTO random_attributes
     SELECT cat_id, dup.entity1_id, dup.entity2_id, q1.tag_id, SUM(q1.freq * q2.freq) AS sim
       FROM random_pairs dup, data_from_new_source_qgrams q1, data_from_new_source_qgrams q2
        WHERE dup.entity1_id = q1.entity_id AND dup.entity2_id = q2.entity_id
        AND q1.tag_id = q2.tag_id AND q1.qgram = q2.qgram
   GROUP BY dup.entity1_id, dup.entity2_id, q1.tag_id;



INSERT INTO random_attributes
SELECT cat_id, entity1_id, entity2_id, d1.tag_id , - abs(d1.value - d2.value)
FROM random_pairs dup, data_from_new_source_real d1, data_from_new_source_real d2
WHERE dup.entity1_id=d1.entity_id AND dup.entity2_id=d2.entity_id AND d1.tag_id = d2.tag_id;


INSERT INTO random_attributes
(SELECT cat_id, dup.entity1_id, dup.entity2_id, d1.tag_id, 0
FROM random_pairs dup, data_from_new_source d1, data_from_new_source d2
WHERE dup.entity1_id = d1.entity_id AND dup.entity2_id = d2.entity_id AND d1.tag_id = d2.tag_id)
EXCEPT ALL (select category_id, entity1_id, entity2_id, tag_id, 0 FROM random_attributes);
--now for each tag_id, and for each threshold value T, get Pr(S>T|M) and Pr(S>T)

RAISE INFO 'Random data computed';



est_dup := (select count(*) from duplicate_pairs)::double precision / (select count(distinct entity_id) *  (count(distinct entity_id) - 1) / 2 from data_from_new_source) * 100.0;
est_dup := greatest(est_dup, 1e-5);
INSERT INTO est_dup_prob VALUES (cat_id, est_dup);


FOR tag_record IN (Select * from global_attributes) LOOP

RAISE INFO 'Processing tag % , %', tag_record.id, tag_record.name;


	Select into min_sim_m, max_sim_m min(similarity), max(similarity) from duplicate_attributes d where d.tag_id = tag_record.id;
	Select into min_sim_u, max_sim_u min(similarity), max(similarity) from random_attributes r where r.tag_id = tag_record.id;

	RAISE INFO 'Similarity ranges   min_sim_u=%, min_sim_m=%,  max_sim_u=% , max_sim_m=%', min_sim_u, min_sim_m, max_sim_u, max_sim_m;
	IF (min_sim_m is null) THEN
		continue;
	END IF;

	IF (max_sim_u > max_sim_m) THEN
		max_sim_m := max_sim_u;
	END IF;

	--Raise INFO 'Range of the tag % is [%,%]', tag_record.name, min_sim_1, max_sim_1;

	SELECT INTO prob_s_n_given_m (SELECT count(*) FROM duplicate_attributes r where r.tag_id = tag_record.id)/ (select count(*) from duplicate_pairs)::double precision;
	SELECT INTO prob_s_n (SELECT count(*) FROM random_attributes r where r.tag_id = tag_record.id)/ (select count(*) from random_pairs)::double precision;
	--TODO: how to better estimate est_dup from Goby clustering?


	Raise INFO 'Dedup probability for category % is %', cat_id, est_dup;

	prob_s_n_given_m := greatest(1e-9, 1 - prob_s_n_given_m);
	prob_s_n := 1 - prob_s_n;
	prob_s_n_given_u := least(1,greatest(1e-9,(prob_s_n - prob_s_n_given_m * est_dup)/ (1- est_dup)));

	INSERT INTO features values(cat_id, tag_record.id, null, null, prob_s_n_given_m, prob_s_n_given_u);

	IF (min_sim_u < min_sim_m) THEN
		SELECT INTO prob_f (SELECT count(*) FROM random_attributes r where r.tag_id = tag_record.id and r.similarity >= min_sim_u and r.similarity < min_sim_m)/ (select count(*) from random_pairs)::double precision;
		prob_f_given_m := 1e-9;
		prob_f_given_u := prob_f / (1- est_dup);
		INSERT INTO features values(cat_id, tag_record.id, min_sim_u, min_sim_m, prob_f_given_m , prob_f_given_u);
	END IF;

	cur_sim := min_sim_m;
	acc_prob_f_given_m := 0;
	threshold_set := false;
	max_sim_m := max_sim_m + 1e-9;

	WHILE (cur_sim < max_sim_m) LOOP

		next_sim := cur_sim + (max_sim_m - min_sim_m) / bins_count;
		SELECT INTO prob_f_given_m (SELECT count(*) FROM duplicate_attributes r where r.tag_id = tag_record.id and r.similarity >= cur_sim and r.similarity < next_sim)/ (select count(*) from duplicate_pairs)::double precision;
		SELECT INTO prob_f (SELECT count(*) FROM random_attributes r where r.tag_id = tag_record.id and r.similarity >= cur_sim and r.similarity < next_sim)/ (select count(*) from random_pairs)::double precision;

		prob_f_given_m := greatest(1e-9, prob_f_given_m);
		prob_f_given_u := least(1,greatest(1e-9,(prob_f - prob_f_given_m * est_dup)/ (1- est_dup)));
		INSERT INTO features values(cat_id, tag_record.id, cur_sim , next_sim, prob_f_given_m , prob_f_given_u);

		cur_sim := cur_sim + (max_sim_m - min_sim_m) / bins_count;
		EXIT WHEN abs(max_sim_m - min_sim_m) < 1e-6;
	END LOOP;

	SELECT INTO m_corr corr(f_given_m, t1+t2)
	FROM features
	WHERE tag_id  = tag_record.id and category_id = cat_id;

	SELECT INTO u_corr corr(f_given_u, t1+t2)
	FROM features
	WHERE tag_id  = tag_record.id and category_id = cat_id;


	RAISE INFO 'For % : M-corr = %, U-corr = %', tag_record.name, m_corr, u_corr;
		-- compute pdf difference
	SELECT INTO pdf_diff SUM(diff)
	FROM (SELECT abs(f_given_m - f_given_u) as diff
		FROM features
		WHERE tag_id = tag_record.id and category_id = cat_id) a;

	RAISE INFO 'PDF diff for % is %', tag_record.name, pdf_diff;
	IF (pdf_diff < prob_dist_threshold or m_corr < 0 or u_corr > 0) THEN
		DELETE FROM features
		WHERE tag_id = tag_record.id and category_id = cat_id;

		--UPDATE field_types
		--SET threshold = null
		--WHERE tag_id = tag_record.id;
	ELSE
		SELECT ceil(count(*)/200.0) INTO sim_step FROM duplicate_attributes WHERE tag_id = tag_record.id;
		sim_itr := 0;
		FOR sim_record IN (SELECT * FROM duplicate_attributes WHERE tag_id = tag_record.id ORDER BY similarity) LOOP
			sim_itr := sim_itr + 1;
			IF (sim_itr % sim_step <> 0) THEN
				continue;
			ELSE
				prob_f_given_m :=  (SELECT count(*) FROM duplicate_attributes r where r.tag_id = tag_record.id and r.similarity >= sim_record.similarity) / (select count(*) from duplicate_pairs)::double precision;
				SELECT INTO prob_f (SELECT count(*) FROM random_attributes r where r.tag_id = tag_record.id and r.similarity >= sim_record.similarity)/ (select count(*) from random_pairs)::double precision;
				prob_f_given_u := least(1,greatest(1e-9,(prob_f - prob_f_given_m * est_dup)/ (1- est_dup)));

				IF (prob_f_given_m > abs_perf_threshold and prob_f_given_m / prob_f_given_u > rel_perf_threshold) THEN
					RAISE INFO 'Setting threshold of % to %', tag_record.name, sim_record.similarity;

					INSERT INTO field_thresholds values (cat_id,  tag_record.id , sim_record.similarity);

					EXIT;
				END IF;
			END IF;
		END LOOP;

	END IF;

END LOOP;
END LOOP;
END;
$$ LANGUAGE plpgsql;






