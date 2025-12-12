#include "../include/ai.h"
#include "../include/utils.h"

static float dot(const float *a, const float *b, u32 len) {
    float acc = 0.0f;
    for (u32 i = 0; i < len; i++) {
        acc += a[i] * b[i];
    }
    return acc;
}

static float activate(float x) {
    return x > 0 ? x : 0; /* ReLU */
}

void ai_init(struct ai_model *model) {
    model->learning_rate = 0.01f;
    model->hidden.inputs = AI_MAX_INPUTS;
    model->hidden.outputs = AI_MAX_NEURONS;
    model->output.inputs = AI_MAX_NEURONS;
    model->output.outputs = 2;
    memset(model->hidden.weights, 0, sizeof(model->hidden.weights));
    memset(model->output.weights, 0, sizeof(model->output.weights));
    memset(model->hidden.bias, 0, sizeof(model->hidden.bias));
    memset(model->output.bias, 0, sizeof(model->output.bias));
}

void ai_forward(struct ai_model *model, const float *input, float *out) {
    float hidden[AI_MAX_NEURONS] = {0};
    for (u32 i = 0; i < model->hidden.outputs; i++) {
        hidden[i] = model->hidden.bias[i];
        hidden[i] += dot(input, model->hidden.weights[i], model->hidden.inputs);
        hidden[i] = activate(hidden[i]);
    }
    for (u32 o = 0; o < model->output.outputs; o++) {
        out[o] = model->output.bias[o];
        out[o] += dot(hidden, model->output.weights[o], model->output.inputs);
    }
}

void ai_train(struct ai_model *model, const float *input, const float *target) {
    float out[2];
    ai_forward(model, input, out);
    for (u32 o = 0; o < model->output.outputs; o++) {
        float error = target[o] - out[o];
        for (u32 i = 0; i < model->output.inputs; i++) {
            model->output.weights[o][i] += model->learning_rate * error * input[i];
        }
        model->output.bias[o] += model->learning_rate * error;
    }
}
