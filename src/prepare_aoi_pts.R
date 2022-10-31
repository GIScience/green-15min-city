# Head ---------------------------------
# purpose: Script to define AOIs and neighborhood sampling.
# First create an AOI based on the greenness polygons data's convex hull. Get OpenStreetMap landuse data which is representing non-residential areas and erase it from the AOI. In the resulting area the Neighborhood locations are sampled.
# author: Marcel Reinmuth
#
#
# 1 Libraries ---------------------------------
library(tidyverse)
library(sf)
source("src/aux/download_ohsome.R") # script to ease OSM data extraction via the ohsome-api

# 1.1 setup -------------------------

aoi <- "ma" # aoi name short
aoi_long <- "mannheim" # aoi name long
utm <- 32632 # EPSG of a metric CRS, e.g. UTM
neighborhood_radius <- 150 # control the size of neighboorhods, this will affect the amount of neighborhood locations to be sampled in the area of interest.

# 2 Main ---------------------------------

# load the greenness polygons transform to metric CRS and create a convex hull
aoi_geom <- st_read(paste0("data/greenness/",aoi,"_greenness.gpkg"),quiet=T) |>
  st_transform(utm) |> st_make_valid() |>
  st_combine() |> st_convex_hull()

if (aoi=="bc") {
  # The AOI for the greenness estimation is based on the GHSL urban area dataset, which includes many suburbs of Barcelona. Therefore we used the admin_level 7 boundary for Barcelona instead.
  aoi_geom <- getOhsomeObjects(
    sf_boundary = aoi |> st_transform(4326) |> st_make_valid(),
    filter_char = "admin_level=7 and short_name=BCN",
    internal = FALSE,
    to_time = "2022-10-01",
    props = "tags",
    big = F,
    type = "geometry",
    cut=F
  ) |> filter(st_geometry_type(geometry)=="POLYGON" | st_geometry_type(geometry)=="MULTIPOLYGON")
}

# within the area of interest we download landuse features to erase from the area of interest
# We kept commercial areas, as there is no clear distinction within OSM of mixed used areas.
# Some cities are not well mapped with respect to landuse=residential, therefore we could not just use this tag to define the areas to be sampled.
erase_cover <- getOhsomeObjects(
  sf_boundary = aoi_geom |> st_transform(4326) |> st_make_valid(),
  filter_char = "landuse in (industrial,forest,farmland,meadow,cemetery,grassland,grass,railway) or natural in (beach,water, scrub, wood) or leisure=marina",
  internal = FALSE,
  to_time = "2022-10-01",
  props = "tags",
  big = F,
  type = "geometry",
  cut=F
) |> filter(st_geometry_type(geometry)=="POLYGON" | st_geometry_type(geometry)=="MULTIPOLYGON")

aoi_geom <- aoi_geom |> st_transform(utm)
aoi_geom_reduced <- aoi_geom |>
  st_difference(erase_cover |> st_transform(utm) |> st_union())

# After reduction we may end up with a geometry collection instead of multi-/polygons. The next lines deal with filtering these out
if (st_geometry_type(aoi_geom_reduced)=="GEOMETRYCOLLECTION") {
  aoi_geom_reduced <- aoi_geom_reduced |> st_collection_extract()
  aoi_geom_reduced <- st_sf(id=seq(1,length(aoi_geom_reduced)), geom=aoi_geom_reduced)
  aoi_geom_reduced <- aoi_geom_reduced |> filter(st_geometry_type(geom)=="POLYGON")
} else {
  # just convert to sf from sfc
  aoi_geom_reduced <- st_sf(id=seq(1,length(aoi_geom_reduced)), geom=aoi_geom_reduced)
}

# calculate the neighboorhood area from the set radius
neighborhood_area <- (pi*(neighborhood_radius**2))

# calculate neighborhood amount and sample in area of interest.
sample_size <- (st_area(aoi_geom_reduced |> st_combine()) / neighborhood_area) |> as.integer()
nb_pts <- st_sample(x = aoi_geom_reduced, size = sample_size, type = "regular")
nb_pts <- st_sf(id=seq(1, length(nb_pts)), geom=nb_pts)


if (!dir.exists("data/input")) {
  dir.create("data/input", recursive = T)
}

# write all outputs to the aoi folder
st_write(nb_pts, paste0("data/input/",aoi,"_origin_pts.gpkg"), append=F)
st_write(aoi_geom, paste0("data/input/",aoi,"_aoi.gpkg"), append=F)
st_write(aoi_geom_reduced, paste0("data/input/",aoi,"_aoi_reduced.gpkg"), append=F)
