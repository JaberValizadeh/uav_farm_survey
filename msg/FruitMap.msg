# uav_farm_survey/FruitMap
#
# Everything the survey has found so far. Published as it grows, so the map is
# watchable during the flight rather than only at the end.

std_msgs/Header header
RipeFruit[] fruit
uint32      sightings_total    # before merging; the raw detector count
