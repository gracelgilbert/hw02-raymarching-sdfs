#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;
float epsilon = 0.0001;
float pi = 3.1415926535;

float random1( vec2 p , vec2 seed) {
  return fract(sin(dot(p + seed, vec2(127.1, 311.7))) * 43758.5453);
}

float random1( vec3 p , vec3 seed) {
  return fract(sin(dot(p + seed, vec3(987.654, 123.456, 531.975))) * 85734.3545);
}

vec2 random2( vec2 p , vec2 seed) {
  return fract(sin(vec2(dot(p + seed, vec2(311.7, 127.1)), dot(p + seed, vec2(269.5, 183.3)))) * 85734.3545);
}

float interpNoise2d(float x, float y) {
  float intX = floor(x);
  float fractX = fract(x);
  float intY = floor(y);
  float fractY = fract(y);

  float v1 = random1(vec2(intX, intY), vec2(1.f, 1.f));
  float v2 = random1(vec2(intX + 1.f, intY), vec2(1.f, 1.f));
  float v3 = random1(vec2(intX, intY + 1.f), vec2(1.f, 1.f));
  float v4 = random1(vec2(intX + 1.f, intY + 1.f), vec2(1.f, 1.f));

  float i1 = mix(v1, v2, fractX);
  float i2 = mix(v3, v4, fractX);
  return mix(i1, i2, fractY);
  return 2.0;

}


float interpNoise3d(float x, float y, float z) {
  float intX = floor(x);
  float fractX = fract(x);
  float intY = floor(y);
  float fractY = fract(y);
  float intZ = floor(z);
  float fractZ = fract(z);

  float v1 = random1(vec3(intX, intY, intZ), vec3(1.f, 1.f, 1.f));
  float v2 = random1(vec3(intX, intY, intZ + 1.0), vec3(1.f, 1.f, 1.f));
  float v3 = random1(vec3(intX + 1.0, intY, intZ + 1.0), vec3(1.f, 1.f, 1.f));
  float v4 = random1(vec3(intX + 1.0, intY, intZ), vec3(1.f, 1.f, 1.f));
  float v5 = random1(vec3(intX, intY + 1.0, intZ), vec3(1.f, 1.f, 1.f));
  float v6 = random1(vec3(intX, intY + 1.0, intZ + 1.0), vec3(1.f, 1.f, 1.f));
  float v7 = random1(vec3(intX + 1.0, intY + 1.0, intZ + 1.0), vec3(1.f, 1.f, 1.f));
  float v8 = random1(vec3(intX + 1.0, intY + 1.0, intZ), vec3(1.f, 1.f, 1.f));

  float i1 = mix(v2, v3, fractX);
  float i2 = mix(v1, v4, fractX);
  float i3 = mix(v6, v7, fractX);
  float i4 = mix(v5, v8, fractX);

  float j1 = mix(i4, i3, fractZ);
  float j2 = mix(i2, i1, fractZ);

  return mix(j2, j1, fractY);

}

float computeWorley(float x, float y, float numRows, float numCols) {
    float xPos = x * float(numCols) / 20.f;
    float yPos = y * float(numRows) / 20.f;

    float minDist = 60.f;
    vec2 minVec = vec2(0.f, 0.f);

    for (int i = -1; i < 2; i++) {
        for (int j = -1; j < 2; j++) {
            vec2 currGrid = vec2(floor(float(xPos)) + float(i), floor(float(yPos)) + float(j));
            vec2 currNoise = currGrid + random2(currGrid, vec2(2.0, 1.0));
            float currDist = distance(vec2(xPos, yPos), currNoise);
            if (currDist <= minDist) {
                minDist = currDist;
                minVec = currNoise;
            }
        }
    }
    return minDist;
    // return 2.0;
}

