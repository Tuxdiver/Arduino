struct payload_data {
    byte typ; // typ = 1: temp, 2: strom
    byte id; // sensor id: 0..255
    union {
      struct {
        float temp; // temperature * 100
        char name[20];
      } temperatur;
      struct {
        int watt;
        unsigned long count;
        unsigned long tx_count;
      } strom;
    } data;
};


// no-cost stream operator as described at
// http://sundial.org/arduino/?page_id=119
template<class T>
inline Print &operator <<(Print &obj, T arg)
{
    obj.print(arg);
    return obj;
}

