
create or replace function tokenize_text_only (text) returns setof text as
$$
BEGIN
  return query
  select trim(token) as token from (
  select trim(both '{}' from ts_lexize('english_stem', token)::text) as token
    from (
    	 select * from ts_parse('default', $1)
	  where tokid = 1 and length(token) < 100 
	  limit 300
	 ) t
	 ) b
	 WHERE token is not null and trim(token)<>'';
END;
$$ language plpgsql;

create or replace function tokenize_text_only_top_k (value text, attr_id integer, k integer) returns setof text as
$$
BEGIN
  return query
  select token from (
  select distinct trim(both '{} ' from ts_lexize('english_stem', token)::text) as token
    from (
    	select * from ts_parse('default', value)
		where tokid != 12 and tokid!=22 and length(token) < 100 
	 ) t
  ) b, cat_qgrams_idf c
	 WHERE b.token = c.qgram AND tag_id = attr_id
	 order by c.doc_count desc
	 limit k;
END;
$$ language plpgsql;

CREATE OR REPLACE FUNCTION arg_min_hash(text,text) RETURNS text AS 
$$
BEGIN
IF (md5($1) < md5($2)) THEN
	RETURN $1;
ELSE
	RETURN $2;
END IF;
END;
$$ language plpgsql IMMUTABLE STRICT; 

CREATE AGGREGATE hashmin (basetype=text, sfunc=arg_min_hash, stype=text) ;


CREATE OR REPLACE FUNCTION topk(arr anyarray,k int) RETURNS setof anyelement AS 
$$
BEGIN
FOR i in 1..k LOOP
return next arr[i] ;
END LOOP;
return;
END;
$$ language plpgsql IMMUTABLE STRICT; 

CREATE OR REPLACE FUNCTION kth(arr anyarray,k int) RETURNS anyelement AS 
$$
BEGIN
IF (array_length(arr,1) < k) THEN
RETURN arr[array_length(arr,1)];
ELSE
RETURN arr[k];
END IF;

END;
$$ language plpgsql IMMUTABLE STRICT;


DROP TABLE IF EXISTS entity_sample CASCADE;
CREATE TABLE entity_sample (entity_id integer);

DROP TABLE IF EXISTS entity_sample_text_attrs CASCADE;
CREATE TABLE entity_sample_text_attrs (entity_id integer, attr_id integer, attr_value text);

--DROP TABLE IF EXISTS entity_sample_text_attrs_filtered CASCADE;
--CREATE TABLE entity_sample_text_attrs_filtered (entity_id integer, category_id integer, attr_id integer, attr_value text);

DROP TABLE IF EXISTS cat_features_tf CASCADE;
CREATE TABLE cat_features_tf(category_id int, attr_id integer, attr_value text, frequency real);

--DROP TABLE IF EXISTS features_idf CASCADE;
--CREATE TABLE features_idf(attr_id integer, attr_value text, inverse_freq real);


DROP TABLE IF EXISTS cat_tag_values_frequency CASCADE;
CREATE TABLE cat_tag_values_frequency(tag_id integer, value text, tuples_count int);
--CREATE INDEX cat_tag_values_frequency__tag_id_value ON cat_tag_values_frequency(tag_id, md5(value));
--CREATE INDEX cat_tag_values_frequency__freq ON cat_tag_values_frequency(tuples_count);

DROP TABLE IF EXISTS cat_tag_frequency CASCADE;
CREATE TABLE cat_tag_frequency(tag_id integer, tuples_count integer);

DROP TABLE IF EXISTS cat_qgrams_idf CASCADE;
CREATE TABLE cat_qgrams_idf(tag_id integer, qgram text, doc_count double precision);
CREATE INDEX cat_qgrams_idf__tag_id_qgram ON cat_qgrams_idf(tag_id, qgram);


DROP TABLE IF EXISTS sample_features_tf CASCADE;
CREATE TABLE sample_features_tf(entity_id int, attr_id integer, attr_value text, frequency real);


DROP TABLE IF EXISTS source_entity_text_attrs CASCADE;
CREATE TABLE source_entity_text_attrs(entity_id integer, attr_id integer, attr_value text);

DROP TABLE IF EXISTS entity_cat_mapping CASCADE;
CREATE TABLE entity_cat_mapping(entity_id integer, category_id integer, sim double precision, source_id int);
create index entity_cat_mapping__entity_id ON entity_cat_mapping(entity_id );
create index on entity_cat_mapping(source_id);
 