float fbmWorley(float x, float y, float height, float xScale, float yScale) {
  float total = 0.f;
  float persistence = 0.5f;
  int octaves = 4;
  float freq = 2.0;
  float amp = 1.0;
  for (int i = 0; i < octaves; i++) {
    // total += interpNoise2d( (x / xScale) * freq, (y / yScale) * freq) * amp;
    total += computeWorley( (x / xScale) * freq, (y / yScale) * freq, 2.0, 2.0) * amp;
    freq *= 2.0;
    amp *= persistence;
  }
  return height * total;
}

float fbm(float x, float y, float height, float xScale, float yScale) {
  float total = 0.f;
  float persistence = 0.5f;
  int octaves = 8;
  float freq = 2.0;
  float amp = 1.0;
  for (int i = 0; i < octaves; i++) {
    // total += interpNoise2d( (x / xScale) * freq, (y / yScale) * freq) * amp;
    total += interpNoise2d( (x / xScale) * freq, (y / yScale) * freq) * amp;
    freq *= 2.0;
    amp *= persistence;
  }
  return height * total;
}

float fbm3D(float x, float y, float z, float height, float xScale, float yScale, float zScale) {
  float total = 0.f;
  float persistence = 0.5f;
  int octaves = 8;
  float freq = 2.0;
  float amp = 1.0;
  for (int i = 0; i < octaves; i++) {
    // total += interpNoise2d( (x / xScale) * freq, (y / yScale) * freq) * amp;
    total += interpNoise3d( (x / xScale) * freq, (y / yScale) * freq, (z / zScale) * freq) * amp;
    freq *= 2.0;
    amp *= persistence;
  }
  return height * total;
}


vec3 castRay(vec3 eye) {
  float a = fs_Pos.x;
  float b = fs_Pos.y;

  vec3 forward = normalize(u_Ref - eye);
  vec3 right = normalize(cross(forward, u_Up));

  vec3 v = (u_Up) * tan(45.0 / 2.0);
  vec3 h = right * (u_Dimensions.x / u_Dimensions.y) * tan(45.0 / 2.0);
  vec3 point = forward + (a * h) + (b * v);

  return normalize(point);
}

float sphereSDF( vec3 p, float radius ) {
  return length(p)-radius;
}

float roundConeSDF( in vec3 p, in float r1, float r2, float h )
{
    vec2 q = vec2( length(p.xz), p.y );
    
    float b = (r1-r2)/h;
    float a = sqrt(1.0-b*b);
    float k = dot(q,vec2(-b,a));
    
    if( k < 0.0 ) return length(q) - r1;
    if( k > a*h ) return length(q-vec2(0.0,h)) - r2;
        
    return dot(q, vec2(a,b) ) - r1;
}

float coneSDF( vec3 p, vec2 c )
{
    // c must be normalized
    float q = length(p.xy);
    return dot(c,vec2(q,p.z));
}

float boxSDF( vec3 p, vec3 b )
{
  vec3 d = abs(p) - b;
  return length(max(d,0.0))
         + min(max(d.x,max(d.y,d.z)),0.0); // remove this line for an only partially signed sdf 
}

float cappedConeSDF( in vec3 p, in float h, in float r1, in float r2 )
{
    vec2 q = vec2( length(p.xz), p.y );
    
    vec2 k1 = vec2(r2,h);
    vec2 k2 = vec2(r2-r1,2.0*h);
    vec2 ca = vec2(q.x-min(q.x,(q.y < 0.0)?r1:r2), abs(q.y)-h);
    vec2 cb = q - k1 + k2*clamp( dot(k1-q,k2)/dot(k2, k2), 0.0, 1.0 );
    float s = (cb.x < 0.0 && ca.y < 0.0) ? -1.0 : 1.0;
    return s*sqrt( min(dot(ca, ca),dot(cb, cb)) ) - 0.5;
}
float opSmoothUnion( float d1, float d2, float k ) {
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h); 
}

