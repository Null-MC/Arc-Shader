#version 400 compatibility

#extension GL_ARB_texture_query_levels : enable
#extension GL_EXT_gpu_shader4 : enable

#define WORLD_NETHER

#include "nether.glsl"
#include "/program/deferred6.fsh"
