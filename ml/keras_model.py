"""
TensorFlow / Keras Reference Implementation of MobileNetV2 with CBAM Attention.
Academic Architecture for SAR-CLD-2024 Cotton Guard Specification.
"""

import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'

import tensorflow as tf
import keras
from keras import layers

class ChannelAttention(layers.Layer):
    """Keras Channel Attention Module using Average and Max Pooling."""
    def __init__(self, ratio: int = 16, **kwargs):
        super().__init__(**kwargs)
        self.ratio = ratio

    def build(self, input_shape):
        channel = input_shape[-1]
        self.shared_dense_one = layers.Dense(
            max(1, channel // self.ratio),
            activation='relu',
            kernel_initializer='he_normal',
            use_bias=True,
            bias_initializer='zeros'
        )
        self.shared_dense_two = layers.Dense(
            channel,
            kernel_initializer='he_normal',
            use_bias=True,
            bias_initializer='zeros'
        )
        super().build(input_shape)

    def call(self, inputs):
        avg_pool = layers.GlobalAveragePooling2D(keepdims=True)(inputs)
        avg_pool = self.shared_dense_one(avg_pool)
        avg_pool = self.shared_dense_two(avg_pool)

        max_pool = layers.GlobalMaxPooling2D(keepdims=True)(inputs)
        max_pool = self.shared_dense_one(max_pool)
        max_pool = self.shared_dense_two(max_pool)

        cbam_feature = keras.activations.sigmoid(avg_pool + max_pool)
        return inputs * cbam_feature

    def compute_output_shape(self, input_shape):
        return input_shape

    def get_config(self):
        config = super().get_config()
        config.update({"ratio": self.ratio})
        return config


class SpatialAttention(layers.Layer):
    """Keras Spatial Attention Module using Channel Mean and Max Projection."""
    def __init__(self, kernel_size: int = 7, **kwargs):
        super().__init__(**kwargs)
        self.kernel_size = kernel_size
        self.conv = layers.Conv2D(
            filters=1,
            kernel_size=kernel_size,
            strides=1,
            padding='same',
            activation='sigmoid',
            kernel_initializer='he_normal',
            use_bias=False
        )

    def call(self, inputs):
        avg_pool = keras.ops.mean(inputs, axis=-1, keepdims=True)
        max_pool = keras.ops.max(inputs, axis=-1, keepdims=True)
        concat = keras.ops.concatenate([avg_pool, max_pool], axis=-1)
        cbam_feature = self.conv(concat)
        return inputs * cbam_feature

    def compute_output_shape(self, input_shape):
        return input_shape

    def get_config(self):
        config = super().get_config()
        config.update({"kernel_size": self.kernel_size})
        return config


class CBAMBlock(layers.Layer):
    """Convolutional Block Attention Module (Channel Attention followed by Spatial Attention)."""
    def __init__(self, ratio: int = 16, kernel_size: int = 7, **kwargs):
        super().__init__(**kwargs)
        self.ratio = ratio
        self.kernel_size = kernel_size
        self.channel_att = ChannelAttention(ratio=ratio)
        self.spatial_att = SpatialAttention(kernel_size=kernel_size)

    def call(self, inputs):
        x = self.channel_att(inputs)
        x = self.spatial_att(x)
        return x

    def compute_output_shape(self, input_shape):
        return input_shape

    def get_config(self):
        config = super().get_config()
        config.update({"ratio": self.ratio, "kernel_size": self.kernel_size})
        return config


def build_mobilenetv2_baseline_keras(num_classes: int = 7, input_shape: tuple = (224, 224, 3)):
    """
    Constructs the baseline MobileNetV2 reference model:
    Input -> MobileNetV2 Backbone -> GlobalAveragePooling2D -> Dropout(0.2) -> Dense(num_classes).
    """
    inputs = keras.Input(shape=input_shape, name="input")
    base_model = keras.applications.MobileNetV2(
        input_shape=input_shape,
        include_top=False,
        weights='imagenet'
    )
    features = base_model(inputs)
    x = layers.GlobalAveragePooling2D(name="global_avg_pool")(features)
    x = layers.Dropout(0.2, name="dropout")(x)
    outputs = layers.Dense(num_classes, activation='softmax', name="classification_head")(x)

    model = keras.Model(inputs=inputs, outputs=outputs, name="MobileNetV2_Baseline_CottonGuard")
    return model, base_model


def build_mobilenetv2_cbam_keras(num_classes: int = 7, input_shape: tuple = (224, 224, 3)):
    """
    Constructs the Proposed MobileNetV2 + CBAM Architecture:
    Input -> MobileNetV2 Backbone -> CBAM Block -> GlobalAveragePooling2D -> Dropout(0.2) -> Dense(num_classes).
    """
    inputs = keras.Input(shape=input_shape, name="input")
    base_model = keras.applications.MobileNetV2(
        input_shape=input_shape,
        include_top=False,
        weights='imagenet'
    )
    features = base_model(inputs)
    attended_features = CBAMBlock(ratio=16, kernel_size=7, name="cbam_block")(features)
    x = layers.GlobalAveragePooling2D(name="global_avg_pool")(attended_features)
    x = layers.Dropout(0.2, name="dropout")(x)
    outputs = layers.Dense(num_classes, activation='softmax', name="classification_head")(x)

    model = keras.Model(inputs=inputs, outputs=outputs, name="MobileNetV2_CBAM_CottonGuard")
    return model, base_model


if __name__ == "__main__":
    print("Building TensorFlow/Keras MobileNetV2 + CBAM Architecture...")
    model, base = build_mobilenetv2_cbam_keras()
    model.summary(line_length=100)
    print("Keras MobileNetV2-CBAM successfully constructed.")
