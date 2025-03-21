CC=gcc
CFLAGS = -march=native -g -Wall -I.
TARGET=test_pass_value
LIB=test_lib
$(TARGET): $(TARGET).o $(LIB).o
	$(CC) $(CFLAGS) -o $(TARGET) $(TARGET).o $(LIB).o

clean: 
	$(RM) $(TARGET) $(TARGET).o $(LIB).o *~
