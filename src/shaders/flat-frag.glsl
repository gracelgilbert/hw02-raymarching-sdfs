#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;
float epsilon = 0.0001;
float pi = 3.1415926535;

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
  float thetaAnim = -smoothstep(-theta1, theta2,  0.5 * (sin(u_Time /  5.0) + 1.0));
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
  float thetaAnim = smoothstep(-theta1, theta2,  0.5 * (sin(u_Time /  5.0) + 1.0));
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
  float thetaAnim = -smoothstep(-theta1, theta2,  0.5 * (sin(u_Time /  5.0) + 1.0));
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
  float thetaAnim = smoothstep(-theta1, theta2,  0.5 * (sin(u_Time /  5.0) + 1.0));
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

float sceneSDF(vec3 dir, vec3 p, out vec3 nor) {
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
    return topWingDistance;
  } else if (bodyDistance < bottomWingDistance){
    nor = getBodyNormal(p);
    return bodyDistance;
  } else {
    nor = getBottomWingNormal(dir, p);
    return bottomWingDistance;
  }
}

float pCurve (float x, float a, float b) {
  float k = powf(a + b, a + b) / (pow(a, a) * pos(b, b));
  return k * powf(x, a) * powf(1.0 - x, b);
}

bool rayMarch(vec3 dir, out vec3 nor) {

  float depth = 0.0;
  float dist = 0.0;
  float counter = 0.0;
  float radius = 2.0;
  if (!sceneBoundingSphere(dir, u_Eye, dist)) {
    return false;
  }

  for (int i = 0; i < 100; i++) {
    vec3 currPoint = u_Eye + depth * dir;
    currPoint.y += sin(u_Time / 10.0);

    float yOffset1 = 3.0;

    float gain = 0.0;

    vec3 normal;
    dist = sceneSDF(dir, currPoint, normal);
    if (dist < epsilon) {
        nor = normal;
        return true;
    }
    depth += dist;
    if (depth > 50.0) {
      nor = vec3(0.0, 0.0, 0.0);
      return false;
    }
  }
  nor = vec3(0.0, 0.0, 0.0);
  return false;

}

void main() {
  vec3 normal = vec3(1.0, 1.0, 1.0);

  if (rayMarch(castRay(u_Eye), normal)) {
    vec4 diffuseColor = vec4(1.0, 0.0, 1.0, 1.0);
    float diffuseTerm = dot(normalize(normal), normalize(vec3(1.0, 0.5, -1.0)));
    float ambientTerm = 0.2;
    float lightIntensity = diffuseTerm + ambientTerm;

    out_Col = vec4(vec3(diffuseTerm, diffuseTerm, diffuseTerm), diffuseColor.a);
  } else {
    out_Col = vec4(0.5 * (castRay(u_Eye - vec3(u_Time / 2.0, 0.0, 0.0)) + vec3(1.0, 1.0, 1.0)), 1.0);
    // out_Col = vec4(0.5, 0.5, 0.5, 1.0);
  }

}
