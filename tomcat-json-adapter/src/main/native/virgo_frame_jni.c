#include <jni.h>

#include <limits.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

#include "FrameL.h"

static void throw_runtime(JNIEnv *env, const char *message) {
    jclass runtime_class = (*env)->FindClass(env, "java/lang/RuntimeException");
    if (runtime_class != NULL) {
        (*env)->ThrowNew(env, runtime_class, message == NULL ? "Native error" : message);
    }
}

static char *copy_jstring(JNIEnv *env, jstring value) {
    const char *utf = NULL;
    char *copy = NULL;

    if (value == NULL) {
        return NULL;
    }

    utf = (*env)->GetStringUTFChars(env, value, NULL);
    if (utf == NULL) {
        return NULL;
    }

    {
        size_t length = strlen(utf);
        copy = (char *) malloc(length + 1U);
        if (copy != NULL) {
            memcpy(copy, utf, length + 1U);
        }
    }
    (*env)->ReleaseStringUTFChars(env, value, utf);
    if (copy == NULL) {
        throw_runtime(env, "Unable to allocate native string buffer.");
    }
    return copy;
}

static jobject build_slice(JNIEnv *env, const char *unit, jlong start_gps, jint step_seconds, jint sample_count, const double *values) {
    jclass slice_class = NULL;
    jmethodID ctor = NULL;
    jstring unit_value = NULL;
    jdoubleArray value_array = NULL;
    jobject slice = NULL;

    slice_class = (*env)->FindClass(env, "org/virgo/dataviewer/backend/history/JniArchiveSlice");
    if (slice_class == NULL) {
        return NULL;
    }
    ctor = (*env)->GetMethodID(env, slice_class, "<init>", "(Ljava/lang/String;JI[D)V");
    if (ctor == NULL) {
        return NULL;
    }

    if (unit != NULL) {
        unit_value = (*env)->NewStringUTF(env, unit);
        if (unit_value == NULL) {
            return NULL;
        }
    }

    value_array = (*env)->NewDoubleArray(env, sample_count);
    if (value_array == NULL) {
        return NULL;
    }
    if (sample_count > 0 && values != NULL) {
        (*env)->SetDoubleArrayRegion(env, value_array, 0, sample_count, values);
        if ((*env)->ExceptionCheck(env)) {
            return NULL;
        }
    }

    slice = (*env)->NewObject(env, slice_class, ctor, unit_value, start_gps, step_seconds, value_array);
    return slice;
}

static jobject build_empty_slice(JNIEnv *env, jlong start_gps, jint sample_count) {
    double *values = NULL;
    jobject slice = NULL;
    int index;

    if (sample_count < 0) {
        throw_runtime(env, "Archive sample count cannot be negative.");
        return NULL;
    }

    values = (double *) malloc((size_t) sample_count * sizeof(double));
    if (sample_count > 0 && values == NULL) {
        throw_runtime(env, "Unable to allocate native archive buffer.");
        return NULL;
    }
    for (index = 0; index < sample_count; index++) {
        values[index] = NAN;
    }

    slice = build_slice(env, NULL, start_gps, 1, sample_count, values);
    free(values);
    return slice;
}

JNIEXPORT jlongArray JNICALL Java_org_virgo_dataviewer_backend_history_JniTrendArchiveReader_resolveBoundsNative(
        JNIEnv *env,
        jclass clazz,
        jstring trend_ffl_path) {
    char *trend_path = NULL;
    FrFile *file = NULL;
    double start = 0.0;
    double end = 0.0;
    jlongArray result = NULL;
    jlong bounds[2];

    (void) clazz;

    trend_path = copy_jstring(env, trend_ffl_path);
    if ((*env)->ExceptionCheck(env)) {
        return NULL;
    }

    file = FrFileINew(trend_path);
    free(trend_path);
    if (file == NULL) {
        throw_runtime(env, "Unable to open trend archive FFL.");
        return NULL;
    }

    start = FrFileITStart(file);
    end = FrFileITEnd(file);
    FrFileIEnd(file);

    bounds[0] = (jlong) llround(start);
    bounds[1] = (jlong) llround(end);

    result = (*env)->NewLongArray(env, 2);
    if (result == NULL) {
        return NULL;
    }
    (*env)->SetLongArrayRegion(env, result, 0, 2, bounds);
    return result;
}

JNIEXPORT jobject JNICALL Java_org_virgo_dataviewer_backend_history_JniTrendArchiveReader_readRawSeriesNative(
        JNIEnv *env,
        jclass clazz,
        jstring trend_ffl_path,
        jstring channel_name,
        jlong start_gps,
        jlong duration_seconds) {
    char *trend_path = NULL;
    char *channel = NULL;
    FrFile *file = NULL;
    FrVect *vect = NULL;
    jobject slice = NULL;
    double *values = NULL;
    jint sample_count = 0;
    jint step_seconds = 1;
    jlong series_start_gps = start_gps;
    int index;

    (void) clazz;

    if (duration_seconds < 0 || duration_seconds > INT_MAX) {
        throw_runtime(env, "Requested archive span is too large for JNI history access.");
        return NULL;
    }

    trend_path = copy_jstring(env, trend_ffl_path);
    channel = copy_jstring(env, channel_name);
    if ((*env)->ExceptionCheck(env)) {
        free(trend_path);
        free(channel);
        return NULL;
    }

    file = FrFileINew(trend_path);
    free(trend_path);
    if (file == NULL) {
        free(channel);
        throw_runtime(env, "Unable to open trend archive FFL.");
        return NULL;
    }

    vect = FrFileIGetVAdc(file, channel, (double) start_gps, (double) duration_seconds, 1);
    free(channel);

    if (vect == NULL) {
        slice = build_empty_slice(env, start_gps, (jint) duration_seconds);
        FrFileIEnd(file);
        return slice;
    }

    FrVectSetMissingValues(vect, NAN);

    if (vect->nData > (FRULONG) INT_MAX) {
        FrVectFree(vect);
        FrFileIEnd(file);
        throw_runtime(env, "Archive vector is too large for JNI history access.");
        return NULL;
    }

    sample_count = (jint) vect->nData;
    if (vect->dx != NULL) {
        int computed_step = (int) llround(vect->dx[0]);
        if (computed_step > 0) {
            step_seconds = (jint) computed_step;
        }
    }
    series_start_gps = (jlong) llround(vect->GTime);

    values = (double *) malloc((size_t) sample_count * sizeof(double));
    if (sample_count > 0 && values == NULL) {
        FrVectFree(vect);
        FrFileIEnd(file);
        throw_runtime(env, "Unable to allocate native archive vector.");
        return NULL;
    }

    for (index = 0; index < sample_count; index++) {
        double value = FrVectGetValueI(vect, (FRULONG) index);
        values[index] = isfinite(value) ? value : NAN;
    }

    slice = build_slice(env, vect->unitY, series_start_gps, step_seconds, sample_count, values);

    free(values);
    FrVectFree(vect);
    FrFileIEnd(file);
    return slice;
}
