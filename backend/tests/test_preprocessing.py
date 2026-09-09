import numpy as np

from app.preprocessing.pipeline import resize, TARGET_SIZE


def test_resize_produces_target_size():
    dummy = np.zeros((200, 300), dtype=np.uint8)
    out = resize(dummy)
    assert out.shape[:2] == TARGET_SIZE