DROP TABLE IF EXISTS source_features_tf CASCADE;
CREATE TABLE source_features_tf(entity_id int, attr_id integer, attr_value text, frequency real);


DROP TABLE IF EXISTS cat_sim_join CASCADE;
CREATE TABLE cat_sim_join (cat1_id int, cat2_id int, similarity double precision);

DROP TABLE IF EXISTS cat_running_time CASCADE;
CREATE TABLE cat_running_time(source_id int, runningtime_ms real, qgrams int);

DROP TABLE IF EXISTS entity_cat_sim;
CREATE TABLE entity_cat_sim(entity_id int, category_id int, sim real);

DROP TABLE IF EXISTS cat_relevant_attrs CASCADE;
CREATE TABLE cat_relevant_attrs(tag_id int);

--INSERT INTO cat_relevant_attrs values (26), (27), (56), (73); 
--INSERT INTO cat_relevant_attrs select id from global_attributes;
--================================================================================================================
/*
CREATE OR REPLACE FUNCTION initial_build_cats()
RETURNS void AS $$
DECLARE 
categories_count int;
BEGIN
categories_count:= 2;

LOOP
update configuration_properties set value = categories_count where name = 'cat_count';
build_categories_features(categories_count>2);

-- now categorize questions and determine recall



-- if alot of false negatives or unclustered tuples, increase K


END LOOP;

END;
$$ LANGUAGE plpgsql;
*/

CREATE OR REPLACE FUNCTION build_categories_features(skip_sampling bool)
RETURNS void AS $$
DECLARE 
cat_id int;
i int;
next_cat_id int;
sum_sim real;
max_cat_id int;
c1_id int;
c2_id int;
sample_size int;
categories_count integer;
BEGIN


sample_size:= (select to_num(value) from configuration_properties where name='cat_sample');
categories_count:= (select to_num(value) from configuration_properties where name='cat_count');

if (not skip_sampling) THEN
-- first, get a sample of entities form local_data
TRUNCATE entity_sample;
INSERT INTO entity_sample
SELECT id FROM local_entities WHERE random() < sample_size::real / (select count(*) from local_entities);

RAISE INFO 'Obtained entity sample, Timestamp : %', (select timeofday());

TRUNCATE entity_sample_text_attrs;
INSERT INTO entity_sample_text_attrs
SELECT s.entity_id, m.global_id, tokenize_text_only(d.value) as token
FROM entity_sample s, local_data d, attribute_mappings m
WHERE s.entity_id = d.entity_id and d.field_id=m.local_id and  m.global_id in (select tag_id from cat_relevant_attrs);

RAISE INFO 'Obtained entity sample attributes , Timestamp : %', (select timeofday());

TRUNCATE cat_tag_frequency;
INSERT INTO cat_tag_frequency
SELECT attr_id, count(distinct entity_id) AS tuples_count
FROM entity_sample_text_attrs
GROUP BY attr_id;

RAISE INFO 'Computed tag frequency, Timestamp : %', (select timeofday());

TRUNCATE cat_qgrams_idf;
INSERT INTO cat_qgrams_idf(tag_id, qgram, doc_count)
SELECT attr_id, attr_value, count(distinct entity_id)/f.tuples_count::double precision 
FROM entity_sample_text_attrs e, cat_tag_frequency f
WHERE e.attr_id = f.tag_id
GROUP BY attr_id,attr_value, f.tuples_count
HAVING count(distinct entity_id)/f.tuples_count::double precision between 0.001 and 0.5;

RAISE INFO 'Computed q-grams IDFs. Timestamp : %', (select timeofday()) ;

TRUNCATE sample_features_tf;

INSERT INTO sample_features_tf
SELECT entity_id, e.attr_id, e.attr_value, count(*) * log (1.0 / doc_count)
FROM entity_sample_text_attrs e, cat_qgrams_idf f
WHERE e.attr_id = f.tag_id and e.attr_value = f.qgram
GROUP BY entity_id, e.attr_id, e.attr_value, doc_count;

RAISE INFO 'Computed sample TF, Timestamp : %', (select timeofday());

-- normalize 

UPDATE sample_features_tf f
SET frequency = frequency / norm
FROM 
(SELECT entity_id , |/sum(frequency * frequency) as norm
FROM sample_features_tf 
GROUP BY entity_id) n
WHERE n.entity_id = f.entity_id;