bool boundingSphereIntersect(vec3 dir, vec3 origin, vec3 center, float radius, out float dist) {

  float a = dir.x * dir.x + dir.y * dir.y + dir.z * dir.z;
  float b = 2.0 * (dir.x * (origin.x - center.x) + dir.y * (origin.y - center.y) + dir.z * (origin.z - center.z));
  float c = (origin.x - center.x) * (origin.x - center.x) + (origin.y - center.y) * (origin.y - center.y) + (origin.z - center.z) * (origin.z - center.z) - (radius * radius);

  float discr = b * b - 4.0 * a * c;
  if (discr < 0.0) {
    return false;
  }

  float t0 = (-b - pow(discr, 0.5)) / (2.0 * a);
  if (t0 > 0.0) {
    dist = t0;
    return true;
  }
  float t1 = (-b + pow(discr, 0.5)) / (2.0 * a);
  if (t1 > 0.0) {
    dist = t1;
    return true;
  }
  return false;
}

vec4 topWingColor(vec3 normal, vec3 point, vec3 dir) {
  float theta1 = pi / 2.0;
  float theta2 = pi;
  float thetaAnim = -smoothstep(-theta1, theta2,  0.5 * (sin(u_Time /  2.0) + 1.0));
  if (point.z < 0.0) {
    thetaAnim *= -1.0;
  }
  mat3 wingAnimationRotation = mat3(vec3(1, 0, 0),
                                    vec3(0, cos(thetaAnim), sin(thetaAnim)),
                                    vec3(0, -sin(thetaAnim), cos(thetaAnim))
                           );  

    point = ((point * wingAnimationRotation));
    vec3 color1 = vec3(0.5, 0.8, 1.0);
    float textureTheta = -pi/9.0;
    if (point.z < 0.0) {
      textureTheta *= -1.0;
    }
    mat3 textureRotation = mat3(vec3(cos(textureTheta), 0, sin(textureTheta)),
                           vec3(0, 1, 0),
                           vec3(-sin(textureTheta), 0, cos(textureTheta))
                           );
    vec3 texturePoint = point * textureRotation;
    float mask = 1.0 - 1.4 * floor(12.0 * computeWorley(texturePoint.x, texturePoint.z, 15.0, 50.0)) / 12.0;
    float distFromCenter = sqrt(point.x * point.x + point.z * point.z);
    distFromCenter += 0.35 * (fbm(point.x, point.z, 1.0, 0.4, 0.4) * 2.0 - 1.0);
    color1 *= mask;

    vec3 color2 = vec3(0.9, 0.5, 0.3);
    // float mask2 = computeWorley(point.x, point.z, 100.0, 100.0);
    float mask2 = fbm3D(point.x, point.y, point.z, 1.0, 0.2, 0.2, 0.2);
    color2 *= mask2;

    if (distFromCenter > 5.5 ) {
      color1 = color2;
    }
    if (distFromCenter > 6.5 && distFromCenter < 7.0 || distFromCenter > 5.5 && distFromCenter < 6.0) {
      color1 = vec3(0.0);
    }

    vec4 diffuseColor = vec4(color1, 1.0);
    float diffuseTerm = dot(normalize(normal), normalize(vec3(1.0, 0.5, -1.0)));
    float ambientTerm = 0.2;
    float lightIntensity = diffuseTerm + ambientTerm;
  return vec4(diffuseColor.rgb * lightIntensity, diffuseColor.a);
}

