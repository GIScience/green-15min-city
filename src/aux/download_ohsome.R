# Head ---------------------------------
# purpose: Function to retrieve OSM Objects from Ohsome
# author: Marcel Reinmuth
#
#
#1 Libraries ---------------------------------
library(sf) # spatial dataframes
library(httr) # get, post requests and there like
library(geojsonsf) # convert sf classes from/to geojsons

#2 Function ---------------------------------
getOhsomeObjects <- function(sf_boundary, filter_char,
                             internal=FALSE, to_time, props,
                             big, type, cut=FALSE) {
  # Extracts OSM features via ohsome API https://docs.ohsome.org/ohsome-api/v1/
  #
  # Args:
  #   sf_boundary: A sf object that represents the area of interest.
  #   filter_char: A string that represents the tag query for the request.
  #   internal: Boolean that controls whether the public or intenral api is used. Deprecated
  #   to_time: A time range or snapshot from which the objects shall be extracted.
  #   props: only meta data or tags?
  #   big: boolean, if set the binary data will be written to disc and only selected attributes will
  #   type: which geometry type: bbox, centroid, actual geometry
  #   cut: the request will be done for the extent (st_bbox) of the input sf_boundary. Shall the result later be reduced to the actual boundary by intersects=T filter? This can lead to problems due to invalid (non simple feature compliant) geometries.
  #
  # Returns:
  #   An sf df with ohsome data

  # Converting of the boundary sf to extent and shaping the coordinates to the right format.
  ext.str <-
    paste(as.character(st_bbox(sf_boundary)), collapse = ",")

  # Prepare url based on internal flag
  url <- ifelse(internal == TRUE, paste0("https://api-internal.ohsome.org/v1/elements/",type),
                paste0("https://api.ohsome.org/v1/elements/",type))


  # Fire a post request against the ohsome api to extract centroid geometries for the desired objects
  resp <- POST(
    url,
    encode = "form",
    body = list(
      #bpolys = extent,
      bboxes = ext.str,
      filter = filter_char,
      #time = "2007-10-09,2021-01-01",
      time = to_time,
      properties = props
    ),
    verbose()
  )

  # Below steps are neccessary to get the geojson response as a proper sf object in R:
  # Get the binary content of the response. A not human readable format of the geojson.
  h <- httr::content(resp, as = "raw")
  # Define output file geojson and write the binary content. It will be aprsed
  # to standard geojson, therefore it is human readable in the file.
  src.file <- paste0("temp_ohsome.geojson")
  dest.file <- paste0("temp_out.gpkg")
  writeBin(h, src.file)

  if (!big==T) {
    ohsome_gj <- st_read(src.file, quiet = T)# Load the written geojson as sf
    # Remove the temporary file
    file.remove(src.file)

    # Intersect the response from Ohsome with the original boundary file to
    # only get objects for the area of concern.
    if (cut==T) {
      ohsome_gj <- ohsome_gj[sf_boundary, op = st_intersects]
    }

  } else {
    # select a predefined set of attributes
    system(paste0('ogr2ogr -f "GPKG" -select name,amenity ', dest.file, ' ', src.file))
    ohsome_gj <- st_read(dest.file, quiet = T)
    file.remove(dest.file)
  }

  # Intersect the response from Ohsome with the original boundary file to
  # only get objects for the area of concern.
  if (cut==T) {
    ohsome_gj <- ohsome_gj[sf_boundary, op = st_intersects]
  }

  # cleanup some memory
  gc()
  # return sf object
  return(ohsome_gj)
}