RAISE INFO 'Normalized sample TF, Timestamp : %', (select timeofday());

END IF;


--choose initial k centroids
TRUNCATE cat_features_tf;

FOR i in 1..categories_count LOOP

IF (select count(*) from cat_features_tf)=0 THEN
	INSERT INTO cat_features_tf(category_id, attr_id, attr_value, frequency)
	SELECT i, attr_id, attr_value, frequency 
	FROM sample_features_tf
	WHERE entity_id = (select entity_id from (select entity_id from sample_features_tf limit 10000) a order by random() limit 1);	

ELSE
	TRUNCATE entity_cat_sim;
	INSERT INTO	entity_cat_sim(entity_id, category_id, sim)
	SELECT entity_id, category_id, sum(s.frequency * f.frequency)
	FROM sample_features_tf s, cat_features_tf f
	WHERE s.attr_id = f.attr_id and s.attr_value = f.attr_value
	GROUP BY entity_id, category_id;

	SELECT into next_cat_id entity_id
	FROM entity_cat_sim
	GROUP BY entity_id
	ORDER BY max(sim) + 0.07 * random()
	limit 1;
	
	INSERT INTO cat_features_tf(category_id, attr_id, attr_value, frequency)
	SELECT i, attr_id, attr_value, frequency
	FROM sample_features_tf
	WHERE entity_id = next_cat_id;

END IF;
	RAISE INFO 'obtained initial centroid #%, Timestamp = %',i, (select timeofday());
END LOOP;


--now iterate

FOR i in 1..10 LOOP 
	-- compute distances
	TRUNCATE entity_cat_sim;
	INSERT INTO	entity_cat_sim(entity_id, category_id, sim)
	SELECT entity_id, category_id, sum(s.frequency * f.frequency)
	FROM sample_features_tf s, cat_features_tf f
	WHERE s.attr_id = f.attr_id and s.attr_value = f.attr_value
	GROUP BY entity_id, category_id;
	
	-- recompute centroids
	TRUNCATE cat_features_tf;
	INSERT INTO cat_features_tf 
	SELECT category_id, attr_id, attr_value, sum(frequency)
	FROM
		(SELECT entity_id, topk(array_agg(category_id order by sim desc),1) as category_id
		FROM entity_cat_sim
		GROUP BY entity_id) a, sample_features_tf b
	WHERE a.entity_id = b.entity_id
	GROUP BY category_id , attr_id, attr_value;
	
	-- keep the top-200 features for each category
	DELETE FROM cat_features_tf
	WHERE (category_id, attr_id || '__' || attr_value) not in 
	(SELECT category_id, topk(array_agg(attr_id || '__' || attr_value order by frequency desc),300)
	FROM cat_features_tf
	GROUP BY category_id);
	
	-- renormalise
	UPDATE cat_features_tf f
	SET frequency = frequency / norm
	FROM 
	(SELECT category_id , |/sum(frequency * frequency) as norm
	FROM cat_features_tf 
	GROUP BY category_id) n
	WHERE n.category_id = f.category_id;

	SELECT into sum_sim sum(maxsim)
	FROM (SELECT entity_id, max(sim) as maxsim
		  FROM entity_cat_sim
		  GROUP BY entity_id) a;
	
	Raise info 'iteration #% done. current sum_sim = %, TimeStamp=%' , i, sum_sim, (select timeofday());
	
END LOOP;

LOOP 
	TRUNCATE cat_sim_join;
	INSERT INTO cat_sim_join (cat1_id, cat2_id, similarity)
	SELECT  a.category_id, b.category_id , sum(a.frequency * b.frequency)
	FROM cat_features_tf a, cat_features_tf b
	WHERE a.category_id < b.category_id AND a.attr_id=b.attr_id and a.attr_value = b.attr_value
	GROUP BY a.category_id, b.category_id
	HAVING sum(a.frequency * b.frequency) > 0.5;

	IF ((select count(*) from cat_sim_join) = 0) THEN 
		EXIT;
	END IF;
	
	SELECT INTO c1_id, c2_id cat1_id, cat2_id
	FROM cat_sim_join
	ORDER BY  similarity desc limit 1;
	
	--merge	
	max_cat_id := (select max(category_id) from cat_features_tf);

	RAISE INFO 'merging % and % into %', c1_id, c2_id, (max_cat_id +1);
	
	INSERT INTO cat_features_tf
	SELECT max_cat_id + 1, attr_id, attr_value , sum(frequency)
	FROM cat_features_tf
	WHERE category_id in (c1_id, c2_id)
	GROUP BY attr_id, attr_value;
	
	DELETE FROM cat_features_tf WHERE category_id in (c1_id, c2_id);
	
	UPDATE cat_features_tf f
	SET frequency = frequency / norm
	FROM 
	(SELECT category_id , |/sum(frequency * frequency) as norm
	FROM cat_features_tf 
	GROUP BY category_id) n
	WHERE n.category_id = f.category_id and n.category_id = max_cat_id + 1;

