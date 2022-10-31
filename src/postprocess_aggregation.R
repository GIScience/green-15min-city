# Head ---------------------------------
# purpose: Aggregate trip scores / utilization by segment and 15min city readiness by neighborhood location
# author: Charlie Hatfield, Marcel Reinmuth
#
#
# 1 Libraries ---------------------------------
library(tidyverse)
library(sf)
library(tictoc)
library(mapview)

# 2 setup ---------------------------------

aoi <- "ma"

# 3 Aggregations ---------------------------------
## 3.1 betweenness centrality on segment level ---------------------------------

# read in all subtopic centrality scores by segments but without geometry
input_segments <- list.files("centrality_layers", pattern = paste0("^",aoi,".*centrality.gpkg"), full.names = T)
input_segments <- lapply(input_segments, FUN = function(x) {
  y <- st_read(dsn=x, quiet=T)
  y <- y |> st_drop_geometry() |> tibble()
  return(y)})
# bind all together
df.big <- do.call(rbind, input_segments)

# sumup centrality
df.small <- df.big |> group_by(toId, fromId) |>
  summarize(centrality = sum(centrality), .groups = "keep") |>
  ungroup()

graph_pedestrian <- st_read(paste0("data/", aoi,"_graph_pedestria.gpkg"), quiet=T)

graph_scores <- left_join(graph_pedestrian, df.small, by=c("toId", "fromId"))

# add min max normalizaion
graph_scores <- graph_scores |> mutate(
  centrality_rel = ( centrality - min(jj$centrality, na.rm=T) ) / (max(jj$centrality, na.rm=T) - min(jj$centrality, na.rm=T))
)


## 3.2 15min idx by distances on neighborhood level  ---------------------------------

# read in all neighboorhood pts without geom
input_pts_files <- list.files("centrality_layers", pattern = paste0("^",aoi,".*origin_pts.*.gpkg"), full.names = T)
input_pts <- lapply(input_pts_files, FUN = function(x) {
  y <- st_read(dsn=x, quiet=T)
  y <- y |> st_drop_geometry() |> tibble()
  y <- y |> select(-id) # remove id to avoid duplicates
  return(y)})

df.long <- do.call(cbind, input_pts) |> tibble() |> rowid_to_column("id")

# There are different walking speeds for different ages
# Montufar et al. 2007 found that for younger adults 1.2 m/s would be appropriate but this speed would exclude
# 40% of older adults. Therefore they recommend a value of 0.91 m/s for older adults which would only exclude the
# slowest 10% of older adults. Toor et al. 2001 found that walking speeds of young children are slower than adults
# but still faster than older adults at 1.1 m/s. For most ages children are comparable to adults in walking speed.
# Montufar et al. DOI: 10.3141/2002-12
# Toor et al. DOI: 10.4271/2001-01-0897

# define speeds per age group
adult_speed <- 15 * 60 * 1.2
child_speed <- 15 * 60 * 1.1
elderly_speed <- 15 * 60 * 0.91

# Loop to convert dist to time and convert that to binary scores to make a 15mc index
mc_index <- df.long
for (i in colnames(df.long)) {

#  i <- colnames(df.long)[2]

  if (startsWith(i, "dist_to") == TRUE) {

    column_name <- str_split(i, "_to_")[[1]][2]
    column_name1 <- paste0(column_name, "_15min_adult")
    column_name2 <- paste0(column_name, "_15min_child")
    column_name3 <- paste0(column_name, "_15min_elderly")


    mc_index <- mc_index |>
      mutate(checkname1 = round(mc_index[,i] / adult_speed, 2),
             checkname2 = round(mc_index[,i] / child_speed, 2),
             checkname3 = round(mc_index[,i] / elderly_speed, 2))

    mc_index$checkname1 <- case_when(mc_index$checkname1 < 1 ~ 1,
                                     TRUE ~ 0)

    mc_index$checkname2 <- case_when(mc_index$checkname2 < 1 ~ 1,
                                     TRUE ~ 0)

    mc_index$checkname3 <- case_when(mc_index$checkname3 < 1 ~ 1,
                                     TRUE ~ 0)


    colnames(mc_index)[colnames(mc_index) == "checkname1"] <- column_name1
    colnames(mc_index)[colnames(mc_index) == "checkname2"] <- column_name2
    colnames(mc_index)[colnames(mc_index) == "checkname3"] <- column_name3

  }
}


index_score_child <- mc_index %>%
  select(contains("child")) %>%
  transmute(index_score_child = rowSums(., na.rm = TRUE))

index_score_elderly <- df.long %>%
  select(contains("adult")) %>%
  transmute(index_score_adult = rowSums(., na.rm = TRUE))

index_score_elderly <- df.long %>%
  select(contains("elderly")) %>%
  transmute(index_score_elderly = rowSums(., na.rm = TRUE))

# read one gpkg, dont drop geom
first_file_w_geom <- st_read(input_pts_files[[1]], quiet=T)


mc_index <- cbind(index_score_adult, index_score_child, index_score_elderly, first_file_w_geom) |> tibble() |> st_as_sf()

# 4 output  ---------------------------------

# write outputs
# aggregated segments
st_write(graph_scores, paste0(aoi,"_graph_centrality.gpkg"), append=F)
# aggregated neighborhoods

#write gpkg
st_write(mc_index, paste0(aoi,"_15mc_index.gpkg"), append=F)
