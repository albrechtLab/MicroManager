# MicroManager

These two files allow for microscope interface through MicroManager, a custom arduino controller, and camera. When compiling this on your computer (running Windows 7), you must use a microcontroller with appropriate relay settings (contact us at albrechtlab@wpi.edu) and follow the next steps:

1. Install Arduino drivers (32 or 64 bit by installing Arduino software https://www.arduino.cc/en/Main/Software).
2. Install appropriate camera drivers (we use http://www.dcamapi.com/).
3. Install appropriate USB3 drivers (typcially from a CD) compatible with the chosen camera.
4. Change RUN_dra and GUI save paths to somewhere on your computer in a 'tmp' folder for convenience.
5. If using your own PC, go to next step and/or set up computer to Admin with notifications set to 'Never'
6. Change 'MMStack.ome.tif' using certain versions of MicroManager to 'MMStack_pos0.ome.tif'
7. Add these scripts to the script pannel and create shortcuts to execute easily.

All other notes and updates will be posted in this README.
