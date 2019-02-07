# Grace Gilbert (gracegi)

## Demo Link
<https://gracelgilbert.github.io/hw02-raymarching-sdfs/>
![](MainImage.png)

## External Resources
- For the SDF functions, both the shape equations and the combination of SDF functions, I used functions from Inigo Quilez's blog:
<https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm>
- For normal calculation of SDFs, I referenced the following source:
<http://jamie-wong.com/2016/07/15/ray-marching-signed-distance-functions/>
- I also referenced the CIS 460 lecture material on ray marching.

## Inspiration
Over the summer, I used Houdini to generate procedural butterfly patterns which I used to shade butterflies. That project utilized existing software packages that have extensive features available. I was curious to see what I could create purely procedurally using SDFs and other tools.

## Implementation
### Geometry
#### Body
The body of the butterfly is generally made up of three modified SDF spheres. These three sections are smoothly blended together using smooth union with a k value of 0.6, making the body look like it is one solid form.
- The center sphere is a simple SDF sphere of radius 1. 
- The tail of the butterfly is a sphere elongated in the x direction, accomplished by scaling the test point down in x to 0.3X the original. I then created a bumpy stripe pattern on the tail by offsetting the test point inward along the normal according to a sin curve. By offsetting the point inward, it inversely pushed the geometry outwards, forming raised stripes. I clamped the sin curve to be between 0.5 and 1.0, preventing the geometry from getting pushed in, and creating larger valleys than peaks in the curve. I also raised it to a power of 0.1 to smooth out the transition. 
- The head of the butterfly is an SDF sphere with two scaled spheres subtracted from it. These two spheres are elongated vertically, as well as elongated along x to carve deeper into the main sphere and create a more defined look. They are then translated to be on either side of the head.
#### Wings
### Normal Calculation
### Optimization Method
### Texturing
### Animation
#### Wings
#### Body
#### Sky