vec4 bottomWingColor(vec3 normal, vec3 point, vec3 dir) {
  vec3 color1 = vec3(0.9, 0.5, 0.8);
  vec3 color2 = vec3(0.7, 0.7, 0.4);

  float theta1 = pi / 2.0;
  float theta2 = pi;
  float thetaAnim = -smoothstep(-theta1, theta2,  0.5 * (sin(u_Time /  2.0) + 1.0));
  if (point.z < 0.0) {
    thetaAnim *= -1.0;
  }
  mat3 wingAnimationRotation = mat3(vec3(1, 0, 0),
                                    vec3(0, cos(thetaAnim), sin(thetaAnim)), // FIX SIGNS FOR Y ROTATION!!!!!!!!!!!!!!!!!!!!!!
                                    vec3(0, -sin(thetaAnim), cos(thetaAnim))
                           );  

    point = ((point * wingAnimationRotation));
    // vec3 color1 = vec3(0.5, 0.8, 1.0);
    float textureTheta = pi/4.0;
    if (point.z < 0.0) {
      textureTheta *= -1.0;
    }
    mat3 textureRotation = mat3(vec3(cos(textureTheta), 0, sin(textureTheta)),
                           vec3(0, 1, 0),
                           vec3(-sin(textureTheta), 0, cos(textureTheta))
                           );
    vec3 texturePoint = point * textureRotation;
    float mask = 1.0 - 1.4 * floor(12.0 * computeWorley(texturePoint.x, texturePoint.z, 15.0, 45.0)) / 12.0;
    float distFromCenter = sqrt(point.x * point.x + point.z * point.z);

    distFromCenter += 0.35 * (fbm(point.x, point.z, 1.0, 0.4, 0.4) * 2.0 - 1.0);
    color1 *= mask;


    // vec3 color2 = vec3(0.9, 0.5, 0.3);
    // float mask2 = computeWorley(point.x, point.z, 100.0, 100.0);
    float mask2 = fbm3D(point.x, point.y, point.z, 1.0, 0.2, 0.2, 0.2);
    color2 *= mask2;

    if (distFromCenter > 5.5 ) {
      color1 = color2;
    }
    if (distFromCenter > 6.5 && distFromCenter < 7.0 || distFromCenter > 5.5 && distFromCenter < 6.0) {
      color1 = vec3(0.0);
    }

    vec4 diffuseColor = vec4(color1, 1.0);
    float diffuseTerm = dot(normalize(normal), normalize(vec3(1.0, 0.5, -1.0)));
    float ambientTerm = 0.2;
    float lightIntensity = diffuseTerm + ambientTerm;
  return vec4(diffuseColor.rgb * lightIntensity, diffuseColor.a);
}

vec4 bodyColor(vec3 normal, vec3 point, vec3 dir) {
    vec4 diffuseColor = vec4(0.1, 0.1, 0.1, 1.0);
    float diffuseTerm = dot(normalize(normal), normalize(vec3(1.0, 0.5, -1.0)));
    float ambientTerm = 0.2;
    float lightIntensity = diffuseTerm + ambientTerm;
  return vec4(diffuseColor.rgb * lightIntensity, diffuseColor.a);
  
}


vec3 getSphereNormal(vec3 p, float t) {
  return normalize(vec3(  sphereSDF(vec3(p[0] + 0.001, p[1], p[2]), t) - sphereSDF(vec3(p[0] - 0.001, p[1], p[2]), t),
                          sphereSDF(vec3(p[0], p[1] + 0.001, p[2]), t) - sphereSDF(vec3(p[0], p[1] - 0.001, p[2]), t),
                          sphereSDF(vec3(p[0], p[1], p[2] + 0.001), t) - sphereSDF(vec3(p[0], p[1], p[2] - 0.001), t)
                       ));
}

float headSDF(vec3 p) {
  vec3 headInvTranslation = vec3(-2.8, -1.0, 0.0);

  vec3 eye1InvTranslation = vec3(-4.2, -1.4, -1.1);  
  vec3 eye2InvTranslation = vec3(-4.2, -1.4, 1.1);
  vec3 eyeInvScale = vec3(0.9, 0.6, 0.75);

  float headDistance = sphereSDF(p + headInvTranslation, 2.0);
  vec3 finalTranslation = headInvTranslation;
  vec3 finalScale = vec3(1.0, 1.0, 1.0);

  float eye1Distance = sphereSDF((p + eye1InvTranslation) * eyeInvScale, 0.6);
  float eye2Distance = sphereSDF((p + eye2InvTranslation) * eyeInvScale, 0.6);
  headDistance = max(-eye1Distance, headDistance);
  headDistance = max(-eye2Distance, headDistance);
  return headDistance;
}

