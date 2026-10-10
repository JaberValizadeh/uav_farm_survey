# uav_farm_survey/SurveyProgress
#
# Where the aircraft is up to in its coverage pattern.

std_msgs/Header header
string  state             # TAKEOFF / TRANSIT / SURVEY / TURN / RETURN / DONE
uint32  leg               # which line it is flying, 0-based
uint32  legs_total
float64 leg_progress      # 0..1 along the current line
float64 area_covered      # square metres of field swept, camera footprint
float64 area_total
