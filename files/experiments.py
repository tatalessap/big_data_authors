import datetime

import matplotlib.pyplot as plt
import pandas as pd
import pickle5 as pickle
import os
from scipy import spatial

import pyspark
from pyspark.sql import SQLContext
from pyspark.sql import SparkSession
from pyspark.sql.types import ArrayType, StructField, StructType, StringType, IntegerType
from pyspark.ml.linalg import Vectors


conf = (pyspark.SparkConf().setAppName('test').set("spark.driver.memory", "6g"))
sc = pyspark.SparkContext(conf=conf)
sc.setLogLevel("ERROR")
spark = SparkSession.builder.appName('test').getOrCreate()

sc.addPyFile("graphframes-0.8.1-spark2.4-s_2.11.jar")
from graphframes import *

"""
create the df of papers by folder authors with:
-id
-year 
-list of authors
"""
def create_table_papers(path, name):
    list_of_json = os.listdir(path)
    new_csv = {}
    list_authors = []
    for json in list_of_json:
        df = (spark.read.json(path + str(json))).select('_source')

        papers = [row['_source'] for row in df.collect()]

        for paper in papers:
            if int(paper.id not in new_csv.keys()):
                new_csv[int(paper.id)] = (int(paper.id),
                                          int(paper.year[:4]),
                                          paper.doi,
                                          list(set([int(au.id) for au in paper.authors])))

    new = spark.createDataFrame(new_csv.values(), schema=['id_paper', 'year', 'doi', 'authors'])

    new.toPandas().sort_values(by=['year']).to_csv(name+".csv", index=False)

"""
create boolean covid yes and no
"""
def create_id_papers_bool(path_json, path_csv, name='id_paper_covid_bool'):
    df = spark.read.load(path_csv, format="csv", sep=",", inferSchema="true", header="true")
    ids_plus = [row['id_paper'] for row in df.select('id_paper').collect()]
    doi_plus = [row['doi'] for row in df.select('doi').collect()]
    json = pd.read_json(path_json).transpose()['id'].tolist()

    k = dict()

    for i in range(len(ids_plus)):
        k[ids_plus[i]] = doi_plus[i]

    covid_idYes = set(ids_plus).intersection(set(json))

    covid_idNo = list(set(ids_plus).difference(set(covid_idYes)))

    covid_idYes = list(covid_idYes)

    values_yes = [1] * len(covid_idYes)

    values_no = [0] * len(covid_idNo)

    covid_idYes.extend(covid_idNo)

    values_yes.extend(values_no)

    list_doi = [k[id] for id in covid_idYes]

    df = spark.createDataFrame(zip(covid_idYes, list_doi, values_yes), schema=['id_paper', 'doi', 'covid'])

    df.toPandas().to_csv(name + ".csv", index=False)

"""
**GRAPH**
methods for the creation of the graph
"""

"""
df row selection by year
"""
def get_df_by_one_year(year1, df):
    print("create the df_window")
    q2 = "year = " + str(year1)
    df_window = df.where(q2)
    return df_window


"""
create link of graph
"""
def count_collaborations(df_window):
    print('start count collaborations')
    list_of_list_authors = [eval(row.authors) for row in df_window.select('authors').collect()]
    collaborations = {}
    id_range_authors = set()

    for list_of_authors in list_of_list_authors:
        for author in list_of_authors:
            id_range_authors.add(int(author))
            for collaborator in list_of_authors:  # the list is visited twice to count the collaborations for each author
                if collaborator != author:
                    if (author, collaborator) not in collaborations.keys():
                        collaborations[(int(author), int(collaborator))] = 1
                    else:
                        collaborations[(int(author), int(collaborator))] = collaborations[(int(author), int(collaborator))] + 1
    return collaborations, list(id_range_authors)


"""
create graph with:
- vertices: id authors
- edges: collaborations with authors and number of collaborations
"""
def create_graph(id_range_authors, collaborations):
    print("create graph")

    vertices = spark.createDataFrame(zip(id_range_authors), schema=['id'])

    src, dst = zip(*collaborations.keys())

    edges = spark.createDataFrame(zip(src, dst, collaborations.values()), schema=['src', 'dst', 'number_coll'])

    g = GraphFrame(vertices, edges)

    return g


"""
steps to create the graph
"""
def steps(df, year, limit):
    df_window = get_df_by_one_year(year, df)
    print((df_window.count(), len(df_window.columns)))
    if limit == 0:
        df_slice = df_window
    else:
        df_slice = df_window.limit(limit)
    del df_window
    collaborations, id_range_authors = count_collaborations(df_slice)
    g = create_graph(id_range_authors, collaborations)
    del collaborations
    del id_range_authors

    return g


