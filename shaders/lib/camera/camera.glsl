// References:
// http://en.wikipedia.org/wiki/Film_speed
// http://en.wikipedia.org/wiki/Exposure_value
// http://en.wikipedia.org/wiki/Light_meter

// Notes:
// EV below refers to EV at ISO 100

#define CAMERA_K 12.5
#define CAMERA_ISO_MIN 100.0
#define CAMERA_ISO_MAX 6400.0
#define CAMERA_SHUTTER_MIN 1.8
#define CAMERA_SHUTTER_MAX 22.0
#define CAMERA_APERTURE_MIN (1.0/4000.0)
#define CAMERA_APERTURE_MAX (1.0/30.0)


// Given an aperture, shutter speed, and exposure value compute the required ISO value
float ComputeISO(const in float aperture, const in float shutterSpeed, const in float ev) {
    return (aperture*aperture * 100.0) / (shutterSpeed * exp2(ev));
}

// Given the camera settings compute the current exposure value
float ComputeEV(const in float aperture, const in float shutterSpeed, const in float iso) {
    return log2((aperture*aperture * 100.0) / (shutterSpeed * iso));
}

// Using the light metering equation compute the target exposure value
float ComputeTargetEV(const in float averageLuminance) {
    // K is a light meter calibration constant
    return log2(averageLuminance * 100.0 / CAMERA_K);
}

void ApplyAperturePriority(const in float focalLength, const in float targetEV, inout float aperture, inout float shutterSpeed, inout float iso) {
    // Start with the assumption that we want a shutter speed of 1/f
    shutterSpeed = 1.0 / (focalLength * 1000.0);
 
    // Compute the resulting ISO if we left the shutter speed here
    iso = clamp(ComputeISO(aperture, shutterSpeed, targetEV), CAMERA_ISO_MIN, CAMERA_ISO_MAX);
 
    // Figure out how far we were from the target exposure value
    float evDiff = targetEV - ComputeEV(aperture, shutterSpeed, iso);
 
    // Compute the final shutter speed
    shutterSpeed = clamp(shutterSpeed * exp2(-evDiff), CAMERA_SHUTTER_MIN, CAMERA_SHUTTER_MAX);
}
 
void ApplyShutterPriority(const in float focalLength, const in float targetEV, inout float aperture, inout float shutterSpeed, inout float iso) {
    // Start with the assumption that we want an aperture of 4.0
    aperture = 4.0;
 
    // Compute the resulting ISO if we left the aperture here
    iso = Clamp(ComputeISO(aperture, shutterSpeed, targetEV), CAMERA_ISO_MIN, CAMERA_ISO_MAX);
 
    // Figure out how far we were from the target exposure value
    float evDiff = targetEV - ComputeEV(aperture, shutterSpeed, iso);
 
    // Compute the final aperture
    const float sqrt2 = sqrt(2.0f);
    aperture = clamp(aperture * pow(sqrt2, evDiff), CAMERA_APERTURE_MIN, CAMERA_APERTURE_MAX);
}
 
void ApplyProgramAuto(const in float focalLength, const in float targetEV, inout float aperture, inout float shutterSpeed, inout float iso)
{
    // Start with the assumption that we want an aperture of 4.0
    aperture = 4.0f;
 
    // Start with the assumption that we want a shutter speed of 1/f
    shutterSpeed = 1.0f / (focalLength * 1000.0f);
 
    // Compute the resulting ISO if we left both shutter and aperture here
    iso = Clamp(ComputeISO(aperture, shutterSpeed, targetEV), CAMERA_ISO_MIN, CAMERA_ISO_MAX);
 
    // Apply half the difference in EV to the aperture
    float evDiff = targetEV - ComputeEV(aperture, shutterSpeed, iso);
    aperture = Clamp(aperture * powf(Sqrt(2.0f), evDiff * 0.5f), CAMERA_APERTURE_MIN, CAMERA_APERTURE_MAX);
 
    // Apply the remaining difference to the shutter speed
    evDiff = targetEV - ComputeEV(aperture, shutterSpeed, iso);
    shutterSpeed = Clamp(shutterSpeed * powf(2.0f, -evDiff), CAMERA_SHUTTER_MIN, CAMERA_SHUTTER_MAX);
}
