CREATE OR REPLACE TABLE vdt_silver.osm_segments AS
SELECT
  CONCAT(u, '-', v, '-', `key`) AS segment_id,
  u AS from_node,
  v AS to_node,
  SAFE_CAST(REGEXP_EXTRACT(osmid, r'\d+') AS INT64) AS osm_way_id,
  name,
  REGEXP_EXTRACT(highway, r'[a-z_]+') AS highway_class,
  SAFE_CAST(REGEXP_EXTRACT(maxspeed, r'\d+') AS INT64) AS speed_limit_kmh,
  SAFE_CAST(REGEXP_EXTRACT(lanes, r'\d+') AS INT64) AS lanes,
  oneway = 'True' AS oneway,
  SAFE_CAST(length AS FLOAT64) AS length_m,
  ST_GEOGFROMTEXT(geom_wkt) AS geom,
  source, ingested_at, 'reference' AS record_type
FROM vdt_bronze.osm_edges_raw;

CREATE OR REPLACE TABLE vdt_silver.osm_intersections AS
SELECT
  osmid AS node_id,
  ST_GEOGPOINT(SAFE_CAST(x AS FLOAT64), SAFE_CAST(y AS FLOAT64)) AS geom,
  IFNULL(highway LIKE '%traffic_signals%', FALSE) AS has_signal,
  source, ingested_at, 'reference' AS record_type
FROM vdt_bronze.osm_nodes_raw;
