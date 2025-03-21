from array import array
import reprlib
import math
import numbers
import functools
import operator

class Vector:
    typecode = 'd'

    def __init__(self, components):
        self._components = array(self.typecode, components)

    def __iter__(self):
        return iter(self._components)

    def __repr__(self):
        components = reprlib.repr(self._components)
        components = components[components.find('['):-1]
        return 'Vector({})'.format(components)

    def __str__(self):
        return str(tuple(self))

    def __bytes__(self):
        return (bytes([ord(self.typecode)]) +
                bytes(self._components))

    def __eq__(self, other):
        return tuple(self) == tuple(other)

    def __abs__(self):
        return math.sqrt(sum(x*x for x in self))

    def __bool__(self):
        return bool(abs(self))

    def __len__(self):
        return len(self._components)

    def __getitem__(self, index):
        # return self._components[index]  # not ideal, returns array
        cls = type(self)
        if isinstance(index, slice):
            return cls(self._components[index])
        elif isinstance(index, numbers.Integral):
            return self._components[index]
        else:
            msg = '{cls.__name__} indices must be integers'
            raise TypeError(msg.format(cls=cls))

    shortcut_names = 'xyzt'

    def __getattr__(self, name):
        cls = type(self)
        if len(name) == 1:
            pos = cls.shortcut_names.find(name)
            if 0 <= pos < len(self._components):
                return self._components[pos]
        msg = '{.__name__!r} object has no attribute {!r}'
        raise AttributeError(msg.format(cls, name))

    def __setattr__(self, name, value):
        cls = type(self)
        if len(name) == 1:
            if name in cls.shortcut_names:
                error = 'readonly attribute {attr_name!r}'
            elif name.islower():
                error = "can't set attributes 'a' to 'z' in {cls_name!r}"
            else:
                error = ''

            if error:
                msg.format(cls_name=cls.__name__, attr_name=name)
        super().__setattr__(name, value)

    def __hash__(self):
        hashes = map(hash, self._components)
        return functools.reduce(operator.xor, hashes, 0)

    @classmethod
    def frombytes(cls, octets):
        typecode = chr(octets[0])
        memv = memoryview(octets[1:]).cast(typecode)
        return cls(memv)

if __name__ == "__main__":
    v = Vector(range(100))
    print(f"Repr is: {repr(v)}")
    print(f"Str is: {str(v)}")
    print(f"Bytes is: {bytes(v)}")
    print(f"From Bytes is: {Vector.frombytes(bytes(v))}")
    print(f"Bool: {bool(v)}")
    print(f"Len: {len(v)}")
    for index in (32, slice(1,10,3)):
        print(f"Getitem {index}: {v[index]}")

    for attr in 'xyzt':
        print(f"Gettattrs {attr}: {v.__getattr__(attr)}")

    v.new_attr = "OOY"
    print(f"Setattr value: {v.new_attr}")
    print(f"Hashed: {hash(v)}")
