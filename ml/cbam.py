"""
Convolutional Block Attention Module (CBAM) for Attention-Based CNN in Cotton Guard.
Implements Channel Attention and Spatial Attention sub-modules compatible with MobileNetV2.
"""

import torch
import torch.nn as nn

class ChannelAttention(nn.Module):
    """Channel Attention Module: Explores inter-channel relationships of features."""

    def __init__(self, in_planes: int, ratio: int = 16):
        super(ChannelAttention, self).__init__()
        self.avg_pool = nn.AdaptiveAvgPool2d(1)
        self.max_pool = nn.AdaptiveMaxPool2d(1)

        reduced_planes = max(1, in_planes // ratio)
        self.fc1 = nn.Conv2d(in_planes, reduced_planes, 1, bias=False)
        self.relu1 = nn.ReLU()
        self.fc2 = nn.Conv2d(reduced_planes, in_planes, 1, bias=False)
        self.sigmoid = nn.Sigmoid()

    def forward(self, x):
        avg_out = self.fc2(self.relu1(self.fc1(self.avg_pool(x))))
        max_out = self.fc2(self.relu1(self.fc1(self.max_pool(x))))
        out = avg_out + max_out
        return self.sigmoid(out)

class SpatialAttention(nn.Module):
    """Spatial Attention Module: Explores inter-spatial relationships of features."""

    def __init__(self, kernel_size: int = 7):
        super(SpatialAttention, self).__init__()
        padding = kernel_size // 2
        self.conv1 = nn.Conv2d(2, 1, kernel_size, padding=padding, bias=False)
        self.sigmoid = nn.Sigmoid()

    def forward(self, x):
        avg_out = torch.mean(x, dim=1, keepdim=True)
        max_out, _ = torch.max(x, dim=1, keepdim=True)
        merged = torch.cat([avg_out, max_out], dim=1)
        out = self.conv1(merged)
        return self.sigmoid(out)

class CBAM(nn.Module):
    """
    Combined Convolutional Block Attention Module.
    Refines input feature maps sequentially along Channel and Spatial dimensions.
    """

    def __init__(self, in_planes: int, ratio: int = 16, kernel_size: int = 7):
        super(CBAM, self).__init__()
        self.ca = ChannelAttention(in_planes, ratio)
        self.sa = SpatialAttention(kernel_size)

    def forward(self, x):
        # 1. Channel Attention refinement
        x_ca = self.ca(x) * x
        # 2. Spatial Attention refinement
        x_sa = self.sa(x_ca) * x_ca
        return x_sa

class MobileNetV2CBAM(nn.Module):
    """
    Academic Proposed Architecture:
    Input -> MobileNetV2 Backbone -> CBAM Attention Module -> GAP -> Dropout -> Linear(7).
    """

    def __init__(self, num_classes: int = 7, pretrained: bool = True):
        super(MobileNetV2CBAM, self).__init__()
        import torchvision.models as models
        weights = models.MobileNet_V2_Weights.DEFAULT if pretrained else None
        base = models.mobilenet_v2(weights=weights)

        # Feature extractor up to last bottleneck block (output channels: 1280)
        self.features = base.features
        self.cbam = CBAM(in_planes=1280, ratio=16)
        self.gap = nn.AdaptiveAvgPool2d(1)
        self.classifier = nn.Sequential(
            nn.Dropout(p=0.2),
            nn.Linear(1280, num_classes)
        )

    def forward(self, x):
        feats = self.features(x)
        attended_feats = self.cbam(feats)
        pooled = self.gap(attended_feats)
        flattened = torch.flatten(pooled, 1)
        logits = self.classifier(flattened)
        return logits
