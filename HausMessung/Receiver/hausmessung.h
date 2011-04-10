struct payload_data {
    byte typ;
    byte id;    // temp sensor: 0..255
    union {
      struct {
        int temp;   // temperature * 100
        char name[20];
      } temperatur;
      struct {
        int watt;
        unsigned long count;
        unsigned long transmittcount;
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

