# Betweenness analysis and 15min City index

This readme contains all information to the betweeness centrality analysis with openrouteservice and create the 15min City index

TOC Steps overviewOverview

<!-- TOC -->

- [Setup openrouteservice locally via docker](#setup-openrouteservice-locally-via-docker)
    - [Get the openrouteservice image which contains functions to export the weighted graph](#get-the-openrouteservice-image-which-contains-functions-to-export-the-weighted-graph)
    - [Download and alter the docker-compose.yml from openrouteservice github](#download-and-alter-the-docker-composeyml-from-openrouteservice-github)
    - [Prepare pbf for all cities](#prepare-pbf-for-all-cities)
        - [Mannheim](#mannheim)
        - [Barcelona](#barcelona)
        - [Merge the pbfs](#merge-the-pbfs)
        - [Run the openrouteservce docker](#run-the-openrouteservce-docker)
    - [Check if the graph is build](#check-if-the-graph-is-build)
    - [Alter the ORS config file](#alter-the-ors-config-file)
- [Setup input Greenspaces inputdata](#setup-input-greenspaces-inputdata)
- [Setup R](#setup-r)
- [Run the analysis](#run-the-analysis)
    - [Data preparation](#data-preparation)
    - [Centrality analysis](#centrality-analysis)
    - [Aggregations](#aggregations)

<!-- /TOC -->




## Setup openrouteservice locally via docker 

Setup ORS for centrality analysis for walking profiles for the following cities:

* Mannheim & Ludwigshafen
* Barcelona


### Get the openrouteservice image which contains functions to export the weighted graph

The main repo of openrouteservice does not yet include functionality to export its graph, that's why we have to checkout the feature branch and built the docker image locally.
```
git clone https://github.com/GIScience/openrouteservice.git
cd openrouteservice
git checkout feature/export-endpoint
```

docker build . -t openrouteservice/openrouteservice:graph_export

### Download and alter the docker-compose.yml from openrouteservice github
https://github.com/GIScience/openrouteservice/blob/master/docker/docker-compose.yml

### Prepare pbf for all cities

#### Mannheim

```
wget http://download.geofabrik.de/europe/germany-latest.osm.pbf                                  
osmium extract -b 8.256,49.363,8.669,49.604 germany-latest.osm.pbf -o osm_file_ma.pbf --overwrite     
```

#### Barcelona

```
wget http://download.geofabrik.de/europe/spain/cataluna-latest.osm.pbf                               
osmium extract -b 1.501,41.04,2.549,41.751 cataluna-latest.osm.pbf -o osm_file_bc.pbf --overwrite     
```

#### Merge the pbfs

`osmium merge osm_file_ma.pbf osm_file_bc.pbf -o osm_file.pbf --overwrite`


#### Run the openrouteservce docker

`ORS_UID=${UID} ORS_GID=${GID} docker-compose up`

### Check if the graph is build

http://localhost:12345/ors/v2/health

### Alter the ORS config file

By default only car profiles are activated.
Edit the config file located at `conf/ors-config.json`
Add "walking" in the array `active` in line 94:

```
"init_threads": 1,
"attribution": "openrouteservice.org, OpenStreetMap contributors",
"elevation_preprocessed": false,
"profiles": {
  "active": [
    "walking"
  ],

```
if you are interested in cycling and car profiles you can add "bike-regular" and "car" as well separated by a comma.



## Setup input Greenspaces inputdata 

Urban green space data used within the scope of this project is based on existing research and methods by Christina Ludwig.

The source code to produce the *urban greenness polygons* can be found here: [https://github.com/redfrexx/green_index](https://github.com/redfrexx/green_index)

Behind the following link you find geopackages for Mannheim and Barcelona preprocessed:

[heibox link](https://heibox.uni-heidelberg.de/d/af033f338e8446ee9ec2/)

make sure to put them in the following path `project_folder/data/greenness`

## Setup R

R is used with the version `4.2.1` on a Ubuntu 22.04 OS. The main libraries comprise: 

```R
c("tidyverse","sf","sfnetworks","geojsonsf")
```

In the folder root folder of this repository you find a R project file `gree_15min_city.Rproj` which make path handling easy. 

## Run the analysis

In the `src` folder are three scripts located:

- `prepare_aoi_pts.R`
- `centrality_calc.R`
- `postprocess_aggregation`

in the subfolder `aux/` you find additional scripts with helper / utils functions to conveniently download OpenStreetMap data and extract the routing graph from openrouteservice.

- `download_ohsome.R` provides you with a function to fire requests against the endpoints of the [ohsome api](https://api.ohsome.org)
- `centrality_utils.R` provides you with functions to extract a routing graph and parse it to R ready sf dataframe and sfnetwork classes

### Data preparation
We start with `prepare_aoi_pts.R` which creates the AOI boundaries and neighborhood locations.

1. Based on the extents of the urban green polygons we define our city AOI boundaries.
2. We request landuse data from OpenSteetMap to be erased from our AOI boundary which we estimate to be not inhabited with the following filter: `landuse in (industrial,forest,farmland,meadow,cemetery,grassland,grass,railway) or natural in (beach,water, scrub, wood) or leisure=marina"`
3. Within the resulting area we regular distribute circular locations with a diameter of 300 Meters. This we define as a walkable neighborhood
4. Results of this script will be saved to `data/input/` as these are the inputs for the subsequents scripts.

### Centrality analysis

The centrality analysis is executed via the script `centrality_calc.R`.

1. Based on the defined AOIs service destination are extracted from OpenStreetMap. The script can consume any tag filter. We defined a specific set of 5 *topics* and 9 *subtopics* which represent essential services. The topics are defined in `data/topics.json`
2. The AOI is then also used to extract a routing graph from openrouteservice. The graph comes as a list of nodes and edges with ids and weights. Helper functions parse it to sf data.frames and sfnetwork classes
3. The sfnetwork representation fo the graph is used within the `sfnetwork` framework to calculate shortest paths to the closest 3 service provision pois. The segments used for the trips are then aggregated. 
4. The output is the network of the city AOI with scores per segment how often it is used as a result of the simulation. We also store the distance to the closest service provision pois for each neighborhood to calculate the 15min city index on neighborhood level later on.
5. Results are saved to `data/centrality_layers`

The analysis is repeated for every subtopic, creating a separate output.

### Aggregations

Post process aggregations on neighborhood and segment level are executed within `postprocess_aggregation.R`

THis script consecutively uses the outputs of `centrality_calc.R`. All subtopic centrality by segment outputs are aggregated in the first part of the script.

The second part imports the neighborhoods and merges all subtopics into one data frame. Based on walking speeds differentiated by age group the minimum distance to the closest subtopic poi is evaluated whether reachable within 15 minutes or not. This binary indicator is then aggregated across the subtopics. The highest score for a neighborhood given the 9 subtopics therefore is 9.

Final output of the betweenness centrality and 15minute city index analysis are:

`<AOI identifier>_graph_centrality.gpkg`

`<AOI identifier>_15mc_index.gpkg`

These are then further used in the python workflow to add greenness to the segments and feed both datasets into visualization.