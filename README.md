# MicroManager

These two files allow for microscope interface through MicroManager, a custom arduino controller, and camera. When compiling this on your computer, you must use a microcontroller with appropriate relay settings (contact us at albrechtlab@wpi.edu) and follow the next steps:

1. Install Arduino drivers (32 or 64 bit by installing Arduino software https://www.arduino.cc/en/Main/Software)
2. Install appropriate camera drivers (we use http://www.dcamapi.com/)
3. Change RUN_dra and GUI save paths to somewhere on your computer in a 'tmp' folder for convenience
4. If using your own PC, go to next step and/or set up computer to Admin with notifications set to 'Never'
5. Change 'MMStack.ome.tif' using certain versions of MicroManager to 'MMStack.pos0.ome.tif'

All other notes and updates will be posted in this README.