float bodySDF(vec3 p) {
  // vec3 headNormal;
  float headDistance = headSDF(p);

  vec3 tailInvScale = vec3(0.3, 1.0, 1.0);
  vec3 tailInvTranslation = vec3(4.2, 0.0, 0.0);

  vec3 centerTranslation = vec3(0.0, -0.2, 0.0);

  float centerDistance = sphereSDF(p + centerTranslation, 1.1);
  float tailDistance = sphereSDF((p + tailInvTranslation) * tailInvScale, 1.0);

  float k = 0.4;
  float h = clamp( 0.5 + 0.5*(centerDistance-tailDistance)/k, 0.0, 1.0 );
  float unionDistance = mix( centerDistance, tailDistance, h ) - k*h*(1.0-h); 

  h = clamp( 0.5 + 0.5*(unionDistance-headDistance)/k, 0.0, 1.0 );
  unionDistance = mix( unionDistance, headDistance, h ) - k*h*(1.0-h); 
  return unionDistance;
}

vec3 getBodyNormal(vec3 p) {
  return normalize(vec3(  bodySDF(vec3(p[0] + 0.001, p[1], p[2])) - bodySDF(vec3(p[0] - 0.001, p[1], p[2])),
                          bodySDF(vec3(p[0], p[1] + 0.001, p[2])) - bodySDF(vec3(p[0], p[1] - 0.001, p[2])),
                          bodySDF(vec3(p[0], p[1], p[2] + 0.001)) - bodySDF(vec3(p[0], p[1], p[2] - 0.001))
                       ));
}

float topRightWingSDF(vec3 p) {
  float wingxTheta = -pi / 2.0 ;
  mat3 wingxRotation = mat3(vec3(1, 0, 0),
                           vec3(0, cos(wingxTheta), sin(wingxTheta)),
                           vec3(0, -sin(wingxTheta), cos(wingxTheta))
                           );
  float wingzTheta = pi / 13.0;                         
  mat3 wingzRotation = mat3(vec3(cos(wingzTheta), sin(wingzTheta), 0),
                           vec3(-sin(wingzTheta), cos(wingzTheta), 0),
                           vec3(0, 0, 1)
                           );
  float theta1 = pi / 2.0;
  float theta2 = pi;
  float thetaAnim = -smoothstep(-theta1, theta2,  0.5 * (sin(u_Time /  2.0) + 1.0));
  mat3 wingAnimationRotation = mat3(vec3(1, 0, 0),
                                    vec3(0, cos(thetaAnim), sin(thetaAnim)),
                                    vec3(0, -sin(thetaAnim), cos(thetaAnim))
                           );  
  vec3 wingInvTranslation = vec3(0.4, 5.0, 0.0);
  vec3 wingScale = vec3(1.0, 1.0, 1.0);
  float coneDist = roundConeSDF((((p * wingAnimationRotation * wingxRotation * wingzRotation) + wingInvTranslation) * wingScale), 2.7, 0.2, 4.0);

  vec3 boxTranslation = vec3(-0.25, -0.1, -3.0);

  float boxDist = boxSDF((p * wingAnimationRotation + boxTranslation), vec3(6.0, 0.00001, 6.0));
  // return coneDist;
  return max(boxDist, coneDist) - 0.1;
}


