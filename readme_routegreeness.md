# Betweenness analysis and 15min City index

This readme contains all information to the generating route greens attributes and generating visualisation maps for both central green routes and 15min city


## Setup input Greenspaces inputdata 

Urban green space data used within the scope of this project is based on existing research and methods by Christina Ludwig.

The source code to produce the *urban greenness polygons* can be found here: [https://github.com/redfrexx/green_index](https://github.com/redfrexx/green_index)

Behind the following link you find geopackages for Mannheim and Barcelona preprocessed:

[heibox link](https://heibox.uni-heidelberg.de/d/af033f338e8446ee9ec2/)

make sure to put them in the following path `project_folder/data/greenness`

## Setup Python

Python is used with the version `3.8` on a Mac OS. JupyterLab with version 3.4.4 was used for running Jupiter notebook based visualisations. The main libraries comprise: 

```
"gdal","geopandas","pandas","numpy", "shapely" ,"folium" ,"branca"
```


## Run the analysis for extracting greenness attributes for each route of a given city

In the `srcpython` folder there is a script located:

- `assign_streets_greenness.py`

Provide the following parameters in this script:

-`datadir`- location of the directory which contains the centrality geopackages for example [heibox link](https://heibox.uni-heidelberg.de/d/e75f153f7de1479abf8c/)
- `EPSG`- UTM EPSG for a given city for example  EPSG = 32631 for Barcelona
- `centrality_threshold` - This is used to filter the important or high centrality routes to reduce the workload/size of generated files for example 20, 10 or 5
- `greenness_gpkg_file` - Specify location of the greenness geopackage with calculated green polygons for a city for example [heibox link](https://heibox.uni-heidelberg.de/d/8e78f8223ee540e5bf06/)
- `greenraster` -  Specify output location of raster that would be generated from the `greenness_gpkg_file` with spatial resolution 10m
- `buffersize`- specify in m the buffer size for which greenness w.r.t the street segments should be calculated. Default = 25m

1)The script has a function rasterzonalstats that would loop over all the files in the centrality folder and calculate for each file the greenness of the routes/streets based on a buffersize of 25m.
2)Greenness attributes such as mean, median, 25percentile, 75percentile, greenarea_sqm, greenness area coverage w.r.t the buffer area i.e gnar_cov%, mean * gnar_cov% i.e. scaledmean 
3)We use scaledmean as a robust indicator for greenness of routes/segments
4)A new folder `greencentrality` is created in the same directory that contains centrality folder with the new geopackages with same name as original geopackage and with an added '_green'. [heibox link](https://heibox.uni-heidelberg.de/d/8cd751868e1f4730b2d1/)


### Converting geopackages into geojson format for plotting with folium 

In folder `jupyternotebooks_vis` the notebook shp2geojson.ipynb converts the geopackages in `greencentrality` folder or `15minjson` folder to geojson formats.

Provide the following parameters in this script:

-`datadir`- location of the directory `greencentrality` or `15mincity` that contains the geopackages with greenness attributes calculated for road segments or 15mincity attributes respectively

1) `outputdir`- Output directory `greencentralityjson` is generated that contains all the geojson converted files. for example [heibox link](https://heibox.uni-heidelberg.de/d/83cb2646bcd94451b1f0/)


### Centrality and Greenness Visualisation

In folder `jupyternotebooks_vis` the notebook routesvis.ipynb generates an html file that is plotted 

Provide the following parameters in this script:

`greenroutes` - Specify the location of the geojson file with greenness attributes in `greencentralityjson` folder
`outputfile`- - Specify the location of the output html file
`citycentriodLat` -  Specify the location of the centroid Latitude for the city visualisation 
`citycentriodLong` - Specify the location of the centroid Longitude for the city visualisation 

1) Two colormaps are generated for Centrality and Greenness respectively. 
2) Base Map is selected as 'cartodbpositron' , 'openstreetmap' and 'ESRI Satellite' for convenience. One could switch between the different basemaps for background reference.
3) For overall 15min City score we use the parameter Centrality_rel i.e. normalized Centrality for visualisation and tooltip allows one to hover over, highlight and see values as popup for each road segment of interest.
   Higher Centrality is represented by darker colours (towards red) 

4) Similarly, for Route Greenness, we use the parameter scaled mean i.e. mean * gnar_cov% (greenness area coverage in %). For visualisation, the tooltip allows one to hover over, highlight and see values as popup for each road segment of interest.
   Higher Greenness is represented by darker colours (towards green)

Final output as html files is located in `data/vis` folder and could be opened with any web browser.

### 15 minute city Visualisation

In folder `jupyternotebooks_vis` the notebook routesvis.ipynb generates an html file that is plotted 

Provide the following parameters in this script:

`pts15mincity` - Specify the location of the geojson file in `15minjson` folder 
`outputfile`- - Specify the location of the output html file
`citycentriodLat` -  Specify the location of the centroid Latitude for the city visualisation 
`citycentriodLong` - Specify the location of the centroid Longitude for the city visualisation 

1) A colormap are generated for the 15min city score. 
2) Base Map is selected as 'cartodbpositron', 'openstreetmap' and 'ESRI Satellite' for convenience. One could switch between the different basemaps for background reference.
3) For Centrality we use the parameter `index_score_adult` i.e the total score (max=9 and min = 0) for visualisation and tooltip allows one to hover over, highlight and see the overall and individual breakup scores for each sub-topic
  as popup for each point of interest.
   Higher 15 minute readiness score is represented by blue colour while the lower score by red. 
4) Different maps are generated for Adults, Children and Elderly

Final output as html files is located in `data/vis` folder and could be opened with any web browser.


