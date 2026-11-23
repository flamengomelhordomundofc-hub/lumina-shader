#define SHADOWS
#define VOLUMETRIC_LIGHT
#define GODRAYS
#define LENS_FLARE
#define REALISTIC_CLOUDS
#define REALISTIC_WATER
#define AUTO_BUMP
#define BLOOM
#define WAVING_FOLIAGE
#define AURORA
#define VIBRANCE

#define VL_STEPS 8 // [6 8 12]

const int shadowMapResolution = 1024; // [512 1024 2048]
const float shadowDistance = 72.0;
const float shadowDistanceRenderMul = 1.0;
const float shadowIntervalSize = 2.0;
const float sunPathRotation = -32.0;
const float ambientOcclusionLevel = 0.72;
