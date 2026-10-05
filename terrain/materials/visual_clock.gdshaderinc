#ifndef VISUAL_CLOCK_INCLUDED
#define VISUAL_CLOCK_INCLUDED
// Negative in gameplay: preserve the engine clock and its CPU buoyancy mirror.
// A review harness may pin a frame without changing production time semantics.
global uniform float review_visual_time;
float visual_time() { return review_visual_time < 0.0 ? TIME : review_visual_time; }
#endif
