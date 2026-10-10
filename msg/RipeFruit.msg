# uav_farm_survey/RipeFruit
#
# One fruit the survey believes in: many sightings, merged.

uint32  id                # assigned in order of first sighting
float64 x                 # running mean of every sighting merged into it
float64 y
uint32  sightings         # how many frames it appeared in
float64 spread            # how far apart those sightings were, m. A fruit
                          # seen twenty times from twenty poses should have a
                          # small spread; a large one means the projection is
                          # disagreeing with itself and the position is soft.
time    first_seen
time    last_seen
