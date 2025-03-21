from vectors import vector2d

def main():
    print("Hello from test-project!")
    v = vector2d.Vector2d(1,2)
    print(f"Repr is: {repr(v)}")
    print(f"Str is: {str(v)}")
    print(f"Bytes is: {bytes(v)}")
    print(f"From Bytes is: {vector2d.Vector2d.frombytes(bytes(v))}")
    print(f"Bool: {bool(v)}")


if __name__ == "__main__":
    main()
