# Head ---------------------------------
# Purpose: Extract a graph with fastest routing weights, use it in sfnetworks to simulate routes from defined neighborhood locations to the closest service points. Aggregate routes/trips by segment and save the distance to the closest service point for each neighborhood location. This is done by each (Sub)topic
# author: Marcel Reinmuth & Charles Hatfield
#
#
# 1 Libraries ---------------------------------
library(tidyverse)
library(sf)
library(tictoc)
library(rjson)


source("src/aux/download_ohsome.R") # script to ease OSM data extraction via the ohsome-api
source("src/aux/centrality_utils.R") # script


## 1.1 Setup ---------------------------------

aoi <- "ma" # aoi name short
aoi_long <- "mannheim" # aoi name long
utm <- 32632 # EPSG of a metric CRS, e.g. UTM

topic.json <- "data/topics.json"

# 2 Input data ---------------------------------

## 2.1 AOI + UOA ---------------------------------
aoi_geom <- st_read(paste0("aoi/",aoi,"_aoi.gpkg"))
aoi_geom_reduced <- st_read(paste0("aoi/",aoi,"_aoi_reduced.gpkg"))
nb_pts <- st_read(paste0("aoi/",aoi,"_origin_pts.gpkg"))


## 2.2 OSM POI ---------------------------------
# get topics and subtopics from the json file. The json is structured as array and one subtopic is represented as one object
topics <- jsonlite::fromJSON(topic.json)

# check available topics

# choose the first: education, schools
topic <- topics[1,1]
subtopic <- topics[1,2]
tag_filter <- topics[1,3]


#retrieve pois from osm via ohsome
poi <- getOhsomeObjects(
  sf_boundary = aoi_geom |> st_buffer(500) |> st_transform(4326),
  filter_char = tag_filter,
  internal = FALSE,
  to_time = "2022-10-01",
  props = "metadata",
  big = F,
  type = "centroid",
  cut=F
)

# remove all attributes but add an id
poi <- poi |> mutate(id=seq(1,nrow(poi))) |> select(id)

# 3 Graph prep ---------------------------------
# This function retrieves you an sf df and sfnetwork representation of a routing graph extracted from the openrouteservice https://openrouteservice.org/
# [[1]]: sf data frame
# [[2]] sfnetwork
graph_pedestrian <- process_graph(
    host="0.0.0.0", # host on which openrouteservice running
    port=12345, # port on which tomcat/openrouteservice is listening
    aoi_bbox=st_bbox(aoi_geom |> st_buffer(500)|> st_transform(4326)), # openrouteservice works with WGS84 / geog. coords. define the aoi where to export the nodes and edges
    aoi=aoi_geom |> st_transform(4326), # TODO rework this param
    profile="foot-walking", # which routing profile shall the graph be based on: pedestrian-walking, driving-car, cycling?
    no_cores=8 # cores spare to run the conversion from list of nodes, edges to df to sf.df
    )

# The following loop iterates over the neighborhood/origin pts (e.g. in Mannheim). Using the extracted openrouteservice graph in sfnetwork we calculate the shortest distance to the selected pois (e.g. schools). The minimum distance is saved as an indicator for 15 min city readiness. The trips taken to each of three pois is aggregated on a segment level to determine the importance of segments.

tic("neighborhood to poi betweenness centrality")
# what are the 3 closest poi?
#initialize dist column for neighborhood pts
nb_pts$poi_dist <- NA
colnames(nb_pts)[3] <- paste0('dist_to_', subtopic)

for (i in 1:nrow(nb_pts)) {
  i <- 1

  first_origin_pt <- nb_pts[i,] # select point by idx
  dist <- st_distance(first_origin_pt, poi |> st_transform(utm), by_element = T) # calc distance to the pois

  # select the closest 3 service points
  poi_in_range <- poi |>  mutate(dist=dist) |> top_n(n=-3, dist)

  # save the minimum distance
  nb_pts[i,3] <- poi_in_range$dist |> min() |> as.integer()

  # run betweenness centrality for the nieghborhood and the closest 3 service pois
  temp_poi_centrality <- targeted_centrality(
    net = graph_pedestrian[[2]],
    src.pts = first_origin_pt |>  st_transform(4326),
    dst.pts = poi_in_range,
    no_cores = 1) # one core is engough, the function is built to be able to receive multiple origins and destinations, but we will use only one origin and 3 destinations now.

  # store / append the result
  if (i == 1) {
    poi_centrality <- temp_poi_centrality
  } else {
    poi_centrality <- rbind(poi_centrality, temp_poi_centrality)
  }

  # every 100th iteration aggregate the trips per segment segment (simple sum)
  # and create some output on the progress
  if (i %% 100 == 0) {
    print(paste0("Current iteration: ", i, "/", nrow(nb_pts)))
    poi_centrality <- poi_centrality |>
      dplyr::group_by(from, to, toId, fromId, weight, unidirectId, bidirectId) |>
      summarize(centrality = sum(centrality),  .groups = "keep")
  }

}
toc()


if (!dir.exists("data/centrality_layers")) {
  dir.create("data/centrality_layers", recursive = T)
}

# write outputs for aggregated trips by segment as sf df / gpkg
# and neighborhood / origin pts with min dist attribute
st_write(poi_centrality, paste0("data/centrality_layers/",aoi,"_", subtopic, "_centrality.gpkg"), append=F)
st_write(nb_pts, paste0("data/centrality_layers",aoi,"_origin_pts_", subtopic, ".gpkg"), append=F)
# write out the the original graph with all segments
st_write(ma_graph_pedestrian[[1]], paste0("data/",aoi,"_graph_pedestrian.gpkg"), append=F)
