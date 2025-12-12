#ifndef GLOBAL_OS_AI_H
#define GLOBAL_OS_AI_H

#include "types.h"

#define AI_MAX_INPUTS 4
#define AI_MAX_NEURONS 8

struct ai_layer {
    u32 inputs;
    u32 outputs;
    float weights[AI_MAX_NEURONS][AI_MAX_NEURONS];
    float bias[AI_MAX_NEURONS];
};

struct ai_model {
    struct ai_layer hidden;
    struct ai_layer output;
    float learning_rate;
};

void ai_init(struct ai_model *model);
void ai_forward(struct ai_model *model, const float *input, float *out);
void ai_train(struct ai_model *model, const float *input, const float *target);

#endif /* GLOBAL_OS_AI_H */