float topLeftWingSDF(vec3 p) {
  float wingxTheta = pi / 2.0 ;
  mat3 wingxRotation = mat3(vec3(1, 0, 0),
                           vec3(0, cos(wingxTheta), sin(wingxTheta)),
                           vec3(0, -sin(wingxTheta), cos(wingxTheta))
                           );
  float wingzTheta = pi / 13.0;                         
  mat3 wingzRotation = mat3(vec3(cos(wingzTheta), sin(wingzTheta), 0),
                           vec3(-sin(wingzTheta), cos(wingzTheta), 0),
                           vec3(0, 0, 1)
                           );
  float theta1 = pi / 2.0;
  float theta2 = pi;
  float thetaAnim = smoothstep(-theta1, theta2,  0.5 * (sin(u_Time /  2.0) + 1.0));
  mat3 wingAnimationRotation = mat3(vec3(1, 0, 0),
                                    vec3(0, cos(thetaAnim), sin(thetaAnim)),
                                    vec3(0, -sin(thetaAnim), cos(thetaAnim))
                           );  
  vec3 wingInvTranslation = vec3(0.4, 5.0, 0.0);
  vec3 wingScale = vec3(1.0, 1.0, 1.0);
  float coneDist = roundConeSDF(((p * wingAnimationRotation * wingxRotation * wingzRotation) + wingInvTranslation) * wingScale, 2.7, 0.2, 4.0);

  vec3 boxTranslation = vec3(-0.25, -0.1, 3.0);

  float boxDist = boxSDF(p * wingAnimationRotation + boxTranslation, vec3(6.0, 0.00001, 6.0));
  // return coneDist;
  return max(boxDist, coneDist) - 0.1;
}

float bottomRightWingSDF(vec3 p) {
  float wingxTheta = -pi / 2.0 ;
  mat3 wingxRotation = mat3(vec3(1, 0, 0),
                           vec3(0, cos(wingxTheta), sin(wingxTheta)),
                           vec3(0, -sin(wingxTheta), cos(wingxTheta))
                           );
  float wingzTheta = -pi / 3.65;                         
  mat3 wingzRotation = mat3(vec3(cos(wingzTheta), sin(wingzTheta), 0),
                           vec3(-sin(wingzTheta), cos(wingzTheta), 0),
                           vec3(0, 0, 1)
                           );
  float theta1 = pi / 2.0;
  float theta2 = pi;
  float thetaAnim = -smoothstep(-theta1, theta2,  0.5 * (sin(u_Time /  2.0) + 1.0));
  mat3 wingAnimationRotation = mat3(vec3(1, 0, 0),
                                    vec3(0, cos(thetaAnim), sin(thetaAnim)),
                                    vec3(0, -sin(thetaAnim), cos(thetaAnim))
                           );                           
  vec3 wingInvTranslation = vec3(-0.4, 6.1, -0.2);
  vec3 wingScale = vec3(1.0, 1.0, 1.0);
  float coneDist = roundConeSDF(((p * wingAnimationRotation * wingxRotation * wingzRotation) + wingInvTranslation) * wingScale, 2.9, 0.2, 5.0);

  vec3 boxTranslation = vec3(1.2, -0.3, -3.0);

  float boxDist = boxSDF(p * wingAnimationRotation + boxTranslation, vec3(7.0, 0.00001, 7.0));
  // return coneDist;
  return max(boxDist, coneDist) - 0.1;
}

float bottomLeftWingSDF(vec3 p) {
  float wingxTheta = pi / 2.0 ;
  mat3 wingxRotation = mat3(vec3(1, 0, 0),
                           vec3(0, cos(wingxTheta), sin(wingxTheta)),
                           vec3(0, -sin(wingxTheta), cos(wingxTheta))
                           );
  float wingzTheta = -pi / 3.65;                         
  mat3 wingzRotation = mat3(vec3(cos(wingzTheta), sin(wingzTheta), 0),
                           vec3(-sin(wingzTheta), cos(wingzTheta), 0),
                           vec3(0, 0, 1)
                           );
  float theta1 = pi / 2.0;
  float theta2 = pi;
  float thetaAnim = smoothstep(-theta1, theta2,  0.5 * (sin(u_Time /  2.0) + 1.0));
  mat3 wingAnimationRotation = mat3(vec3(1, 0, 0),
                                    vec3(0, cos(thetaAnim), sin(thetaAnim)),
                                    vec3(0, -sin(thetaAnim), cos(thetaAnim))
                           );                              
  vec3 wingInvTranslation = vec3(-0.4, 6.1, 0.2);
  vec3 wingScale = vec3(1.0, 1.0, 1.0);
  float coneDist = roundConeSDF(((p * wingAnimationRotation * wingxRotation * wingzRotation) + wingInvTranslation) * wingScale, 2.9, 0.2, 5.0);

  vec3 boxTranslation = vec3(1.2, -0.3, 3.0);

  float boxDist = boxSDF(p * wingAnimationRotation + boxTranslation, vec3(7.0, 0.00001, 7.0));
  // return coneDist;
  return max(boxDist, coneDist) - 0.1;
}

