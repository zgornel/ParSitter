from array import array
import math

class Vector2d:
    typecode = 'd'

    def __init__(self, x, y):
        self.x = float(x)
        self.y = float(y)

    def __iter__(self):
        return (i for i in (self.x, self.y))

    def __repr__(self):
        class_name = type(self).__name__
        return f"{class_name}({repr(self.x)},{repr(self.y)})"

    def __str__(self):
        return str(tuple(self))

    def __bytes__(self):
        return (bytes([ord(self.typecode)]) +
                bytes(array(self.typecode, self)))

    def __eq__(self, other):
        return tuple(self) == tuple(other)

    def __abs__(self):
        return math.hypot(self.x, self.y)

    def __bool__(self):
        return bool(abs(self))

    @classmethod
    def frombytes(cls, octets):
        typecode = chr(octets[0])
        memv = memoryview(octets[1:]).cast(typecode)
        return cls(*memv)

if __name__ == "__main__":
    v = Vector2d(1,2)
    print(f"Repr is: {repr(v)}")
    print(f"Str is: {str(v)}")
    print(f"Bytes is: {bytes(v)}")
    print(f"From Bytes is: {Vector2d.frombytes(bytes(v))}")
    print(f"Bool: {bool(v)}")