def save_graph(g, namegraph):
    print(g.edges.show(n=10))
    g.vertices.write.parquet(str(namegraph) + "vertices")
    g.edges.write.parquet(str(namegraph) + "edges")


def load_graph(namegraph):
    sameV = spark.read.parquet(str(namegraph) + "vertices")
    sameE = spark.read.parquet(str(namegraph) + "edges")
    # Create an identical GraphFrame.
    sameG = GraphFrame(sameV, sameE)
    return sameG


def hist_graph(years, y, title):
    fig, ax = plt.subplots()
    plt.bar(list(years), y)  # A bar chart
    plt.xticks(list(years), tuple([str(yea) for yea in years]))
    plt.xlabel('years')
    plt.ylabel('value')
    plt.title(title)
    plt.show()


def visualize_graphs(list_g):
    count_vertex = []
    count_edges = []
    average_degree = []
    density = []

    for y in list_g.keys():
        count_vertex.append((list_g[y].vertices.count()))
        count_edges.append((list_g[y].edges.count()))
        average_degree.append(
            (((list_g[y].degrees).select('degree')).groupBy().sum().collect()[0][0]) / list_g[y].vertices.count())
        density.append(
            ((2 * (list_g[y].edges.count())) / ((list_g[y].vertices.count()) * ((list_g[y].vertices.count()) - 1))))
    print(list_g.keys())
    print(average_degree)
    print(density)

    hist_graph(list_g.keys(), count_vertex, "number of vertices")
    hist_graph(list_g.keys(), count_edges, "number of edges")
    hist_graph(list_g.keys(), average_degree, "average degree")
    hist_graph(list_g.keys(), density, "density")


"""
STRUCT AUTHORS ANALYSIS - COSINE
"""

"""
Create analysis of authors:
- cosine
- number of collaborators for each two year
- number of papers
"""
def create_data_authors_info(authors_collaborations, authors_info, list_couple_years, name_csv):
    data = list()
    for author_id in authors_collaborations:
        row = tuple()

        author = authors_collaborations[author_id]

        if list(author.keys()):
            number_of_collaborators = len(author[list(author.keys())[0]].keys())
        else:
            number_of_collaborators = 0

        row = row + (author_id, authors_info[author_id]['Name'], number_of_collaborators)  # id and name

        previous_two_years_collaborators = [0] * number_of_collaborators

        absolute_collaborators = [0] * number_of_collaborators

        for couple_year in list_couple_years:  # for each year
            year1 = couple_year[0]
            year2 = couple_year[1]
            previous_two_years_collaborators, absolute_collaborators, tuple_year = info_couple_year(
                authors_info[author_id], author, year1, year2, previous_two_years_collaborators, absolute_collaborators,
                number_of_collaborators)
            row = row + tuple_year

        data.append(row)

    schema = ['id', 'name', 'num_Collaborations']

    for years in list_couple_years:
        schema.append('cosine_similarity_' + str(years[0]) + "_" + str(years[1]))
        schema.append('num_collaborations_' + str(years[0]) + "_" + str(years[1]))
        schema.append('gain_collaborators_last_two_years_' + str(years[0]) + "_" + str(years[1]))
        schema.append('gain_collaborators_absolute_' + str(years[0]) + "_" + str(years[1]))
        schema.append('num_papers_' + str(years[0]) + "_" + str(years[1]))

    authors_cosine_and_info = spark.createDataFrame(data, schema=schema)

    authors_cosine_and_info.toPandas().to_csv(name_csv+".csv", index=False)