END LOOP;

END;
$$ LANGUAGE plpgsql;





CREATE OR REPLACE FUNCTION cat_entity_source(new_source_id int)
RETURNS void AS $$
DECLARE 
k int;
BEGIN

k:= (select to_num(value) from configuration_properties where name='cat_k');

TRUNCATE source_entity_text_attrs;

IF (new_source_id >0) THEN
	INSERT INTO source_entity_text_attrs
	SELECT entity_id, a.tag_id, token 
	FROM (SELECT d.entity_id, m.global_id as tag_id, tokenize_text_only(d.value) as token
	  FROM local_entities e, local_data d, attribute_mappings m
WHERE d.field_id=m.local_id AND e.id = d.entity_id AND e.source_id = new_source_id) a, cat_qgrams_idf i
	WHERE a.tag_id = i.tag_id and token=qgram;
ELSE
	INSERT INTO source_entity_text_attrs
	SELECT entity_id, a.tag_id, token 
	FROM (SELECT d.entity_id, m.global_id as tag_id, tokenize_text_only(d.value) as token
	  FROM local_data d, attribute_mappings m
	  WHERE d.field_id=m.local_id) a, cat_qgrams_idf i
	WHERE a.tag_id = i.tag_id and token=qgram;
END IF;

RAISE INFO 'extracted source entities';


TRUNCATE source_features_tf;

INSERT INTO source_features_tf
SELECT entity_id, e.attr_id, e.attr_value, count(*) * log (1.0 / doc_count)
FROM source_entity_text_attrs e, cat_qgrams_idf f
WHERE e.attr_id = f.tag_id and e.attr_value = f.qgram
GROUP BY entity_id, e.attr_id, e.attr_value,doc_count;

RAISE INFO 'extracted source features tfs';

UPDATE source_features_tf f
SET frequency = frequency / norm
FROM 
(SELECT entity_id , |/sum(frequency * frequency) as norm
FROM source_features_tf 
GROUP BY entity_id) n
WHERE n.entity_id = f.entity_id;

RAISE INFO 'normalization done';

--now join

INSERT INTO entity_cat_mapping
SELECT entity_id, category_id, sum(s.frequency * f.frequency), new_source_id
FROM source_features_tf s INNER JOIN cat_features_tf f ON (s.attr_id = f.attr_id and s.attr_value = f.attr_value)
GROUP BY entity_id, category_id;

RAISE INFO 'join done';
-- TODO : detect null categorization and put in a single cluster 

--TODO: what if they all have the same similairy? 

DELETE FROM entity_cat_mapping e
USING
(select entity_id, kth(array_agg(sim order by sim desc),k) as threshold
FROM entity_cat_mapping e
GROUP BY entity_id) a
WHERE a.entity_id = e.entity_id and e.sim < threshold;

--now create new cats for tuples unassigned to cats


--return (select count(*) from source_entity_text_attrs);

END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION cat_all_sources()
RETURNS void AS $$
DECLARE 
cur_source int;
StartTime timestamptz;
EndTime timestamptz;
Delta real;
i int;
sources_count int;
correct_cats int;
entity_count int;
qgrams int;
BEGIN

TRUNCATE entity_cat_mapping;

select into sources_count count(*) from local_sources;
i := 1;

--FOR cur_source in (select source_id from doit_data group by source_id order by count(*) limit sources_limit offset sources_offset) LOOP
FOR cur_source in (select id from local_sources) LOOP
	StartTime := clock_timestamp();
	perform cat_entity_source(cur_source);
	EndTime := clock_timestamp();
	Delta :=  extract(epoch from EndTime) - extract(epoch from StartTime) ;
	RAISE INFO 'Source % (% of %) done. Duration in millisecs=%',cur_source, i, sources_count, Delta;
	INSERT INTO cat_running_time values(cur_source, delta, null);
	i := i+1;
 
END LOOP;

END;
$$ LANGUAGE plpgsql;


