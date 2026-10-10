cmake_minimum_required(VERSION 3.0.2)
project(uav_farm_survey)

find_package(catkin REQUIRED COMPONENTS
  rospy std_msgs std_srvs geometry_msgs nav_msgs sensor_msgs
  visualization_msgs tf message_generation
)

add_message_files(
  FILES
  FruitSighting.msg
  RipeFruit.msg
  FruitMap.msg
  SurveyProgress.msg
)

generate_messages(DEPENDENCIES std_msgs geometry_msgs)

catkin_package(
  CATKIN_DEPENDS rospy std_msgs std_srvs geometry_msgs nav_msgs sensor_msgs
                 visualization_msgs tf message_runtime
)

catkin_install_python(PROGRAMS
  scripts/survey_pilot
  scripts/fruit_detector
  scripts/orchard_map
  scripts/make_orchard
  scripts/make_orchard_textures
  scripts/reset_robot
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

install(DIRECTORY launch urdf worlds config rviz models
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)
