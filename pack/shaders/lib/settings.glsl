#define SHADOWS
#define GODRAYS
#define REALISTIC_CLOUDS
#define REALISTIC_WATER
#define BLOOM
#define WAVING_FOLIAGE
#define VIBRANCE

const int shadowMapResolution = 1024; // [512 1024 2048]
const float shadowDistance = 64.0;
const float shadowDistanceRenderMul = 1.0;
const float shadowIntervalSize = 2.0;
const float sunPathRotation = -30.0;
const float ambientOcclusionLevel = 0.70;