bool topLeftBoudningSphere(vec3 dir, vec3 origin, out float dist) {
  vec3 center = vec3(1.0, 1.0, -5.5);
  float radius = 4.9;
  return boundingSphereIntersect(dir, origin, center, radius, dist);
}

bool topRightBoudningSphere(vec3 dir, vec3 origin, out float dist) {
  vec3 center = vec3(1.0, 1.0, 5.5);
  float radius = 4.9;
  return boundingSphereIntersect(dir, origin, center, radius, dist);
}


bool bottomLeftBoudningSphere(vec3 dir, vec3 origin, out float dist) {
  vec3 center = vec3(-3.5, 1.0, -3.5);
  float radius = 4.9;
  return boundingSphereIntersect(dir, origin, center, radius, dist);
}

bool bottomRightBoudningSphere(vec3 dir, vec3 origin, out float dist) {
  vec3 center = vec3(-3.5, 1.0, 3.5);
  float radius = 4.9;
  return boundingSphereIntersect(dir, origin, center, radius, dist);
}

float topWingSDF(vec3 dir, vec3 p) {
  float topRightDist = topRightWingSDF(p);
  float topLeftDist = topLeftWingSDF(p);
  float testDist;
  if (!topRightBoudningSphere(dir, u_Eye, testDist)) {
    topRightDist = 10000.0;
  }

  if (!topLeftBoudningSphere(dir, u_Eye, testDist)) {
    topLeftDist = 10000.0;
  }
  return min(topRightDist, topLeftDist);
}

float bottomWingSDF(vec3 dir, vec3 p) {
  float bottomRightDist = bottomRightWingSDF(p);
  float bottomLeftDist = bottomLeftWingSDF(p);
  float testDist;
  if (!bottomRightBoudningSphere(dir, u_Eye, testDist)) {
    bottomRightDist = 10000.0;
  }

  if (!bottomLeftBoudningSphere(dir, u_Eye, testDist)) {
    bottomLeftDist = 10000.0;
  }
  return min(bottomRightDist, bottomLeftDist);
}

vec3 getTopWingNormal(vec3 dir, vec3 p) { 
  return normalize(vec3(  topWingSDF(dir, vec3(p[0] + 0.001, p[1], p[2])) - topWingSDF(dir, vec3(p[0] - 0.001, p[1], p[2])),
                          topWingSDF(dir, vec3(p[0], p[1] + 0.001, p[2])) - topWingSDF(dir, vec3(p[0], p[1] - 0.001, p[2])),
                          topWingSDF(dir, vec3(p[0], p[1], p[2] + 0.001)) - topWingSDF(dir, vec3(p[0], p[1], p[2] - 0.001))
                       ));
}

vec3 getBottomWingNormal(vec3 dir, vec3 p) {
  return normalize(vec3(  bottomWingSDF(dir, vec3(p[0] + 0.001, p[1], p[2])) - bottomWingSDF(dir, vec3(p[0] - 0.001, p[1], p[2])),
                          bottomWingSDF(dir, vec3(p[0], p[1] + 0.001, p[2])) - bottomWingSDF(dir, vec3(p[0], p[1] - 0.001, p[2])),
                          bottomWingSDF(dir, vec3(p[0], p[1], p[2] + 0.001)) - bottomWingSDF(dir, vec3(p[0], p[1], p[2] - 0.001))
                       ));
}



float unionSDF(float d1, float d2) {
  return min(d1, d2);
}

float opUnion( float d1, float d2 ) {  
  return min(d1,d2); 
}

float opSubtraction( float d1, float d2 ) { 
  return max(-d1,d2); 
}

