from authors_analysis.py import *


time=datetime.datetime.now()
print(datetime.datetime.now())
authors_collaborators, authors_info = load_struct_authors('authors_collaborators', 'authors_info')
list_couple_years =[(2015, 2016),
                   (2016, 2017),
                   (2017, 2018),
                   (2018, 2019),
                   (2019, 2020)]
create_data_authors_info(authors_collaborators, authors_info, list_couple_years, name_csv="data_all")
print(datetime.datetime.now())
print(datetime.datetime.now()-time)
