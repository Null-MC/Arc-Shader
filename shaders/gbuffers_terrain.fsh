#version 400 compatibility

#extension GL_ARB_gpu_shader5 : enable

#if defined PARALLAX_ENABLED && defined PARALLAX_DEPTH_WRITE
    #extension GL_ARB_conservative_depth : enable
#endif

#include "overworld.glsl"
#include "program/gbuffers_terrain.fsh"