def info_couple_year(author_info, author, year1, year2, previous_two_years_collaborators, absolute_collaborators,
                     number_of_collaborators):
    n = 1  # position of value of number-collaborations
    all_c = [0] * (number_of_collaborators)
    if year1 not in author.keys() and year2 not in author.keys():  # if the authors didn't write in the year1 and year2, cosine=code
        # no collaborators
        cosine_similarity = 99
        number_of_papers = 0
    elif year1 not in author.keys():  # if the authors didn't write in the year1, cosine=code
        all_c = [x[n] for x in sorted(author[year2].items())]  # number of collaborator only second year
        cosine_similarity = 98
        number_of_papers = author_info['NumPapers'][year2]
    elif year2 not in author.keys():  # if the authors didn't write in the year2, cosine=code
        all_c = [x[n] for x in sorted(author[year1].items())]  # number of collaborator only first year
        cosine_similarity = 97
        number_of_papers = author_info['NumPapers'][year1]
    else:
        vect1 = [x[n] for x in sorted(author[year1].items())]
        vect2 = [x[n] for x in sorted(author[year2].items())]
        zipped_lists = zip(vect1, vect2)
        all_c = [x + y for (x, y) in zipped_lists]  # sum of the two list to count how many collaborators
        x = Vectors.dense(vect1)
        y = Vectors.dense(vect2)
        cosine_similarity=1 - x.dot(y)/(x.norm(2)*y.norm(2))
        number_of_papers = author_info['NumPapers'][year2] + author_info['NumPapers'][year1]

    number_collaborators_two_year = len(all_c) - all_c.count(0)  # if the value is >=1, the collaborator is counted

    if number_collaborators_two_year != 0:
        f = lambda x, y: 1 if (x == 0 and y > 0) else 0
        gain_collaborators_last_two_years = ([f(x, y) for x, y in zip(previous_two_years_collaborators, all_c)]).count(
            1)  # there are new collaboratos?
        gain_collaborators_absolute = ([f(x, y) for x, y in zip(absolute_collaborators, all_c)]).count(1)

    else:
        gain_collaborators_last_two_years = 0
        gain_collaborators_absolute = 0

    previous_two_years_collaborators = all_c
    absolute_collaborators = [x + y for x, y in zip(absolute_collaborators, all_c)]

    return previous_two_years_collaborators, absolute_collaborators, (
        float(cosine_similarity), number_collaborators_two_year, gain_collaborators_last_two_years,
        gain_collaborators_absolute, number_of_papers)  # tuple


"""
Create struct_
- author
    - year1
    - year2
        - collaborator1 = number of collaborations
        - collaborator1 = number of collaborations
"""
def increase_col(id_au, year, id_coll, coll):
    if id_coll in coll[id_au][year].keys():
        coll[id_au][year][id_coll] = coll[id_au][year][id_coll] + 1
    else:
        coll[id_au][year][id_coll] = 1
    return coll


def complete_year(id_au, year, ids_coll, coll):
    for id in ids_coll:
        coll[id_au][year][id] = 0
    return coll

def collaborations_and_info_extraction(authors_collaborators, authors_info, path, list_of_json, ids_paper=[]):
    for autjson in list_of_json:
        collaborators_all = set()

        df = (spark.read.json(path + autjson)).select('_source')

        papers = [row['_source'] for row in df.collect()]

        author_json = int(autjson[:-5])

        del df

        for paper in papers:

            if int(paper.id) in ids_paper or ids_paper == []:

                if author_json not in authors_collaborators.keys():
                    authors_collaborators[author_json] = {}

                year = int(paper.year[:4])
                collaborators = [au for au in paper.authors]

                for collaborator in collaborators:

                    if int(collaborator.id) != author_json:

                        if year not in authors_collaborators[author_json].keys():
                            authors_collaborators[author_json][year] = {}

                        authors_collaborators = increase_col(author_json, year, int(collaborator.id), authors_collaborators)
                        collaborators_all.add(int(collaborator.id))

                    elif int(collaborator.id) not in authors_info.keys():  # it's the id of the author
                        authors_info[author_json] = {'Name': str(collaborator.name), 'NumPapers': {}}

                if year not in authors_info[author_json]['NumPapers'].keys():
                    authors_info[author_json]['NumPapers'][year] = 1
                else:
                    authors_info[author_json]['NumPapers'][year] = authors_info[author_json]['NumPapers'][year] + 1

            for year in authors_collaborators[author_json].keys():
                authors_collaborators = complete_year(author_json, year, list(collaborators_all.difference(authors_collaborators[author_json][year].keys())), authors_collaborators)

    return authors_collaborators, authors_info

def save_struct_authors(authors_collaborators, authors_info, name_authors_collaborators, name_authors_info):
    with open(name_authors_collaborators+'.pickle', 'wb') as handle:
        pickle.dump(authors_collaborators, handle, protocol=pickle.HIGHEST_PROTOCOL)
    with open(name_authors_info+'.pickle', 'wb') as handle:
        pickle.dump(authors_info, handle, protocol=pickle.HIGHEST_PROTOCOL)


def load_struct_authors(name_authors_collaborators, name_authors_info):
    with open(name_authors_collaborators + '.pickle', 'rb') as fp:
        authors_collaborators = pickle.load(fp)

    with open(name_authors_info + '.pickle', 'rb') as fp:
        authors_info = pickle.load(fp)

    return authors_collaborators, authors_info


def mean_column_m(list_m):
    m = set()
    for el in list_m:
        if el <= 1:
            m.add(el)

    print(sum(m) / len(m))
    return sum(m) / len(m)


print("Graph: create")
time= datetime.datetime.now()
print(datetime.datetime.now())

df = spark.read.option("header", True).csv("csv/covid_plus_2015_2020.csv")

print("graph 2019 20000")

g = steps(df, 2019, 20000)

del g
datetime.datetime.now()
print(datetime.datetime.now()-time)


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
