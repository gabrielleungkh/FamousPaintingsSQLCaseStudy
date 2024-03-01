
import pandas as pd
from sqlalchemy import create_engine

# Using SQLAlchemy, create an engine as a starting point for using DBAPI tools
# I am learning SQL with PostgreSQL
conn_string = 'postgresql+psycopg2://username:password@localhost/painting'
db = create_engine(conn_string)
conn = db.connect()

# Iterate over all csv files in the Famous Paintings dataset and first load each csv into a pandas dataframe
# Then use the .to_sql function in pandas to load each dataset into the postgres database
files = ['artist', 'canvas_size', 'image_link', 'museum_hours', 'museum', 'product_size', 'subject', 'work']

for file in files:
    df = pd.read_csv(f'FILEPATH\\{file}.csv')
    df.to_sql(file, con=conn, if_exists='replace', index=False)