float opIntersection( float d1, float d2 ) { 
  return max(d1,d2); 
}

bool sceneBoundingSphere(vec3 dir, vec3 origin, out float dist) {
  vec3 center = vec3(-1.5, 0, 0);
  float radius = 9.0;
  return boundingSphereIntersect(dir, origin, center, radius, dist);
}


bool topWingBoudningSphere(vec3 dir, vec3 origin, out float dist) {
  vec3 center = vec3(2.0, 0, 0);
  float radius = 8.5;
  return boundingSphereIntersect(dir, origin, center, radius, dist);
}

bool bottomWingBoudningSphere(vec3 dir, vec3 origin, out float dist) {
  vec3 center = vec3(-3.0, 0, 0);
  float radius = 7.6;
  return boundingSphereIntersect(dir, origin, center, radius, dist);
}

bool bodyBoudningSphere(vec3 dir, vec3 origin, out float dist) {
  vec3 center = vec3(-1.0, 0, 0);
  float radius = 6.65;
  return boundingSphereIntersect(dir, origin, center, radius, dist);
}

float sceneSDF(vec3 dir, vec3 p, out vec3 nor, out vec4 col) {
  float topWingDistance = topWingSDF(dir, p);
  float bottomWingDistance = bottomWingSDF(dir, p);
  float bodyDistance = bodySDF(p);


  float testDistance;
  if (!topWingBoudningSphere(dir, u_Eye, testDistance)) {
    topWingDistance = 10000.0;
  }
  if (!bottomWingBoudningSphere(dir, u_Eye, testDistance)) {
    bottomWingDistance = 10000.0;
  }

  if (!bodyBoudningSphere(dir, u_Eye, testDistance)) {
    bodyDistance = 10000.0;
  }


  if (topWingDistance < bodyDistance && topWingDistance < bottomWingDistance) {
    nor = getTopWingNormal(dir, p);
    col = topWingColor(nor, p, dir);
    return topWingDistance;
  } else if (bodyDistance < bottomWingDistance){
    nor = getBodyNormal(p);
    col = bodyColor(nor, p, dir);
    return bodyDistance;
  } else {
    nor = getBottomWingNormal(dir, p);
    col = bottomWingColor(nor, p, dir);
    return bottomWingDistance;
  }
}

float pCurve (float x, float a, float b) {
  float k = pow(a + b, a + b) / (pow(a, a) * pow(b, b));
  return k * pow(x, a) * pow(1.0 - x, b);
}

bool rayMarch(vec3 dir, out vec3 nor, out vec4 col) {

  float depth = 0.0;
  float dist = 0.0;
  float counter = 0.0;
  float radius = 2.0;
  if (!sceneBoundingSphere(dir, u_Eye, dist)) {
    return false;
  }

  for (int i = 0; i < 200; i++) {
    vec3 currPoint = u_Eye + depth * dir;
    // currPoint.y += sin(u_Time / 10.0);
    // break up a and b with some noise
    currPoint.y += pCurve(0.5 * sin(u_Time / 10.0) + 0.5, 2.0, 4.0);

    // float yOffset1 = 3.0;

    // float gain = 0.0;

    vec3 normal;
    dist = sceneSDF(dir, currPoint, normal, col);
    if (dist < epsilon) {
        nor = normal;
        return true;
    }
    depth += dist;
    if (depth > 30.0) {
      nor = vec3(0.0, 0.0, 0.0);
      return false;
    }
  }
  nor = vec3(0.0, 0.0, 0.0);
  return false;

}

void main() {
  vec3 normal = vec3(1.0, 1.0, 1.0);
  vec4 color = vec4(1.0, 1.0, 1.0, 1.0);
  if (rayMarch(castRay(u_Eye), normal, color)) {
    out_Col = color;
  } else {
    out_Col = vec4(0.5 * (castRay(u_Eye) + vec3(1.0, 1.0, 1.0)), 1.0);
    // out_Col = vec4(0.5, 0.5, 0.5, 1.0);
  }

}
