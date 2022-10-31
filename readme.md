# Green 15 Minute City

This Repository contains all code and resources that where used for the project *Green 15 Minute City*. 


The project has been submitted to the hackathon challenge *OSS4SDG Sustainable Smart Cities* by a team from [HeiGIT](https://heigit.org/).

## Motivation

As we enter into a post-Covid world, it has become increasingly clear **how important one’s immediate environment is to living a healthy and fulfilling life.** The pandemic laid bare the deficiencies, the inequities, and the unsustainability that had come to define much of our lives and our surroundings. Simultaneously, climate change is forcing us to reconsider and re-evaluate the built environment and whether or not we are doing enough to mitigate or adapt to its worsening effects.


And it is with these challenges in mind that we at the [Heidelberg Institute for Geoinformation Technology (HeiGIT)](https://heigit.org/) responded to the **OSS4SDG** Hackathon with the following submission. With our expertise in routing, big data, and the use of geospatial data for humanitarian interventions, we wanted to ask how we can use our skills to develop **actionable and open source information for the betterment of urban environments and urban livelihoods**. Specifically, borrowing from notions of the **15-minute city**, we wanted to investigate mobility patterns and access to essential services across age groups (children, adults, and the elderly). And using this information, we identified the most **central road segments** for pedestrian travel to these services and how green these road segments were. The goal here being that by identifying the **most traveled road segments and their greenness**, or lack thereof, we would be able to give cities and stakeholders pinpointable and **actionable information** on how to equitably and effectively **improve their urban environments**. And, perhaps more importantly, what populations (spatially across the city) and **who** (from an age perspective) **lacked access** to essential services within a 15-minute travel time for pedestrians.

Of course, there are limitations to our analysis and much room for improvement. Our centrality indicators could be improved, points of interest (essential services) could be better calibrated, and deeper attention could be paid to not just mobility by age but by ability and type. However, we believe that we have provided a valuable initial tool to understanding how access to urban services and, in a way, the right to the city by mobility varies across space. And further, where immediate steps can be taken to improve the greenness of a city, which is an increasingly important factor as we consider global warming and urban heat islands, carbon sinks, and equitable access to green and open space.


### !VIDEO LINK HERE!

---

## Structure of this project

The project is split in different components. Please refer to the respective readme's for more details and to reproduce the workflow.

### 1 Urban green space index

Urban green space data used within the scope of this project is based on existing research and methods by Christina Ludwig.

The source code to produce the *urban greenness polygons* can be found here: [https://github.com/redfrexx/green_index](https://github.com/redfrexx/green_index)

Paper on the method:



### 2 Betweenness analysis and 15min City index

Generation of neighborhood origins and service destination within the urban AOIs is done in R. The network analysis component requires a compiled routing graph. For this we set up a local instance of [openrouteservice](https://openrouteservice.org/).

Paper on the type of betweenness centrality measure that was used (also called targeted centrality):

Petricola, S., Reinmuth, M., Lautenbach, S. et al. Assessing road criticality and loss of healthcare accessibility during floods: the case of Cyclone Idai, Mozambique 2019. Int J Health Geogr 21, 14 (2022). [https://doi.org/10.1186/s12942-022-00315-2](https://doi.org/10.1186/s12942-022-00315-2)


For a detailed overview on all the steps see the following readme:

[readme_centrality.md](readme_centrality.md)

### 3 OpenStreetMap completeness analysis

The basis for our betweenness centrality analysis is openstreetmap data. An important component in using this data is to check the quality. We did this using the [ohsome quality analyst service](https://oqt.ohsome.org/). We used the indicator *Mapping saturation* to get detailed intrinsic information on the evolution of OpenStreetMap objects used within the scope of this project.

### 4 Conflation of greenness and betweenness centrality & visualization

The results of the centrality analysis are on a graph segment level. In the last step, these were intersected with the adjacent green values within the city AOIs. 

Together with the 15-minute city index of neighborhood locations, the segments were visualized as html files in a Python environment. 

For more information see the following readme:

[readme_viz.md](readme_viz.md)

---

## Contributors

- Charles Hatfield
- Christina Ludwig
- Maya Moritz
- Rutendo Mukaratirwa
- Sukanya Randhawa
- Marcel Reinmuth