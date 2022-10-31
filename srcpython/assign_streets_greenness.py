#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Oct 18 15:01:34 2022

@author: srandhawa
"""

import numpy as np
import pandas as pd
import geopandas as gpd
from osgeo import gdal
import os
#import rasterstats as rs
import shapely


def rasterzonalstats(df,nodata, input_raster, datadir):
      
    outputdf = pd.DataFrame()
    for i in range(len(df)):
        
            input_shp =   datadir + os.sep + 'temp.shp'

            #Each basin geometry converted to shapefile
            selection = df['geometry'][i:i+1]
            #selection = bdf['geometry'][i:i+1]
            if selection.geometry.is_empty.bool():
                rasterarr = []
            else:
                selection.to_file(input_shp)
            
                output_raster = datadir + os.sep + 'temp.tif'
                
                ds = gdal.Warp(output_raster,
                              input_raster,
                              format = 'GTiff',
                              cutlineDSName = input_shp,
                              cropToCutline=True,
                              )
                ds = None
                
                
                raster = gdal.Open(output_raster, gdal.GA_ReadOnly)
                rasterarr = raster.ReadAsArray()
                #remove nodata values
                rasterarr = rasterarr[rasterarr!=nodata]
            
            if (np.size(rasterarr)==0):
                outputdf.at[i, 'median']=np.nan
                outputdf.at[i , 'count']=np.nan
                outputdf.at[i , 'mean']=np.nan
                outputdf.at[i , '25percentile']=np.nan
                outputdf.at[i , '75percentile']=np.nan
            
            else:    
            
                outputdf.at[i, 'median']=np.median(rasterarr)
                outputdf.at[i , 'count']=len(rasterarr)
                outputdf.at[i , 'mean']=np.mean(rasterarr)
                outputdf.at[i , '25percentile']=np.percentile(rasterarr,25)
                outputdf.at[i , '75percentile']=np.percentile(rasterarr,75)
                
            
    df = pd.concat([df, outputdf], axis = 1)
    #remove rows containing nan values 
#    df = df.dropna()
    df=df.reset_index(drop=True)
    return df


if __name__ == "__main__": 
    
    #List directory where all centrality files are stored
    datadir = '......./.../centrality'
    outputdir = os.path.dirname(datadir)+ os.sep+ 'greencentrality'
    if not os.path.exists(outputdir):
        os.makedirs(outputdir)
    #Barcelona
    EPSG = 32631
    #Mannheim
    #EPSG = 32632
    nodata= -9999
    centrality_threshold= 10
    buffersize = 25
    #generate the green raster with spatial resolution 10m from greeness geopackage
    ## read in the greenness indexed polygons for a city 
    greenness_gpkg_file = '...../greenness/Barcelona/greenness_trees.gpkg'
    greenraster = '/Users/srandhawa/Desktop/HeiGIT/OSS4SDG/greenness/Barcelona/Barcelona-2022-08-01_2021-08-01_2022-08-01_ndvi_median_copy.tif'

    # convert it into a raster     
    attribute = 'green'
    res= 10
    command = 'gdal_rasterize -a %s -of GTiff -tr %s %s -a_nodata %s %s %s ' % (attribute,res, res,nodata, greenness_gpkg_file, greenraster)
    os.system(command)
    
    #For each centrality file (incase of mutiple centrality shapefiles that coresspond to different sub-topics 
    #For each central route/street, greeness attributes are calculated w.r.t 25m surrounding buffer of the route/street
    #Greenness attributes such as mean, median,25percentile,75percentile,greenarea_sqm, greenness area coverage w.r.t the buffer area i.e gnar_cov%, mean * gnar_cov% i.e. scaledmean 
    #We plot scaledmean as a robust indicator for greeness of routes/segments
    
    for item in os.listdir(datadir):
    
        streets_gpkg_file = datadir +os.sep+ item
        outputfile = outputdir+os.sep+os.path.basename(streets_gpkg_file)[:-5]+'_green.gpkg'
        #read the street network to df and calculate buffer of 25m
        streets = gpd.read_file(streets_gpkg_file)
        streets= streets.to_crs(epsg=EPSG)

        #pick only streets that have high centrality measure as defined by centrality_threshold
        streets = streets[streets['centrality']>=centrality_threshold]
        #reindex 
        streets = streets.reset_index(drop=True)
    
        #buffer
        orig_geom = streets.geometry
        streets.geometry = streets.geometry.buffer(buffersize)

        #perform rasterzonalstats - add attributes green mean, percentile, counts, median
        #s_stats = rs.zonal_stats(streets,greenraster,nodata = np.nan, geojson_out=True,all_touched=True,stats="count mean median percentile_25 percentile_50 percentile_75")
        #s_stats= gpd.GeoDataFrame.from_features(s_stats)
        s_stats = rasterzonalstats(streets,nodata, greenraster, datadir)
        s_stats['greenarea_sqm']= s_stats['count']*100
        s_stats['bufarea_sqm']= s_stats.geometry.area
        s_stats['gnar_cov%']= s_stats['greenarea_sqm']*100/s_stats['bufarea_sqm']
        s_stats.rename(columns={'geometry': 'bufgeometry'}, inplace=True)
        #Convert counts to area% w.r.t buffer area
        orig_geom = orig_geom.to_frame()
        s_stats= pd.concat([s_stats,orig_geom], axis= 1)
        s_stats = s_stats.drop('bufgeometry', axis=1)  
    
        geometry = s_stats["geometry"].astype(str).map(shapely.wkt.loads) 
        s_stats = gpd.GeoDataFrame(s_stats, crs="EPSG:"+str(EPSG), geometry=geometry)
        s_stats['scaledmean']= s_stats['mean']*(s_stats['gnar_cov%']/100)
        s_stats.to_file(outputfile)
            
        