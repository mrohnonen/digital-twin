import os
import osmnx as ox
import pandas as pd
from google.cloud import bigquery

project = os.environ['PROJECT_ID']
lat, lon = float(os.environ['CENTER_LAT']), float(os.environ['CENTER_LON'])
radius = int(os.environ['RADIUS_M'])

def text(v):
    return None if v is None or (isinstance(v, float) and v != v) else str(v)

def frame(gdf, need):
    df = gdf.reset_index()
    for c in need:
        if c not in df.columns:
            df[c] = None
    df['geom_wkt'] = df.geometry.to_wkt()
    df = df.drop(columns='geometry')
    for c in df.columns:
        df[c] = df[c].map(text)
    df['source'] = 'osm via osmnx'
    df['ingested_at'] = pd.Timestamp.now(tz='UTC')
    return df

G = ox.graph_from_point((lat, lon), dist=radius, network_type='drive')
nodes, edges = ox.graph_to_gdfs(G)
bq = bigquery.Client(project=project)
jobs = (('osm_nodes_raw', frame(nodes, ['highway'])),
        ('osm_edges_raw', frame(edges, ['name', 'highway', 'maxspeed', 'lanes', 'oneway'])))
for name, df in jobs:
    schema = [bigquery.SchemaField(c, 'TIMESTAMP' if c == 'ingested_at' else 'STRING') for c in df.columns]
    cfg = bigquery.LoadJobConfig(schema=schema, write_disposition='WRITE_TRUNCATE')
    bq.load_table_from_dataframe(df, f'{project}.vdt_bronze.{name}', job_config=cfg).result()
    print(name, len(df))
