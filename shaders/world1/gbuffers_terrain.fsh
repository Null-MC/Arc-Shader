#version 400 compatibility

#extension GL_ARB_gpu_shader5 : enable

#if defined PARALLAX_ENABLED && defined PARALLAX_DEPTH_WRITE
    #extension GL_ARB_conservative_depth : enable
#endif

#define WORLD_END

#include "end.glsl"
#include "/program/gbuffers_terrain.fsh"
