# uav_farm_survey/FruitSighting
#
# One ripe fruit, seen once, in one frame. Raw output of the detector.
#
# A sighting is not a fruit. The drone flies over a bush at 4 m with a camera
# running at 10 Hz, so the same berry is seen in twenty or thirty consecutive
# frames from twenty slightly different angles, each giving a slightly
# different world position. Turning that into "there is one fruit, here" is
# orchard_map's job, and keeping the two apart is what lets the map say how
# many times it saw something - which is the difference between a detection it
# is confident about and a red pixel that appeared once.

std_msgs/Header header    # stamp of the image this came from; frame_id = world

float64 x                 # where the fruit is, in the world frame
float64 y
float64 z                 # the assumed fruit plane, not a measurement

uint32  u                 # where it was in the image, for debugging the
uint32  v                 # projection when a report lands somewhere silly
float64 area_px           # blob size; a proxy for confidence and for
                          # rejecting single-pixel noise
float64 range             # camera height above the fruit plane when seen
